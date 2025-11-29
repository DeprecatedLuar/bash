#!/bin/bash

metrics=("$@")
[[ ${#metrics[@]} -eq 0 ]] && metrics=(cpu ram gpu fan)

for metric in "${metrics[@]}"; do
    case "$metric" in
        cpu)
            usage=$(top -bn2 -d1 | awk '/^%Cpu/ {cpu=$2} END {printf "%.0f", cpu}')
            temp=$(sensors | awk '/^(Package id 0|Core 0):/ && /\+[0-9.]+°C/ {
                match($0, /\+([0-9.]+)/, a); print a[1]; exit
            }')
            [[ -n "$usage" && -n "$temp" ]] && printf "CPU %s%% (%.0f°C)\n" "$usage" "$temp"
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
    esac
done
