#!/bin/bash                                  # shebang
log() {                                      # 定义 log 函数
    echo "$(date '+%F %T') $*"               # 时间戳 + 所有参数
}
greet() {                                    # 定义 greet 函数
    local who="$1"                            # $1 存进局部变量 who
    echo "hello, $who"                        # 输出
}
greet nina                                   # 调用 greet
log "func test ok"                           # 调用 log
