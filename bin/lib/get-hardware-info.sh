#!/usr/bin/env bash

components=("$@")
[[ ${#components[@]} -eq 0 ]] && components=(cpu ram gpu disk)

for component in "${components[@]}"; do
    case "$component" in
        cpu)
            model=$(lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2}')
            cores=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^[ \t]+/, "", $2); print $2}')
            threads=$(lscpu | awk -F: '/^CPU\(s\):/ {gsub(/^[ \t]+/, "", $2); print $2}')
            freq=$(lscpu | awk -F: '/CPU max MHz/ {gsub(/^[ \t]+/, "", $2); printf "%.1f", $2/1000}')
            [[ -z "$freq" ]] && freq=$(lscpu | awk -F: '/CPU MHz/ {gsub(/^[ \t]+/, "", $2); printf "%.1f", $2/1000}')
            [[ -n "$model" ]] && printf "CPU: %s (%s cores / %s threads @ %sGHz)\n" "$model" "$cores" "$threads" "$freq"
            ;;
        ram)
            total=$(free -h | awk '/^Mem:/ {print $2}')
            # Try to get RAM type/speed (works without sudo on some systems)
            speed=$(cat /sys/devices/system/memory/*/speed 2>/dev/null | head -1)
            if [[ -n "$speed" ]]; then
                printf "RAM: %s @ %sMHz\n" "$total" "$speed"
            else
                printf "RAM: %s\n" "$total"
            fi
            ;;
        gpu)
            # All GPUs via lspci (most reliable)
            while read -r gpu; do
                [[ -n "$gpu" ]] && printf "GPU: %s\n" "$(echo "$gpu" | sed 's/.*: //')"
            done < <(lspci | grep -i 'vga\|3d\|display')
            ;;
        disk)
            lsblk -d -o NAME,SIZE,MODEL --noheadings 2>/dev/null | while read -r name size model; do
                [[ "$name" == loop* || "$name" == zram* ]] && continue
                [[ -z "$model" ]] && model="(unknown)"
                printf "DISK: /dev/%s %s %s\n" "$name" "$size" "$model"
            done
            ;;
    esac
done
