#!/system/bin/sh

ret=0

cat /proc/mounts | grep "/dev/block/tee"
ret=$?
if [ $ret -ne 0 ]; then
	make_ext4fs -a /tee /dev/block/tee
	setprop tee.need_remount 1
fi

