#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/recovery:10661888:1272188ee0c73b64ae456ec9cdca32054ce3ff01; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/boot:9623552:6b1519f0a16fbe1fdecdcbf7f35c51d017c27348 EMMC:/dev/block/recovery 0a2a46906d90726302c5645ec1fe05929ec7d1ea 10659840 6b1519f0a16fbe1fdecdcbf7f35c51d017c27348:/system/recovery-from-boot.p && installed=1 && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
  [ -n "$installed" ] && dd if=/system/recovery-sig of=/dev/block/recovery bs=1 seek=10659840 && sync && log -t recovery "Install new recovery signature: succeeded" || log -t recovery "Installing new recovery signature: failed"
else
  log -t recovery "Recovery image already installed"
fi
