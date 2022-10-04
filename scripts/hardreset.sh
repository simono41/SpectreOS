#!/usr/bin/env bash

set -ex

umount -a
mount -f / -o remount,ro
echo "System schaltet sich gleich SOFORT!!! aus in"
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep1

echo s >| /proc/sysrq-trigger
echo u >| /proc/sysrq-trigger
echo b >| /proc/sysrq-trigger
