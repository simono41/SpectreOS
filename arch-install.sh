#!/usr/bin/env bash
#
set -ex

clear

git config --global credential.helper store
arch=$(uname -m)
repo=spectreos
repo1=shell-scripte-code
cache=/var/cache/pacman/pkg/
repo_url="https://git.spectreos.de/simono41/SpectreOS/raw/master/repo.sh"

if cat /etc/passwd | grep "x:1000" > /dev/null; then
    tempuser=$(cat /etc/passwd | grep "x:1000" | awk '{print $1}')
    user=${tempuser%%:*}
else
    user=$(whoami)
fi

#fastinstall arch-install fastinstall ${name} ${Partition} ${boot} ${device} ${dateisystem} ${raid} ${swap} ${swapspeicher} ${swapverschluesselung} ${offline} ${autodisk} ${autodiskdevice} ${autostartdesktop} ${autologin} ${verschluesselung} ${usbkey} ${usbkeydevice} ${extraparameter} ${skipcheck} ${nvidia} ${nopassword}

echo "$(date "+%Y%m%d-%H%M%S")"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    # while-schleife
    while (( "$#" ))
    do
        echo ${1}
        startparameter="${startparameter}${1} "
        shift
    done
    sudo "${0}" "${startparameter}" 2>&1 | tee /home/${user}/install.log
    exit 0
fi
echo "Logged in as root"

