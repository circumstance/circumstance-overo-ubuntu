#! /bin/sh

#altered by Tim Redfern, 2012 for circumstance - tomorrow the ground forgets you were here

# fdisk portion of script based on mkcard.sh v0.4
# (c) Copyright 2009 Graeme Gregory <dp@xora.org.uk>
# Additional functionality by Steve Sakoman
# (c) Copyright 2010-2011 Steve Sakoman <steve@sakoman.com>
# Licensed under terms of GPLv2
#
# Parts of the procudure base on the work of Denys Dmytriyenko
# http://wiki.omap.com/index.php/MMC_Boot_Format

VERSION=0.9
RELEASE="gnome-r13"

# hack to use a particular kernel variant
KERNEL_VARIANT=""

export LC_ALL=C

MOUNT_POINT="/media/temp"

PWD=`pwd`
WORK_DIR=$PWD

if [ $# -eq 0 ]; then
	echo ""
	echo "$0 version $VERSION"
	echo "Usage: $0 <drive> <machine> <image> <release>"
	echo "   drive: SD device (i.e. /dev/sdc)"
	exit 1;
fi

if ! id | grep -q root; then
	echo "This utility must be run prefixed with sudo or as root"
	exit 1;
fi

if [ "$1" = "/dev/sda" ] ; then
	echo "Sorry, /dev/sda probably holds your PC's rootfs.  Please specify a SD device."
	exit 1;
fi
DRIVE=$1

#make sure that the SD card isn't mounted before we start
if [ -b ${DRIVE}1 ]; then
	umount ${DRIVE}1
	umount ${DRIVE}2
elif [ -b ${DRIVE}p1 ]; then
	umount ${DRIVE}p1
	umount ${DRIVE}p2
else
	umount ${DRIVE}
fi

dd if=/dev/zero of=$DRIVE bs=1024 count=1024

SIZE=`fdisk -l $DRIVE | grep Disk | grep bytes | awk '{print $5}'`

echo DISK SIZE – $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

echo CYLINDERS – $CYLINDERS

# Align partitions for SD card performance/wear optimization
# FAT partition size is 131072 sectors (64MB) less:
#	MBR - 1 sector
#       padding to align to the page size of the underlying flash - 127 sectors
# so we start the first partition at sector 128 and make it 131072 - 128 = 130944 sectors
# second partition starts at 131072 and continues to fill the card
{
echo 128,130944,0x0C,*
echo 131072,,,-
} | sfdisk --force -D -uS -H 255 -S 63 -C $CYLINDERS $DRIVE

sleep 1

if [ -b ${DRIVE}1 ]; then
	PART1=${DRIVE}1
	PART2=${DRIVE}2
elif [ -b ${DRIVE}p1 ]; then
	PART1=${DRIVE}p1
	PART2=${DRIVE}p2
else
	echo "Improper partitioning on $DRIVE"
	exit 1;
fi

umount ${PART1}
mkfs.vfat -F 32 -n boot ${PART1}

umount ${PART2}
mke2fs -j -L rootfs ${PART2}


# create a mount point if it doesn't already exist
if [ ! -d $MOUNT_POINT ]; then
	if ! mkdir $MOUNT_POINT; then
		echo "Could not create mount point: $MOUNT_POINT"
		echo "SD card creation was not successful"
		exit 1;
	fi
fi

if mount -t vfat ${PART1} $MOUNT_POINT; then
	echo "Populating boot partition files"
	tar xvf  boot.tgz -C  $MOUNT_POINT
	sync
	cd $WORK_DIR
	umount $MOUNT_POINT
	echo "Boot partition complete"
else
	echo "Can't mount ${PART1} at $MOUNT_POINT for boot partition creation"
	echo "SD card creation was not successful"
	exit 1;
fi

# this shouldn't be necessary, but Ubuntu seems to remove the mount point!
if [ ! -d $MOUNT_POINT ]; then
	if ! mkdir $MOUNT_POINT; then
		echo "Could not create mount point: $MOUNT_POINT"
		echo "SD card creation was not successful"
		exit 1;
	fi
fi

if mount -t ext3 ${PART2} $MOUNT_POINT; then
		echo "Populating rootfs partition files"
		echo "This will take several minutes . . ."
		tar xvf rootfs.tgz  -C  $MOUNT_POINT
		sync
		cd $WORK_DIR
		umount $MOUNT_POINT
		echo "Rootfs partition complete"
	else
		echo "Error populating rootfs partition"
		echo "SD card creation was not successful"
	fi


echo "SD card creation was successful"

exit 0;


