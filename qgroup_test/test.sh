#!/bin/sh

mnt="/mnt/mybtrfs"
disk="/dev/sdb"
subv="$mnt/subv"
snap="$mnt/snap"

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

#giving limited size
#is_compressed
#is_exclusive
limiting_prepare()
{
	options=""

	if [ $# -ne 3 ]	
	then
		echo "Usage: limited_size, is_compressed, is_exclusive"
		return 1
	fi
	
	btrfs sub create $subv
	if [ $? -ne 0 ]
	then
		echo "creating $subv should be successful"
		return 1
	fi

	if [ $2 -eq 1 ]
	then
		options="$options""c"
	elif [ $2 -ne 0 ]
	then
		echo "invalid is_commpressed is given"
		return 1
	fi

	if [ $3 -eq 1 ]
	then
		options="$options""e"
	elif [ $3 -ne 0 ]
	then
		echo "invalid is_exclusive is passed"
		return 1
	fi
	
	if [ "$options" ]
	then
		options=-"$options"
	fi

	btrfs qgroup limit $options $1 $subv 
	if [ $? -ne 0 ]
	then
		echo "limiting $subv to $1 should be successful"
		echo "btrfs qgroup limit $options $1 $subv"
		return 1
	fi
}

#parent_qgroupid
#limit_size
#is_compressed
#is_exclusive
limiting_prepare_single_parent()
{
	options=""
	if [ $# -ne 4 ]
	then
		echo "Usage: parent_qgroupid, limited_size, is_compressed, is_exclusive"
		return 1
	fi

	str=`btrfs qgroup show $mnt| grep $1`
	if [ -z $str ]
	then
		btrfs qgroup create $1 $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $1 should be successful"
			return 1
		fi
	fi

	if [ $3 -eq 1 ]
	then
		options="$options""c"
	elif [ $3 -ne 0 ]
	then
		echo "invalid argument is_compressed is given"
		return 1
	fi

	if [ $4 -eq 1 ]
	then
		options="$options""e"
	elif [ $4 -ne 0 ]
	then
		echo "invalid argument is_exclusive is given"
		return 1
	fi

	if [ "$options" ]
	then
		options=-"$options"
	fi

	btrfs qgroup limit $options $2 $1 $mnt
	if [ $? -ne 0 ]
	then
		echo "limiting $1 should be successful"
		return 1
	fi
}

#qgroupid
#referenced_expected
#exclusive_expected
check_qgroup_accounting()
{
	if [ $# -ne 3 ]
	then
		echo "Usage: qgroupid, expected_ref, expected_excl"
		return 1
	fi
	
	referenced=`btrfs qgroup show $mnt | grep $1 | awk '{print $2}'`
	exclusive=`btrfs qgroup show $mnt | grep $1 | awk '{print $3}'`

	if [ -z $referenced -o -z $exclusive ]
	then
		echo "getting ref and excl should be successful"
		return 1
	fi

	if [ $referenced -ne $2 -o $exclusive -ne $3 ]
	then
		echo "qgroup accounting for $1 should be successful"
		return 1
	fi
}

case1()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/0 $mnt
	if [ $? -eq 0 ]
	then
		echo "creating 0 qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case2()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case3()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/5 $mnt
	if [ $? -eq 0 ]
	then
		echo "creating 0/5 qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case4()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/256 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/256 qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case5()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/281474976710655 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/(2^48-1) qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case6()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/281474976710656 $mnt
	if [ $? -eq 0 ]
	then
		echo "creating 0/(2^48) qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case7()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/0 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/0 qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case8()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 65535/0 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating (2^16-1)/0 qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case9()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 65536/0 $mnt
	if [ $? -eq 0 ]
	then
		echo "creating (2^16)/0 qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case10()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/0 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/0 qgroup should be successful"
		return 1
	fi

	btrfs qgroup create 1/0 $mnt
	if [ $? -eq 0 ]
	then
		echo "creating qgroup existed should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case11()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 qgroup should be successful"
		return 1
	fi
	
	btrfs qgroup destroy 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "destroying a qgroup existed should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case12()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup destroy 0/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "destroying a qgroup not existed should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case13()
{
	
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/1 should be successful"
		return 1
	fi

	btrfs qgroup assign 0/1 0/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "assigning qgroup relation to himself should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi

}

case14()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 1/1 should be successful"
		return 1
	fi

	btrfs qgroup create 1/2 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 1/2 should be successful"
		return 1
	fi

	btrfs qgroup assign 1/1 1/2 $mnt
	if [ $? -eq 0 ]
	then
		echo "assigning qgroup relation in the same level should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case15()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/1 should be successful"
		return 1
	fi

	btrfs qgroup create 1/5 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/5 should be successful"
		return 1
	fi

	btrfs qgroup assign 1/5 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "bad qgroup relation should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case16()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/1 should be successful"
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 1/1 should be successful"
		return 1
	fi

	btrfs qgroup assign 0/1 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assigning 0/1 to 1/0 should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case17()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/1 should be successful"
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 1/1 should be successful"
		return 1
	fi

	btrfs qgroup assign 1/1 0/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "bad qgroup relation should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case18()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 0/1 should be successful"
		return 1
	fi

	btrfs qgroup assign 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "parent qgroup dose't exist,assigning qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case19()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating qgroup 1/0 should be successful"
		return 1
	fi

	btrfs qgroup assign 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "child qgroup dose't exist,assigning qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case20()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup assign 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "qgroups dose't exist,assigning qgroup should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case21()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 qgroup should be successful"
		return 1
	fi
	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/1 qgroup should be successful"
		return 1
	fi
	btrfs qgroup assign 0/1 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assigning 0/1 to 1/1 should be successful"
		return 1
	fi
	btrfs qgroup remove 0/1 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "removing 0/1 1/1 should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case22()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/1 qgroup should be successful"
		return 1
	fi
	btrfs qgroup remove 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "removing 0/1 1/1 should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case23()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 qgroup should be successful"
		return 1
	fi

	btrfs qgroup remove 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "removing 0/1 1/1 should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case24()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup remove 0/1 1/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "removing 0/1 1/1 should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case25()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=1K count=2
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }' `
	./check_accuracy 2048 $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case26()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case27()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5242880-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case28()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5242880-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case29()
{
	echo "compressed is not supported now"
}

case30()
{
	echo "compressed is not supported now"
}

case31()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size1=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5242880-4096)) $size1 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid $(($size1+4096)) $(($size1+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap
	if [ $? -ne 0 ]
	then
		echo "snapshot $subv to $snap should be successful"
	fi

	dd if=/dev/zero of=$subv/data1 bs=2M count=1
	sync
	size2=`du -sh -b $subv/data1 | awk '{ print $1 }'`
	./check_accuracy $((2*1024*1024)) $size2 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | grep subv | awk '{ print $2 }'`
	check_qgroup_accounting $qgroupid $(($size2+$size1+4096)) $(($size2+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case32()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $((3*1024*1024+4096)) $((3*1024*1024+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case33()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case34()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case35()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case36()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 3M
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case37()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 5M
	if [ $? -eq 0 ]
	then
		echo "fallocating should not be successful"
		return 1
	fi
#	sync
#	size=`du -sh -b $subv/data | awk '{ print $1 }'`
#	./check_accuracy $((5*1024*1024-4096)) $size 95
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

#	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
#	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case38()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 6M
	if [ $? -eq 0 ]
	then
		echo "fallocating should not be successful"
		return 1
	fi
#	sync
#	size=`du -sh -b $subv/data | awk '{ print $1 }'`
#	./check_accuracy $((5*1024*1024-4096)) $size 95
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

#	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
#	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case39()
{
	echo "compressed not supported"
}

case40()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 6M
	if [ $? -eq 0 ]
	then
		echo "fallocating should not be successful"
		return 1
	fi
#	sync
#	size=`du -sh -b $subv/data | awk '{ print $1 }'`
#	./check_accuracy $((5*1024*1024-4096)) $size 95
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

#	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
#	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case41()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 3M
	sync
	size1=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size1 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size1+4096)) $(($size1+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snap $subv $snap
	fallocate $subv/data1 -l 3M
	sync
	size2=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size2 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size1+$size2+4096)) $(($size2+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case42()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 3M
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case43()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 4M
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((4*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case44()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 6M
	if [ $? -eq 0 ]
	then
		echo "fallocating should not be successful"
		return 1
	fi
#	sync
#	size=`du -sh -b $subv/data | awk '{ print $1 }'`
#	./check_accuracy $((5*1024*1024-4096)) $size 95
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

#	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
#	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case45()
{
	echo "compressed is not supported"
}

case46()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 3M
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case47()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 4M
	sync
	size1=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((4*1024*1024)) $size1 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size1+4096)) $(($size1+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snap $subv $snap
	fallocate $subv/data1 -l 3M
	sync
	size2=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size2 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size1+$size2+4096)) $(($size2+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case48()
{
	echo "compressed not supported"
}

case49()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi

}

case50()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap
	if [ $? -ne 0 ]
	then
		echo "snapshot $subv to $snap should be successful"
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case51()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case52()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case53()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case54()
{
	echo "compressed is not supported now"
}

case55()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case56()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap
	if [ $? -ne 0 ]
	then
		echo "snapshot $subv to $snap should be successful"
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case57()
{
	echo "compressed is not supported now"
}

case58()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case59()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap
	if [ $? -ne 0 ]
	then
		echo "snaoshot $subv to $snap should be successful"
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case60()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case61()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case62()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case63()
{
	echo "compressed is not supported"
}

case64()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case65()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case66()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare $((5*1024*1024)) 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case67()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case68()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case69()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case70()
{
	echo "compressed is not supported"
}

case71()
{
	echo "compressed is not supported"
}

case72()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data1 bs=5M count=1
	sync
	size1=`du -sh -b $subv/data1 | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size1 91
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap
	if [ $? -ne 0 ]
	then
		echo "snapshot $subv to $snap should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data2 bs=5M count=1
	sync
	size2=`du -sh -b $subv/data2 | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size2 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size1+$size2+4096)) $(($size2+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $(($size1+$size2)) $(($size2))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case73()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=5M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case74()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi

}

case75()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((6*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case76()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=6M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case77()
{
	echo "compressed is not supported now"
}

case78()
{
	echo "compressed is not supported now"
}

case79()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	limiting_prepare_single_parent 1/1 10M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi
	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assign $qgroupid to 1/1 should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data1 bs=5M count=1
	sync
	size1=`du -sh -b $subv/data1 | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size1 95
	if [ $? -ne 0 ]
	then
		return 1
	fi
	check_qgroup_accounting $qgroupid $(($size1+4096)) $(($size1+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi
	check_qgroup_accounting 1/1 $size1 $size1
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs sub snapshot $subv $snap 
	if [ $? -ne 0 ]
	then
		echo "snapshot $subv to $snap should be successful"
		return 1
	fi

	dd if=/dev/zero of=$subv/data2 bs=6M count=1
	sync
	size2=`du -sh -b $subv/data2 | awk '{ print $1 }'`
	./check_accuracy $((5*1024*1024-4096)) $size2 95

	check_qgroup_accounting $qgroupid $(($size1+$size2+4096)) $(($size2+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $(($size1+$size2)) $(($size2+$size1))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case80()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`

	dd if=/dev/zero of=$subv/data bs=2K count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case81()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	dd if=/dev/zero of=$subv/data bs=2K count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne  0 ]
	then
		echo "truncating $subv/data should be successful"
		return 1
	fi
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy 0 $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case82()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	fallocate $subv/data -l 2K
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 8192 8192
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case83()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	dd if=/dev/zero of=$subv/data bs=2K count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne  0 ]
	then
		echo "removing $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case84()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	dd if=/dev/zero of=$subv/data bs=2K count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne  0 ]
	then
		echo "truncating $subv/data should be successful"
		return 1
	fi
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy 0 $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case85()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	fallocate $subv/data -l 2K
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((2*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid 8192 8192
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case86()
{
	echo "rescanning is not implemented now"
}

case87()
{
	echo "rescanning is not implemented now"
}

case88()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/urandom of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi


	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case89()
{
	quota_setup "nodatacow"
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare 5M 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	dd if=/dev/zero of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/urandom of=$subv/data bs=3M count=1
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }'`
	./check_accuracy $((3*1024*1024)) $size 100
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi


	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case90()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	btrfs qgroup destroy $qgroupid $mnt
	if [ $? -ne 0 ]
	then
		echo "btrfs qgroup destroy $qgroupid should be successful"
		return 1
	fi

	btrfs qgroup limit 5M $qgroupid $mnt
	if [ $? -eq 0 ]
	then
		echo "limiting $qgroupid should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi

}

case91()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	btrfs qgroup destroy $qgroupid $mnt
	if [ $? -ne 0 ]
	then
		echo "destroying $qgroupid should be successful"
		return 1
	fi
	btrfs qgroup create  $qgroupid $mnt
	if [ $? -ne 0 ]
	then
		echo "creating $qgroupid should be successful"
		return 1
	fi

	btrfs qgroup limit 5M $qgroupid $mnt
	if [ $? -ne 0 ]
	then
		echo "limiting $qgroupid should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case92()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 should be successful"
		return 1
	fi
	btrfs qgroup create 1/0 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/0 should be successful"
		return 1
	fi
	btrfs qgroup assign 0/1 1/0 $mnt
	if [ $? -ne 0 ]
	then
		echo "assigning 0/1 1/0 should be successful"
		return 1
	fi
	btrfs qgroup destroy 0/1 $mnt
	if [ $? -eq 0 ]
	then 
		echo "destroying should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

#first is subvol qgroupid
several_parallel_parent_qgroup()
{
	qgroupid=$1
	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/1 should be successful"
		return 1
	fi
	btrfs qgroup create 1/2 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/2 should be successful"
		return 1
	fi
	btrfs qgroup limit 5M 1/1 $mnt
	if [ $? -ne 0 ]
	then 
		echo "limiting 1/1 should be successful"
		return 1
	fi
	btrfs qgroup limit 10M 1/2 $mnt
	if [ $? -ne 0 ]
	then
		echo "limiting 1/2 should be successful"
		return 1
	fi

	btrfs qgroup assign $qgroupid 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "assing $qgroupid 1/1 should be successful"
		return 1
	fi

	btrfs qgroup assign $qgroupid 1/2 $mnt
	if [ $? -ne 0 ]
	then
		echo "assing $qgroupid 1/2 should be successful"
		return 1
	fi
}

case93()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	several_parallel_parent_qgroup $qgroupid
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=1M count=10
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }' `
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi
	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case94()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	several_parallel_parent_qgroup $qgroupid
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=1M count=10
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }' `
	./check_accuracy $((5*1024*1024-4096)) $size 95
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	rm -f $subv/data
	if [ $? -ne 0 ]
	then
		echo "rm $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 0 0
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case95()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	several_parallel_parent_qgroup $qgroupid
	if [ $? -ne 0 ]
	then
		return 1
	fi

	dd if=/dev/zero of=$subv/data bs=1M count=10
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }' `
	./check_accuracy $((5*1024*1024-4096)) $size 90
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	truncate --size=0 $subv/data
	if [ $? -ne 0 ]
	then
		echo "rm $subv/data should be successful"
		return 1
	fi

	sync
	check_qgroup_accounting $qgroupid 4096 4096
	if [ $? -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting 1/1 0 0
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case96()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	limiting_prepare none 0 0
	if [ $? -ne 0 ]
	then
		return 1
	fi

	qgroupid=0/`btrfs sub list $mnt | awk '{print $2}'`
	several_parallel_parent_qgroup $qgroupid
	if [ $? -ne 0 ]
	then
		return 1
	fi

	fallocate $subv/data -l 5M
	sync
	size=`du -sh -b $subv/data | awk '{ print $1 }' `
#	./check_accuracy $((5*1024*1024-4096)) $size 95
#	if [ $? -ne 0 ]
#	then
#		return 1
#	fi
	if [ $size -ne 0 ]
	then
		return 1
	fi

	check_qgroup_accounting $qgroupid $(($size+4096)) $(($size+4096))
	if [ $? -ne 0 ]
	then
		return 1
	fi
	check_qgroup_accounting 1/1 $size $size
	if [ $? -ne 0 ]
	then 
		return 1
	fi
	check_qgroup_accounting 1/2 $size $size
	if [ $? -ne 0 ]
	then
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case97()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup create 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 0/1 qgroup should be successful"
		return 1
	fi

	btrfs qgroup limit 10M 0/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "limiting 0/1 qgroup should be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

case98()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	btrfs qgroup limit 10M 0/1 $mnt
	if [ $? -eq 0 ]
	then
		echo "limiting a qgroup not existed should not be successful"
		return 1
	fi

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

ncases=100
#creating qgroups
#destroy qgroups
create_destroy_qgroups()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup create $i $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $i should be successful"
			return 1
		fi
		i=$(($i+1))
	done

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup destroy $i $mnt
		if [ $? -ne 0 ]
		then
			echo "destroying qgroup $i should be successful"
			return 1
		fi
		i=$(($i+1))
	done

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

#creating qgroups
#limiting qgroups
#destroy qgroups
create_limit_qgroups()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup create $i $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $i should be successful"
			return 1
		fi
		i=$(($i+1))
	done

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup limit 10M  $i $mnt
		if [ $? -ne 0 ]
		then
			echo "limiting qgroup $i should be successful"
			return 1
		fi
		i=$(($i+1))
	done

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup destroy $i $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $i should be successful"
			return 1
		fi
		i=$(($i+1))
	done

	quota_clean
	if [ $? -ne 0 ]
	then
		return 1
	fi
}

#assign 1000 qgroups to one parent qgroup
assign_to_qgroup()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi

	i1=1
	while [ $i1 -le $ncases ]
	do
		btrfs qgroup create $i1 $mnt
		if [ $? -ne 0 ]
		then
			echo "creating qgroup $i should be successful"
			return 1
		fi
		i1=$(($i1+1))
		sync
	done
	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/1 should be successful"
		return 1
	fi

	i1=1
	while [ $i1 -le $ncases ]
	do
		btrfs qgroup assign $i1 1/1 $mnt
		sync
		if [ $? -ne 0 ]
		then
			echo "assign $i to 1/1 should be successful"
			return 1
		fi
		i1=$(($i1+1))
	done
}

case99()
{
	create_destroy_qgroups
	if [ $? -ne 0 ]
	then
		return 1
	fi
	create_limit_qgroups
	if [ $? -ne 0 ]
	then
		return 1
	fi
	assign_to_qgroup
	if [ $? -ne 0 ]
	then
		return 1
	fi
	quota_clean
	if [ $? -ne 0 ]
	then
		echo "quota_clean should be successful"
		return 1
	fi
}

case100()
{
	quota_setup
	if [ $? -ne 0 ]
	then
		return 1
	fi
	limiting_prepare 10M 0 0
	if [ $? -ne  0 ]
	then
		return 1
	fi
	i2=1
	while [ $i2 -le 50 ]
	do
		btrfs sub snapshot $subv $mnt/$i2
		if [ $? -ne 0 ]
		then
			return 1
		fi
		i2=$(($i2+1))
	done
	quota_clean
	if [ $? -ne 0 ]
	then
		echo "quota_clean should be successful"
		return 1
	fi
}

rm -f result.txt
rm -f log.txt
j=85
while [ $j -le 85 ]
do
	echo "--------------------------" >> log.txt
	printf "Case $j: " >> log.txt
	printf "Case $j:" >> result.txt

	case$j >> log.txt
	if [ $? -ne 0 ]
	then
		printf "Failure\n" >> result.txt
	else
		printf "Success\n" >> result.txt
	fi
	j=$(($j+1))
done