function minimalinstallation() {
    cp -v /opt/${repo}/mirrorlist* /etc/pacman.d/
    pacstrap -c -d -G -C /opt/${repo}/pacman.conf -M ${mountpoint} $(cat /opt/${repo}/packages.txt)

    # hooks
    cp -v /opt/${repo}/configs/install/* ${mountpoint}/usr/lib/initcpio/install/
    cp -v /opt/${repo}/configs/hooks/* ${mountpoint}/usr/lib/initcpio/hooks/
    cp -v /opt/${repo}/configs/script-hooks/* ${mountpoint}/usr/lib/initcpio/

    mkdir -p ${mountpoint}/etc/pacman.d/hooks
    cp -v /opt/${repo}/configs/pacman-hooks/* ${mountpoint}/etc/pacman.d/hooks/
    cp -v /opt/${repo}/pacman.conf ${mountpoint}/etc/pacman.conf
    cp -v /opt/${repo}/mirrorlist* ${mountpoint}/etc/pacman.d/
    chmod 644 -R ${mountpoint}etc/pacman.d/mirrorlist*

    cp /opt/${repo}/scripts/update.sh ${mountpoint}/usr/bin/update-script
    chmod +x ${mountpoint}/usr/bin/update-script
    if ! arch-chroot ${mountpoint} /usr/bin/update-script; then
        echo "Aktualisierung nicht erfolgreich!!!"
    fi
}

function gitclone() {

    # Lade das Failback herunter falls nicht vorhanden
    if ! [ -f "/usr/bin/repo" ]; then curl -o /usr/bin/repo "${repo_url}"; fi

    # Aktualisiere die Repositiories
    # Überprüfe ob das GIT Repo überhaupt vorhanden ist, sonst verwende das Failback
    if [ -f "/opt/${repo}/repo.sh" ]; then /opt/${repo}/repo.sh; else /usr/bin/repo; fi

    # Lese die Umgebungsvariablen neu
    source /etc/environment

    if ! [ -f "/usr/bin/git" ]; then pacmanconf; fi

    # SSH 1/2
    git config --global credential.helper store
    git config --global core.editor "nano"
    git config --global user.email "user1@spectreos.de"
    git config --global user.name "user1"
    git config --global push.default simple
    git config --global pull.rebase true
    if [ -d "/opt/${repo}" ]; then
        echo "${repo} existiert bereits!!!"
        cd /opt/${repo}
        git checkout ${arch}
        if ! git remote set-url origin ${WEBADDRESS_OS}; then
            git remote add origin ${WEBADDRESS_OS}
        fi
        git pull
    else
        git clone -b ${arch} ${WEBADDRESS_OS} /opt/${repo}
    fi
    if [ -d "/opt/${repo1}" ]; then
        echo "${repo1} existiert bereits!!!"
        cd /opt/${repo1}
        if ! git remote set-url origin ${WEBADDRESS_OS}; then
            git remote add origin ${WEBADDRESS_OS}
        fi
        git pull
    else
        git clone ${WEBADDRESS_SCRIPTE} /opt/${repo1}
    fi
    cd /
}

function secureumount() {
    echo "unmounte alle lvms!!!"
    if vgchange -an; then echo "Alle Physikalischen Volumen wurde erfolgreich entbunden :-D"; fi

    if [ "${dateisystem}" == "btrfs" ]; then
        if cat /proc/mounts | grep ${mountpoint} > /dev/null; then
            umount ${mountpoint}/boot
            btrfs filesystem df ${mountpoint}
            echo "umount!!!"
            umount ${mountpoint}/home
            umount ${mountpoint}/opt
            umount ${mountpoint}/var/cache/pacman/pkg
            umount ${mountpoint}/var/lib
            # custom-mounts
            for wort in ${mountsnaps}
            do
                if cat /proc/mounts | grep ${mountpoint}${wort} > /dev/null; then
                    umount ${mountpoint}${wort}
                fi
            done
            umount ${mountpoint}
            umount /mnt/btrfs-root
            #umount -R /mnt
        fi
    elif [ "${dateisystem}" == "ext4" ]; then

        if cat /proc/mounts | grep ${mountpoint}/boot > /dev/null; then
            umount ${mountpoint}/boot
        fi

        if cat /proc/mounts | grep ${mountpoint} > /dev/null; then
            umount ${mountpoint}
        fi
    fi
    echo "unmounte nochmal alle lvms!!!"
    if vgchange -an; then echo "Alle Physikalischen Volumen wurde erfolgreich entbunden :-D"; fi

    if fdisk -l | grep "${deviceluks}" > /dev/null; then
        read -p "Should ${deviceluks} be removed? [Y/n] : " cryptremove
        if [ "${cryptremove}" != "n" ]; then
            if ! cryptsetup remove ${deviceluks}; then umount ${deviceluks}; fi
        fi
    fi

    if [ "${olddeviceluks}" != "" ]; then
        if fdisk -l | grep "${olddeviceluks}" > /dev/null; then
            read -p "Should ${olddeviceluks} be removed? [Y/n] : " cryptremove
            if [ "${cryptremove}" != "n" ]; then
                if ! cryptsetup remove ${olddeviceluks}; then umount ${deviceluks}; fi
            fi
        fi
    fi

    if fdisk -l | grep "/dev/mapper/${deviceluksname}" > /dev/null; then
        read -p "Should /dev/mapper/${deviceluksname} be removed? [Y/n] : " cryptremove
        if [ "${cryptremove}" != "n" ]; then
            if ! cryptsetup remove /dev/mapper/${deviceluksname}; then umount ${deviceluks}; fi
        fi
    fi

    if fdisk -l | grep "/dev/mapper/luks0" > /dev/null; then
        read -p "Should /dev/mapper/luks0 be removed? [Y/n] : " cryptremove
        if [ "${cryptremove}" != "n" ]; then
            if ! cryptsetup remove /dev/mapper/luks0; then umount ${deviceluks}; fi
        fi
    fi

    if fdisk -l | grep "/dev/mapper/luks1" > /dev/null; then
        read -p "Should /dev/mapper/luks1 be removed? [Y/n] : " cryptremove
        if [ "${cryptremove}" != "n" ]; then
            if ! cryptsetup remove /dev/mapper/luks1; then umount ${olddeviceluks}; fi
        fi
    fi

    if fdisk -l | grep "cryptsetup remove /dev/mapper/main-root" > /dev/null; then
        read -p "Should /dev/mapper/main-root be removed? [Y/n] : " cryptremove
        if [ "${cryptremove}" != "n" ]; then
            cryptsetup remove /dev/mapper/main-root
        fi
    fi

    if cat /proc/mounts | grep ${device}${m2ssd}1 > /dev/null; then
        umount ${device}${m2ssd}1
    fi

    if [ -n "${usbkeydevice}" ]; then
        if cat /proc/mounts | grep ${usbkeydevice} > /dev/null; then
            umount ${usbkeydevice}
        fi
    fi

    safeumount "${device}${efipartitionnummer}"
    safeumount "${device}${bootpartitionnummer}"
    if [ "${swap}" != "n" ]; then safeumount "${device}${swappartitionnummer}"; fi
    safeumount "${device}${rootpartitionnummer}"

    if cat /proc/mounts | grep /mnt > /dev/null; then umount /mnt; fi

}

function formatencrypt() {
    if [ "${verschluesselung}" == "y" ]; then
        if [ "y" != "${lvmsupport}" ]; then
            echo 'unmounte alle lvms!!!'
            vgchange -an
        fi
        echo "Please write big YES"
        cryptsetup -c aes-xts-plain64 -y -s 512 luksFormat ${device}${rootpartitionnummer}
        mountencrypt
    fi

}

function mountencrypt() {
    if [ "${verschluesselung}" == "y" ]; then
        cryptsetup luksOpen ${device}${rootpartitionnummer} ${deviceluksname}
    fi
    if [ "y" == "${lvmsupport}" ]; then
        mountlvm
    fi
}

function partitioniere() {
    wipefs -a -f ${device}
    sgdisk -o ${device}
    if [ "${m2ssddevice}" == "y" ]; then
        sgdisk -a 2048 -n ${bootpartitionnummer: -1}::+1024K -c ${bootpartitionnummer: -1}:"BIOS Boot Partition" -t ${bootpartitionnummer: -1}:ef02 ${device}
        sgdisk -a 2048 -n ${efipartitionnummer: -1}::+1G -c ${efipartitionnummer: -1}:"EFI Boot Partition" -t ${efipartitionnummer: -1}:ef00 ${device}
        if [ "${swap}" != "n" ]; then
            sgdisk -a 2048 -n ${swappartitionnummer: -1}::+${swapspeicher} -c ${swappartitionnummer: -1}:"Linux swap" -t ${swappartitionnummer: -1}:8200 ${device}
        fi
        sgdisk -a 2048 -n ${rootpartitionnummer: -1}:: -c ${rootpartitionnummer: -1}:"Linux filesystem" -t ${rootpartitionnummer: -1}:8300 ${device}

    else
        sgdisk -a 2048 -n ${bootpartitionnummer}::+1024K -c ${bootpartitionnummer}:"BIOS Boot Partition" -t ${bootpartitionnummer}:ef02 ${device}
        sgdisk -a 2048 -n ${efipartitionnummer}::+1G -c ${efipartitionnummer}:"EFI Boot Partition" -t ${efipartitionnummer}:ef00 ${device}
        if [ "${swap}" != "n" ]; then
            sgdisk -a 2048 -n ${swappartitionnummer}::+${swapspeicher} -c ${swappartitionnummer}:"Linux swap" -t ${swappartitionnummer}:8200 ${device}
        fi
        sgdisk -a 2048 -n ${rootpartitionnummer}:: -c ${rootpartitionnummer}:"Linux filesystem" -t ${rootpartitionnummer}:8300 ${device}

    fi

    secureumount
    formatencrypt

}

function mountlvm() {
    vgchange -ay
}

function makelvm() {
    echo "unmounte alle lvms!!!"
    if vgchange -an; then echo "Alle Physikalischen Volumen wurde erfolgreich entbunden :-D"; fi

    if [ "y" == "${lvmsupport}" ]; then
        if [ "${verschluesselung}" == "y" ]; then
            pvcreate -ff /dev/mapper/${deviceluksname}
            vgcreate ${devicelvmname} /dev/mapper/${deviceluksname}
        else
            pvcreate -ff ${device}${rootpartitionnummer}
            vgcreate ${devicelvmname} ${device}${rootpartitionnummer}
        fi
        if [ "${swap}" != "n" ]; then
            lvcreate -L ${swapspeicher} -n swap ${devicelvmname}
        fi
        lvcreate -l 100%FREE -n root ${devicelvmname}
        mountlvm
    fi
}

function partitionierelvm() {
    wipefs -a -f ${device}
    sgdisk -o ${device}

    if [ "${m2ssddevice}" == "y" ]; then
        blkdiscard  ${device}
        sgdisk -a 2048 -n ${bootpartitionnummer: -1}::+1024K -c ${bootpartitionnummer: -1}:"BIOS Boot Partition" -t ${bootpartitionnummer: -1}:ef02 ${device}
        sgdisk -a 2048 -n ${efipartitionnummer: -1}::+1G -c ${efipartitionnummer: -1}:"EFI Boot Partition" -t ${efipartitionnummer: -1}:ef00 ${device}
        sgdisk -a 2048 -n ${rootpartitionnummer: -1}:: -c ${rootpartitionnummer: -1}:"Linux filesystem" -t ${rootpartitionnummer: -1}:8300 ${device}

        secureumount
        formatencrypt
        makelvm
    else
        #shred -v -n 1 ${device}
        sgdisk -a 2048 -n ${bootpartitionnummer}::+1024K -c ${bootpartitionnummer}:"BIOS Boot Partition" -t ${bootpartitionnummer}:ef02 ${device}
        sgdisk -a 2048 -n ${efipartitionnummer}::+1G -c ${efipartitionnummer}:"EFI Boot Partition" -t ${efipartitionnummer}:ef00 ${device}
        sgdisk -a 2048 -n ${rootpartitionnummer}:: -c ${rootpartitionnummer}:"Linux filesystem" -t ${rootpartitionnummer}:8300 ${device}

        secureumount
        formatencrypt
        makelvm
    fi




}

function partitionierewithoutboot() {
    if [ "${m2ssddevice}" == "y" ]; then
        if blkid -s PARTUUID -o value ${device}${rootpartitionnummer}; then
            sgdisk -d ${rootpartitionnummer: -1} ${device}
        fi
        sgdisk -a 2048 -n ${rootpartitionnummer: -1}:: -c ${rootpartitionnummer: -1}:"Linux filesystem" -t ${rootpartitionnummer: -1}:8300 ${device}

        secureumount
        formatencrypt
        makelvm
    else
        if blkid -s PARTUUID -o value ${device}${rootpartitionnummer}; then
            sgdisk -d ${rootpartitionnummer} ${device}
        fi
        sgdisk -a 2048 -n ${rootpartitionnummer}:: -c ${rootpartitionnummer}:"Linux filesyst" -t ${rootpartitionnummer}:8300 ${device}

        secureumount
        formatencrypt
        makelvm
    fi


}

function safebootloader() {

    mount ${device}${efipartitionnummer} /mnt/
    if ! [ -d "/root/bootloader" ]; then
        mkdir -p /root/bootloader
        cp -Rv /mnt/ /root/bootloader
    fi
    umount /mnt/

}

function restorebootloader() {

    cp -Rv /root/bootloader/mnt/* ${mountpoint}/boot

}

function partitionieredual() {
    if blkid -s PARTUUID -o value ${device}${efipartitionnummer}; then
        safebootloader
    fi
    #repartioniere Windows-Partition
    echo "WICHTIG!!! DIE WINDOWS PARTITION MUSS VON HAND AUS VERKLEINER WERDEN, ODER ES MUSS NOCH FREIER SPEICHER AUF DER FESTPLATTE ENTHALTEN SEIN!!!"
    if [ "${m2ssddevice}" == "y" ]; then
        if blkid -s PARTUUID -o value ${device}${rootpartitionnummer}; then
            echo "entferne partition ${device}${rootpartitionnummer}"
            sleep 5
            #parted -s ${device} rm ${rootpartitionnummer}
            sgdisk -d ${rootpartitionnummer: -1} ${device}
            sync
        fi
        if [ "${swap}" != "n" ]; then
            if blkid -s PARTUUID -o value ${device}${swappartitionnummer}; then
                sgdisk -d ${swappartitionnummer: -1} ${device}
            fi

            sgdisk -a 2048 -n ${swappartitionnummer: -1}::+${swapspeicher} -c ${swappartitionnummer: -1}:"Linux swap" -t ${swappartitionnummer: -1}:8200 ${device}
        fi

        sgdisk -a 2048 -n ${rootpartitionnummer: -1}:: -c ${rootpartitionnummer: -1}:"Linux filesystem" -t ${rootpartitionnummer: -1}:8300 ${device}

        echo "WARNING!!! CREATE NEW WINDOWS BOOTLOADER!!!"
        sleep 10

        if blkid -s PARTUUID -o value ${device}${bootpartitionnummer}; then
            sgdisk -d ${bootpartitionnummer: -1} ${device}
        fi

        sgdisk -a 2048 -n ${bootpartitionnummer: -1}::+1024K -c ${bootpartitionnummer: -1}:"BIOS Boot Partition" -t ${bootpartitionnummer: -1}:ef02 ${device}

        if blkid -s PARTUUID -o value ${device}${efipartitionnummer}; then
            sgdisk -d ${efipartitionnummer: -1} ${device}
        fi

        sgdisk -a 2048 -n ${efipartitionnummer: -1}:: -c ${efipartitionnummer: -1}:"Linux/Windows bootloader" -t ${efipartitionnummer: -1}:ef00 ${device}

    else
        if blkid -s PARTUUID -o value ${device}${rootpartitionnummer}; then
            echo "entferne partition ${device}${rootpartitionnummer}"
            sleep 5
            #parted -s ${device} rm ${rootpartitionnummer}
            sgdisk -d ${rootpartitionnummer} ${device}
            sync
        fi

        if [ "${swap}" != "n" ]; then
            if blkid -s PARTUUID -o value ${device}${swappartitionnummer}; then
                sgdisk -d ${swappartitionnummer} ${device}
            fi

            sgdisk -a 2048 -n ${swappartitionnummer}::+${swapspeicher} -c ${swappartitionnummer}:"Linux swap" -t ${swappartitionnummer}:8200 ${device}
        fi

        sgdisk -a 2048 -n ${rootpartitionnummer}:: -c ${rootpartitionnummer}:"Linux filesystem" -t ${rootpartitionnummer}:8300 ${device}

        echo "WARNING!!! CREATE NEW WINDOWS BOOTLOADER!!!"
        sleep 10

        if blkid -s PARTUUID -o value ${device}${bootpartitionnummer}; then
            sgdisk -d ${bootpartitionnummer} ${device}
        fi

        sgdisk -a 2048 -n ${bootpartitionnummer}::+1024K -c ${bootpartitionnummer}:"BIOS Boot Partition" -t ${bootpartitionnummer}:ef02 ${device}

        if blkid -s PARTUUID -o value ${device}${efipartitionnummer}; then
            sgdisk -d ${efipartitionnummer} ${device}
        fi

        sgdisk -a 2048 -n ${efipartitionnummer}:: -c ${efipartitionnummer}:"Linux/Windows bootloader" -t ${efipartitionnummer}:ef00 ${device}

    fi

    secureumount
    formatencrypt
    makelvm
}

function usbkeyinstallation() {
    mkdir -p /mnt/usb-stick
    mount ${usbkeydevice} /mnt/usb-stick
    if ! [ -f "/mnt/usb-stick/archkey" ]; then
        dd if=/dev/urandom of=/mnt/usb-stick/archkey bs=512 count=4
    fi
    cryptsetup luksAddKey ${device}${rootpartitionnummer} /mnt/usb-stick/archkey

}

function usbsecret() {

    cp /opt/${repo}/install/usbsecret ${mountpoint}/usr/lib/initcpio/install/usbsecret
    cp /opt/${repo}/hooks/usbsecret ${mountpoint}/root/usbsecret

    # hooks
    #cp install/usbsecret ${mountpoint}/usr/lib/initcpio/install/usbsecret
    #cp hooks/usbsecret ${mountpoint}/usr/lib/initcpio/hooks/usbsecret

    sed "s|%USB_UUID%|${usbsecretdeviceuuid}|g;" ${mountpoint}/root/usbsecret > ${mountpoint}/usr/lib/initcpio/hooks/usbsecret

}

function cron() {
    echo "cron-job snapshot"
    mkdir -p ${mountpoint}/var/spool/cron/
    echo -n "0 18 * * * /usr/bin/snapshot make var/cache/pacman/pkg opt home " > ${mountpoint}/var/spool/cron/root

    # custom-mounts
    for wort in ${mountsnaps}
    do
        echo -n "${wort#/*} " >> ${mountpoint}/var/spool/cron/root
    done
    echo "ROOT" >> ${mountpoint}/var/spool/cron/root

    cp /opt/${repo}/scripts/snapshot.sh ${mountpoint}/usr/bin/snapshot
    chmod 755 ${mountpoint}/usr/bin/snapshot

}

function makeswapfile() {
    #swapfile
    fallocate -l ${swapfilespeicher} ${mountpoint}/swapfile
    chmod 600 ${mountpoint}/swapfile
    mkswap ${mountpoint}/swapfile
    echo "/swapfile none swap defaults 0 0" >> ${mountpoint}/etc/fstab
}

function makebtrfsswapfile() {

    # From https://github.com/sebastian-philipp/btrfs-swapon
    cp -v /opt/${repo}/scripts/btrfs-swapon ${mountpoint}/usr/bin/btrfs-swapon
    cp -v /opt/${repo}/scripts/btrfs-swapoff ${mountpoint}/usr/bin/btrfs-swapoff
    cp -v /opt/${repo}/configs/service/btrfs-swapon.service ${mountpoint}/root/btrfs-swapon.service

    chmod +x ${mountpoint}/usr/bin/btrfs-swapon
    chmod +x ${mountpoint}/usr/bin/btrfs-swapoff

    sed "s|%swapfilespeicher%|${swapfilespeicher}|g;" ${mountpoint}/root/btrfs-swapon.service > ${mountpoint}/etc/systemd/system/btrfs-swapon.service

    arch-chroot ${mountpoint} systemctl enable btrfs-swapon

}

function safeumount() {
    echo "unmount \"${1}\""
    if cat /proc/mounts | grep "${1}" > /dev/null; then
        umount "${1}"
    fi
}

function installation {

    #boot
    echo "format"
    if [ "y" != "${noinstall}" ]; then
        mkfs.vfat -F 32 ${device}${efipartitionnummer}
        safeumount "${device}${efipartitionnummer}"
    fi

    #root
    if [ "${dateisystem}" == "btrfs" ]; then
        #mkfs.btrfs -f -L p_arch ${device}2
        if [ "y" != "${noinstall}" ]; then
            btrfsformat #btrfs
        fi
        subvolume #btrfs

    elif [ "${dateisystem}" == "ext4" ]; then
        echo "confirm with y"
        if [ "${verschluesselung}" == "y" ]; then
            if [ "y" != "${noinstall}" ]; then
                sleep 1
                mkfs.ext4 -L p_arch ${deviceluks} #ext4
                safeumount "${deviceluks}"
            fi
            mount ${deviceluks} ${mountpoint}
        else
            if [ "y" != "${noinstall}" ]; then
                mkfs.ext4 -L p_arch ${device}${rootpartitionnummer} #ext4
                safeumount "${device}${rootpartitionnummer}"
            fi
            mount ${device}${rootpartitionnummer} ${mountpoint}
        fi
        mkdir -p ${mountpoint}/boot
        mount ${device}${efipartitionnummer} ${mountpoint}/boot
    fi

    #swap
    if [ "y" != "${noinstall}" ]; then
        if [ "${swap}" != "n" ]; then
            mkswap -L p_swap ${device}${swappartitionnummer}
            swapon ${device}${swappartitionnummer}
        fi
    fi

    #installation
    if [ "${offline}" != "n" ]
    then
        if [ -f /run/archiso/bootmnt/arch/${arch}/airootfs.sfs ]; then
            echo "It is not a copytoram system."
            if [ "y" != "${noinstall}" ]; then
                unsquashfs -f -d ${mountpoint} /run/archiso/bootmnt/arch/${arch}/airootfs.sfs
            fi
        elif [ -f /run/archiso/copytoram/airootfs.sfs ]; then
            echo "It is a copytoram system."
            if [ "y" != "${noinstall}" ]; then
                unsquashfs -f -d ${mountpoint} /run/archiso/copytoram/airootfs.sfs
            fi
        else
            read -p "Where is the airootfs.sfs? Please specify the complete path or choose the online installation? [/airootfs.sfs/online] : " installationsfehler
            if [ "${installationsfehler}" == "online" ]; then
                minimalinstallation
            else
                unsquashfs -f -d ${mountpoint} ${installationsfehler}
            fi
        fi
    else
        minimalinstallation
    fi


    # module and hooks
    parameter="base udev modconf block keymap "
    #parameter="base udev autodetect keyboard keymap consolefont "
    #parameter="base systemd autodetect keyboard sd-vconsole "
    #parameter="${parameter}modconf block "

    if [ "${swap}" != "n" ]; then
        parameter="${parameter}resume "
    fi

    if [ "${verschluesselung}" == "y" ]; then
        parameter="${parameter}encrypt "
        #For Systemd Bootloader
        #parameter="${parameter}sd-encrypt "
    fi

    if [ "y" == "${lvmsupport}" ]; then
        parameter="${parameter}lvm2 "
    fi

    parameter="${parameter}filesystems "

    if [ "${dateisystem}" == "btrfs" ]; then
        if [ "${raid}" != "n" ]; then
            parameter="${parameter}btrfs "
        fi
    fi

    if [ "${usbsecret}" == "y" ]; then
        parameter="${parameter}usbsecret "
    fi

    parameter="${parameter}keyboard fsck "

    if [ "${nvidia}" == "y" ]; then
        echo "MODULES=\"amdgpu i915 nvidia\"" > ${mountpoint}/etc/mkinitcpio.conf
        echo "HOOKS=\"${parameter}\"" >> ${mountpoint}/etc/mkinitcpio.conf
        echo "COMPRESSION=\"zstd\"" >> ${mountpoint}/etc/mkinitcpio.conf
        echo "blacklist nouveau" > ${mountpoint}/etc/modprobe.d/blacklist-nouveau.conf
    else
        echo "MODULES=\"amdgpu i915 nouveau\"" > ${mountpoint}/etc/mkinitcpio.conf
        echo "HOOKS=\"${parameter}\"" >> ${mountpoint}/etc/mkinitcpio.conf
        echo "COMPRESSION=\"zstd\"" >> ${mountpoint}/etc/mkinitcpio.conf
    fi

    echo "blacklist floppy" > ${mountpoint}/etc/modprobe.d/blacklist-floppy.conf
    echo "install dell-smbios /bin/false" > ${mountpoint}/etc/modprobe.d/blacklist-dell-smbios.conf
    echo "tmpfs /tmp tmpfs defaults,size=6G 0 0" > ${mountpoint}/etc/fstab
    echo "tmpfs /dev/shm tmpfs defaults 0 0" >> ${mountpoint}/etc/fstab

    #fstab
    rootbind=$(blkid -s PARTUUID -o value ${device}${rootpartitionnummer})

    #genfstab -Up ${mountpoint} >> ${mountpoint}/etc/fstab

    if [ "${dateisystem}" == "btrfs" ]; then
        btrfsfstab #btrfs

        mkdir -p ${mountpoint}/btrfs-root
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            echo "${deviceluks} /btrfs-root/ btrfs defaults 0 0" >> ${mountpoint}/etc/fstab #btrfs
        else
            echo "PARTUUID=${rootbind} /btrfs-root/ btrfs defaults 0 0" >> ${mountpoint}/etc/fstab #btrfs
        fi
        #grep -v "/var/lib" < ${mountpoint}/etc/fstab > fstab.neu; mv fstab.neu ${mountpoint}/etc/fstab

        echo "/btrfs-root/__current/ROOT/var/lib /var/lib none bind 0 0" >> ${mountpoint}/etc/fstab #btrfs

        cron

    elif [ "${dateisystem}" == "ext4" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            echo "${deviceluks} / ext4 rw,defaults,noatime,nodiratime,discard 0 0" >> ${mountpoint}/etc/fstab #ext4
        else
            echo "PARTUUID=${rootbind} / ext4 rw,defaults,noatime,nodiratime,discard 0 0" >> ${mountpoint}/etc/fstab #ext4
        fi
    fi

    echo "tmpfs /home/${user}/.cache tmpfs noatime,nodev,nosuid,size=2G 0 0" >> ${mountpoint}/etc/fstab

    bootbind=$(blkid -s PARTUUID -o value ${device}${efipartitionnummer})

    echo -e "PARTUUID=${bootbind} /boot vfat rw,relatime 0 2" >> ${mountpoint}/etc/fstab


    if [ "${swap}" != "n" ]; then
        if [ "${swapverschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            swappartition=$(blkid -s PARTUUID -o value ${device}${swappartitionnummer})
            echo "swap PARTUUID=${swappartition} /dev/urandom swap,cipher=aes-cbc-essiv:sha256,size=256" > ${mountpoint}/etc/crypttab
            echo "/dev/mapper/swap none swap defaults 0 0" >> ${mountpoint}/etc/fstab
        else
            swappartition=$(blkid -s PARTUUID -o value ${device}${swappartitionnummer})
            echo "PARTUUID=${swappartition} swap swap sw 0 0" >> ${mountpoint}/etc/fstab
        fi
    fi

    #makeswapfile+fstab
    if [ "y" != "${noinstall}" ]; then
        if [ "${swapfile}" == "y" ]; then
            if [ "${dateisystem}" == "btrfs" ]; then
                makebtrfsswapfile
            elif [ "${dateisystem}" == "ext4" ]; then
                makeswapfile
            fi
        fi
    fi

    #hostname
    echo "${hostname}" > ${mountpoint}/etc/hostname
    echo "hostname=\"${hostname}\"" > /etc/conf.d/hostname

    # os-release
    cp /opt/${repo}/os-release ${mountpoint}/etc/

    if [ "y" != "${noinstall}" ]; then
        if [ "${usbsecret}" == "y" ]; then
            usbsecret
        fi
    fi

    if [ "y" != "${noinstall}" ]; then
        if [ "${usbkey}" == "y" ]; then
            usbkeyinstallation
        fi
    fi

    if [ "${autodisk}" == "y" ]
    then
        for wort in ${autodiskdevice}
        do
            echo "fstab ${wort} wird erstellt!!!"
            autodiskdevicedateisystem=$(blkid -s TYPE -o value ${wort})
            autodiskdevicepartuuid=$(blkid -s PARTUUID -o value ${wort})
            mkdir -p ${mountpoint}/media/${user}/${autodiskdevicepartuuid}
            echo "PARTUUID=${autodiskdevicepartuuid} /media/${user}/${autodiskdevicepartuuid} ${autodiskdevicedateisystem} defaults 0 2" >> ${mountpoint}/etc/fstab

        done


    fi

    #forbtrfssnapshots
    cp ${mountpoint}/etc/fstab ${mountpoint}/etc/fstab.default

}

function grubinstall() {

    sleep 1
    tobootdevice=$(blkid -s PARTUUID -o value ${device}${rootpartitionnummer})
    if aufloesung=$(xrandr | grep -o -E '[0-9]{3,4}\x[0-9]{3,4}' | head -1); then
        echo "Deine aufloesung ist ${aufloesung}"
    fi
    [[ -z "${aufloesung}" ]] && aufloesung=auto

    cp /opt/${repo}/configs/grub.d/10_linux ${mountpoint}/etc/grub.d/10_linux

    mkdir -p ${mountpoint}/boot/grub/themes/
    #cp -Rv /opt/${repo}/grub-config/themes/poly-light/ ${mountpoint}/boot/grub/themes/
    cp -Rv /opt/${repo}/grub-config/themes/Stylish/ ${mountpoint}/boot/grub/themes/
    cp -Rv /opt/${repo}/grub-config/themes/Vimix/ ${mountpoint}/boot/grub/themes/
    sed -i 's|GRUB_DISTRIBUTOR=.*$|GRUB_DISTRIBUTOR=\"'$repo'\"|' ${mountpoint}/etc/default/grub
    sed -i 's|GRUB_PRELOAD_MODULES=.*$|GRUB_PRELOAD_MODULES=\"part_gpt part_msdos zstd btrfs lvm\"|' ${mountpoint}/etc/default/grub

    if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
        sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*$|GRUB_CMDLINE_LINUX_DEFAULT=\"\"|' ${mountpoint}/etc/default/grub
    else
        sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*$|GRUB_CMDLINE_LINUX_DEFAULT=\"\"|' ${mountpoint}/etc/default/grub
    fi

    #sed -i 's|GRUB_BACKGROUND=.*$|GRUB_BACKGROUND=\"\/usr\/share\/grub\/background.png\"|' ${mountpoint}/etc/default/grub
    #sed -i 's|GRUB_THEME=.*$|GRUB_THEME="\/boot\/grub\/themes\/poly-light\/theme.txt"|' ${mountpoint}/etc/default/grub
    sed -i 's|#GRUB_THEME=.*$|GRUB_THEME="\/boot\/grub\/themes\/Stylish\/theme.txt"|' ${mountpoint}/etc/default/grub
    sed -i 's|GRUB_THEME=.*$|GRUB_THEME="\/boot\/grub\/themes\/Stylish\/theme.txt"|' ${mountpoint}/etc/default/grub
    #sed -i 's|GRUB_THEME=.*$|GRUB_THEME="\/boot\/grub\/themes\/Vimix\/theme.txt"|' ${mountpoint}/etc/default/grub
    #sed -i 's|#GRUB_BACKGROUND=.*$|GRUB_BACKGROUND=\"\/usr\/share\/grub\/background.png\"|' ${mountpoint}/etc/default/grub
    #sed -i 's|#GRUB_THEME=.*$|GRUB_THEME="\/boot\/grub\/themes\/poly-light\/theme.txt"|' ${mountpoint}/etc/default/grub
    sed -i 's|GRUB_GFXMODE=.*$|GRUB_GFXMODE="'$aufloesung'"|' ${mountpoint}/etc/default/grub

    if [ "y" == "${lvmsupport}" ]; then
        cryptdevicesystem="${devicelvmname}"
    elif [ "${verschluesselung}" == "y" ]; then
        cryptdevicesystem="${deviceluksname}"
    fi

    parameter=""

    if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
        rootbootsystem="${deviceluks}"
        parameter="root=${rootbootsystem} ${parameter}cryptdevice=PARTUUID=${tobootdevice}:${cryptdevicesystem} "
        echo "GRUB_ENABLE_CRYPTODISK=y" >> ${mountpoint}/etc/default/grub
    else
        rootbootsystem="$(blkid -s PARTUUID -o value ${device}${rootpartitionnummer})"
        parameter="${parameter}root=PARTUUID=${rootbootsystem} "
    fi

    if [ "${swap}" == "y" ]; then
        parameter="${parameter}resume=PARTUUID=${swappartition} "
    fi

    if [ "${usbkey}" == "y" ]; then
        parameter="${parameter}cryptkey=UUID=${usbkeyuuid}:${usbkeydateisystem}:\/archkey "
    fi

    parameter="${parameter}autostartdesktop=${autostartdesktop} lang=${lang} keytable=${keytable} tz=${tz} "

    sed -i '/GRUB_CMDLINE_LINUX=/d' ${mountpoint}/etc/default/grub
    echo "GRUB_CMDLINE_LINUX=\"${parameter}\"" >> ${mountpoint}/etc/default/grub
    echo "GRUB_DISABLE_OS_PROBER=true" >> ${mountpoint}/etc/default/grub
}

function btrfsformat() {
    sleep 1
    if [ "$raid" == "raid0" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkfs.btrfs -f -m raid0 -d raid0 ${deviceluks} ${device1}
            safeumount "${deviceluks}"
        else
            mkfs.btrfs -f -m raid0 -d raid0 ${device}${rootpartitionnummer} ${device1}
            safeumount "${device}${rootpartitionnummer}"
        fi
    elif [ "$raid" == "raid1" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkfs.btrfs -f -m raid1 -d raid1 ${deviceluks} ${device1}
            safeumount "${deviceluks}"
        else
            mkfs.btrfs -f -m raid1 -d raid1 ${device}${rootpartitionnummer} ${device1}
            safeumount "${device}${rootpartitionnummer}"
        fi
    elif [ "$raid" == "raid10" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkfs.btrfs -f -m raid10 -d raid10 ${deviceluks} ${device1}
            safeumount "${deviceluks}"
        else
            mkfs.btrfs -f -m raid10 -d raid10 ${device}${rootpartitionnummer} ${device1}
            safeumount "${device}${rootpartitionnummer}"
        fi
    else
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkfs.btrfs -f -m single ${deviceluks}
            safeumount "${deviceluks}"
        else
            mkfs.btrfs -f -m single ${device}${rootpartitionnummer}
            safeumount "${device}${rootpartitionnummer}"
        fi
    fi
    btrfs filesystem show

}

function btrfsfstab() {

    rootbind=$(blkid -s PARTUUID -o value ${device}${rootpartitionnummer})

    if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then


        echo -e "${deviceluks} / btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/ROOT 0 0" >> ${mountpoint}/etc/fstab

        echo -e "${deviceluks} /home btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/home 0 0" >> ${mountpoint}/etc/fstab
        echo -e "${deviceluks} /opt btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/opt 0 0" >> ${mountpoint}/etc/fstab
        echo -e "${deviceluks} /var/cache/pacman/pkg btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/var/cache/pacman/pkg 0 0" >> ${mountpoint}/etc/fstab

        # custom-mounts
        for wort in ${mountsnaps}
        do
            echo -e "${deviceluks} ${wort} btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current${wort} 0 0" >> ${mountpoint}/etc/fstab
        done


    else

        echo -e "PARTUUID=${rootbind} / btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/ROOT 0 0" >> ${mountpoint}/etc/fstab

        echo -e "PARTUUID=${rootbind} /home btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/home 0 0" >> ${mountpoint}/etc/fstab
        echo -e "PARTUUID=${rootbind} /opt btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/opt 0 0" >> ${mountpoint}/etc/fstab
        echo -e "PARTUUID=${rootbind} /var/cache/pacman/pkg btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/var/cache/pacman/pkg 0 0" >> ${mountpoint}/etc/fstab

        # custom-mounts
        for wort in ${mountsnaps}
        do
            echo -e "PARTUUID=${rootbind} ${wort} btrfs rw,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current${wort} 0 0" >> ${mountpoint}/etc/fstab
        done


    fi
}

function btrfsmount() {
    #[[ -z "${device}" ]] && device=${2}

    if [ "${1}" == "1" ] || [ "${1}" == "" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkdir -p /mnt/btrfs-root
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd ${deviceluks} /mnt/btrfs-root
        else
            mkdir -p /mnt/btrfs-root
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd ${device}${rootpartitionnummer} /mnt/btrfs-root
        fi
    fi
    if [ "${1}" == "2" ] || [ "${1}" == "" ]; then
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mkdir -p ${mountpoint}
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/ROOT ${deviceluks} ${mountpoint}

            mkdir -p ${mountpoint}/home
            mkdir -p ${mountpoint}/opt
            mkdir -p ${mountpoint}/var/cache/pacman/pkg
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/home ${deviceluks} ${mountpoint}/home
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/opt ${deviceluks} ${mountpoint}/opt
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/var/cache/pacman/pkg ${deviceluks} ${mountpoint}/var/cache/pacman/pkg

            # custom-mounts
            for wort in ${mountsnaps}
            do
                mkdir -p ${mountpoint}${wort}
                mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current${wort} ${deviceluks} ${mountpoint}${wort}
            done

            mkdir -p ${mountpoint}/var/lib
            mount --bind /mnt/btrfs-root/__current/ROOT/var/lib ${mountpoint}/var/lib
        else
            mkdir -p ${mountpoint}
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/ROOT ${device}${rootpartitionnummer} ${mountpoint}

            mkdir -p ${mountpoint}/home
            mkdir -p ${mountpoint}/opt
            mkdir -p ${mountpoint}/var/cache/pacman/pkg
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/home ${device}${rootpartitionnummer} ${mountpoint}/home
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/opt ${device}${rootpartitionnummer} ${mountpoint}/opt
            mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current/var/cache/pacman/pkg ${device}${rootpartitionnummer} ${mountpoint}/var/cache/pacman/pkg

            # custom-mounts
            for wort in ${mountsnaps}
            do
                mkdir -p ${mountpoint}${wort}
                mount -o defaults,noatime,nodiratime,discard,ssd,compress=zstd,subvol=__current${wort} ${device}${rootpartitionnummer} ${mountpoint}${wort}
            done

            mkdir -p ${mountpoint}/var/lib
            mount --bind /mnt/btrfs-root/__current/ROOT/var/lib ${mountpoint}/var/lib
        fi
        # boot mount
        mkdir -p ${mountpoint}/boot
        mount -t vfat ${device}${efipartitionnummer} ${mountpoint}/boot

    fi
}

function subvolume() {

    # Mount
    btrfsmount 1

    # Create
    if [ "y" != "${noinstall}" ]; then
        mkdir -p /mnt/btrfs-root/__snapshot
        mkdir -p /mnt/btrfs-root/__current
        btrfs subvolume create /mnt/btrfs-root/__current/ROOT
        btrfs subvolume create /mnt/btrfs-root/__current/home
        btrfs subvolume create /mnt/btrfs-root/__current/opt
        mkdir -p /mnt/btrfs-root/__current/var/cache/pacman
        btrfs subvolume create /mnt/btrfs-root/__current/var/cache/pacman/pkg/

        # custom-mounts
        for wort in ${mountsnaps}
        do
            mkdir -p /mnt/btrfs-root/__current${wort%/*}
            btrfs subvolume create /mnt/btrfs-root/__current${wort}
        done
    fi

    btrfs subvolume list -p /mnt/btrfs-root

    # Mount
    btrfsmount 2

}

function update() {
    #statements
    local if="${1}"
    local of="${2}"
    local execute="${3}"
    local parameters="${4}"
    if [ -f "${of}" ]
    then
        rm ${of}
    else
        echo "${of} noch nicht vorhanden!"
    fi
    /usr/bin/curl -v -C - -f ${if} > ${of}
    chmod 755 ${of}

    ${of} ${execute} ${parameters}

}

function systemdboot() {
    tobootdeviceuuid=$(blkid -s PARTUUID -o value ${device}${rootpartitionnummer})
    swappartitionpart=$(blkid -s PARTUUID -o value ${device}${swappartitionnummer})

    # zurücksetzen der parameter
    parameter=""

    if [ "${swap}" != "n" ]; then
        parameter="${parameter}resume=PARTUUID=${swappartitionpart} "
    fi
    if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
        tobootdevice=${deviceluks}
        parameter="${parameter}cryptdevice=PARTUUID=${tobootdeviceuuid}:${deviceluksname} "
        if [ "${usbkey}" == "y" ]; then
            parameter="${parameter}cryptkey=UUID=${usbkeyuuid}:${usbkeydateisystem}:/archkey "
        fi
    else
        tobootdevice="PARTUUID=${tobootdeviceuuid} "
    fi
    if [ "${dateisystem}" == "btrfs" ]; then
        parameter="${parameter}rootflags=subvol=__current/ROOT "
    fi

    if [ "${cpusucks}" != "n" ]; then
        parameter="${parameter} pci=noacpi rcu_nocbs=0-7 processor.max_cstate=1 i8042.noloop i8042.nomux i8042.nopnp i8042.reset"
    fi

    parameter="${parameter}autostartdesktop=${autostartdesktop} lang=${lang} keytable=${keytable} tz=${tz} "

    kernel="initramfs-linux.img"
    linuz="vmlinuz-linux"
    kernelback="initramfs-linux-fallback.img"

    mkdir -p ${mountpoint}/boot/EFI/systemd/
    mkdir -p ${mountpoint}/boot/EFI/BOOT/
    cp ${mountpoint}/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${mountpoint}/boot/EFI/systemd/systemd-bootx64.efi
    cp ${mountpoint}/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${mountpoint}/boot/EFI/BOOT/BOOTX64.EFI

    mkdir -p ${mountpoint}/boot/loader/entries/
    echo "title    "${repo}"" > ${mountpoint}/boot/loader/entries/arch-uefi.conf
    echo "linux    /${linuz}" >> ${mountpoint}/boot/loader/entries/arch-uefi.conf
    echo "initrd   /intel-ucode.img" >> ${mountpoint}/boot/loader/entries/arch-uefi.conf
    echo "initrd   /${kernel}" >> ${mountpoint}/boot/loader/entries/arch-uefi.conf
    echo "options  root=${tobootdevice} rw ${parameter}" >> ${mountpoint}/boot/loader/entries/arch-uefi.conf

    echo "title    "${repo}"" > ${mountpoint}/boot/loader/entries/arch-uefi-fallback.conf
    echo "linux    /${linuz}" >> ${mountpoint}/boot/loader/entries/arch-uefi-fallback.conf
    echo "initrd   /intel-ucode.img" >> ${mountpoint}/boot/loader/entries/arch-uefi-fallback.conf
    echo "initrd   /${kernelback}" >> ${mountpoint}/boot/loader/entries/arch-uefi-fallback.conf
    echo "options  root=${tobootdevice} rw ${parameter}" >> ${mountpoint}/boot/loader/entries/arch-uefi-fallback.conf

    echo "default   arch-uefi" > ${mountpoint}/boot/loader/loader.conf
    echo "timeout   1" >> ${mountpoint}/boot/loader/loader.conf

    echo "Additional boot entries are created !!!"

    arch-chroot ${mountpoint} efibootmgr -c -d ${device} -p 1 -l /EFI/systemd/systemd-bootx64.efi -L "Linux Boot Manager"

    arch-chroot ${mountpoint} efibootmgr -c -d ${device} -p 1 -l \\${linuz} -L "Arch Linux efistub" -u "initrd=/${kernel} root=${tobootdevice} rw ${parameter}"
}

function luksabfrage() {

    if [ "n" != "${verschluesselung}" ]; then
        if [ "y" == "${lvmsupport}" ]; then
            deviceluks="/dev/mapper/main-root"
            deviceluksname="luks0"
            devicelvmname="main"
        else
            deviceluks="/dev/mapper/luks0"
            deviceluksname="luks0"
            devicelvmname="luks0"
        fi
        if [ "${noinstall}" != "y" ] && fdisk -l | grep ${deviceluks} > /dev/null; then
            olddeviceluks="${deviceluks}"
            if [ "y" == "${lvmsupport}" ]; then
                deviceluks="/dev/mapper/main1-root"
                deviceluksname="luks1"
                devicelvmname="main1"
            else
                deviceluks="/dev/mapper/luks1"
                deviceluksname="luks1"
                devicelvmname="luks1"
            fi
            echo "${deviceluks} wird jetzt verwendet!!!"
        fi
    fi

}

function abfrage() {

    if [ "${fastinstallnext}" == "y" ]; then

        [[ -z "${name}" ]] && name=arch-linux

        [[ -z "${user}" ]] && user=user1

        [[ -z "${Partition}" ]] && Partition=bios

        [[ -z "${device}" ]] && device=/dev/sda

        [[ -z "${raid}" ]] && raid=n

        [[ -z "${dateisystem}" ]] && dateisystem=btrfs

        [[ -z "${swap}" ]] && swap=n

        [[ -z "${swapspeicher}" ]] && swapspeicher=8G

        [[ -z "${swapverschluesselung}" ]] && swapverschluesselung=n

        [[ -z "${autologin}" ]] && autologin=y

        [[ -z "${usbkeydevice}" ]] && usbkeydevice=/dev/sdb1

        [[ -z "${autodiskdevice}" ]] && autodiskdevice=/dev/sdb1

        [[ -z "${nvidia}" ]] && nvidia=n

        [[ -z "${cpusucks}" ]] && cpusucks=n

        [[ -z "${lvmsupport}" ]] && lvmsupport=n

        luksabfrage

        if [ "${offline}" != "n" ]
        then
            install="offline"
        else
            install="online"
        fi

        if [ "${device}" == "/dev/nvme0n1" ]; then
            m2ssddevice=y
        fi

        echo "Überspringe die Konfiguration wegen dem fastinstall Parameter!!!"
        echo "Sie können die Überprüfung mit skipcheck überspringen!!!"
    else

        # youre virtual name
        read -p "What's your name?: " name
        [[ -z "${name}" ]] && name=arch-linux

        # youre folder and login name
        read -p "What's your username?: " user
        [[ -z "${user}" ]] && user=user1

        # Partionierung
        # UEFI oder Legacy-BIOS
        echo ""
        echo "UEFI = Unified Extensible Firmware Interface"
        echo "Recommended for newer PCs"
        echo "IMPORTANT FOR THIS MUST BE SELECTED IN THE BOAT MENU THE UEFI USB STICK OTHERWISE CAN NOT BE CREATED A UEFI BOAT ENTRY !!!"
        echo ""
        echo "BIOS = basic input/output system"
        echo "Recommended for old PCs and portable USB sticks "
        echo ""
        echo "Please write down the entries: D !!!"
        echo "For each yes you have to make a y and for every no an n, unless it is interpreted differently!!!"
        echo ""
        if mount | grep efi > /dev/null && [ -d /sys/firmware/efi/efivars/ ]; then
            echo "System supports UEFI"
            read -p "How would you like to have your hard drive partitioned?: [UEFI/bios] " Partition
            [[ -z "${Partition}" ]] && Partition=uefi
        else
            echo "System supports not UEFI"
            read -p "How would you like to have your hard drive partitioned?: [uefi/BIOS] " Partition
            [[ -z "${Partition}" ]] && Partition=bios
        fi

        firstdevice=$(fdisk -l | awk '{print $2}' | sed '1!d')
        read -p "Specify a hard disk: [${firstdevice%?}] : " device
        [[ -z "${device}" ]] && device=${firstdevice%?}
        if [ "${device}" == "/dev/nvme0n1" ]; then
            m2ssddevice=y
        fi

        echo "BTRFS dos´nt support 32-Bit Systems!!!"
        read -p "Which file system should be used? [BTRFS/ext4] " dateisystem
        [[ -z "${dateisystem}" ]] && dateisystem=btrfs

        if [ "${dateisystem}" == "btrfs" ]; then
            read -p "Should a raid be made ?: [raid0/raid1/raid10/N] " raid
            [[ -z "${raid}" ]] && raid=n
            if [ "${raid}" == "n" ]; then
                echo "No raid is generated!"
            else
                fdisk -l
                read -p "Please enter the disks in a row to be connected to a raid !!!: " device1
            fi
            echo "Standard snapshots / /home /opt /var/cache/pacman/pkg"
            echo "The directories may not overlap otherwise there may be problems with the unmount !!!"
            read -p "Should more snapshots be created ?: " mountsnaps
        fi

        read -p "Do you want to create a swap partition? : [y/N] " swap
        [[ -z "${swap}" ]] && swap=n
        if [ "${swap}" != "n" ]; then
            echo "The swap is used for the installation immediately because the unpacker of the squashfs file needs at least 1GB of RAM."
            read -p "Do you want create your swap with : [2G/4G/8G/16G] " swapspeicher
            [[ -z "${swapspeicher}" ]] && swapspeicher=8G

            echo "WARNING with a encrypted Swap disk you cant go in the hibernate-modus!!!"
            read -p "Should the Swap disk be encrypted? : [y/N] " swapverschluesselung
            [[ -z "${swapverschluesselung}" ]] && swapverschluesselung=n
        fi

        read -p "Do you want to create a swapfile? : [y/N] " swapfile
        if [ "${swapfile}" == "y" ]; then
            read -p "Do you want create your swapfile with : [2G/4G/8G/16G] " swapfilespeicher
            [[ -z "${swapfilespeicher}" ]] && swapfilespeicher=8G

        fi

        if [ "${raid}" == "n" ]; then
            read -p "Should the hard disk be encrypted? : [y/N] " verschluesselung
            if [ "${verschluesselung}" == "y" ]; then
                modprobe dm-crypt
                read -p "Should an additional USB stick be created for decryption? : [y/N] " usbkey
                if [ "${usbkey}" == "y" ]; then
                    read -p "Which USB stick should be selected ?: [/dev/sdb2] :  " usbkeydevice
                    [[ -z "${usbkeydevice}" ]] && usbkeydevice=/dev/sdb2
                    usbkeydateisystem=$(blkid -s TYPE -o value ${usbkeydevice})
                    usbkeyuuid=$(blkid -s UUID -o value ${usbkeydevice})
                fi
            fi
        fi

        # berechnungen

        read -p "Should an offline installation be carried out? : [Y/n] " offline
        if [ "${offline}" != "n" ]
        then
            install="offline"
        else
            install="online"
            echo "You can choose with an online installation, which distrubtion you want to install!!!"

        fi
        hostname=spectreos

        echo "WARNING!!! Diese Methode ist wegen einer neuen UDEV Rule unnötig geworden der alle angeschlossen Laufwerke automatisch mountet ;-)"
        read -p "Should you an disk added to your fstab? : [y/udevautomountrule/N] " autodisk
        if [ "${autodisk}" == "y" ]
        then
            read -p "Which DISK stick should be selected ?: [/dev/sdb1 /dev/sdc1] : " autodiskdevice
            [[ -z "${autodiskdevice}" ]] && autodiskdevice=/dev/sdb1

            for wort in ${autodiskdevice}
            do
                echo "fstab ${wort} wird erstellt!!!"
                autodiskdevicedateisystem=$(blkid -s TYPE -o value ${wort})
                autodiskdeviceuuid=$(blkid -s PARTUUID -o value ${wort})

            done
        elif [ "${autodisk}" == "udevautomountrule" ]; then
            udevautomountrule=y

        fi

        read -p "Should you autologin in youre System? : [Y/n] " autologin
        [[ -z "${autologin}" ]] && autologin=y

        if lspci | grep -e VGA -e 3D -m 1 | grep NVIDIA; then
            read -p "Will you have activate youre Nvidia driver? : [y/N] " nvidia
        fi
        [[ -z "${nvidia}" ]] && nvidia=n

        if lspci | grep -e VGA -e 3D -m 1 | grep AMD; then
            read -p "Will you have activate youre AMD driver? : [y/N] " amd
        fi
        [[ -z "${amd}" ]] && amd=n

        read -p "Will you have use youre second Graphic-Card? : [y/N] " multicard
        [[ -z "${multicard}" ]] && multicard=n

        echo "On devices cannot acpi fully work, this boot options can help you :-D"
        read -p "Will youre CPU SUCKS on every boot? : [y/N] " cpusucks
        [[ -z "${cpusucks}" ]] && cpusucks=n

        read -p "Will youre Device have LVM Support? : [y/N] " lvmsupport
        [[ -z "${lvmsupport}" ]] && lvmsupport=n

        echo "Windows dualboot funktioniert nur im UEFI Modus und auch nur derzeit mit GRUB!!!"
        echo "Ausserdem muss die UEFI_Bootpartition über 256MB mindesten sein!!!"
        read -p "Do you want a extra parameter for the installation? : [skipbootpartition/noinstall/noskipuser/debug/windualboot81/windualboot10/dualboot] " extraparameter
        for wort in ${extraparameter}
        do
            echo "$wort"
            export ${wort}="y"
            echo "Extra-Parameter ${wort}=y"
        done

    fi

    # Ausgaben
    cmdlineparameter=$(cat /proc/cmdline)

    # for-schleife
    for wort in ${cmdlineparameter}
    do
        #echo "$wort"
        export ${wort%=*}=${wort#*=}
        #echo "Parameter ${wort%=*} = ${wort#*=}"
    done

    # Dateisystem
    if [ "${dateisystem}" == "btrfs" ]; then
        mountpoint="/mnt/btrfs-current"
    elif [ "${dateisystem}" == "ext4" ]; then
        mountpoint="/mnt"
    fi

    #
    echo "name: ${name}"
    echo "username: ${user}"
    echo "partition type: ${Partition}"
    echo "Bootloader: ${boot}"
    echo "Drive: ${device}"
    if [ "${raid}" != "n" ]; then
        echo "Raid: ${raid}"
        echo "Hard Drives: ${device1}"
    fi
    echo "File system: ${dateisystem}"
    if [ "${swap}" != "n" ]; then
        echo "Swap-partition ${swapspeicher}"
    fi
    if [ "${swapfile}" == "y" ]; then
        echo "Swapfile ${swapfilespeicher}"
    fi
    #echo "Rootpasswort: ${pass}"
    echo "Architektur: ${arch}"
    echo "Installation: ${install}"
    if [ "${dateisystem}" == "btrfs" ]; then
        for wort in ${mountsnaps}
        do
            echo "Snapshot ${wort} wird erstellt!!!"
        done
    fi
    if [ "${usbsecret}" == "y" ]; then
        echo "USB-secret: aktiv"
        echo "USB-UIDD: ${usbsecretdeviceuuid}"
        echo "USB-Label: ${usbsecretdevice}"
    fi
    if [ "${verschluesselung}" == "y" ]; then
        echo "Fesptplatte with Luks 512KB encryption: aktiv"
        if [ "${usbkey}" == "y" ]; then
            echo "${usbkeydevice} is used as key for decrypting: "
            echo "File system: ${usbkeydateisystem}"
        fi
    fi

    RCLOCALSHUTDOWN="${mountpoint}/etc/rc.local.shutdown"

    # Partitionierung

    if [ "${m2ssddevice}" == "y" ]; then
        m2ssd=p
    fi

    luksabfrage

    echo "Zusatzparameter"
    if [ "${windualboot81}" == "y" ]; then
        echo "Windows Dualboot: ${windualboot81}"
    fi
    if [ "${windualboot10}" == "y" ]; then
        echo "Windows Dualboot: ${windualboot10}"
    fi
    if [ "${dualboot}" == "y" ]; then
        echo "SpectreOS Dualboot: ${dualboot}"
    fi
    if [ "${skipbootpartition}" == "y" ]; then
        echo "Überspringe Formatieren der Boot Partition: ${skipbootpartition}"
    fi
    if [ "${debug}" == "y" ]; then
        echo "Debug Menü: ${debug}"
    fi
    if [ "${noinstall}" == "y" ]; then
        echo "Keine Installation: ${noinstall}"
        if [ "y" == "${noskipuser}" ]; then
            echo "Der User wird nicht uebersprungen!!!"
        fi
    fi

    if [ "y" == "${windualboot81}" ]; then
        bootpartitionnummer=${m2ssd}1
        efipartitionnummer=${m2ssd}2
        if [ "${swap}" != "n" ]; then
            swappartitionnummer=${m2ssd}5
            rootpartitionnummer=${m2ssd}6
        else
            rootpartitionnummer=${m2ssd}5
        fi
    elif [ "y" == "${windualboot10}" ]; then
        bootpartitionnummer=${m2ssd}1
        efipartitionnummer=${m2ssd}2
        if [ "${swap}" != "n" ]; then
            swappartitionnummer=${m2ssd}5
            rootpartitionnummer=${m2ssd}6
        else
            rootpartitionnummer=${m2ssd}5
        fi
    elif [ "y" == "${dualboot}" ]; then
        bootpartitionnummer=${m2ssd}1
        efipartitionnummer=${m2ssd}2
        if [ "${swap}" != "n" ]; then
            swappartitionnummer=${m2ssd}3
            rootpartitionnummer=${m2ssd}5
        else
            rootpartitionnummer=${m2ssd}4
        fi
    else
        bootpartitionnummer=${m2ssd}1
        efipartitionnummer=${m2ssd}2
        if [ "${swap}" != "n" ]; then
            swappartitionnummer=${m2ssd}3
            rootpartitionnummer=${m2ssd}4
        else
            rootpartitionnummer=${m2ssd}3
        fi
    fi

    echo "Boot-Partition = ${device}${bootpartitionnummer}"
    echo "EFI-Partition = ${device}${efipartitionnummer}"
    if [ "${swap}" != "n" ]; then
        echo "Swap-Partition = ${device}${swappartitionnummer}"
    fi
    echo "ROOT-Partition = ${device}${rootpartitionnummer}"

    #
    if [ "${skipcheck}" != "y" ]; then
        read -p "Are all the details correct ?: [y/N] " sicherheitsabfrage
        if [ "$sicherheitsabfrage" != "y" ]
        then
            echo "ABGEBROCHEN"
            exit 1
        fi
    fi
    echo "Operating system is installed !!!"
    sleep 5

}

# Begin the Script!!!

# fastinstall=y device=/dev/sda
# for-schleife
for wort in ${1}
do
    echo "$wort"
    export ${wort%=*}=${wort#*=}
    echo "Parameter ${wort%=*} = ${wort#*=}"
done

if [ "${fastinstall}" == "y" ] && [ "${fastinstallnext}" != "y" ]; then
    gitclone
    /opt/${repo}/arch-install.sh "${1} fastinstallnext=y "
    exit 0
elif [ "${phaseone}" != "n" ] && [ "${fastinstallnext}" != "y" ]; then
    if wget -qO- ipv4.icanhazip.com 1>/dev/null 2>&1; then
        read -p "Should I look at the internet for a new install script and then run it ?: [Y/n] " update
        if [ "${update}" == "debug" ]
        then
            echo "Skip the download a new script !!!"
        else
            if [ "${update}" != "n" ]
            then
                read -p "Should I update youre packages and then run it ?: [y/N] " updatepackages
                if [ "${updatepackages}" == "y" ]; then
                    echo "Please dont update the linux kernel!!!"
                    if [ -f  /opt/${repo}/packages.txt ]; then
                        pacman -Sy $(cat /opt/${repo}/packages.txt) --noconfirm --needed --ignore linux
                    else
                        echo "Kann keine neuen Packete nachinstallieren weil die base.txt nicht gefunden werden kann!!"
                        echo "Es kann sein das dass Programm nicht korrekt funktioniert!!!"
                    fi
                fi
                gitclone
                /opt/${repo}/arch-install.sh "${1} phaseone=n "
                exit 0
            fi
        fi
    else
        echo "No internet connection detected!"
        update=n
    fi
fi

if [ "${update}" != "n" ]; then
    echo "Online-Modus activated!"
    #vpntunnel
fi
# debug = Installation ueberspringen zu arch-graphical-install und DEBEUG-MODUS
abfrage

secureumount

if [ "y" == "${debug}" ] || [ "y" == "${noinstall}" ]
then
    echo "DEBEUG-MODUS"
    echo "For encrypt mount mountencrypt"
    echo "Then for normal btrfs mount run: btrfsmount 1 and btrfsmount 2"
    echo "If no more commands are required, simply press enter"
    echo "Which command should be executed? "

    befehl=blablabla
    while [ "$befehl" != "" ]
    do
        read -p "" befehl
        $befehl
    done

fi

#
echo "A purge stops the chance of installing on the system."
echo "It may take a while!"
if [ "y" != "${noinstall}" ] && [ "y" != "${skipbootpartition}" ]; then
    sleep 5
    #dd if=/dev/zero of=${device} bs=64M count=10 status=progress
fi
#
if [ "${Partition}" == "uefi" ]
then
    echo "Partitions with UEFI"

    if [ "y" != "${noinstall}" ]; then
        if ! [ "${skipbootpartition}" == "y" ]; then
            if [ "y" == "${windualboot81}" ] || [ "y" == "${windualboot10}" ]; then
                partitionieredual
            else
                if [ "y" == "${lvmsupport}" ]; then
                    partitionierelvm
                else
                    partitioniere
                fi
            fi
        else
            partitionierewithoutboot
        fi
    else
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mountencrypt
        fi
    fi

    echo "installation"
    installation
    if [ "y" == "${windualboot81}" ] || [ "y" == "${windualboot10}" ]; then
        restorebootloader
    fi
    grubinstall

    arch-chroot ${mountpoint} mkinitcpio -P -c /etc/mkinitcpio.conf
    arch-chroot ${mountpoint} grub-install --target=i386-pc --recheck ${device}
    # https://wiki.archlinux.org/title/GRUB/Tips_and_tricks
    arch-chroot ${mountpoint} grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="${repo}" --recheck --removable
    #systemdboot
    echo "Finished"
elif [ "${Partition}" == "bios" ]; then
    echo "Partitions with MBR"
    if [ "y" != "${noinstall}" ]; then
        if ! [ "${skipbootpartition}" == "y" ]; then
            if [ "y" == "${windualboot81}" ] || [ "y" == "${windualboot10}" ]; then
                partitionieredual
            else
                if [ "y" == "${lvmsupport}" ]; then
                    partitionierelvm
                else
                    partitioniere
                fi
            fi
        else
            partitionierewithoutboot
        fi
    else
        if [ "${verschluesselung}" == "y" ] || [ "y" == "${lvmsupport}" ]; then
            mountencrypt
        fi
    fi

    echo "installation"
    installation
    if [ "y" == "${windualboot81}" ] || [ "y" == "${windualboot10}" ]; then
        restorebootloader
    fi
    grubinstall

    arch-chroot ${mountpoint} mkinitcpio -P -c /etc/mkinitcpio.conf
    arch-chroot ${mountpoint} grub-install --target=i386-pc --recheck ${device}
    echo "Finished"
else
    echo "Entry Invalid"
    exit 1
fi

# benutzerwechsel

# Nur nötig wenn der Name gleich dem Usernamen gleichen soll
arch-chroot ${mountpoint} usermod -l "${user}" "user1"
arch-chroot ${mountpoint} usermod -d /home/"${user}" -m "${user}"
arch-chroot ${mountpoint} chfn -f "${name}" "${user}"

if ! [ "${fastinstall}" == "y" ]; then
    read -s -p "Please choose a passwort for you!!! " userpass
fi

echo "${user}:${userpass}" > user-keys.txt
arch-chroot ${mountpoint} chpasswd < user-keys.txt
read -s -p "Please choose a passwort for root!!! " rootpass
echo "root:${rootpass}" > root-keys.txt
arch-chroot ${mountpoint} chpasswd < root-keys.txt

if [ ${autologin} != "n" ]; then
    mkdir -p ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/
    echo "[Service]" > ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
    echo "ExecStart=" >> ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
    echo "ExecStart=-/usr/bin/agetty --autologin ${user} -s %I 115200,38400,9600 vt102" >> ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
else
    rm ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
fi

if [ -f "/etc/locale.conf" ]; then cp /etc/locale.conf ${mountpoint}/etc/locale.conf; fi
if [ -f "/etc/vconsole.conf" ]; then cp /etc/vconsole.conf ${mountpoint}/etc/vconsole.conf; fi
if [ -f "/etc/locale.gen" ]; then cp /etc/locale.gen ${mountpoint}/etc/locale.gen; fi

arch-chroot ${mountpoint} locale-gen

if [ -f "/etc/X11/xorg.conf.d/20-keyboard.conf" ]; then
    cp /etc/X11/xorg.conf.d/20-keyboard.conf ${mountpoint}/etc/X11/xorg.conf.d/20-keyboard.conf
fi

if [ "${nvidia}" == "y" ]; then
    arch-chroot ${mountpoint} pacman -Sy nvidia lib32-nvidia-utils nvidia-settings nvidia-utils --needed --noconfirm
    arch-chroot ${mountpoint} nvidia-xconfig
    echo "Bitte füge \"Option         \"DPI\" \"96 x 96\"\" in der xorg.conf im Section \"Monitor\" Bereich hinzu, falls die Schrift zu klein erscheint :)"
    #sed -i 's/ServerArguments=.*$/ServerArguments=-nolisten tcp -dpi 96/' ${mountpoint}/etc/sddm.conf
    # https://wiki.archlinux.org/title/xorg#Setting_DPI_manually
    # Set in Nvidia xorg.conf in Device or Screen
    # Option              "DPI" "96 x 96"
    # https://wiki.archlinux.org/title/Vulkan#Selecting_Vulkan_driver
    echo "VK_ICD_FILENAMES=\"/usr/share/vulkan/icd.d/nvidia_icd.json\"" >> ${mountpoint}/etc/environment
fi

if [ "${amd}" == "y" ]; then
    # https://wiki.archlinux.org/title/Vulkan#Selecting_Vulkan_driver
    echo "VK_ICD_FILENAMES=\"/usr/share/vulkan/icd.d/amd_icd64.json\"" >> ${mountpoint}/etc/environment
fi

if [ "${multicard}" == "y" ]; then
    echo "DRI_PRIME=1" >> ${mountpoint}/etc/environment
fi

# Kopiere Netzwerkonfigurationen wie WLAN-Passwörter (falls vorhanden)
if [ -f "/etc/NetworkManager/system-connections/*" ]; then
    cp -v /etc/NetworkManager/system-connections/* ${mountpoint}/etc/NetworkManager/system-connections/
fi

touch ${mountpoint}/etc/grub-snapshot
arch-chroot ${mountpoint} grub-mkconfig -o /boot/grub/grub.cfg

cp /opt/${repo}/scripts/update.sh ${mountpoint}/usr/bin/update-script
chmod +x ${mountpoint}/usr/bin/update-script
if ! arch-chroot ${mountpoint} /usr/bin/update-script; then
    echo "Aktualisierung nicht erfolgreich!!!"
fi

if [ "${udevautomountrule}" == "y" ]; then
    #autodiskmount
    mkdir -p ${mountpoint}/media/
    mkdir -p ${mountpoint}/etc/udev/rules.d/
    cp /opt/${repo}/configs/11-media-by-label-auto-mount.rules ${mountpoint}/etc/udev/rules.d/11-media-by-label-auto-mount.rules
    udevadm control --reload-rules && udevadm trigger
fi

echo "df!!!"
df -h
if [ "${dateisystem}" == "btrfs" ]; then
    btrfs filesystem df ${mountpoint}
fi
echo "umount!!!"
read -p "Weiter mit unmount..."
secureumount
echo ""
echo "$(date "+%Y%m%d-%H%M%S")"
echo "Fertig!!!"
read -p "Allation completed successfully. Do you want to RESTART the PC ?: [Y/n] " sicherheitsabfrage
if [ "$sicherheitsabfrage" != "n" ]
then
    echo "restart now"
    reboot
fi
exit 0
