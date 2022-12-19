#!/usr/bin/env bash
#
set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo "${0}" "$@"
    exit 0
fi

# full install parameters
# ./make_mksquashfs-auto.sh makesystem mkinitcpio filesystem makeimage makebios makeiso
# Parameter:
# Entfernt die Datenträger die noch gemounted sind: umount
# Mountet die Datenträger: mount
# 
# Packete die installiert sein muessen:
# arch-install-scripts
# xorriso
# squashfs-tools

iso_name=spectreos
iso_label="SPECTREOS"
iso_label_short="S_OS"
iso_version=$(date +%Y%m%d)
out_dir=out
install_dir=arch

# while-schleife
while (( "$#" ))
do
    echo ${1}
    export ${1}="y"
    shift
done

arch=$(uname -m)
repo=spectreos
repo1=shell-scripte-code

isohostname="${iso_name}"

work_dir="/builds"

function umount_chroot() {
    if ! umount -Rfl /builds/${arch}/airootfs; then
        echo "Buildverzeichnis NICHT erfolgreich ungemounted"
    fi
}

function mount_chroot() {
    umount_chroot
    ### https://bugs.archlinux.org/task/46169
    mount --bind ${work_dir}/${arch}/airootfs/ ${work_dir}/${arch}/airootfs/
    ### https://wiki.archlinux.org/index.php/Install_Arch_Linux_from_existing_Linux#Using_a_chroot_environment
    mount -t proc /proc ${work_dir}/${arch}/airootfs/proc
    mount -o bind /dev ${work_dir}/${arch}/airootfs/dev
    mount -o bind /dev/pts ${work_dir}/${arch}/airootfs/dev/pts
    mount -o bind /sys ${work_dir}/${arch}/airootfs/sys
    ### Before chrooting to it, we need to set up some mount points and copy the resolv.conf for networking.
    ### https://askubuntu.com/questions/469209/how-to-resolve-hostnames-in-chroot
    #mount --bind /etc/resolv.conf ${work_dir}/${arch}/airootfs/etc/resolv.conf
    #mount --bind /run ${work_dir}/${arch}/airootfs/run
    cp /etc/resolv.conf ${work_dir}/${arch}/airootfs/etc/resolv.conf
}

