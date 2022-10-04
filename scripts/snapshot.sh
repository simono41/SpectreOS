#!/usr/bin/env bash

set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo $0 $1 $2 $3 $4 $5 $6 $7 $8 $9
    exit 0
fi
echo "Als root Angemeldet"

timetoday="$(date "+%Y%m%d-%H%M%S")"

if [ "make" == "$1" ] || [ "add" == "$1" ] || [ "backup" == "$1" ] || [ "cp" == "$1" ] || [ "create" == "$1" ]; then
    
    while (( "$(expr $# - 1)" ))
    do
        
        pfad="${2}"
        
        echo "${timetoday}" > /btrfs-root/__current/${pfad}/SNAPSHOT
        echo "BACKUP" >> /btrfs-root/__current/${pfad}/SNAPSHOT
        
        sed -i "s|__current/${pfad}|__snapshot/${pfad}@`head -n 1 /btrfs-root/__current/${pfad}/SNAPSHOT`|g;" /etc/fstab.default
        
        mkdir -p /btrfs-root/__snapshot/${pfad%/*}
        btrfs subvolume snapshot /btrfs-root/__current/${pfad} /btrfs-root/__snapshot/${pfad}@`head -n 1 /btrfs-root/__current/${pfad}/SNAPSHOT`
        #btrfs subvolume snapshot -r /btrfs-root/__current/${pfad} /btrfs-root/__snapshot/${pfad}@`head -n 1 /btrfs-root/__current/${pfad}/SNAPSHOT`
        
        #if ! [ "${pfad}" == "ROOT" ]; then
        #    rm /btrfs-root/__current/${pfad}/SNAPSHOT
        #fi
        
        shift
        
    done
    
    #reset-fstab
    cp /etc/fstab /etc/fstab.default
    
    kernel="initramfs-linux.img"
    linuz="vmlinuz-linux"
    kernelback="initramfs-linux-fallback.img"
    
    cp /boot/${kernel} /boot/backup_initramfs-linux.img
    cp /boot/${linuz} /boot/backup_vmlinuz-linux
    
    #stable-snapshot-boot
    #if [ -f "/boot/arch-uefi.conf.default" ]; then
    #    kernel="initramfs-stable.img"
    #    linuz="vmlinuz-stable"
    #    sed "s|%LINUZ%|${linuz}|g;s|%KERNEL%|${kernel}|g;s|rootflags=subvol=__current/ROOT|rootflags=subvol=__snapshot/ROOT@`head -n 1 /btrfs-root/__current/ROOT/SNAPSHOT`|g" /boot/arch-uefi.conf.default > /boot/loader/entries/arch-uefi-stable.conf
    #fi
    
    echo "__snapshot/ROOT@`head -n 1 /btrfs-root/__current/ROOT/SNAPSHOT`" >> /etc/grub-snapshot
    grub-mkconfig -o /boot/grub/grub.cfg
    
    #if [ -f /btrfs-root/__current/ROOT/SNAPSHOT ]; then
    #    rm /btrfs-root/__current/ROOT/SNAPSHOT
    #fi
    
    elif [ "restore" == "$1" ] || [ "remake" == "$1" ] || [ "mv" == "$1" ]; then
    
    while (( "$(expr $# - 1)" ))
    do
        
        pfad="${2}"
        
        if [ -d /btrfs-root/__current/${pfad/@*}.old ]; then
            btrfs subvolume delete /btrfs-root/__current/${pfad/@*}.old
        fi
        mv /btrfs-root/__current/${pfad/@*} /btrfs-root/__current/${pfad/@*}.old
        btrfs subvolume snapshot /btrfs-root/__snapshot/${pfad} /btrfs-root/__current/${pfad/@*}
        
        #only root for the fstab
        if [ "${pfad}" == "ROOT" ]; then
            cp /etc/fstab /btrfs-root/__current/${pfad/@*}/etc/fstab
        fi
        
        
        
        
        shift
        
    done
    
    
    btrfs subvolume list -p /
    
    #echo "Bitte noch die /etc/fstab editieren und die neuen IDs eintragen!!!"
    
    echo "Bitte damit die Änderungen wirksam werden das System neustarten!!!"
    
    #reboot
    
    elif [ "delete" == "$1" ] || [ "del" == "$1" ] || [ "rm" == "$1" ]; then
    
    while (( "$(expr $# - 1)" ))
    do
        pfad="${2}"
        
        if btrfs subvolume delete /btrfs-root/__snapshot/${pfad}\@* ;then
            echo "${pfad} erfolgreich gelöscht!!!"
        else
            echo "${pfad} konnte nicht gefunden werden!!!"
        fi
        
        shift
    done
    
else
    
    echo "bash ./snapshot.sh PARAMETER PFAD"
    echo "Parameters: make restore"
    echo "make var/cache/pacman/pkg opt home ROOT"
    echo "restore ROOT@20170725-235544 home@20170725-235544 opt@20170725-235544 var/cache/pacman/pkg@20170725-235544"
    
    btrfs subvolume list -p /
    
fi

echo "Fertig !!!"
