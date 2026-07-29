#!/usr/bin/env bash
# vm_health_check.sh
# Checks basic VM health: CPU load, memory, disk and swap.
# Usage: vm_health_check.sh [explain]
#
# Exit codes:
#   0 = OK (all checks OK)
#   1 = WARN (one or more WARN)
#   2 = CRITICAL (one or more CRITICAL)

set -o pipefail
EXPLAIN=false
if [[ ${1:-} == "explain" ]]; then
  EXPLAIN=true
fi

# Thresholds (tweak as needed)
CPU_WARN_PER_CORE=0.7
CPU_CRIT_PER_CORE=1.0
MEM_WARN_PERCENT=75
MEM_CRIT_PERCENT=90
DISK_WARN_PERCENT=80
DISK_CRIT_PERCENT=90
SWAP_WARN_PERCENT=50
SWAP_CRIT_PERCENT=90

status_ok=true
messages=()

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

check_cpu() {
  if [[ -r /proc/loadavg ]]; then
    load1=$(awk '{print $1}' /proc/loadavg)
  else
    load1=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1)
  fi
  ncpu=$(nproc 2>/dev/null || echo 1)

  load_per_core=$(awk -v l="$load1" -v n="$ncpu" 'BEGIN{printf "%.2f", l / n}')

  cpu_state="OK"
  if awk -v v="$load_per_core" -v t="$CPU_CRIT_PER_CORE" 'BEGIN{exit !(v>t)}'; then
    cpu_state="CRITICAL"; status_ok=false
  elif awk -v v="$load_per_core" -v t="$CPU_WARN_PER_CORE" 'BEGIN{exit !(v>t)}'; then
    cpu_state="WARN"
  fi

  messages+=("CPU: $cpu_state (load1=$load1, cores=$ncpu, load_per_core=$load_per_core)")
}

check_memory() {
  if command -v free >/dev/null 2>&1; then
    read -r _ total used free shared buff_cache available < <(free -m | awk 'NR==2{print $1,$2,$3,$4,$5,$7}')
    if [[ -z "$available" || "$available" == "0" ]]; then
      available=$free
    fi
    used_bytes=$(( total - available ))
    used_percent=$(awk -v u="$used_bytes" -v t="$total" 'BEGIN{printf "%d", (u/t)*100}')
  else
    total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    used_kb=$(( total_kb - avail_kb ))
    used_percent=$(awk -v u="$used_kb" -v t="$total_kb" 'BEGIN{printf "%d", (u/t)*100}')
    total=$(( total_kb/1024 ))
    available=$(( avail_kb/1024 ))
  fi

  mem_state="OK"
  if (( used_percent >= MEM_CRIT_PERCENT )); then
    mem_state="CRITICAL"; status_ok=false
  elif (( used_percent >= MEM_WARN_PERCENT )); then
    mem_state="WARN"
  fi

  messages+=("Memory: $mem_state (used=${used_percent}%, total=${total}MB, available=${available}MB)")
}

check_disk() {
  dfline=$(df -P / | awk 'NR==2')
  if [[ -z "$dfline" ]]; then
    messages+=("Disk: UNKNOWN (df failed)")
    return
  fi
  used_percent=$(echo "$dfline" | awk '{print $5}' | tr -d '%')
  size=$(echo "$dfline" | awk '{print $2}')
  avail=$(echo "$dfline" | awk '{print $4}')

  disk_state="OK"
  if (( used_percent >= DISK_CRIT_PERCENT )); then
    disk_state="CRITICAL"; status_ok=false
  elif (( used_percent >= DISK_WARN_PERCENT )); then
    disk_state="WARN"
  fi

  messages+=("Disk(/): $disk_state (used=${used_percent}% )")
}

check_swap() {
  if command -v free >/dev/null 2>&1; then
    swap_total=$(free -m | awk 'NR==3{print $2}')
    swap_used=$(free -m | awk 'NR==3{print $3}')
    if [[ -z "$swap_total" || "$swap_total" -eq 0 ]]; then
      messages+=("Swap: OK (no swap configured)")
      return
    fi
    swap_used_pct=$(( swap_used * 100 / swap_total ))
  else
    swap_used_pct=0
  fi

  swap_state="OK"
  if (( swap_used_pct >= SWAP_CRIT_PERCENT )); then
    swap_state="CRITICAL"; status_ok=false
  elif (( swap_used_pct >= SWAP_WARN_PERCENT )); then
    swap_state="WARN"
  fi

  messages+=("Swap: $swap_state (used=${swap_used_pct}%)")
}

check_uptime() {
  uptime_str=$(uptime -p 2>/dev/null || uptime)
  messages+=("Uptime: ${uptime_str}")
}

run_checks() {
  check_cpu
  check_memory
  check_disk
  check_swap
  check_uptime
}

print_summary() {
  if [[ "$EXPLAIN" == true ]]; then
    echo "VM Health Check - detailed report ($(timestamp))"
    echo
    for m in "${messages[@]}"; do
      echo "- $m"
    done
  else
    if [[ "$status_ok" == true ]]; then
      echo "HEALTHY: All checks OK"
    else
      echo -n "UNHEALTHY:"
      first=true
      for m in "${messages[@]}"; do
        if [[ "$m" == *"CRITICAL"* ]] || [[ "$m" == *"WARN"* ]]; then
          if [[ "$first" == true ]]; then
            echo -n " ${m}"; first=false
          else
            echo -n "; ${m}"
          fi
        fi
      done
      echo
    fi
  fi
}

run_checks
print_summary

for m in "${messages[@]}"; do
  if [[ "$m" == *"CRITICAL"* ]]; then
    exit 2
  fi
done

for m in "${messages[@]}"; do
  if [[ "$m" == *"WARN"* ]]; then
    exit 1
  fi
done

exit 0
