#!/system/bin/sh
# 温控Boost + GPU调频器监听 - 由service.sh启动
# 监听 /data/cur_powermode.txt (Scene/vtools切换模式时写入)

MDIR="$1"
BOOST="/dev/hfdem_boost"
MANUAL="/dev/hfdem_manual_boost"
LOG="$MDIR/boost.log"
PROP="$MDIR/module.prop"
CONF="$MDIR/gpu_boost.conf"
LAST=""
KGSL="/sys/class/kgsl/kgsl-3d0"

GPU_BOOST_ENABLED=0
[ -f "$CONF" ] && . "$CONF"
[ "$GPU_BOOST_ENABLED" != "1" ] && exit 0

_get_time() { date "+%Y-%m-%d %H:%M:%S"; }
_wval() { chmod 0644 "$2" 2>/dev/null; echo "$1" > "$2" 2>/dev/null; }
_lock_val() { chmod 0644 "$2" 2>/dev/null; echo "$1" > "$2" 2>/dev/null; chmod 0444 "$2" 2>/dev/null; }
_get_ver() { grep "^version=" "$PROP" 2>/dev/null | cut -d= -f2; }
_status() {
    local ver=$(_get_ver)
    sed -i "s/^description=.*/description=hfdem PowerTune $ver | GPU: $1 | 温控: $2 | $3/" "$PROP" 2>/dev/null
}

NUM_PWRLVL="$(cat $KGSL/num_pwrlevels 2>/dev/null)"
MIN_PWRLVL="$((NUM_PWRLVL - 1))"

_set_gpu_unlock() {
    _lock_val "0" "$KGSL/max_pwrlevel"
    _lock_val "$MIN_PWRLVL" "$KGSL/min_pwrlevel"
    _lock_val "$MIN_PWRLVL" "$KGSL/default_pwrlevel"
    _lock_val "0" "$KGSL/thermal_pwrlevel"
    _lock_val "0" "$KGSL/throttling"
    [ -f "$KGSL/force_clk_on" ] && _wval "0" "$KGSL/force_clk_on"
    [ -f "$KGSL/force_no_nap" ] && _wval "0" "$KGSL/force_no_nap"
    [ -f "$KGSL/force_rail_on" ] && _wval "0" "$KGSL/force_rail_on"
    [ -f "$KGSL/bcl" ] && _wval "0" "$KGSL/bcl"
    [ -f "$KGSL/max_gpu_clk" ] && _lock_val "2147483647" "$KGSL/max_gpu_clk"
    [ -f "$KGSL/max_clock_mhz" ] && _lock_val "2147483647" "$KGSL/max_clock_mhz"
    [ -f "$KGSL/min_clock_mhz" ] && _lock_val "0" "$KGSL/min_clock_mhz"
    [ -f /sys/kernel/gpu/gpu_max_clock ] && _lock_val "2147483647" /sys/kernel/gpu/gpu_max_clock
    [ -f /sys/kernel/gpu/gpu_min_clock ] && _lock_val "0" /sys/kernel/gpu/gpu_min_clock
    for df in /sys/class/devfreq/*kgsl-3d0; do
        [ -d "$df" ] && {
            _lock_val "0" "$df/min_freq"
            _lock_val "2147483647" "$df/max_freq"
        }
    done
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

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 3; done
sleep 5

_set_gpu_unlock

CUR=""
while [ -z "$CUR" ]; do
    CUR=$(cat /data/cur_powermode.txt 2>/dev/null)
    [ -z "$CUR" ] && sleep 5
done
LAST="$CUR"
_set_mode "$LAST"

while true; do
    sleep 5
    CUR=$(cat /data/cur_powermode.txt 2>/dev/null)
    [ -z "$CUR" ] && sleep 30 && continue
    if [ "$CUR" != "$LAST" ]; then
        rm -f "$MANUAL"
        LAST="$CUR"
        _set_mode "$LAST"
    fi
done
