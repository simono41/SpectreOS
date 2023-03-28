#!/usr/bin/env bash
#
set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo "$@"
    exit 0
fi
echo "Als root Angemeldet"

RCLOCAL='/etc/rc.local'
RCLOCALSHUTDOWN='/etc/rc.local.shutdown'
SYSCTL='/etc/sysctl.conf'
SUDOERS="/etc/sudoers"
autostartdesktop=sway
repo=SpectreOS
repo1=shell-scripte-code
hostname=SpectreOS
user=user1
userpass=user1
arch=$(uname -m)
branch=master
offline=false

# Lese die Umgebungsvariablen neu
source /etc/environment

# while-schleife
while (( "$#" ))
do
    echo ${1}
    export ${1}="y"
    shift
done

if cat /etc/passwd | grep "x:1000" > /dev/null; then
    tempuser=$(cat /etc/passwd | grep "x:1000" | awk '{print $1}')
    user=${tempuser%%:*}
fi

function pacmanconf() {

    cp -v /opt/${repo}/mirrorlist* /etc/pacman.d/

    cp -v /opt/${repo}/pacman.conf /etc/pacman.conf

    pacman-key --init
    pacman-key --populate archlinux

    pacman -Syu git glibc --needed --noconfirm

}

function gitclone() {
    git config --global credential.helper store
    git config --global core.editor "vim"
    git config --global user.email "user1@spectreos.de"
    git config --global user.name "user1"
    git config --global push.default simple
    git config --global pull.rebase true
    git config --global --add safe.directory '*'

    # Aktualisiere die Repositiories
    # Überprüfe ob das GIT Repo überhaupt vorhanden ist, sonst verwende das Failback
    if [ -f "/opt/${repo}/repo.sh" ]; then /opt/${repo}/repo.sh; else /usr/bin/repo; fi

    # Lese die Umgebungsvariablen neu
    source /etc/environment

    if [ "${offline}" != "true" ]; then
        if [ -d "/opt/${repo}" ]; then
            echo "${repo} existiert bereits!!!"
            cd /opt/${repo}
            git checkout ${branch}
            if ! git remote set-url origin ${WEBADDRESS_OS}; then
                git remote add origin ${WEBADDRESS_OS}
            fi
            git pull
        else
            git clone -b ${branch} ${WEBADDRESS_OS} /opt/${repo}
        fi
        if [ -d "/opt/${repo1}" ]; then
            echo "${repo1} existiert bereits!!!"
            cd /opt/${repo1}
            if ! git remote set-url origin ${WEBADDRESS_SCRIPTE}; then
                git remote add origin ${WEBADDRESS_SCRIPTE}
            fi
            git pull
        else
            git clone ${WEBADDRESS_SCRIPTE} /opt/${repo1}
        fi
    fi
    cd /
}

function standartinstallation() {
    if ! pacman -Syu $(cat /opt/${repo}/packages.txt)  --needed --noconfirm; then
        echo "Konnte Aktualisierung nicht abschließen!!!"
        echo "Versuche die Packete automatisch zu aktualisieren!!!"
        sleep 5
    fi
}

function addusers() {
    # Erstelle Gruppen
    groupid=2000
    for wort in wheel audio input power storage video sys optical adm lp scanner sddm kvm fuse autologin network wireshark docker libvirt libvirtdbus; do
        if ! cat /etc/group | grep ${wort}; then
            while cat /etc/group | grep ${groupid}; do
                groupid=$((${groupid} + 1))
            done
            groupadd ${wort} -g ${groupid}
        fi
    done

    useruid=1000
    while cat /etc/passwd | grep ${useruid}; do
        useruid=$((${useruid} + 1))
    done

    useradd -m -g users -G wheel,audio,input,power,storage,video,sys,optical,adm,lp,scanner,sddm,kvm,fuse,autologin,network,wireshark,docker,libvirt,libvirtdbus -s /usr/bin/zsh --uid ${useruid} ${user}
    echo "${user}:${userpass}" | chpasswd
    mkdir -p /home/${user}/
    userrechte
}

