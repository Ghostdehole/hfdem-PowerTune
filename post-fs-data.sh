#!/system/bin/sh
MODDIR=${0%/*}
MODPATH=/data/adb/modules/hfdem_savemode

# 等待启动
while [ ! -f /proc/version ]; do sleep 1; done
