#!/system/bin/sh
# 温控Boost + GPU频率自动监听 - 由service.sh启动
# 监听 /data/cur_powermode.txt (Scene/vtools切换模式时写入)

MDIR="$1"
BOOST="/dev/hfdem_boost"
MANUAL="/dev/hfdem_manual_boost"
LOG="$MDIR/boost.log"
PROP="$MDIR/module.prop"
LAST=""
KGSL="/sys/class/kgsl/kgsl-3d0"

_get_time() { date "+%Y-%m-%d %H:%M:%S"; }
_wval() { chmod 0644 "$2" 2>/dev/null; echo "$1" > "$2" 2>/dev/null; }
_status() {
    sed -i "s/^description=.*/description=hfdem PowerTune v2.2.0 | GPU: $1 | 温控: $2 | $3/" "$PROP" 2>/dev/null
}

NUM_PWRLVL="$(cat $KGSL/num_pwrlevels 2>/dev/null)"
MIN_PWRLVL="$((NUM_PWRLVL - 1))"

_set_gpu() {
    local max_pwr="$1"
    local max_freq="$2"
    _wval "$max_pwr" "$KGSL/max_pwrlevel"
    for df in /sys/class/devfreq/*kgsl-3d0; do
        [ -d "$df" ] && _wval "$max_freq" "$df/max_freq"
    done
}

_boost_on() {
    [ -f "$BOOST" ] && return
    for i in /sys/class/thermal/t*; do
        grep -Eq "cpu|gpu" "$i/type" 2>/dev/null && _wval "105000" "$i/trip_point_2_temp"
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
    rm -f "$BOOST"
    local t=$(_get_time)
    echo "[$t] Boost OFF" >> "$LOG"
}

_set_mode() {
    local mode="$1"
    local gpu_label=""
    local thermal_label=""

    case "$mode" in
        powersave|balance)
            _set_gpu "$MIN_PWRLVL" "221000000"
            gpu_label="省电(221MHz)"
            if [ ! -f "$MANUAL" ]; then
                [ -f "$BOOST" ] && _boost_off
                thermal_label="🔴 OFF"
            else
                [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
            fi
            ;;
        performance)
            _set_gpu "3" "370000000"
            gpu_label="均衡(370MHz)"
            if [ ! -f "$MANUAL" ]; then
                [ -f "$BOOST" ] || _boost_on
                thermal_label="🟢 ON"
            else
                [ -f "$BOOST" ] && thermal_label="🟢 ON(手动)" || thermal_label="🔴 OFF(手动)"
            fi
            ;;
        fast)
            _set_gpu "0" "690000000"
            gpu_label="性能(690MHz)"
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

sleep 15
_set_mode "balance"

while true; do
    sleep 10
    CUR=$(cat /data/cur_powermode.txt 2>/dev/null)
    [ -z "$CUR" ] && sleep 30 && continue
    if [ "$CUR" != "$LAST" ]; then
        rm -f "$MANUAL"
        LAST="$CUR"
        _set_mode "$LAST"
    fi
done
