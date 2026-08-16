# biliLive-tools-fnOS native4

## 到监控时间自动恢复当前直播

native4 每 5 秒检测一次 `handleTime`。

例如：
- 主播 01:20 已经直播
- 监控时间 01:36~02:00

01:36 前由 native3 strict gate 阻止录制。

01:36 进入时间窗后：
- 记录 `ENTER`
- 自动调用 `manager.startRecord()`
- 最多尝试 3 次，每次约间隔 10 秒
- 作用类似在时间到达时自动执行一次“开始操作”
- 已经录制不会重复启动
- 用户明确关闭自动监控时不会强制开启

日志关键词：

```text
[fnOS native4 window] ENTER
[fnOS native4 window] AUTO-START
```

## 网页日志

假设 biliLive-tools 地址：

```text
http://192.168.100.125:3000
```

日志页面：

```text
http://192.168.100.125:3000/fnos-logs
```

可切换：
- backend.log
- main.log
- webui.log
- proxy.log

页面每 5 秒自动刷新，不需要 SSH。

## native3 继续保留

- Asia/Shanghai 秒级严格判断
- 时间窗外 FINAL gate
- Bilibili batch 时间过滤
- startRecord 默认不越过时间窗
- 跨午夜
- 格式异常 fail-closed

如果仓库已经使用 native2 的 build_fpk.sh，上游为 3.20.0 时：
- PACK_REV = native4
- fnOS manifest = 3.20.4
