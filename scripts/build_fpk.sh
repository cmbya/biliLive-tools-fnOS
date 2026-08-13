#!/usr/bin/env bash
set -euo pipefail

RAW_TAG="${1:-}"
if [[ -z "$RAW_TAG" ]]; then
  echo "用法: $0 3.19.0" >&2
  exit 2
fi
# biliLive-tools 当前正式标签使用 3.19.0 这种形式；也兼容手动输入 v3.19.0。
TAG="${RAW_TAG#v}"
VERSION="$TAG"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_REV="$(tr -d '[:space:]' < "$ROOT/PACK_REV")"
[[ -n "$PACK_REV" ]] || { echo "PACK_REV 为空" >&2; exit 2; }

WORK="$ROOT/.build"
PKG="$WORK/package"
DIST="$ROOT/dist"
rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"
cp -a "$ROOT/package-template" "$PKG"

# 1) 写入目标上游版本。当前原生方案直接安装与上游版本对齐的 bililive-cli npm 包。
python3 - "$PKG/app/native/bootstrap.py" "$VERSION" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); version=sys.argv[2]
s=p.read_text(encoding='utf-8')
s,n1=re.subn(r'^TARGET_VERSION\s*=\s*"[^"]+"', f'TARGET_VERSION = "{version}"', s, flags=re.M)
s,n2=re.subn(r'^CLI_VERSION\s*=\s*"[^"]+"', f'CLI_VERSION = "{version}"', s, flags=re.M)
if n1 != 1 or n2 != 1:
    raise SystemExit('无法更新 bootstrap.py 中的 TARGET_VERSION/CLI_VERSION')
p.write_text(s, encoding='utf-8')
PY

# 2) 更新 fnOS manifest。
python3 - "$PKG/manifest" "$VERSION" "$PACK_REV" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); version, pack_rev=sys.argv[2:]
lines=p.read_text(encoding='utf-8').splitlines()
replace={
    'version': f'{version}-{pack_rev}',
    'desc': f'biliLive-tools {version} x86 原生飞牛版。无需 Docker，使用 fnOS Node.js 运行 Web 后端并提供 WebUI；支持持久化配置、默认录像共享目录和授权目录访问。',
    'changelog': f'自动跟随上游 biliLive-tools {version} 构建；fnOS 原生 x86 封装 {pack_rev}。保留用户配置、录像目录、Linux npm 兼容和同源 WebUI/API 代理。',
    'checksum': '',
}
out=[]; seen=set()
for line in lines:
    key=line.split('=',1)[0] if '=' in line else ''
    if key in replace:
        out.append(f'{key}={replace[key]}'); seen.add(key)
    else:
        out.append(line)
for k,v in replace.items():
    if k not in seen: out.append(f'{k}={v}')
p.write_text('\n'.join(out)+'\n', encoding='utf-8')
PY

# 3) app/ -> app.tgz，并写入 MD5 checksum。
tar -czf "$PKG/app.tgz" -C "$PKG/app" .
APP_MD5="$(md5sum "$PKG/app.tgz" | awk '{print $1}')"
python3 - "$PKG/manifest" "$APP_MD5" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); md5=sys.argv[2]
s=p.read_text(encoding='utf-8')
s,n=re.subn(r'^checksum=.*$', f'checksum={md5}', s, flags=re.M)
if n != 1: raise SystemExit('manifest checksum 字段异常')
p.write_text(s, encoding='utf-8')
PY
rm -rf "$PKG/app"

# 4) 静态自检。
for f in "$PKG"/cmd/*; do bash -n "$f"; done
python3 -m py_compile "$ROOT/package-template/app/native/bootstrap.py"
/opt/hostedtoolcache/node/22.*/x64/bin/node --check "$ROOT/package-template/app/native/web_server.js" 2>/dev/null || node --check "$ROOT/package-template/app/native/web_server.js"
python3 - <<PY
import json
for p in [r"$PKG/config/privilege", r"$PKG/config/resource", r"$PKG/wizard/config", r"$PKG/wizard/install"]:
    json.load(open(p, encoding='utf-8'))
PY
grep -q '^platform=x86$' "$PKG/manifest"
grep -q "^version=${VERSION}-${PACK_REV}$" "$PKG/manifest"
grep -q "^checksum=${APP_MD5}$" "$PKG/manifest"

# 5) 生成 FPK。
OUT="$DIST/biliLive-tools_${VERSION}_${PACK_REV}_fnOS_x86.fpk"
tar -czf "$OUT" -C "$PKG" .

# 6) 解包复核。
VERIFY="$WORK/verify"
mkdir -p "$VERIFY"
tar -xzf "$OUT" -C "$VERIFY"
EXPECTED="$(awk -F= '$1=="checksum"{print $2}' "$VERIFY/manifest")"
ACTUAL="$(md5sum "$VERIFY/app.tgz" | awk '{print $1}')"
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo "checksum 校验失败" >&2; exit 1; }
gzip -t "$OUT"
sha256sum "$OUT" | tee "$DIST/SHA256SUMS.txt"

echo
printf '构建成功: %s\n' "$OUT"
