# W2 产出② · OOM Killer 笔记（2026-11-01）

> 计划锚点：Phase 0R2 · W2（逾期补交）· 硬产出②
> 要求：用自己的话写，禁止复制粘贴；写完提交 GitHub 才算交
> 用法：每个问题下写 2-5 句，不确定的查 `man` 或问我

## 1. OOM Killer 是什么？内核在什么情况下才会动用它？
杀进程，清理缓存和swap都用不了后用的

（提示：它是最后手段，不是第一反应）

> **陪练批注**：✅ 方向对，点赞。补严谨一点：
> ① 触发点是**内存分配失败**——进程向内核要一页内存，内核给不出来；
> ② 顺序是 **回收 page cache → swap 匿名页 → 还救不回来 → OOM Killer**，它是"牺牲一个、保住整个系统"的最后手段；
> ③ 如果是 cgroup 限了 `MemoryMax`，笼子里撞线也会触发（实验 A 那种，叫 memcg OOM）。

## 2. 在动手杀进程之前，内核已经尝试过哪两步？
清理缓存和swap

（提示：缓存、swap）

> **陪练批注**：✅ 对。顺序再钉一下：先回收 **page cache**（干净页直接丢，脏页回写后丢），再把**匿名页 swap 出去**；如果 swap 被禁（实验 A 的 `MemorySwapMax=0`），第二步直接跳过 → 直奔 OOM。

## 3. 它怎么挑受害者？
看~~清理的~~**被杀的**优先级，-1000表示~~永不清除~~**免死（内核不会选它）**，+1000表示~~优先清除~~**OOM 时第一个被杀**
（提示：`oom_score`、`/proc/<pid>/oom_score`、`oom_score_adj` 的 -1000 / 1000 各是什么意思）

> **陪练批注**：⚠️ 这里概念串线了——不是"**清理**"的优先级，是"**被杀**"的优先级。内核给每个进程算一个 **oom_badness 分数**：RSS + swap + 页表占用越多分越高，再叠加 `oom_score_adj` 的人工调整（范围 -1000 ~ +1000）。
> - `/proc/<pid>/oom_score`：当前分数（实验 B 里的 666）
> - `oom_score_adj = -1000`：免死金牌，连候选名单都不进（分数显示 0）
> - `oom_score_adj = +1000`：优先送死（666 → 1333）
> OOM 时挑**分数最高**的那个开刀。

## 4. 线上怎么确认发生过 OOM？
查日志，过滤oom和journalctl -k

（提示：`dmesg -T | grep -i oom`、`journalctl -k`，日志里要认哪几个关键词）

> **陪练批注**：✅ 大方向对，但 `journalctl -k` 是**命令**不是过滤词 😄 两条路：
> - `dmesg -T | grep -i oom`：内核环形缓冲区，重启就丢；
> - `journalctl -k`：systemd 日志，能按时间过滤（`--since today`）。
> 要认的关键词：`Killed process`、`Out of memory`、`oom-kill:constraint=`；memcg 版还有 `Memory cgroup out of memory` 和 `oom_memcg=`。实验 C 你捞到的那行就是证据。

## 5. 发生后你的处理步骤？

（治标至少两条，治本至少两条）

> **【陪练代填】**（2026-11-01，应本人要求补全；面试前必须能用自己话复述）
>
> **治标（先救火）**
> 1. 服务已经被杀：靠 systemd 的 `Restart=` 自动拉起，或手动 `systemctl restart <服务>`；
> 2. 临时加 swap / 扩内存 / 把流量切到其他节点，先顶住；
> 3. 手动杀掉明显吃内存又不要紧的进程（`ps aux --sort=-rss | head`）。
>
> **治本（防复发）**
> 1. 给服务设内存上限：cgroup 的 `MemoryMax=`，或 K8s 的 `resources.limits.memory`，超了只死自己（实验 A）；
> 2. 修内存泄漏：复现问题、盯 RSS 曲线、必要时抓 heap dump；
> 3. 加监控告警：内存使用率、RSS 持续上涨、OOM 事件（W3 监控脚本正好要用）；
> 4. 核心进程用 `OOMScoreAdjust=-1000` 保护，批处理任务设 `+1000` 先挨刀（实验 B）。
>
> **批注**：Q1–Q4 是你自己写的，这题我代填了——但明天抽查：口述治标/治本各两条，讲不出来就自己重写 😄

## 6. 我在 VM 上的观察/实验（可选）

