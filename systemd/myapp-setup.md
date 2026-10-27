# W2 产出① · systemd 管理 Python HTTP 服务（2026-10-27）

> 计划锚点：Phase 0R2 · W2（逾期补交）· 硬产出①
> 环境：nina VM（Ubuntu 22.04），用户 nina
> 2026-10-27 陪练代填：文中解释性内容由陪练根据用户本人的操作与屏幕记录代写，所有操作与验证均为用户亲手完成；建议面试前用自己的话复述一遍

## 一、目标

- 我要管理的服务：用 Python 自带的 `http.server` 在 8000 端口提供 `/opt/myapp` 目录下的静态页面
- 要达到的效果：常驻运行、崩溃后自动重启（`Restart=on-failure`）、开机自启（`enable`）

## 二、我的 unit 文件

```ini
[Unit]
Description=test
After=network.target auditd.service

[Service]
User=nina
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/python3 -m http.server 8000 --directory /opt/myapp
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

逐段解释（用自己话）：

- `[Unit]` 段：描述与启动顺序。`Description=test` 是给人看的名字（`systemctl status` 第一行）；`After=network.target` 表示排在网络就绪之后启动，只管顺序、不代表依赖成功；`auditd.service` 是照 `ssh.service` 的例子顺手留的，本机没装 auditd（`systemctl status auditd` 报 Unit could not be found），写不写都不影响。
- `[Service]` 段：怎么跑。`User=nina` 用普通用户运行、不用 root；`WorkingDirectory=/opt/myapp` 指定工作目录；`ExecStart` 必须是绝对路径——systemd 不经过 shell，不读 `PATH`，也不能写管道和重定向；`Restart=on-failure` 表示非零退出/异常被杀才拉起，手动 `systemctl stop` 不会重启。
- `[Install]` 段：什么时候上岗。`WantedBy=multi-user.target` 表示 `enable` 时在 `/etc/systemd/system/multi-user.target.wants/` 建一个指向本文件的软链接，开机进入多用户模式时由 systemd 拉起——这就是开机自启的实现方式。

## 三、操作流程（按我实际敲的顺序）

1. 准备目录和页面：`sudo mkdir -p /opt/myapp`；`echo "hello from myapp" | sudo tee /opt/myapp/index.html`
2. 写 unit 文件：`sudo nano /etc/systemd/system/myapp.service`，按 `[Unit]` / `[Service]` / `[Install]` 三段写完
3. 重载配置并启动：`sudo systemctl daemon-reload`；`sudo systemctl start myapp`
4. 查看状态：`systemctl status myapp --no-pager`，看到 `active (running)`
5. 设置开机自启：`sudo systemctl enable myapp`；`systemctl is-enabled myapp` 显示 `enabled`
6. 重启验证：`sudo reboot`；重启后 status 仍 `active (running)`，`wget -qO- http://localhost:8000` 返回 `hello from myapp`

## 四、踩的坑（现象 → 原因 → 怎么改的）

- 坑 1：段名大小写。初稿写成 `[service]` / `[install]`，systemd 直接不认这一段，报 `Service has no ExecStart setting`。改成 `[Service]` / `[Install]`。
- 坑 2：指令拼写错误被静默忽略。`Restart` 一开始写成 `Restrart`，systemd 只在 journal 里记一句 `Unknown key name` 就忽略，服务看着 `active (running)` 一切正常、实际自动重启根本没开。改成 `Restart=` 并 `daemon-reload` 后才生效。
- 坑 3：`WorkingDirectory=` 空值。最初留空，靠 `ExecStart` 里的 `--directory` 才没出事，属于隐患，已补 `/opt/myapp`。
- 坑 4：环境缺 curl。想用 `curl` 验证时发现 VM 没装，改用 `wget -qO- http://localhost:8000`。
- 坑 5：nano 保存退出。`Ctrl+O` 写入 → 回车确认文件名 → `Ctrl+X` 退出。

## 五、验收结果

- 首次启动后：`Loaded: disabled`；`Active: active (running) since 2026-10-27 19:10:46`；`Main PID 2679`
- `wget -qO- http://localhost:8000` 输出：`hello from myapp`
- `systemctl is-enabled myapp`：`enabled`
- 重启后：`Loaded: enabled`；`Active since 19:22:45`；`Main PID 738`（PID 变化 = 开机重新拉起）
- 崩溃测试（修复 `Restrart` 后）：`Restart=on-failure`；`MainPID 2933` → `pkill -9` → 2 秒内恢复 `active (running)`，新 `Main PID 2940`
- 结论：目标全部达成——常驻运行、崩溃自动重启、开机自启均验证通过。

## 六、一句话总结（面试版）

我把一个 Python `http.server` 服务做成 systemd 托管：unit 文件里用 `[Service]` 指定运行用户、工作目录和 `ExecStart` 绝对路径，`Restart=on-failure` 实现崩溃自动拉起；用 `systemctl enable` 在 `multi-user.target.wants` 下建软链接实现开机自启；每次改完 unit 先 `daemon-reload`，最后通过重启机器和 `kill -9` 崩溃测试两轮验证。
