# W2 Day 2 · top 与内存监控（2026-10-19）

> 计划锚点：Phase 0R2 · 第 2 周（进程管理与系统监控）· Day 2/7
> 环境：nina VM（1 核 / 2 GB），10:41 快照
> 用法：空行处用自己的话填，填完喊陪练检查
> 2026-10-19 陪练批注订正：保留原答痕迹（错误用删除线、旁边订正；空白处补标准答案）

## 今日练习清单

- `top` 交互：`1` 每核 / `P` 按 CPU / `M` 按内存 / `q` 退出
- `top -b -n 2`：批处理两帧（第一帧不可信）
- `yes > /dev/null &`：造 CPU 大户，观察 %CPU ~100
- `free -h`、`/proc/meminfo`、`vmstat 1 5`

## 实测数据

### top 快照（10:41，远程抓的）

- nproc = **1**
- load average = **0.00 / 0.09 / 0.09**
- Tasks = 204 total, 1 running, 203 sleeping, 0 zombie
- %Cpu(s) = us 13.3 / sy 13.3 / id 73.3 / wa 0.0（第一帧，开机以来平均）
- RES 榜：gnome-shell ≈355 MB；VSCode 的 4 个 MainThread 118 / 111 / 104 / 87 MB
- 彩蛋：PID 2355 VIRT 17.6g vs RES 118 MB，差约 150 倍

### 内存快照

```
total 1.9Gi / used 1.1Gi / free 158Mi / buff-cache 658Mi / available 650Mi
swap 2.6Gi used 39Mi
MemFree 162220 kB / MemAvailable 666192 kB
vmstat 1 5 第二行起：r≈0 b=0 si=0 so=0 id 91~97 wa 0~1
```

### yes drill

- yes 的 %CPU = __99%__（实测三帧 93.8 / 97.0 / 96.0——1 核 VM 上 top 自己也抢核；无观测开销时可到 99.9）；顶栏 id 掉到 __0.0__（当时 us 24.5 / sy 75.5——sy 高是因为 yes 每行都要调 write()）；一分钟 load = __短跑几秒几乎不动（0.03）；持续跑满 1 分钟约 0.6，约 3 分钟才接近 1.0（指数衰减平均）__
- 没跑就补跑：`yes > /dev/null & PID=$!; top -b -n 2 | tail -25; kill $PID`

## 关键概念（用自己话）

- load average 是什么：_系统平均有多少进程处于可运行或不可运行状态_______（订正/补充：更准确 = 过去 1 / 5 / 15 分钟的指数衰减平均，统计 **R 可运行 + D 不可中断睡眠** 两类进程；普通 S 睡眠不算——「不可运行」容易把 S 也误伤，实际指的就是 D）
- 判断 load 忙不忙和什么比：__核数______（补充：load ≈ 核数即满载，持续超过核数×2 值得查）；load 高但 CPU 闲说明：___说明有大量进程卡在 D 状态_____ ✅（典型 = 磁盘/NFS 慢、iowait 高）
- %Cpu(s) 里的 wa 是什么：___CPU 空闲、同时有进程在等磁盘 I/O 的时间占比_____；wa 持续高说明：__~~SRE 高频~~ → 订正：磁盘/存储子系统是瓶颈（该查 iostat / iotop 的 %util 和 await）__
- top 的 %CPU 与 ps aux 的 %CPU 区别：____top 的 %CPU 是相邻两次采样之间的增量 ÷ 采样间隔，反映当前瞬时占用；
 ps aux 的 %CPU 是进程生命周期内累计 CPU 时间 ÷ 存活时间，反映历史平均。____ ✅（补充：所以刚起的忙进程 ps 看着偏低、停忙的老进程 ps 还偏高，别被历史平均骗了）
- 为什么 `top -b -n 1` 第一帧不能信：___因为 top 的占用率靠两次快照做差得来，第一帧没有「上一次」，只能退化用「累计 CPU 时间 ÷ 系统运行时间」估算——这本质是平均值，不是瞬时值（跟 ps aux 同源）。从第二帧起才有真实的两点采样。_____（补充：严格说，系统顶栏 %Cpu(s) 第一帧 = 开机以来平均；进程行的第一帧 = 进程存活期平均，如刚才 yes 的 93.8 = 2.22s ÷ 2.37s。二者思想同源：没有区间就拿累计值凑平均）
- free 的 free 和 available 差在哪：____free：完全没被使用过的空闲内存。Linux 会把不用的内存拿去当页缓存（buff/cache），所以这个数天生很小。

available：估算出来的、能给新程序用的内存 = free + 大部分可回收的 buff/cache（不含已被 swap 占走的部分，也不含不可回收的 slab/tmpfs）。____（补充：可回收部分还包括可回收的 slab（SReclaimable）；available 是内核估算值，不是精确值）
- 看到 free 很低，先看什么再决定慌不慌：__先看 available（MemAvailable）够不够；再看 buff/cache 是不是大头（可回收），以及 swap used + si/so 是否持续非零、有无 OOM 记录。free 低但 available 充足 = 正常，Linux 拿空闲内存做缓存而已，不慌__

## 自测记录

| 题目 | 我的答案 | 判定 |
|---|---|---|
| Q1 load 三窗口 | 只答了核数 1 | 补：1 分钟最敏感 / 15 分钟最平滑；0.09 ≈ 1 核的 9% 在排队 |
| Q2 Tasks | 204 / 1 / 203 / 0 | ✅ |
| Q3 wa | 数据抄对，未解读 | 补：wa=0 无进程等磁盘 |
| Q4 倍数 | 未算 | 补：17.6g ÷ 118MB ≈ 152 倍 |
| Q5 top vs ps %CPU | 采样区间 vs 生命期平均；第一帧退化 | ✅ 优秀 |
| 块 2 Q3 | si/so | 半对：第一眼先看 available，si/so 是「已换页」的证据 |

## 今日独立产出

今天独立完成了 top / free / vmstat 三件套实操：用第二帧读实时 CPU、用 available 判断内存水位、用 si/so 判断真实内存压力，并产出这份带批注订正的 Day2 记录
