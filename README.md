# biliLive-tools fnOS x86 自动构建

这是 `renmu123/biliLive-tools` 的非官方 fnOS x86 原生自动构建仓库。

- 每天检查一次上游 GitHub 正式 Release，发现新版本后构建 FPK。
- FPK 的 manifest 版本直接使用上游版本，例如 `3.22.1`。
- FPK 文件名为 `biliLive-tools_3.22.1_fnOS_x86.fpk`，Release tag 为 `fnos-3.22.1`。
- 自动构建的 FPK 仍以 GitHub Pre-release 发布，因为构建检查不能代替实际安装测试。

同一个上游版本只发布一次。封装代码有改动时，需要等待下一上游版本或另行决定新的版本策略，不能静默替换同版本的 FPK。

## 旧版迁移

旧 FPK 曾把上游补丁号和 `native` 修订号合成 manifest 版本。例如上游 `3.22.1` 的旧包版本是 `3.22.108`。改为直接使用 `3.22.1` 后，旧包在版本比较中会显得更高；FnDepot 无法把当前 `3.22.1` 自动识别为这些旧包的升级。已有安装需要单独迁移；不要依赖索引降版本来覆盖旧包。

## 自动检查时间

每天北京时间约 08:37 检查一次。

## 重要提示

自动构建验证 FPK 结构、上游 Release 标签及对应 `bililive-cli` npm 版本。上游若改变 CLI 参数、WebUI API、依赖或配置结构，仍需检查 fnOS 封装。