（如果做了实验，记录命令和 dmesg 输出；没做就写"未做"）

### 实验 A：cgroup 限 200MB，看内核杀谁（2026-11-01 19:44，实测）

命令：

```bash
# 造压脚本 /tmp/eat_memory.py：每 0.5 秒吃 10MB，最多 40 块（400MB）；内存上限 200MB，必然被杀
# 循环体两行（缩进 4 空格）：chunks.append(bytearray(10*1024*1024)) 然后 time.sleep(0.5)

# 用 systemd-run 临时开一个 scope（cgroup），限内存 200M、禁 swap，跑造压脚本
# --scope=放进临时 cgroup；--collect=结束后自动清理；--unit=给 cgroup 起名 oom-demo；& = 放后台
sudo systemd-run --scope --collect -p MemoryMax=200M -p MemorySwapMax=0 --unit oom-demo python3 /tmp/eat_memory.py &

# 观察 cgroup 当前内存用量（字节），应一路涨到 200MB 附近（本次没截到输出，进程约 10 秒就被杀了）
sudo watch -n 1 'cat /sys/fs/cgroup/system.slice/oom-demo.scope/memory.current'

# 查内核日志：-T=可读时间戳；grep -i oom=忽略大小写找 oom 行；tail -5=最后五条
sudo dmesg -T | grep -iE "oom|killed process" | tail -5
```

关键输出（dmesg）：

```text
oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,
oom_memcg=/system.slice/oom-demo.scope,task_memcg=/system.slice/oom-demo.scope,
task=python3,pid=3585,uid=0
Memory cgroup out of memory: Killed process 3585 (python3)
total-vm:226748kB, anon-rss:204288kB, file-rss:5632kB, shmem-rss:0kB,
UID:0 pgtables:480kB oom_score_adj:0
```

结论：`constraint=CONSTRAINT_MEMCG` = cgroup 超限触发；`oom_memcg=/system.slice/oom-demo.scope` = 超限的就是那个笼子；`anon-rss:204288kB ≈ 199.5MB` 正好顶到 200MB 上限；只死了笼子里的 python3，系统其他进程安然无恙。

### 实验 B：oom_score_adj 三档（陪练整理，数据为本人实测）

| 操作 | oom_score | 含义 |
|---|---|---|
| 默认 | 666 | 基线分，按内存占用算出 |
| `oom_score_adj=+1000` | 1333 | 权重拉满，最优先被杀 |
| `oom_score_adj=-1000` | 0 | 免死金牌，不进候选名单 |

命令：

```bash
sleep 300 &                                        # 起一个几乎不吃内存的靶子进程，放后台
PID=$!                                             # $! = 上一个后台进程的 PID
cat /proc/$PID/oom_score                           # 默认分：666
echo 1000 | sudo tee /proc/$PID/oom_score_adj      # 调到最高 +1000（tee 把 stdin 写进文件）
cat /proc/$PID/oom_score                           # 变成 1333
echo -1000 | sudo tee /proc/$PID/oom_score_adj     # 调到最低 -1000 = 免死
cat /proc/$PID/oom_score                           # 变成 0
kill $PID                                          # 清理（此时 sleep 已自然到点退出，报"没有那个进程"属正常）
```

### 实验 C：journalctl 复核

```bash
# -k=只看内核日志；--since today=今天；grep -iE=忽略大小写；tail -10=最后十条
sudo journalctl -k --since today | grep -iE "oom |killed process" | tail -10
```

输出：

```text
11月 01 19:44:22 nina-VirtualBox kernel: Memory cgroup out of memory: Killed process 3585 (python3) total-vm:226748kB, anon-rss:204288kB, file-rss:5632kB, shmem-rss:0kB, UID:0 pgtables:480kB oom_score_adj:0
```

### 踩的坑

1. Python 缩进：for 循环体完全顶格 → `IndentationError`；行首多一个空格 → `unexpected indent`。缩进就是语法。
2. `sudo tee/proc/...` 少空格 → bash 把 `tee/proc/4017/...` 当成一整个命令名 → `找不到命令`。
3. `cat /proc/$PID/om_score` 拼写漏了 `o`。
4. `kill $PID` 报"没有那个进程"：sleep 300 五分钟已自然结束，不是权限或 PID 问题。
5. grep 写成了 `"oom |killed process"`（oom 后多了空格），所以 `oom-kill:` 行没匹配上；要一起匹配应写 `grep -iE "oom|killed process"`。

## 今日产出

- 这份笔记 + 本次 commit
