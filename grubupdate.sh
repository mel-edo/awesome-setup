#!/bin/sh

sudo grub-install --no-nvram
sudo grub-mkconfig -o /boot/grub/grub.cfg
