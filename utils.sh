#!/system/bin/sh
MODDIR=${0%/*}

write_val() {
    find "$2" -type f 2>/dev/null | while read -r file; do
        chmod 0644 "$file" 2>/dev/null
        echo "$1" > "$file" 2>/dev/null
    done
}

lock_val() {
    find "$2" -type f 2>/dev/null | while read -r file; do
        chmod 0644 "$file" 2>/dev/null
        echo "$1" > "$file" 2>/dev/null
        chmod 0444 "$file" 2>/dev/null
    done
}

lock_val_in_path() {
    if [ "$#" = "4" ]; then
        find "$2/" -path "*$3*" -name "$4" -type f 2>/dev/null | while read -r file; do
            lock_val "$1" "$file"
        done
    else
        find "$2/" -name "$3" -type f 2>/dev/null | while read -r file; do
            lock_val "$1" "$file"
        done
    fi
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
    while [ "$(getprop sys.user.0.ce_available)" != "true" ]; do
        sleep 3
    done
}
