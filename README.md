# biliLive-tools fnOS x86 自动构建

这是 `renmu123/biliLive-tools` 的非官方 fnOS x86 原生自动构建仓库。

- 不使用 Docker
- 每天检查一次上游 GitHub 正式 Release
- 发现新版本后自动生成 `.fpk`
- 自动发布为 GitHub Pre-release
- 可在 Actions 页面手动指定版本构建
- `PACK_REV` 是 fnOS 封装版本，当前为 `native1`

## 第一次设置

1. 新建公开仓库 `biliLive-tools-fnOS`。
2. 把本模板根目录中的文件上传到仓库根目录。
3. `.github` 若网页上传时被隐藏，请用 **Add file → Create new file**，文件名输入：
   `.github/workflows/build-bililive-fpk.yml`，再粘贴模板中的 workflow 内容。
4. 仓库 **Settings → Actions → General → Workflow permissions** 选择 **Read and write permissions** 并保存。
5. 进入 **Actions → Build biliLive-tools fnOS FPK → Run workflow**，第一次留空版本直接运行。
6. 成功后在 **Releases** 下载 FPK。

## 自动检查时间

Workflow 使用：

```yaml
- cron: "37 0 * * *"
```

GitHub cron 为 UTC，即每天北京时间约 08:37 检查一次。

## 版本规则

例如：

- 上游：`3.19.0`
- fnOS 封装：`native1`
- FPK：`biliLive-tools_3.19.0_native1_fnOS_x86.fpk`
- Release tag：`fnos-3.19.0-native1`

如果以后只修改 fnOS 封装，不改上游版本，把 `PACK_REV` 从 `native1` 改成 `native2`，再手动运行 Actions 即可。

## 重要提示

自动构建只能验证 FPK 结构、上游 Release 标签和对应 `bililive-cli` npm 版本是否存在。上游如果改变 CLI 参数、WebUI API、依赖或配置结构，仍可能需要更新 fnOS 封装，因此自动发布默认使用 Pre-release。
