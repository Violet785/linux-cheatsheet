#!/bin/bash
NOW=$(date '+%F %T')
THRESH=80
DISK_USED=$(df -P / | tail -1 |awk ' {print $5}' |tr -d '%')
echo "$NOW cipanshiyonglv: ${DISK_USED}%"
if [ "$DISK_USED" -ge "$THRESH" ]; then
    echo "ALERT: disk ${DISK_USED}% >= ${THRESH}%"
else
    echo "OK: disk ${DISK_USED}% < ${THRESH}%"
fi