function system() {

    pacman -Sy arch-install-scripts squashfs-tools dosfstools libisoburn --needed --noconfirm
    
    if [ "${makesystem}" == "y" ]; then
        mkdir -p ${work_dir}/${arch}/airootfs
        cp -v mirrorlist* /etc/pacman.d/
        pacstrap -c -G -C pacman.conf -M ${work_dir}/${arch}/airootfs $(cat packages.txt)
    fi
    
    if [ "${mkinitcpio}" == "y" ]; then
        # module and hooks
        
        # hooks
        cp -v configs/install/* ${work_dir}/${arch}/airootfs/usr/lib/initcpio/install/
        cp -v configs/hooks/* ${work_dir}/${arch}/airootfs/usr/lib/initcpio/hooks/
        cp -v configs/script-hooks/* ${work_dir}/${arch}/airootfs/usr/lib/initcpio/
        
        mkdir -p ${work_dir}/${arch}/airootfs/etc/pacman.d/hooks
        cp -v configs/pacman-hooks/* ${work_dir}/${arch}/airootfs/etc/pacman.d/hooks/
        cp -v pacman.conf ${work_dir}/${arch}/airootfs/etc/pacman.conf
        cp -v mirrorlist* ${work_dir}/${arch}/airootfs/etc/pacman.d/
        chmod 644 -R ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist*
        
        # modprobe.d
        mkdir -p ${work_dir}/${arch}/airootfs/etc/modprobe.d/
        echo "blacklist floppy" > ${work_dir}/${arch}/airootfs/etc/modprobe.d/blacklist-floppy.conf
        echo "blacklist nouveau" > ${work_dir}/${arch}/airootfs/etc/modprobe.d/blacklist_nouveau.conf
        echo "install dell-smbios /bin/false" > ${work_dir}/${arch}/airootfs/etc/modprobe.d/blacklist-dell-smbios.conf
        
        # modules
        echo "MODULES=\"amdgpu i915 nouveau fuse loop\"" > ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf
        echo "HOOKS=\"base udev keyboard keymap consolefont modconf archiso block filesystems\"" >> ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf
        echo "COMPRESSION=\"zstd\"" >> ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf
    fi
}

function IMAGE() {
    
    if [ "$image" != "n" ]
    then
        
        echo "Unmounte System"
        sleep 2
        umount_chroot

        echo "System wird gereinigt und komprimiert!!!"
        sleep 5
        
        mkdir -p ${work_dir}/iso/${install_dir}/${arch}/airootfs/
        
        if [ -f ${work_dir}/${arch}/airootfs/pkglist.txt ]; then
            cp ${work_dir}/${arch}/airootfs/pkglist.txt ${work_dir}/iso/${install_dir}/${arch}/
        fi
        
        if [ -f ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs ]
        then
            echo "${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs wird neu angelegt!!!"
            rm ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs
        else
            echo "airootfs.sfs nicht vorhanden!"
        fi
        
        mksquashfs ${work_dir}/${arch}/airootfs ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs -comp zstd
        
        mkdir -p tmp/
        sha512sum ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs > tmp/airootfs.sha512
        echo "$(cat tmp/airootfs.sha512 | awk -F ' ' '{print $1}') /run/archiso/bootmnt/${install_dir}/${arch}/airootfs.sfs" > ${work_dir}/iso/${install_dir}/${arch}/airootfs.sha512
        
    else
        echo "Image wird nicht neu aufgebaut!!!"
    fi
    
}

function copykernel() {
    
    mkdir -p ${work_dir}/iso/boot
    mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}/
    cp ${work_dir}/${arch}/airootfs/boot/initramfs-linux.img ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img
    cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz
    cp ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img ${work_dir}/iso/boot/initramfs-${arch}.img
    cp ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz ${work_dir}/iso/boot/vmlinuz-${arch}
    
}

function UEFI() {
    
    mkdir -p ${work_dir}/iso/boot
    mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
    
    mkdir -p ${work_dir}/iso/boot/
    mkdir -p ${work_dir}/iso/EFI/boot/
    
    mkdir -p ${work_dir}/iso/boot/grub/
    
    mkdir -p ${work_dir}/iso/EFI/archiso
    mkdir -p ${work_dir}/iso/EFI/boot
    mkdir -p ${work_dir}/iso/loader/entries
    
    
    if [ "$efi" != "n" ]
    then
        
        if [ -f ${work_dir}/iso/EFI/archiso/efiboot.img ]
        then
            rm ${work_dir}/iso/EFI/archiso/efiboot.img
        else
            echo "efiboot.img nicht vorhanden!"
        fi
        
        truncate -s 4M ${work_dir}/iso/EFI/archiso/efiboot.img
        mkfs.vfat -n ${iso_label_short}_EFI ${work_dir}/iso/EFI/archiso/efiboot.img
        
        copykernel
        
        mkdir -p ${work_dir}/efiboot
        
        mount -t vfat -o loop ${work_dir}/iso/EFI/archiso/efiboot.img ${work_dir}/efiboot
        
        mkdir -p ${work_dir}/efiboot/EFI/boot/
        
        cp -v grub-config/cfg/*.cfg ${work_dir}/iso/boot/grub/
        
        mkdir -p ${work_dir}/iso/boot/grub/themes
        cp -Rv grub-config/themes/Stylish/ ${work_dir}/iso/boot/grub/themes/
        cp grub-config/unicode.pf2 ${work_dir}/iso/boot/grub/
        cp -Rv grub-config/{locales,tz} ${work_dir}/iso/boot/grub/

        cp -Rv /usr/lib/grub/i386-pc ${work_dir}/iso/boot/grub/
        grub-mkimage -d ${work_dir}/iso/boot/grub/i386-pc -o ${work_dir}/iso/boot/grub/i386-pc/core.img -O i386-pc -p /boot/grub biosdisk iso9660
        #grub-install --target=i386-pc --force --removable --boot-directory=${work_dir}/iso/boot/ --efi-directory=${work_dir}/efiboot/ /dev/sdc

        cat ${work_dir}/iso/boot/grub/i386-pc/cdboot.img ${work_dir}/iso/boot/grub/i386-pc/core.img > ${work_dir}/iso/boot/grub/i386-pc/eltorito.img

        cp -Rv /usr/lib/grub/x86_64-efi ${work_dir}/iso/boot/grub/
        grub-mkimage -d ${work_dir}/iso/boot/grub/x86_64-efi -o ${work_dir}/iso/EFI/boot/bootx64.efi -O x86_64-efi -p /boot/grub iso9660
        #grub-install --target=x86_64-efi --force --removable --boot-directory=${work_dir}/iso/EFI/boot/ --efi-directory=${work_dir}/efiboot/ /dev/sdc

        cp -Rv /usr/lib/grub/x86_64-efi ${work_dir}/efiboot/EFI/boot/
        grub-mkimage -d ${work_dir}/iso/boot/grub/x86_64-efi -o ${work_dir}/efiboot/EFI/boot/bootx64.efi -O x86_64-efi -p /boot/grub iso9660
        
        cp ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.bin ${work_dir}/iso/boot/memtest
        cp ${work_dir}/${arch}/airootfs/usr/share/licenses/common/GPL2/license.txt ${work_dir}/iso/boot/memtest.COPYING
        cp ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.bin ${work_dir}/iso/EFI/boot/memtest
        cp ${work_dir}/${arch}/airootfs/usr/share/licenses/common/GPL2/license.txt ${work_dir}/iso/EFI/boot/memtest.COPYING

        sed -e 's|@iso_label@|'$iso_label'|' -i ${work_dir}/iso/boot/grub/kernels.cfg
        sed -e 's|@parameters@||' -i ${work_dir}/iso/boot/grub/kernels.cfg
        sed -e 's|grub_theme=.*$|grub_theme=/boot/grub/themes/Stylish/theme.txt|' -i ${work_dir}/iso/boot/grub/variable.cfg
        sed -e 's|def_bootlang=.*$|def_bootlang=\"de_DE\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        sed -e 's|def_keyboard=.*$|def_keyboard=\"de\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        sed -e 's|def_timezone=.*$|def_timezone=\"Europe/Berlin\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        sed -e 's|def_netinstall=.*$|def_netinstall=\"no\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        sed -e 's|def_autostartdesktop=.*$|def_autostartdesktop=\"sway\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        sed -e 's|def_copytoram=.*$|def_copytoram=\"n\"|' -i ${work_dir}/iso/boot/grub/defaults.cfg
        
        ###
        
        sleep 5
        
        if [ "$trennen" != "n" ]
        then
            umount -d ${work_dir}/efiboot
        fi
        
    fi
    
}

function makegrubiso() {

    mkdir -p ${out_dir}
    xorriso -as mkisofs \
        --modification-date=$(date -u +%Y-%m-%d-%H-%M-%S-00  | sed -e s/-//g) \
        --protective-msdos-label \
        -volid "${iso_label}" \
        -appid "${iso_name} Live/Rescue CD" \
        -publisher "${username}" \
        -preparer "Prepared by simono41 SpectreOS/${0##*/}" \
        -r -graft-points -no-pad \
        --sort-weight 0 / \
        --sort-weight 1 /boot \
        --grub2-mbr ${work_dir}/iso/boot/grub/i386-pc/boot_hybrid.img \
        -partition_offset 16 \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
        -eltorito-alt-boot \
        -append_partition 2 0xef ${work_dir}/iso/EFI/archiso/efiboot.img  \
        -e --interval:appended_partition_2:all:: -iso_mbr_part_type 0x00 \
        -no-emul-boot -iso-level 3 \
        -o "${out_dir}/${imagename}" \
        "${work_dir}/iso/"
    
}


