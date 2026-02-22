#!/bin/bash

apt update -y && apt upgrade -y

apt install grub2 wimtools ntfs-3g -y

#Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

#Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

#Create GPT partition table
parted /dev/sda --script -- mklabel gpt

#Create two partitions
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

#Inform kernel of partition table changes
partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30 

#Format the partitions
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

echo "NTFS partitions created"

echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

mount /dev/sda1 /mnt

#Prepare directory for the Windows disk
cd ~
mkdir windisk

mount /dev/sda2 windisk

grub-install --root-directory=/mnt /dev/sda

#Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

cd /root/windisk


mkdir winfile
WINDOWS_ISO_URL="https://138-201-250-118.top/Getintopc.com/Windows.server.2022.with.update.20348.1487.10in1.x64.v23.01.11.iso?md5=xWE_RISV1n_COz6SMl_y7w&expires=1774312601"
wget -c "$WINDOWS_ISO_URL" -O "windows_server_2022.iso"

if [ $? -ne 0 ]; then
    echo "Error: One or more ISO downloads failed. Please check the URLs and your network connection."
    exit 1
fi
echo "ISO downloads complete."

mount -o loop windows_server_2022.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

VIRTIO_ISO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-0.1.285.iso"

wget -c "$VIRTIO_ISO_URL" -O "virtio_win.iso"

if [ $? -ne 0 ]; then
    echo "Error: One or more ISO downloads failed. Please check the URLs and your network connection."
    exit 1
fi

echo "ISO downloads complete."

mount -o loop virtio_win.iso winfile

mkdir /mnt/sources/virtio

rsync -avz --progress winfile/* /mnt/sources/virtio

cd /mnt/sources

touch cmd.txt

echo 'add virtio /virtio_drivers' >> cmd.txt

wimlib-imagex update boot.wim 2 < cmd.txt

reboot


