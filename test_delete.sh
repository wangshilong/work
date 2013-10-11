#!/bin/sh

MNT="/mnt"
DEV="/dev/sda9"
TRACE_PATH="/sys/kernel/debug/tracing"
TRACE_FILTER=$TRACE_PATH/set_ftrace_filter
RESULT=/home/wangsl/btrfs_vs_ext4.txt

touch $RESULT
_fail()
{
	echo $1
	exit 1;
}

test_prepare()
{
	df -Th | grep $DEV && umount $DEV
	if [ $1 = "btrfs" ];then
		mkfs.btrfs -f $DEV || _fail "mkfs btrfs fails"
	fi
	if [ $1 = "ext4" ];then
		mkfs.ext4 $DEV || _fail "mkfs ext4 fails"
	fi

	mount $DEV $MNT
	#disable other cpu
	echo 0 > /sys/devices/system/cpu/cpu1/online
	echo 0 > /sys/devices/system/cpu/cpu2/online
	echo 0 > /sys/devices/system/cpu/cpu3/online
}

add_btrfs_delete_filter()
{
	echo __unlink_start_trans >> $TRACE_FILTER
	echo btrfs_orphan_add >> $TRACE_FILTER
	echo btrfs_unlink_inode >> $TRACE_FILTER
	echo btrfs_end_transaction >> $TRACE_FILTER
	echo btrfs_block_rsv_add >> $TRACE_FILTER
	echo btrfs_commit_transaction >> $TRACE_FILTER
}

add_ext4_delete_filter()
{
	echo ext4_find_entry >> $TRACE_FILTER
	echo __ext4_journal_start_sb >> $TRACE_FILTER
	echo ext4_orphan_add >> $TRACE_FILTER
	echo ext4_delete_entry >> $TRACE_FILTER
	echo ext4_mark_inode_dirty >> $TRACE_FILTER
}

function enable_ftrace()
{
#	echo function >> $TRACE_PATH/current_tracer
	echo 1 > /sys/kernel/debug/tracing/tracing_on
	echo 1 > /sys/kernel/debug/tracing/function_profile_enabled
}

disable_ftrace()
{
	echo 0 > $TRACE_PATH/function_profile_enabled
	echo 0 > $TRACE_PATH/tracing_on
}

#btrfs
date >> $RESULT
test_prepare "btrfs"
add_btrfs_delete_filter
mkdir -p $MNT/btrfs
~/creat_unlink -i 100000 1 $MNT/btrfs
sync
#we only trace file removal
enable_ftrace
~/creat_unlink -r 100000 1 $MNT/btrfs >> $RESULT
#some options here
#disable_ftrace

#ext4
test_prepare "ext4"
add_ext4_delete_filter
mkdir -p $MNT/ext4
~/creat_unlink -i 100000 1 $MNT/ext4
sync
#we only trace file removal
enable_ftrace
~/creat_unlink -r 100000 1 $MNT/ext4 >> $RESULT
cat $TRACE_PATH/trace_stat/function0 >> $RESULT
#some options here
disable_ftrace