system

if [ "${filesystem}" == "y" ]; then
    cp -v arch-graphical-install-auto.sh ${work_dir}/${arch}/airootfs/usr/bin/arch-graphical-install-auto
    chmod +x ${work_dir}/${arch}/airootfs/usr/bin/arch-graphical-install-auto
    # Dieses Script sorgt dafür, dass die Repository´s als Systemvariablen eingerichtet werden
    cp -v repo.sh ${work_dir}/${arch}/airootfs/usr/bin/repo
    chmod +x ${work_dir}/${arch}/airootfs/usr/bin/repo
    # Falls das benötigte Packet nicht enthalten ist, installiere es erneut
    mount_chroot
    chroot ${work_dir}/${arch}/airootfs /usr/bin/arch-graphical-install-auto archisoinstall
    
fi

if [ "${makeimage}" == "y" ]; then
    
    # System-image
    
    IMAGE
    
fi

if [ "${umount}" == "y" ]; then
    umount_chroot
fi

if [ "${mount}" == "y" ]; then
    mount_chroot
fi

if [ "${makebios}" == "y" ]; then
    
    copykernel
    
    UEFI
    
fi

if [ "${makeiso}" == "y" ]; then
    # MAKEISO
    if [ "$image" != "n" ]
    then
        
        imagename=arch-${iso_name}-${iso_version}-${arch}.iso
        
        if [ "$run" != "n" ]
        then
            if [ -f ${out_dir}/${imagename} ]
            then
                rm ${out_dir}/${imagename}
            fi
            
            makegrubiso
            
        fi
    fi
fi

# chroot

sync

echo "$(date "+%Y%m%d-%H%M%S")"
echo "Fertig!!!"
