```markdown
# Linux 目录地图笔记（2026-09-08 D1）

## 我理解的目录分工
- /etc：系统配置大本营。里面全是纯文本配置文件（passwd 用户户口本、hostname 机器名），cat 就能读，相当于 Windows 注册表+配置文件合体
- /var/log：系统日志流水账。auth.log=登录记录、syslog=系统全局日志；日志会"轮转"备份（.1/.2.gz），不会无限膨胀撑爆磁盘
- /proc：虚拟文件系统！不在硬盘上，是内核在内存里实时生成的"仪表盘"。cat 它=现场问内核要数据（cpuinfo/meminfo/uptime 永远最新）
- /proc/[PID]/：每个运行中进程的"房间"，藏着进程全部秘密（cmdline=启动命令、fd=打开的文件、status=状态）
- /tmp：临时文件目录，程序运行时的临时数据扔这里，重启可能被清
- /home/nina：我的家目录。普通用户的家都住在 /home 下，只有自己和 root 能进

## 今天我学到的命令
1. `cd ~`：回到自己的家目录（~ = 家目录的快捷写法）
2. `cat /etc/passwd | grep nina`：查看 passwd 并过滤出 nina——| 是管道，把左边输出喂给右边处理
3. `find / -size +10M`：全盘找大于 10MB 的文件（磁盘爆满排查第一招）
4. `find /var/log -mtime -1`：找 24 小时内修改过的文件（排查"今天系统动了啥"）
5. `ls -a`：列出含隐藏文件的所有内容（.开头=隐藏文件，.bashrc 是 shell 配置）
6. `tail -5 文件`：看文件最后 5 行
7. `cat /proc/$$/status`：$$=当前 shell 的 PID，查看自己进程的状态

## 今天踩的坑
- `cd~` 报错：命令和参数之间必须有空格！cd ~ 才对
- `cat/etc/passwd` 报错：同样的问题——cat 和路径之间要空格
- 在聊天框发 /etc 开头的内容会被当成斜杠命令拦截

## 关键概念
- 绝对路径 vs 相对路径：/etc/passwd 从根目录 / 开始写，任何位置都能找到；只写文件名=只在当前目录找
- 管道 |：左边命令的输出 → 右边命令的输入（Linux 组合拳核心）
- 重定向：2>/dev/null = 把"标准错误(fd 2)"扔进黑洞 /dev/null，报错闭嘴
- fd 三兄弟：0=标准输入 1=标准输出 2=标准错误
- PID 1 = systemd：开机第一个进程，进程世界的根
- 用户体系：root UID=0 超级用户；系统服务账户 UID 1-999（shell 是 nologin 禁登录）；普通用户 UID≥1000（nina=1000）
- 权限：普通用户看不到 /etc/ssl/private（敏感目录保护），报 Permission denied 时用 sudo 借 root 身份

## 自测答案
- nina 的 UID 是：1000
- 我的内核版本是：6.8.0-117-generic
- fd 里的 0/1/2 是：标准输入 / 标准输出 / 标准错误
```
