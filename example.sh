#!/bin/bash

until [ "${comfirm}" = "y" ]
do

check=""
until [ "${check}" = "y" ]
do

dev1=""
until [ -n "${dev1}" ]
do

read -p " [] Do you want install from 
    (1) tar.xz
    (2) kernel folder
 -> " tar

if [ ${tar} = "1" ]; then
	sudo rm -rf arch
	sudo rm -rf dist
	tar Jxvf boot.tar.xz
	tar Jxvf modules.tar.xz
fi

read -p " [] Where is your card reader?[eg] sdx
 -> " reader
dev1=$(lsblk | grep "${reader}"1)
dev2=$(lsblk | grep "${reader}"2)	
done

echo
echo ${dev1}
echo ${dev2}
echo 
read -p " [] Is that correct?[y/n]
 -> " check
done

path1=$(echo "$dev1" | grep -o "/media/.*")
path2=$(echo "$dev2" | grep -o "/media/.*")

echo
echo ${path1}
echo ${path2}
echo
read -p " [] Is the path correct?[y/n]
 -> " comfirm
done

echo
read -p " [] What's your kernel name?
 -> " name
echo " ** Installing kernel"
cp arch/arm/boot/zImage "${path1}"/"${name}"
sed -i '/kernel=/d' "${path1}"/config.txt
echo "kernel=${name}" | sudo tee --append "${path1}"/config.txt

echo
echo " ** Installing modules"
sudo cp -rp dist/lib/modules/* "${path2}"/lib/modules/

echo
echo " ** Installing dtb overlays"
rm -f "${path1}"/overlays/*
cp arch/arm/boot/dts/*.dtb* "${path1}"/
sed -i '/device_tree=/d' "${path1}"/config.txt
echo "device_tree=bcm2710-rpi-3-b.dtb" | sudo tee --append "${path1}"/config.txt
cp arch/arm/boot/dts/overlays/*.dtb* "${path1}"/overlays

echo
echo " ** Waiting for file system sync"
sync

read -p " [] Do you want to unmount SD card?[y/n]
 -> " umount
if [ "${umount}" = "y" ]; then
	sudo umount "${path1}"
	sudo umount "${path2}"
fi