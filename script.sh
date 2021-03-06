#!/bin/bash
function hm_fn(){
        tee -a homework.log
}

function start_fn(){
       echo Task $1 is going | hm_fn
}


function finish_fn(){
        echo Task $1 is done | hm_fn
}


function check_folder(){
        while true; do
                echo -n "Enter a folder for " $1 | hm_fn
                read path; echo Read is done with status code $? | hm_fn
                if [ -d /$path ]
                        then
                        echo 'This folder is exists. You must to repeat'
                        continue
                else
                        mkdir /$path; echo Create a dir /$path is done with status code $?| hm_fn
                        break
                fi
        done
}


function network(){
        #Network
        start_fn 1

        sed -i 's/ONBOOT=no/ONBOOT=yes/' /etc/sysconfig/network-scripts/ifcfg-enp0s3
        service network restart

        finish_fn 1
}


function ssh(){
        #SSH
        start_fn 2

        for var in INPUT OUTPUT
        do
                iptables -A $var -p tcp --dport 22 -j ACCEPT; echo Command for added iptables $var is done with status code $?| hm_fn
        done
       sed -i 's/#PermitRootLogin yes/PermitRootlogin no/' /etc/ssh/sshd_config; echo Added a permit root login is done with status code $?| hm_fn
        systemctl restart sshd; echo Restart sshd is done with status code $?| tee -a hm_fn

        finish_fn 2
}


function iso(){
        #ISO
        start_fn 3

        check_folder ISO
        mount /CentOS-7-x86_64-DVD-2009.iso /$path; echo Mount for ISO is done with status code $?| hm_fn
        yum --desablerepo=\* version &> /dev/null; echo Disabled a repo is done with status code $?| hm_fn

        echo '[LocalRepo]' >  /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn
        echo  'name=LocalRepository' >> /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn
        echo  'baseurl=file:///'$path >> /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn
        echo  'enabled=1' >> /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn
        echo  'gpgcheck=0' >> /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn
        echo  'gpgkey=file::///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' >>  /etc/yum.repos.d/local.repo; echo Write data to local.repo is done with status code $?| hm_fn

        finish_fn 3
}


function raid(){
        #RAID
        start_fn 4

        echo 'Start state of disks' && lsblk| hm_fn

        yum install mdadm -y; echo Install mdadm is done with status code $?| hm_fn
        read -p "Enter disk for raid: " first second third; echo Read a disks is done with status code $?| hm_fn

        for var in $first $second $third
        do
                (echo n; echo p; echo 1; echo ; echo ; echo t; echo fd; echo w) | fdisk /dev/$var; echo Create a raid for $var is done with status code $?| hm_fn
        done

        mdadm --create /dev/md5 --level=5 --raid-devices=3  /dev/sd[b-d]1; echo Create a raid for disks is done with status code $?| hm_fn
        mdadm --detail --scan --verbose >>  /etc/mdadm.conf; echo Add config to 'etc/mdadm.conf' is done with status code $?| hm_fn

        echo 'Finish state of discks' && lsblk| hm_fn
        pvcreate /dev/md5 && vgcreate vlgrp1 /dev/md5 && lvcreate -l +100%FREE -n lv  vlgrp1; echo Creating a LVM is done with status code $?| hm_fn

        mkfs -t xfs /dev/vlgrp1/lv; echo Creating a xfs is done with status code $?| hm_fn

        check_folder mounting
        tempUUID=$(blkid /dev/vlgrp1/lv | cut -c 22-57)
        echo 'UUID='$tempUUID'     '$path'   xfs     defaults 0 0' >> /etc/fstab
        mount /dev/vlgrp1/lv /$path; echo Mount volume is done with status code $?| hm_fn

        finish_fn 4
}


function delete_raid(){
        #DELETE_RAID
        start_fn 5

        echo 'Enter a mountpoint'
        read mp

        umount /$mp && echo SUCCESS unmount
        tempUUID=$(blkid /dev/vlgrp1/lv | cut -c 22-57)
        sed -i '/UUID='$tempUUID'/d' /etc/fstab
        lvremove /dev/vlgrp1/lv -y; echo 'lvremove' is done with status code $?| hm_fn
        vgremove /dev/vlgrp1 -y; echo 'vgremove' is done with status code $?| hm_fn
        pvremove /dev/md5 -y; echo 'pvremove' is done with status code $?| hm_fn
        rm /etc/mdadm.conf -f; echo 'rm' is done with status code $?| hm_fn
        mdadm -S /dev/md5; echo 'mdadm ' is done with status code $?| hm_fn

        echo ??Enter a first disk??
        read disk1; echo Read is done with status code $?| hm_fn
        mdadm --zero-superblock /dev/"$disk1"1
        (echo d; echo w;) | fdisk /dev/$disk1

        read disk2; echo Read is done with status code $?| hm_fn
        mdadm --zero-superblock /dev/"$disk2"1
        (echo d; echo w;) | fdisk /dev/$disk2

        read disk3; echo Read is done with status code $?| hm_fn
        mdadm --zero-superblock /dev/"$disk3"1
        (echo d; echo w;) | fdisk /dev/$disk3

        lsblk


        finish_fn 5
}


function nfs(){
        #NFS
        start_fn 6

        install nfs-utils; echo Install a nfs-utils is done with status code $?| hm_fn
        systemctl start rpcbind; echo Start RPCBIND is done with status code $?| hm_fn
        systemctl enable rpcbind; echo Enable RPCBIND is done with status code $?| hm_fn
        systemctl start nfs-server; echo Start NFS_SERVER is done with status code $?| hm_fn
        systemctl enable nfs-server; echo Enable NFS-SERVER is done with status code $?| hm_fn
        systemctl start rpc-statd; echo Start RPC-STATD is done with status code $?| hm_fn
        systemctl start nfs-idmapd; echo NFS-IDMAPD is done with status code $?| hm_fn

        echo -n "Enter a dir for nfs "| hm_fn
        read path_nfs; echo Read is done with status code $?| hm_fn
        mkdir -p /$path_nfs; echo Create a dir /$path_nfs is done with status code $?| hm_fn

        echo -n "Enter a mountpoint for nfs "| hm_fn
        read path_mpnfs; echo Read is done with status code $?| hm_fn
        mkdir -p /$path_mpnfs; echo Create a dir /$path_mpnfs is done with status code $?| hm_fn

        chmod 777 /$path_nfs; echo Chmode is done with status code $?| hm_fn

        echo '/$path_nfs *(rw,sync,no_root_squash)' >> /etc/exports;echo Write a data is done with status code $?| hm_fn
        exportfs -r; echo Exportfs is done with status code $?| hm_fn
        mount -t nfs 192.168.57.5:/$path_nfs /$path_mpnfs; echo Mount nfs is done with status code $?| hm_fn

        finish_fn 6
}


echo 'Enter a point:
        1. Configuration of network
        2. Configuration SHH
        3. Add local DVD ISO
        4. RAID5  3 drives + lvm + xfs + mount
        5. Delete a raid
        6. NFS
        7. exit'

while true;do
        read point
        if [[ $point = 1 ]]
                then
                        network
        elif [[ $point = 2 ]]
                then
                        ssh
        elif [[ $point = 3 ]]
                then
                        iso
        elif [[ $point = 4 ]]
                then
                        raid
        elif [[ $point = 5 ]]
                then
                        delete_raid
        elif [[ $point = 6 ]]
                then
                        nfs
        elif [[ $point = 7 ]]
                then
                break
        else
                echo -e 'Try again.'
        fi
done
