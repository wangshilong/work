#!/bin/bash

ncases=1

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
	sync

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
	sync

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

	sync
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
	sync

	btrfs qgroup create 1/1 $mnt
	if [ $? -ne 0 ]
	then
		echo "creating 1/1 should be successful"
		return 1
	fi

	i=1
	while [ $i -le $ncases ]
	do
		btrfs qgroup assign $i 1/1 $mnt
		if [ $? -ne 0 ]
		then
			echo "assign $i to 1/1 should be successful"
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
