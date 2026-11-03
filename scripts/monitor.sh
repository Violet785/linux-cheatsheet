#!/bin/bash
export LC_ALL=C

cpulimit=80
LOG_DIR="/var/log/myapp"
memlimit=90
disklimit=85

log(){
    echo "$(date '+%F %T') $*"
}

check_cpu(){
    local usage=$(top -bn2 -d 1 | awk '/%Cpu/ {print int(100 - $8)}' | tail -1)
    if [ "$usage" -gt "$cpulimit" ]; then
	log "[ALERT] CPU ${usage}% > ${cpulimit}%"
    else
     	log "[OK] cpu ${usage}"
    fi
}

check_mem(){
    local usage=$(free | awk 'NR==2 {print int($3/$2*100)}')
    if [ "$usage" -gt "$memlimit" ]; then
 	log "[ALERT] mem ${usage}% > ${memlimit}%"
    else
  	log "[OK] mem ${usage}"
    fi
}

check_disklimit(){
    local usage=$(df -P / | tail -1 | awk '{print $5}'| tr -d '%')
    if [ "$usage" -gt "$disklimit" ]; then
    	log "[ALERT] disk ${usage}% > ${disklimit}%" 
    else 
	log "[OK] disk ${usage}"
    fi
}

check_log(){
    [ -d "$LOG_DIR" ] || { log "[SKIP] ${LOG_DIR} 不存在"; return; }
    local hits=$(find "$LOG_DIR" -name '*.log' -mmin -5 -exec grep -il error {} +)
    if [ -n "$hits" ]; then
    	log "[ALERT] find new wrong: ${hits}"
    else
	log "[OK] not new wrong"
    fi
}

check_cpu
check_mem
check_disklimit
check_log

