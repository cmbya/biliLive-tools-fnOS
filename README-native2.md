# biliLive-tools-fnOS native2

## 修复内容

### 监控时间段外提前录制

native2 同时修两条路径：

1. `startRecord()` 的时间限制判断方向；
2. Bilibili 批量查询 `handleBatchQuery()` 缺少 `handleTime` 二次过滤。

运行前会自动修补安装后的：

```text
@bililive-tools/manager/lib/manager.js
```

补丁幂等；每次启动都会验证两个 guard。

### 可见日志

不用 SSH。

默认录像目录下会创建：

```text
biliLive-tools-Logs/
├── backend.log
├── main.log
└── webui.log
```

超过约 10 MiB 自动保留 `.1`。

重点搜索：

```text
[fnOS native2 time]
```

时间范围外的 Bilibili 批量检查被拦截：

```text
[fnOS native2 time] SKIP Bilibili batch ...
```

startRecord 因未到监听时间被拦截：

```text
[fnOS native2 time] BLOCK startRecord outside monitor window ...
```

### fnOS 安装版本

使用纯数字版本。

```text
上游：3.20.0
封装：native2
fnOS manifest：3.20.2
FPK：biliLive-tools_3.20.0_native2_fnOS_x86.fpk
```

### 自动构建

- 每日检查上游；
- Release 已存在则不重复编译；
- 新上游版本先在 Actions 里安装真实 npm CLI，
  检查两个补丁点仍兼容，再生成 FPK；
- 最新版本检测不使用未认证 GitHub REST API。
