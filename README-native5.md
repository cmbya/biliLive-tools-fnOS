# biliLive-tools-fnOS native5

native5 修复 native4 无法启动的问题。

## 根因

当前 3.20.0 实际把录制管理代码打包进：

```text
bililive-cli/lib/index-xxxxxxxx.cjs
```

native4 错误地只寻找：

```text
@bililive-tools/manager/lib/manager.js
```

因此应用在启动补丁阶段直接失败。

## native5 修复

启动时自动扫描：

```text
node_modules/bililive-cli/lib/**/*.cjs
node_modules/bililive-cli/lib/**/*.js
node_modules/bililive-cli/lib/**/*.mjs
node_modules/@bililive-tools/manager/lib/*
```

通过 native2 已存在标记和录制函数特征自动定位真正的 bundle。

成功后日志会出现：

```text
[fnOS native5 time] target bundle: index-xxxx.cjs ...
[fnOS native5 time] target path: ...
```

然后继续应用：

- native3 严格时间闸门
- 时间窗外 FINAL gate
- Bilibili batch 时间过滤
- native4 时间窗 ENTER -> AUTO-START
- 最多 3 次窗口启动尝试
- `/fnos-logs` 网页日志

如果上游仍为 3.20.0，使用现有 build_fpk.sh：

```text
PACK_REV = native5
fnOS manifest = 3.20.5
FPK = biliLive-tools_3.20.0_native5_fnOS_x86.fpk
```
