# W2 Day 1 · 进程基础（2026-10-18）

> 计划锚点：Phase 0R2 · 第 2 周（进程管理与系统监控）· Day 1/7
> 环境：nina VM（Ubuntu 22.04.5）
> 记录方式：本人填空 + 陪练批注订正（保留原答痕迹）

## 今日练习清单

- `ps aux` / `ps -ef`：全系统进程快照
- `ps aux --sort=-%cpu` / `--sort=-%mem`：按 CPU / 内存排序
- `sleep 1000 &` + `jobs -l`：造后台进程，认作业号与 PID
- `ps -o pid,ppid,stat,cmd -p <PID>`：定点观察
- `/proc/<PID>/`：status / cmdline / fd / cwd / exe
- `pgrep -a` / `pstree -p`：按名字抓进程、看进程树
- 内存 Top3：`ps -eo pid,stat,rss,%mem,cmd --sort=-rss`

## 实测记录（VM 真实输出）

### 1. 后台 sleep 是一个独立进程

```
$ sleep 1000 &
[1] 3413
$ jobs -l
[1]+  3413 运行中               sleep 1000 &
$ ps -o pid,ppid,stat,cmd -p 3413
    PID    PPID STAT CMD
   3413    2388 S    sleep 1000
```

- `[1]` 是 **作业号**，`3413` 是 **子进程**（补充：准确说是子进程的 PID）
- `STAT = S` 说明 **处于睡眠状态**（补充：准确说"可中断睡眠"——等闹钟/定时器，不占 CPU）
- `PPID = 2388` 是 **父进程**（补充：是我所在 shell（bash）的 PID——后台进程的爹仍是当前 shell，fork 出来的亲儿子）

### 2. fd 0/1/2 默认都指向终端

```
$ ls -l /proc/3413/fd/
0 -> /dev/pts/0
1 -> /dev/pts/0
2 -> /dev/pts/0
```

- 0 = 标准输入，1 = 标准输出，2 = 错误输出 ✅（三个全对）
- `2>&1` 的意思：~~吧标准输入和错误输出都放进文件~~ **→ 订正：把标准错误（fd 2）复制到标准输出（fd 1）当前指向的地方。所以 `> file 2>&1` 会把正常输出和报错一起写进文件**

### 3. 孤儿进程实测：PPID 过继给 1

```
$ bash -c 'sleep 600 &'   # 造完就让爹退出
$ ps -o pid,ppid,stat,cmd -p 3494
    PID    PPID STAT CMD
   3494       1 S    sleep 600
```

- 爹退出后 PPID 变成 1，是因为 **父进程死后子进程变为孤儿进程**（补充：孤儿被 systemd（PID 1）收养，保证永远有人 `wait()` 收尸）

### 4. 内存 Top3 与 RSS / VSZ

| 进程 | PID | %MEM | VSZ | RSS |
|---|---|---|---|---|
| gnome-shell | 1370 | 17.8 | ≈ 3.9 GB | ≈ 352 MB |
| node extensionHost（VSCode） | 2595 | 8.9 | ≈ 17.7 GB | ≈ 177 MB |
| node agentHost（VSCode） | 2269 | 7.0 | ≈ 17.7 GB | ≈ 139 MB |

- RSS 的含义：**真实内存**（补充：Resident Set Size——真正驻留物理内存的部分）
- VSZ 和 RSS 差在哪：**虚拟内存**（补充：VSZ 是虚拟地址空间"额度"（申请/映射总量，含没摸过的页）；RSS 是实际躺在物理内存里的量）
- 排障时看哪个、为什么：~~虚拟~~ **→ 订正：看 RSS（或 %MEM）——真实账单；VSZ 17.7 GB vs RSS 177 MB 就是例子，看 VSZ 会被吓死还会误判**

## 关键概念速记（用自己话）

- 僵尸 Z 怎么来的：~~父进程死了，子进程没被回收~~ **→ 订正：子进程先退出，父进程还活着却没调用 `wait()` 收尸**——只剩 PCB 占着 PID，杀不掉，等爹收尸或杀爹（注意方向：死的是子进程，赖账的是父进程）
- 信号：`kill` 默认发 **15** 号（叫 **SIGTERM**）；`kill -9` 是 **9** 号（SIGKILL）；Ctrl+C 发 **2** 号（SIGINT），只发给 **前台进程组**
- STAT：R = 在运行，S = 睡眠状态，D = 不可中断睡眠，T = 可暂停（补充：即"停止"，Ctrl+Z / SIGSTOP），Z = 僵尸进程（其余全对 ✅）
- TTY 列 `?` 表示 **没挂在终端上**（补充：即"无控制终端"，Ctrl+C 打不到）

## 今日彩蛋：神秘 sleep 180

`pgrep -a sleep` 看到不是我开的 `sleep 180`。

- 顺 PPID 链查到的路线：**sleep 180 → sh（PID 2551）→ sshd: nina@notty**；sh 的孩子里还有 `code command-shell`
- 它其实是：**VSCode Remote-SSH 的连接保活循环**——每 180 秒睡醒换一个新的 sleep 进程，所以每次 `pgrep` 看到的 PID 都不一样
- 教训：**陌生进程先查 PPID 链，再下结论**

## 自测记录

| 题目 | 我的答案 | 判定 |
|---|---|---|
| PPID 去哪看 | ps -ef 里有 | ✅ |
| sleep 的 STAT | 不知道 → S | 讲解补全 |
| sleep 的 PPID | 不知道 → 2388 = shell | 讲解补全 |
| fd 0/1/2 | 输入、输出 | 0/1 对，2 = 错误输出 |
| 僵尸怎么认 | Z | ✅ |
| 抽考：kill 默认信号 | — | SIGTERM 15；-9 = SIGKILL |
| 抽考：TTY ? | — | 无控制终端 |
| 抽考：杀 shell 后 PPID | — | 过继给 1（实测） |

## 今日独立产出

- **独立完成进程观察实操：造后台进程、`ps` 定点观察、fd 查看、内存 Top3 排序；观察题 1、5 独立答对；填写本记录**