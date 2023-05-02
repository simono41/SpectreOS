### Hinweis
    Die Master-Branch gehört zur x86_64 Prozessor-Architektur (Die x86_64 ist auch die aktuellste Branch)

### Abhängigkeiten
    pacman -S arch-install-scripts squashfs-tools dosfstools libisoburn

### ROM bauen
    ./make_mksquashfs-auto.sh makesystem mkinitcpio filesystem makeimage makebios makeiso

### ROM in einer VM-Testen
    qemu-system-x86_64 --enable-kvm --cdrom out/arch-deadc0de_remix_os-20211212-x86_64.iso -boot d -m 8G

### Erzeugen einen Images mit dynamischer größe
    qemu-img create -f qcow2 ~/SpectreOS.img 200G

### ROM zum starten von Wayland mit VNC und Image mit Passwort Authentifizierung
    printf "change vnc password\n%s\n" password | sudo qemu-system-x86_64 --cdrom out/arch-spectreos-* -boot d -m 8G -vnc :1,password -monitor stdio --enable-kvm -vga qxl -k de -hda ~/SpectreOS.img 

### Zum starten mit Wine in Wayland von World of Warcraft
    DISPLAY=:0 wine Wow.exe -opengl

### Zum anzeigen der Größe der installierten Packeten
    LC_ALL=C pacman -Qi | awk '/^Name/{name=$3} /^Installed Size/{print $4$5, name}' | sort -h

### Zum starten einer Sitzung mit Mosh
    LC_ALL="en_US.UTF-8" mosh --ssh="ssh -p PORT" user@server

### Set DPI in Nvidia xorg.conf in Device or Screen
    xrandr --dpi 96

    Set in Nvidia xorg.conf in Device or Screen
    Option              "DPI" "96 x 96"

    starten sie auch beim ersten start arandr und speichern sie im .screenlayout Ordner die monitor.sh um die aktuelle Auflösung dauerhaft zu sichern und beim nächsten Start von i3 zu laden

### Ändern eines fonts mittels gsettings (dbus-launch ist optional)
    gsettings list-keys org.gnome.desktop.interface
    gsettings get org.gnome.desktop.interface font-name
    gsettings set org.gnome.desktop.interface cursor-theme capitaine-cursors
    gsettings set org.gnome.desktop.interface gtk-theme Arc-Dark
    gsettings set org.gnome.desktop.interface icon-theme Arc
    gsettings set org.gnome.desktop.wm.preferences theme "Arc-Dark"

### Liste zur README.bootparams
    https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio-archiso/-/blob/master/docs/README.bootparams

### Hier zu einem ähnlichem Script zu make_mksquashfs-auto.sh
    https://gitlab.archlinux.org/archlinux/archiso/-/blob/master/archiso/mkarchiso

### Hier ein Script zum vollautomatisiertem starten mit QEMU
    https://gitlab.archlinux.org/archlinux/archiso/-/blob/master/scripts/run_archiso.sh
