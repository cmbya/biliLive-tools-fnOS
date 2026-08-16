# biliLive-tools-fnOS native6

native6 是稳定版定时监听修复。

## 这次为什么不再改深层 bundle 结构

native5 已经能正确找到当前实际运行的：

```text
bililive-cli/lib/index-xxxxxxxx.cjs
```

但 native3 的 FINAL gate 还依赖编译后必须存在：

```text
recorder.cache
recorders.push(recorder)
```

当前 3.20.0 的 CJS bundle 不保留这个可匹配结构，所以应用在启动前失败。

native6 删除了这两个高风险注入点：

- recorder.cache / recorders.push FINAL gate
- return manager 内部时间窗 scheduler

它们都不再是启动条件。

## native6 核心修复

仍然保留已经能在真实 bundle 中定位的稳定补丁：

1. 自动定位 `index-*.cjs / .js / .mjs`
2. 独立使用 Asia/Shanghai 判断 handleTime
3. 修正 startRecord 的反向时间判断
4. `ignoreDataLimit` 默认改为 false，防止自动入口默认越过时间窗
5. 普通自动轮询按 handleTime 过滤
6. Bilibili batch 按 handleTime 二次过滤
7. 如果能识别 `recordRetryImmediately` 的直接重试路径，则额外加时间保护；识别不到只记日志，不阻止应用启动
8. 修改后的真实 bundle 会执行 `node --check`，语法错误则拒绝启动

## 到时间自动恢复“跳过本场”

不再往 11MB CJS bundle 深处塞 scheduler。

native6 启动一个独立的：

```text
fnos_time_monitor.js
```

它每 5 秒读取录制任务。

当任务从：

```text
时间窗外 -> 时间窗内
```

时，会主动触发一次开始录制；未进入录制状态时最多尝试 3 次，每次间隔约 10 秒。

这样可以处理：

```text
主播已经开播
-> 之前处于“自动（跳过本场）”
-> 到设定监听时间
-> 自动重新尝试开始当前场
```

如果你手动关闭了该任务的自动监控，则不会强制开启。

## 日志

仍然全部使用飞牛文件管理器，不需要 SSH。

录像共享目录：

```text
biliLive-tools-Logs/
├── backend.log
├── main.log
├── webui.log
└── time-monitor.log
```

重点：

### backend.log

启动成功应该看到：

```text
[fnOS native6 time] target bundle: index-xxxx.cjs ...
[fnOS native6 time] strict Beijing clock = OK
[fnOS native6 time] startRecord guard = OK
[fnOS native6 time] node --check = OK
```

### time-monitor.log

进入监听时间应该看到：

```text
[fnOS native6 window] ENTER ...
[fnOS native6 window] AUTO-START attempt=1/3 ...
[fnOS native6 window] AUTO-START response ...
```

## 版本

如果上游是 3.20.0：

```text
PACK_REV = native6
fnOS manifest = 3.20.6
FPK = biliLive-tools_3.20.0_native6_fnOS_x86.fpk
```

## 本地验证

生成包前已经检查：

- bash -n
- 所有内嵌 Python 语法
- sidecar Node.js `node --check`
- 模拟 `index-RwUbYTSt.cjs` 的 native2 已打补丁 bundle
- runtime patch 连续运行两次（幂等）
- mock Recorder API：时间窗进入后成功发送一次 AUTO-START
