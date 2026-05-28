SKIPUNZIP=0

ui_print " "
ui_print "|=================================="
ui_print "| hfdem PowerTune v2.2.0"
ui_print "| 作者：温柔浩"
ui_print "|=================================="
ui_print " "

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

# 检测是否为小米设备
if [ -d "/mi_ext" ] || [ -d "/dev/mi_display" ]; then
    ui_print "- 小米设备检测到，合并miui.prop"
    cat $MODPATH/miui.prop >> $MODPATH/system.prop
fi

# 设置权限
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/utils.sh 0 0 0755
set_perm $MODPATH/post-fs-data.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/boost_monitor.sh 0 0 0755

ui_print " "
ui_print "- 安装完成，重启生效"
ui_print " "
