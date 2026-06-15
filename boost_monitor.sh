#!/system/bin/sh
# 温控Boost + GPU调频器监听 - inotifyd 事件驱动
# 监听 /data/cur_powermode.txt（Scene/schedhorizon 切换模式时写入）
# cur_powermode.txt 不存在时退出，Boost 走手动（action.sh）

# ==========================================
# 1. inotifyd 事件响应区
# 兼容: w(直接写入), c(修改), y(移动), update(原子替换后的重载)
# ==========================================
if [ "$1" = "w" ] || [ "$1" = "c" ] || [ "$1" = "y" ] || [ "$1" = "update" ]; then
    BOOST="/dev/hfdem_boost"
    MANUAL="/dev/hfdem_manual_boost"
    LOG="${MDIR:-${0%/*}}/boost.log"
    PROP="${MDIR:-${0%/*}}/module.prop"
    LAST_STATE_FILE="/dev/hfdem_last_mode"

    _get_time() { date "+%Y-%m-%d %H:%M:%S"; }
    _wval() { chmod 0644 "$2" 2>/dev/null; echo "$1" > "$2" 2>/dev/null; }
    _lock_val() { chmod 0644 "$2" 2>/dev/null; echo "$1" > "$2" 2>/dev/null; chmod 0444 "$2" 2>/dev/null; }
    _get_ver() { grep "^version=" "$PROP" 2>/dev/null | cut -d= -f2; }
    _status() {
        local ver=$(_get_ver)
        sed -i "s/^description=.*/description=hfdem PowerTune $ver | GPU: $1 | 温控: $2 | $3/" "$PROP" 2>/dev/null
    }

    _set_gpu_governor() {
        local mod_pct="$1"
        for df in /sys/class/devfreq/*kgsl-3d0; do
            [ -d "$df" ] && _lock_val "$mod_pct" "$df/mod_percent"
        done
    }

    _boost_on() {
        [ -f "$BOOST" ] && return
        for i in /sys/class/thermal/t*; do
            grep -Eq "cpu|gpu" "$i/type" 2>/dev/null && _wval "105000" "$i/trip_point_2_temp"
        done
        _wval "10" /sys/class/thermal/thermal_message/sconfig
        # DCVS 拉满
        local BUS_DIR="/sys/devices/system/cpu/bus_dcvs"
        [ -d "$BUS_DIR/DDRQOS" ] && {
            _lock_val "1" "$BUS_DIR/DDRQOS/hw_max_freq"
            _lock_val "1" "$BUS_DIR/DDRQOS/boost_freq"
            _lock_val "1" "$BUS_DIR/DDRQOS/hw_min_freq"
        }
        # UFS 拉满
        for df in /sys/class/devfreq/*ufs*; do
            [ -d "$df" ] && {
                [ -f "$df/max_freq" ] && _wval "2147483646" "$df/max_freq"
                [ -f "$df/min_freq" ] && _wval "2147483646" "$df/min_freq"
            }
        done
        touch "$BOOST"
        local t=$(_get_time)
        echo "[$t] Boost ON" >> "$LOG"
    }

    _boost_off() {
        [ -f "$BOOST" ] || return
        for i in /sys/class/thermal/t*; do
            grep -Eq "cpu|gpu" "$i/type" 2>/dev/null && _wval "100000" "$i/trip_point_2_temp"
        done
        _wval "0" /sys/class/thermal/thermal_message/sconfig
        # DCVS 恢复
        local BUS_DIR="/sys/devices/system/cpu/bus_dcvs"
        [ -d "$BUS_DIR/DDRQOS" ] && _wval "0" "$BUS_DIR/DDRQOS/min_freq"
        # UFS 恢复
        for df in /sys/class/devfreq/*ufs*; do
            [ -d "$df" ] && [ -f "$df/min_freq" ] && _wval "0" "$df/min_freq"
        done
        rm -f "$BOOST"
        local t=$(_get_time)
        echo "[$t] Boost OFF" >> "$LOG"
    }

    _set_mode() {
        local mode="$1"
        local gpu_label=""
        local thermal_label=""

        case "$mode" in
            powersave)
                _set_gpu_governor "100"
                gpu_label="调频100%"
                if [ ! -f "$MANUAL" ]; then
                    [ -f "$BOOST" ] && _boost_off
                    thermal_label="🔴 OFF"
                else
                    [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
                fi
                ;;
            balance)
                _set_gpu_governor "100"
                gpu_label="调频100%"
                if [ ! -f "$MANUAL" ]; then
                    [ -f "$BOOST" ] && _boost_off
                    thermal_label="🔴 OFF"
                else
                    [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
                fi
                ;;
            performance)
                _set_gpu_governor "120"
                gpu_label="调频120%"
                if [ ! -f "$MANUAL" ]; then
                    [ -f "$BOOST" ] && _boost_off
                    thermal_label="🔴 OFF"
                else
                    [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
                fi
                ;;
            fast)
                _set_gpu_governor "120"
                gpu_label="调频120%"
                if [ ! -f "$MANUAL" ]; then
                    [ -f "$BOOST" ] || _boost_on
                    thermal_label="🟢 ON"
                else
                    [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
                fi
                ;;
        esac

        local t=$(_get_time)
        echo "[$t] Mode: $mode | GPU: $gpu_label" >> "$LOG"
        _status "$gpu_label" "$thermal_label" "$t"
    }

    # 执行状态更新逻辑
    CUR=$(cat /data/cur_powermode.txt 2>/dev/null)
    LAST=$(cat "$LAST_STATE_FILE" 2>/dev/null)

    if [ -n "$CUR" ] && [ "$CUR" != "$LAST" ]; then
        rm -f "$MANUAL"
        echo "$CUR" > "$LAST_STATE_FILE"
        _set_mode "$CUR"
    fi
    exit 0
fi

# ==========================================
# 2. 守护进程主入口
# ==========================================
if [ -n "$1" ] && [ -d "$1" ]; then
    export MDIR="$1"
else
    export MDIR="${0%/*}"
fi

LAST_STATE_FILE="/dev/hfdem_last_mode"

# 等待开机完成，给外部调度模块时间创建 cur_powermode.txt
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 3; done
sleep 10

# GPU 动态调频未开启则退出
CONF="${MDIR:-${0%/*}}/gpu_boost.conf"
[ -f "$CONF" ] && . "$CONF"
[ "$GPU_BOOST_ENABLED" != "1" ] && exit 0

# cur_powermode.txt 仍不存在则退出，Boost 走手动（action.sh）
[ -f /data/cur_powermode.txt ] || exit 0

# ==========================================
# 3. 核心监听循环 (inotifyd + 防原子替换)
# ==========================================
while true; do
    # 监听 w(写入), c(修改), D(删除自身/原子替换)
    inotifyd "$0" /data/cur_powermode.txt:wcD

    # inotifyd 退出（大概率是原子替换 mv 操作）
    sleep 0.5

    if [ ! -f /data/cur_powermode.txt ]; then
        # 真的被删了，建空文件等待下次写入
        touch /data/cur_powermode.txt
    else
        # 原子替换，伪造 update 事件立即应用新模式
        "$0" "update" "/data/cur_powermode.txt"
    fi

    # 循环回到开头，inotifyd 重新绑定到新文件 inode
done
