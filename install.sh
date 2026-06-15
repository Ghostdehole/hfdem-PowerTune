SKIPUNZIP=0

ui_print " "
ui_print "|=================================="
ui_print "| hfdem PowerTune $(unzip -p "$ZIPFILE" module.prop 2>/dev/null | grep "^version=" | cut -d'=' -f2)"
ui_print "| 作者：温柔浩"
ui_print "|=================================="
ui_print " "

if [ -d "/data/adb/modules/yuni_kernel" ]; then
    ui_print "============================================"
    ui_print "  检测到 Yuni Kernel 附加模块"
    ui_print "  功能重复，安装已取消"
    ui_print "============================================"
    abort "  请卸载 Yuni Kernel 附加模块后重试"
fi

OLD_MOD="/data/adb/modules/hfdem_savemode"
if [ -d "$OLD_MOD" ]; then
    ui_print "- 清除旧模块残留..."
    rm -f "$OLD_MOD/service.sh"
    rm -f "$OLD_MOD/utils.sh"
    rm -f "$OLD_MOD/system.prop"
    rm -f "$OLD_MOD/miui.prop"
    rm -f "$OLD_MOD/action.sh"
    rm -f "$OLD_MOD/uninstall.sh"
    rm -f "$OLD_MOD/post-fs-data.sh"
    rm -f "$OLD_MOD/customize.sh"
    rm -f "$OLD_MOD/module.prop"
    rm -f "$OLD_MOD/boost_monitor.sh"
    rm -rf "$OLD_MOD/META-INF"
    rm -f "$OLD_MOD/boost.log"
    ui_print "- 旧模块已清理"
else
    ui_print "- 首次安装，跳过清理"
fi

unzip -o "$ZIPFILE" -d "$MODPATH" >&2

getVolumeKey() {
  sleep 1
  while true; do
    keyInfo=$(getevent -qlc 1 | grep KEY_VOLUME)
    [ -n "$keyInfo" ] && { echo "$keyInfo" | grep -q KEY_VOLUMEUP && return 0 || return 1; }
  done
}

ui_print " "
ui_print "- 是否开启 GPU 动态调频？"
ui_print "  音量+ 开启 / 音量- 关闭"

if getVolumeKey; then
    echo "GPU_BOOST_ENABLED=1" > "$MODPATH/gpu_boost.conf"
    ui_print "  [OK] GPU 动态调频已开启"
else
    echo "GPU_BOOST_ENABLED=0" > "$MODPATH/gpu_boost.conf"
    ui_print "  [--] GPU 动态调频已关闭"
fi

# 检测是否为小米设备
if [ -d "/mi_ext" ] || [ -d "/dev/mi_display" ]; then
    ui_print "- 小米设备检测到，合并miui.prop"
    cat $MODPATH/miui.prop >> $MODPATH/system.prop
fi

# 设置权限
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/utils.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/boost_monitor.sh 0 0 0755

ui_print " "
ui_print "- 安装完成，重启生效"
ui_print " "
