#!/usr/bin/env bash

set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo $0 $1 $2 $3 $4 $5 $6 $7 $8 $9
    exit 0
fi
echo "Als root Angemeldet"


kernel1="$(echo $(find /boot/ -name "initramfs*linux.img") | cut -d" " -f1)"
linuz1="$(echo $(find /boot/ -name "vmlinuz*") | cut -d" " -f1)"
kernel="${kernel1#/*/}"
linuz="${linuz1#/*/}"

kernelback1="$(echo $(find /boot/ -name "initramfs*-fallback.img") | cut -d" " -f1)"
kernelback="${kernelback1#/*/}"


echo "Kernel: ${kernel}"
echo "Linuz: ${linuz}"
echo "Kernel-fallback: ${kernelback}"

if [ "${kernel1}" == "/boot/initramfs-linux.img" ]; then
    echo "Ist die selbe Datei. Operation nicht notwendig!!!"
else

    cp "${kernel1}" "/boot/initramfs-linux.img"
    cp "${linuz1}" "/boot/vmlinuz-linux"

fi

if [ -f /boot/arch-uefi.conf.default ]; then
    sed "s|%LINUZ%|vmlinuz-linux|g;
    s|%KERNEL%|initramfs-linux.img|g" /boot/arch-uefi.conf.default > /boot/loader/entries/arch-uefi.conf

    sed "s|%LINUZ%|vmlinuz-linux|g;
    s|%KERNEL%|initramfs-linux-fallback.img|g" /boot/arch-uefi.conf.default > /boot/loader/entries/arch-uefi-fallback.conf
fi

if [ -f /boot/initramfs-stable.img ]; then
    cp /boot/initramfs-linux.img /boot/initramfs-stable.img
    cp /boot/vmlinuz-linux /boot/vmlinuz-stable
fi

echo "Bootloader update $(date)" >> /update.log