function add_plymouth() {
    cd /opt/
    if [ "${version%-*-*}" != "lite" ] && [ "${skip}" != "skip" ] && ! [ "${version#*-}" == "cli" ]; then
        aurinstaller "https://aur.archlinux.org/plymouth.git"
        aurinstaller "https://aur.archlinux.org/plymouth-theme-dark-arch.git"
        plymouth-set-default-theme -R dark-arch
    fi
    if ! [ -d plymouth-bgrt ]; then
        if git clone https://github.com/darac/plymouth-bgrt.git; then
            cd plymouth-bgrt
            if ./install.sh; then
                plymouth-set-default-theme -R plymouth-bgrt
            else
                echo "Konnte das Bootlogo nicht finden!!!"
            fi
            echo "Git erfolgreich runtergeladen ;-D"
        else
            echo "Konnte Git nicht herunterladen!!!"
        fi
    else
        cd plymouth-bgrt
        update_git
    fi
    cd /

}

function userrechte() {
    #user
    chown -cR "$user":users /home/"$user"
    #chmod 750 -R /home/"$user"
    #ssh
    if ! [ -d /home/"$user"/.ssh ]; then
        mkdir -p /home/"$user"/.ssh
    fi
    chmod 700 /home/"$user"/.ssh
    if [ -f /home/"$user"/.ssh/config ]; then
        chmod 400 /home/${user}/.ssh/config
    fi

    if [ -f /home/"$user"/.ssh/id_rsa ]; then
        chmod 600 /home/"$user"/.ssh/id_rsa
    fi

    if ! [ -f /home/"$user"/.ssh/authorized_keys ]; then
        touch /home/"$user"/.ssh/authorized_keys
    fi
    chmod 600 /home/"$user"/.ssh/authorized_keys
    #gnupg
    mkdir -p /home/"$user"/.gnupg
    chmod -R 700 /home/"$user"/.gnupg
    chown -cRv "$user":users /home/${user}/.gnupg
    if [ -f /home/${user}/.gnupg/* ]; then
        chmod -v 600 /home/${user}/.gnupg/*
    fi

}

function links() {
    #
    mkdir -p /home/"$user"/Schreibtisch/
    if [ -f "/usr/share/applications/arch-install.desktop" ]; then
        if [ -f "/home/"$user"/Schreibtisch/arch-install.desktop" ]; then
            echo "datei existiert bereits!"
        else
            ln -s /usr/share/applications/arch-install.desktop /home/"$user"/Schreibtisch/arch-install.desktop
        fi
        #chmod +x /home/"$user"/Schreibtisch/arch-install.desktop
    fi

    mkdir -p /home/"$user"/Desktop/
    if [ -f "/usr/share/applications/arch-install.desktop" ]; then
        if [ -f "/home/"$user"/Desktop/arch-install.desktop" ]; then
            echo "datei existiert bereits!"
        else
            ln -s /usr/share/applications/arch-install.desktop /home/"$user"/Desktop/arch-install.desktop
        fi
        #chmod +x /home/"$user"/Desktop/arch-install.desktop
    fi
}

function add_locale_settings() {
    # set systemconfiguration

    echo "LANG=de_DE.UTF-8" > /etc/locale.conf
    echo "LC_COLLATE=C" >> /etc/locale.conf
    echo "LANGUAGE=de_DE" >> /etc/locale.conf

    echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen
    echo "de_DE ISO-8859-1" >> /etc/locale.gen
    if ! grep 'en_US.UTF-8 UTF-8' /etc/locale.gen 1>/dev/null 2>&1; then
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    fi

    locale-gen

    echo "KEYMAP=de" > /etc/vconsole.conf
    echo "FONT=lat9w-16" >> /etc/vconsole.conf
    if [ -f "/etc/conf.d/keymaps" ]; then
        sed -i 's/keymap=.*$/keymap=\"de\"/' /etc/conf.d/keymaps
    fi

    sed -e 's|Option "XkbLayout".*$|Option "XkbLayout" "de"|' -i /etc/X11/xorg.conf.d/20-keyboard.conf
    if [ "$keytable_short" != "de" ]; then
        sed -e 's|    xkb_layout.*$|    xkb_layout de|' -i /home/${user}/.config/sway/config
    fi

    # https://stackoverflow.com/questions/5767062/how-to-check-if-a-symlink-exists
    if [ -L /etc/localtime ]; then
        rm /etc/localtime
    fi
    ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
}

function update_git() {
    git reset --hard
    if ! git pull; then
        echo "Konnte die Git-Repository nicht aktualisieren!!!"
    fi
}

# Lade wichtige Git-Repositorys herunter
gitclone

# Konfiguriere die Repositoryverwaltung Pacman
pacmanconf

if [ "$1" == "adduser" ]; then
    user="$2"
    userpass="$3"
    if cat /etc/passwd | grep "x:1000" > /dev/null; then
        echo "${user} existiert bereits!!!"
    else
        addusers
    fi
    exit 0
elif [ "$1" == "add_plymouth" ]; then
    add_plymouth
    exit 0
elif [ "$1" == "userrechte" ]; then
    userrechte
    exit 0
fi

if cat /etc/passwd | grep ${user} > /dev/null; then
    echo "${user} existiert bereits!!!"
else
    addusers
fi

if [ "$erstellen" == "exit" ]
then
    exit 0
fi

# grundinstallation


echo "root:root" | chpasswd

# sudoers/wheel

echo "Lege $SUDOERS neu an!!!"

echo "root ALL=(ALL) NOPASSWD: ALL" > $SUDOERS

echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> $SUDOERS

# systemaktualisierung

standartinstallation

# Your commands

# startup
cp /opt/${repo}/scripts/startup-script.sh /usr/bin/startup-script
chmod 755 /usr/bin/startup-script

cp /opt/${repo}/service/startup-script.service /etc/systemd/system/
chmod 644 /etc/systemd/system/startup-script.service
systemctl enable startup-script.service

echo "Packetliste2 Ende"
echo "Beginne mit dem Konfigurieren des Systems :D"

# import compress script

# compress-script
cp /opt/${repo}/scripts/compress.sh /usr/bin/compress
chmod 755 /usr/bin/compress
cp /opt/${repo}/scripts/compress-pigz.sh /usr/bin/compress-pigz
chmod 755 /usr/bin/compress-pigz

# pinentray wayland
cp /opt/${repo}/scripts/pinentry-wayland /usr/bin/pinentry-wayland
chmod 755 /usr/bin/pinentry-wayland

# set system startup files
echo "System startup files"
cp -v /opt/${repo}/service/* /etc/systemd/system/

systemctl enable acpid
systemctl enable ntpd
systemctl enable avahi-daemon
systemctl enable cups
systemctl enable sshd
systemctl disable systemd-random-seed.service
systemctl enable cronie
systemctl enable systemd-timesyncd.service
systemctl disable docker
systemctl disable x11vnc
#systemctl enable mpd
#systemctl enable syncthing@simono41.service
echo "Bitte OpenVPN config in die /etc/openvpn/client/client.conf kopieren!!!"
if [ -f /lib/systemd/system/openvpn-client@client.service ]; then
    echo "link vorhanden!"
else
    ln /lib/systemd/system/openvpn-client@.service /lib/systemd/system/openvpn-client@client.service
fi
#Bei ausdokumentierung wird eine/die VPN automatisch aus der /etc/openvpn/client/client.conf gestartet!!!
#systemctl enable openvpn-client@client.service
#systemctl enable wg-quick@peer1.service
systemctl enable fail2ban
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
#systemctl enable httpd
#systemctl enable sddm

#add_plymouth

#mkdir -p /etc/systemd/system/getty\@tty1.service.d/
#echo "[Service]" > /etc/systemd/system/getty\@tty1.service.d/autologin.conf
#echo "ExecStart=" >> /etc/systemd/system/getty\@tty1.service.d/autologin.conf
#echo "ExecStart=-/usr/bin/agetty --autologin ${user} -s %I 115200,38400,9600 vt102" >> /etc/systemd/system/getty\@tty1.service.d/autologin.conf

# iso_name
echo "${hostname}" > /etc/hostname
echo "hostname=\"${hostname}\"" > /etc/conf.d/hostname

# uefi-boot
cp /opt/${repo1}/uefi-boot.sh /usr/bin/uefi-boot
chmod 755 /usr/bin/uefi-boot

# youtube
cp /opt/${repo1}/youtube.sh /usr/bin/youtube-downloader
chmod 755 /usr/bin/youtube-downloader

# write-partitions manager
cp /opt/${repo}/scripts/write_cowspace /usr/bin/write_cowspace
chmod 755 /usr/bin/write_cowspace

# installer-/usr/bin/
cp /opt/${repo}/arch-install.sh /usr/bin/arch-install
chmod 755 /usr/bin/arch-install

if ! grep 'TERMINAL' /etc/environment; then
    echo "TERMINAL=wezterm" >> /etc/environment
fi

if ! grep 'EDITOR' /etc/environment; then
    echo "EDITOR=vim" >> /etc/environment
fi

# /etc/arch-release
echo "OS=${repo}" > /etc/arch-release

# tablet-onboard
cp /opt/${repo}/scripts/tablet-onboard.sh /usr/bin/tablet-onboard
chmod +x /usr/bin/tablet-onboard

# bash.bashrc
sed "s|%OS_NAME%|${repo}|g;" /opt/${repo}/configs/bash.bashrc > /etc/bash.bashrc

cp /opt/${repo}/service/btrfs-swapon.service /etc/systemd/system/

# btrfs-swapfile
cp /opt/${repo}/scripts/btrfs-swapon /usr/bin/
chmod 755 /usr/bin/btrfs-swapon
cp /opt/${repo}/scripts/btrfs-swapoff /usr/bin/
chmod 755 /usr/bin/btrfs-swapoff

# ssh
cp /opt/${repo}/configs/sshd_config /etc/ssh/sshd_config

# snapshot.sh
cp /opt/${repo}/scripts/snapshot.sh /usr/bin/snapshot
chmod 755 /usr/bin/snapshot

# update-script
cp /opt/${repo}/scripts/update.sh /usr/bin/update-script
chmod 755 /usr/bin/update-script

# Verzeichnisse
mkdir -p /home/${user}/Dokumente
mkdir -p /home/${user}/Bilder
mkdir -p /home/${user}/Musik
mkdir -p /home/${user}/Downloads
mkdir -p /home/${user}/Videos
mkdir -p /home/${user}/Desktop
mkdir -p /home/${user}/Public
mkdir -p /home/${user}/Templates

# addusers.sh
cp /opt/${repo}/scripts/addusers.sh /usr/bin/addusers
chmod 755 /usr/bin/addusers

# set default shell
chsh -s /usr/bin/zsh root
chsh -s /usr/bin/zsh ${user}

# aurinstaller
cp /opt/${repo}/scripts/aurinstall.sh /usr/bin/aurinstaller
chmod +x /usr/bin/aurinstaller
cp /opt/${repo}/scripts/aurupdater.sh /usr/bin/aurupdater
chmod +x /usr/bin/aurupdater

# setcap-ping
setcap cap_net_raw+ep /bin/ping

# gpg pinentry
mkdir -p /home/${user}/.gnupg/
cp /opt/${repo}/scripts/pinentry-wayland /usr/bin/

# installer
mkdir -p /usr/share/applications/
cp /opt/${repo}/desktop/arch-install.desktop /usr/share/applications/arch-install.desktop

# install-picture
mkdir -p /usr/share/pixmaps/
cp /opt/${repo}/desktop/install.png /usr/share/pixmaps/

# grub_background
mkdir -p /usr/share/grub/
cp /opt/${repo}/grub/grub_background.png /usr/share/grub/background.png

# bluetooth-network-polkit
mkdir -p /etc/polkit-1/rules.d/
cp /opt/${repo}/polkit/51-blueman.rules /etc/polkit-1/rules.d/51-blueman.rules
cp /opt/${repo}/polkit/50-org.freedesktop.NetworkManager.rules /etc/polkit-1/rules.d/50-org.freedesktop.NetworkManager.rules

# os-release
cp /opt/${repo}/os-release /etc/

# lsb-release
cp /opt/${repo}/lsb-release /etc/

# autodiskmount
mkdir -p /media/
mkdir -p /etc/udev/rules.d/

# touchpad
#cp /opt/${repo}/01-touchpad.rules /etc/udev/rules.d/01-touchpad.rules
cp /opt/${repo}/scripts/mouse-pnp-event-handler.sh /usr/bin/mouse-pnp-event-handler.sh
chmod +x /usr/bin/mouse-pnp-event-handler.sh
cp /opt/${repo}/scripts/touchpad_toggle.sh /usr/bin/touchpad_toggle
chmod +x /usr/bin/touchpad_toggle

# hardreset
cp /opt/${repo}/scripts/hardreset.sh /usr/bin/hardreset.sh
chmod +x /usr/bin/hardreset.sh

# slowtype
cp /opt/${repo}/scripts/slowtype /usr/bin/slowtype
chmod +x /usr/bin/slowtype

# clipboard wrapper
cp -v /opt/${repo}/scripts/clipboard_wrapper/* /usr/bin/

# Convert commands (vim)
cp -v /opt/${repo}/scripts/csv2tsv /usr/bin/
cp -v /opt/${repo}/scripts/tsv2csv /usr/bin/

# cpu_gpu sensors
mkdir -p /etc/conf.d
cp /opt/${repo}/scripts/lm_sensors /etc/conf.d/lm_sensors

# wacom stylus-support
cp /opt/${repo}/configs/10-wacom.rules /etc/udev/rules.d/10-wacom.rules
cp /usr/share/X11/xorg.conf.d/70-wacom.conf /etc/X11/xorg.conf.d/

# zramctrl
cp /opt/${repo}/scripts/zramctrl /usr/bin/zramctrl
cp /opt/${repo}/service/zramswap.service /etc/systemd/system/zramswap.service
systemctl enable zramswap

# hooks
cp -v /opt/${repo}/configs/install/* /usr/lib/initcpio/install/
cp -v /opt/${repo}/configs/hooks/* /usr/lib/initcpio/hooks/
cp -v /opt/${repo}/configs/script-hooks/* /usr/lib/initcpio/

mkdir -p /etc/pacman.d/hooks
cp -v /opt/${repo}/configs/pacman-hooks/* /etc/pacman.d/hooks/

cp -v /opt/${repo}/make-packages-txt.sh /usr/bin/make-packages-txt.sh
chmod +x /usr/bin/make-packages-txt.sh

pacmanversion="pacman.conf"
sed 's|%VERSION%|'$pacmanversion'|' -i /etc/pacman.d/hooks/pacmanconf.hook

# nano
echo "include "/usr/share/nano/*.nanorc"" > /etc/nanorc

# Install rc.local
echo "[Unit]
Description=/etc/rc.local compatibility

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/rc-local.service
touch $RCLOCAL
chmod +x $RCLOCAL
systemctl enable rc-local.service
if ! grep '#!' $RCLOCAL; then
    echo "#!/bin/bash" > $RCLOCAL
fi

if ! grep 'setcap cap_net_raw+ep /bin/ping' $RCLOCAL; then
    echo "setcap cap_net_raw+ep /bin/ping" >> $RCLOCAL
fi


# Install rc.shutdown

echo "[Unit]
Description=/etc/rc.local.shutdown Compatibility
ConditionFileIsExecutable=/etc/rc.local.shutdown
DefaultDependencies=no
After=basic.target
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/etc/rc.local.shutdown
StandardInput=tty
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/rc-local-shutdown.service
touch $RCLOCALSHUTDOWN
chmod +x $RCLOCALSHUTDOWN
systemctl enable rc-local-shutdown.service
if ! grep '#!' $RCLOCALSHUTDOWN; then
    echo "#!/bin/bash" > $RCLOCALSHUTDOWN
fi

# set desktop
echo "set desktop"
#
mkdir -p /etc/X11/xinit/
echo "Systemsprache und dienste werden erstellt!"

mkdir -p /etc/X11/xorg.conf.d/
cp -R /opt/${repo}/configs/xorg.conf.d/* /etc/X11/xorg.conf.d/
if ! [ -f "/etc/X11/xorg.conf.d/40-libinput.conf" ]; then
    ln -s /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/40-libinput.conf
fi

if ! [ -f "/usr/bin/l" ]; then
    ln -s /usr/bin/ls /usr/bin/l
fi

su ${user} -l -c "chezmoi init --apply https://git.brothertec.eu/simono41/dotfiles.git"
su ${user} -l -c "chezmoi update -v"

# https://aur.archlinux.org/packages/ttf-font-nerd-dummy
# I was going to delete it because at the moment the only package that provides ttf-font-nerd is ttf-iosevka-nerd (see this search entry),
# if ttf-iosevka-nerd no longer provides ttf-font-nerd (which can be a possible fix to bug #74050),
# this AUR package will be the only package that provides ttf-font-nerd, in which case it is better deleted.
#if pacman -Rdd ttf-iosevka-nerd --noconfirm; then
#    aurinstaller ttf-font-nerd-dummy
#fi

#aurinstaller conky-lua-nv
#aurinstaller passdmenu
#aurinstaller ntfysh-bin
#aurinstaller spotify
#aurinstaller https://github.com/MultiMC/multimc-pkgbuild
#aurinstaller jetbrains-toolbox
#aurinstaller kickoff

# Minecraft-launcher
aurinstaller polymc-bin

# bash beautifier
aurinstaller beautysh

# arandr for wayland
aurinstaller wdisplays

# audio bar
aurinstaller sov

# brightness bar
aurinstaller wob

# logout screen
aurinstaller wlogout

# on-screen keyboard (start with wvkbd-mobintl)
aurinstaller wvkbd

# background temparature
aurinstaller wl-gammarelay-rs
if [ "${archisoinstall}" == "y" ]; then
    echo "Entferne wl-gammerelay-rs Ordner um Speicherplatz zu sparen"
    rm -R /home/${user}/aur-builds/wl-gammarelay-rs
fi

# thinkpad docking station Ultra
#aurinstaller evdi-git
#aurinstaller displaylink
# Systemd Service (zum testen)
#systemctl enable displaylink

# MS-Fonts
mkdir -p /etc/fonts/conf.avail/
cp /opt/${repo}/configs/20-no-embedded.conf /etc/fonts/conf.avail/

if ! [ -f "/etc/fonts/conf.d/20-no-embedded.conf" ]; then
    ln -s /etc/fonts/conf.avail/20-no-embedded.conf /etc/fonts/conf.d/
fi

# Clear and regenerate your font cache
fc-cache -f -v

# Icons
gsettings set org.gnome.desktop.interface cursor-theme capitaine-cursors
gsettings set org.gnome.desktop.interface gtk-theme Arc-Darker
gsettings set org.gnome.desktop.interface icon-theme Arc
gsettings set org.gnome.desktop.wm.preferences theme "Arc-Darker"

gtk-update-icon-cache

userrechte

# grub-updater
if [ -d /etc/grub.d ]; then
    cp /opt/${repo}/configs/grub.d/10_linux /etc/grub.d/10_linux
fi
mkdir -p /boot/grub/
grub-mkconfig -o /boot/grub/grub.cfg

#aurupdater
add_locale_settings

if pacman -Qdtq; then
    echo "Verwaiste Packete werden entfernt :)"
    pacman -Rsn $(pacman -Qdtq) --noconfirm
else
    echo "Es müssen keine verwaisten Packete entfernt werden :)"
fi

if ! pacman -Syu --needed --noconfirm; then
    echo "Konnte Aktualisierung nicht abschliessen!!!"
fi

mkinitcpio -P -c /etc/mkinitcpio.conf

echo "Erstelle Packetverzeichnis!!!"

if [ "${archisoinstall}" == "y" ]; then
    mkdir -p ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/
    echo "[Service]" > ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
    echo "ExecStart=" >> ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf
    echo "ExecStart=-/usr/bin/agetty --autologin ${user} -s %I 115200,38400,9600 vt102" >> ${mountpoint}/etc/systemd/system/getty\@tty1.service.d/autologin.conf

    links

    pacman -Qq > /pkglist.txt
    if [ $(ls /var/cache/pacman/pkg | wc -w) -gt 0 ]; then
        rm -R /var/cache/pacman/pkg/*
    fi

    if [ -f /root/.bash_history ]; then
        rm /root/.bash_history
    fi

    if [ -f /home/${user}/.bash_history ]; then
        rm /home/${user}/.bash_history
    fi
fi

echo "$(date "+%Y%m%d-%H%M%S")"
echo "Fertig!!!"

exit 0
