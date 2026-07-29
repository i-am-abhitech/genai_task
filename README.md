# genai_task - VM Health Check

A small bash utility that checks basic virtual machine health (CPU load, memory, root disk usage, swap, uptime).

## Files
- `vm_health_check.sh` — the health-check script.

## Installation
1. Clone the repo:
   git clone git@github.com:i-am-abhitech/genai_task.git
   cd genai_task

2. Make the script executable:
   chmod +x vm_health_check.sh

## Usage
- Quick / concise status:
  ./vm_health_check.sh

- Detailed explanation:
  ./vm_health_check.sh explain

Exit codes:
- `0` = OK (all checks OK)
- `1` = WARN (one or more checks in WARN)
- `2` = CRITICAL (one or more checks in CRITICAL)

## Thresholds
You can edit thresholds at the top of `vm_health_check.sh`:
- CPU: `CPU_WARN_PER_CORE`, `CPU_CRIT_PER_CORE` (load-per-core)
- Memory: `MEM_WARN_PERCENT`, `MEM_CRIT_PERCENT`
- Disk: `DISK_WARN_PERCENT`, `DISK_CRIT_PERCENT`
- Swap: `SWAP_WARN_PERCENT`, `SWAP_CRIT_PERCENT`

## Running regularly
Add to cron or a systemd timer to run periodically and act on exit codes.

Example cron (every 5 minutes):
```
*/5 * * * * /path/to/genai_task/vm_health_check.sh || logger -p local0.warning "VM health check failed"
```

## Notes
- Uses common utilities: `awk`, `df`, `free`, `nproc`, `uptime`. It has fallbacks for common environments.
- For production monitoring, consider integrating with your monitoring system (Prometheus exporter, pushgateway, or cloud monitoring APIs).

## License
MIT
