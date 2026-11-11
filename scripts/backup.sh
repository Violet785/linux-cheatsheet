#!/bin/bash
export LC_ALL=C

SRC_DIR=/opt/myapp/data
DST_DIR=/backup
KEEP_DAYS=7

log() {
    echo "$(date '+%F %T') $*"
}


do_backup() {
     [ -d "$SRC_DIR" ] || { log "[ERROR] 源目录不存在：$SRC_DIR"; return 1; }

    local pkg="$DST_DIR/backup_$(date +%F).tar.gz"

    # ② 打包并判断成败
    if tar -czf "$pkg" -C /opt/myapp data; then
        log "[OK] 备份完成：$pkg"
    else
        log "[ERROR] 备份失败：$pkg"
        return 1
    fi
}

cleanup() {
 # ③ 删除超过保留天数的备份
    find "$DST_DIR" -name 'backup_*.tar.gz' -mtime +"$KEEP_DAYS" -delete
    # ④ 收尾日志
    log "[OK] 清理完成"

}

do_backup
cleanup
