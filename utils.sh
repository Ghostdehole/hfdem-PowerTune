#!/system/bin/sh
MODDIR=${0%/*}

write_val() {
    find "$2" -type f 2>/dev/null | while read -r file; do
        chmod 0644 "$file" 2>/dev/null
        echo "$1" > "$file" 2>/dev/null
    done
}

wait_until_boot_complete() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 3
    done
    sleep 5
}

wait_until_login() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 3
    done
    local i=0
    while [ ! -d /data/data/android ] && [ $i -lt 30 ]; do
        sleep 3
        i=$((i + 1))
    done
}
