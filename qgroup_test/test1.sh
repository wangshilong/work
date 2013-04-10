#!/bin/sh

mnt="/mnt/mybtrfs"
disk="/dev/sdb"
subv="$mnt/subv"
snap="$mnt/snap"
ncases=30

test_mounted()
{	
	lines=`cat /proc/mounts | grep $disk`
	if [ -z "$lines" ]
	then
		return 0
	else
		return 1
	fi
}

quota_setup()
{
	test_mounted
	if [ $? -eq 1 ]
	then
		umount $disk
		if [ $? -ne 0 ]
		then
			echo "unable to umount $disk"
			exit 1
		fi

	fi

	mkfs.btrfs $disk
	if [ $? -ne 0 ]
	then
		echo "mkfs.btrfs fails"
		return 1
	fi

	if [ $# -eq 0 ]
	then
		mount $disk $mnt
		if [ $? -ne 0 ]
		then
			echo "mounting fails"
			return 1
		fi
	else
		mount -o $1 $disk $mnt
		if [ $? -ne 0 ]
		then
			echo "mounting fails"
			return 1
		fi
	fi

	btrfs quota enable $mnt
	if [ $? -ne 0 ]
	then
		echo "enabling quota fails"
		return 1
	fi
	sync
}

quota_clean()
{
	btrfs quota disable $mnt
	if [ $? -ne 0 ]
	then 
		echo "quota disabling fails"
		return 1
	fi

	if [ -d $subv ]
	then
		btrfs sub delete $subv
		if [ $? -ne 0 ]
		then
			echo "deleting $subv should be successful"
			return  1
		fi
	fi

	if [ -d $snap ]
	then
		btrfs sub delete $snap
		if [ $? -ne 0 ]
		then
			echo "deleting $snap should be successful"
			return 1
		fi
	fi

	umount $mnt
	if [ $? -ne 0 ]
	then 
		echo "umounting $mnt fails"
		return 1
	fi

	btrfsck $disk
	if [ $? -ne 0 ]
	then 
		echo "btrfscking $disk fails"
		return 1
	fi
}

assign_to_qgroup()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 2/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 2/1 should be successful"
		return 1
	fi

	i1=1
	while [ $i1 -le $ncases ]
	do
		btrfs qgroup create 1/$i1 $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $i should be successful"
			return 1
		fi
		btrfs qgroup assign 1/$i1 2/1 $mnt
		if [ $? -ne 0 ]
		then
			echo "assign 1/$i1 to 2/1 $mnt should be successful"
			return 1
		fi
		i1=$(($i1+1))
	done

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}
assign_to_qgroup
