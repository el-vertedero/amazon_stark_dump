#!/system/bin/sh
#
# Copyright (c) 2023 Amazon.com, Inc. or its affiliates.  All rights reserved.
#
# PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.

# This is a workaround for Hynix eMMC which has a problem that lifetime will
# be reset to 0x01 after warmboot. After some bytes of data written, it will
# recover to normal value.

wait_write_for_hynix() {
     data_part='179[[:space:]]\{7\}0[[:space:]]mmcblk0'
     diskstats_dat=(`cat /proc/diskstats |grep $data_part`)
     written_s=${diskstats_dat[9]}
     #check for 85m written per /proc/diskstats
     size_written=85
     size_check=$(($size_written*2048))
     if [[ $written_s -lt $size_check ]]; then
         exit 0
     else
         exit 1
     fi
}

manfid=$1
manfid_hynix=0x000090
if [ "$1" == "$manfid_hynix" ] ; then
    wait_write_for_hynix
else
    exit 1
fi
