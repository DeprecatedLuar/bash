#!/bin/bash

metrics=("$@")
[[ ${#metrics[@]} -eq 0 ]] && metrics=(cpu ram gpu fan bat)

for metric in "${metrics[@]}"; do
    case "$metric" in
        cpu)
            usage=$(top -bn2 -d1 | awk '
                /^%Cpu/ {cpu=$2}
                /^CPU:/ {gsub(/%/,"",$2); cpu=$2}
                END {if(cpu) printf "%.0f", cpu}
            ')
            temp=$(sensors 2>/dev/null | grep -E '^(Package id 0|Core 0|temp1):' | head -1 | sed 's/.*+\([0-9.]*\).*/\1/')
            if [[ -n "$usage" ]]; then
                if [[ -n "$temp" ]]; then
                    printf "CPU %s%% (%.0f°C)\n" "$usage" "$temp"
                else
                    printf "CPU %s%%\n" "$usage"
                fi
            fi
            ;;
        ram)
            if [[ ${#metrics[@]} -eq 1 ]]; then
                free -h | awk '/^Mem:/ {
                    total=$2; used=$3; free=$4; available=$7
                    printf "RAM %.0f%% (%s / %s)\n", ($3/$2*100), used, total
                    printf "Used: %s | Free: %s | Available: %s\n", used, free, available
                }' RS='\n' FS='[[:space:]]+'
                echo ""
                ps aux --sort=-%mem | awk 'NR>1 && $4>4 {
                    cmd=$11; gsub(/^.*\//, "", cmd)
                    printf "%.0f%% %s (%s)\n", $4, cmd, $2
                }'
            else
                free | awk '/^Mem:/ {printf "RAM %.0f%%\n", $3/$2*100}'
            fi
            ;;
        gpu)
            if command -v nvidia-smi &>/dev/null; then
                usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
                temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
                [[ -n "$usage" && -n "$temp" ]] && printf "GPU %s%% (%.0f°C)\n" "$usage" "$temp"
            fi
            ;;
        fan)
            sensors | awk '/^fan[0-9]+:/ && /RPM/ {
                match($0, /[[:space:]]+([0-9]+) RPM/, a); sum+=a[1]; count++
            } END {if(count>0) printf "FAN %.0frpm\n", sum/count}'
            ;;
        bat)
            for psu in /sys/class/power_supply/*; do
                [[ "$(cat "$psu/type" 2>/dev/null)" == "Battery" ]] || continue
                capacity=$(cat "$psu/capacity" 2>/dev/null)
                status=$(cat "$psu/status" 2>/dev/null)
                [[ -n "$capacity" ]] && printf "BAT %s%% (%s)\n" "$capacity" "$status"
            done
            ;;
    esac
done
