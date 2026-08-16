#!/usr/bin/env bash
set -euo pipefail

RAW_TAG="${1:-}"

if [[ -z "$RAW_TAG" ]]; then
  echo "用法: $0 3.20.0" >&2
  exit 2
fi

TAG="${RAW_TAG#v}"
VERSION="$TAG"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_REV="$(tr -d '[:space:]' < "$ROOT/PACK_REV")"

[[ -n "$PACK_REV" ]] || {
  echo "PACK_REV 为空" >&2
  exit 2
}

if [[ ! "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "上游版本必须是 X.Y.Z，当前：$VERSION" >&2
  exit 2
fi

UP_MAJOR="${BASH_REMATCH[1]}"
UP_MINOR="${BASH_REMATCH[2]}"
UP_PATCH="${BASH_REMATCH[3]}"

if [[ ! "$PACK_REV" =~ ^native([0-9]+)$ ]]; then
  echo "PACK_REV 必须是 native数字，例如 native2；当前：$PACK_REV" >&2
  exit 2
fi

PACK_SEQ="${BASH_REMATCH[1]}"

if (( 10#$PACK_SEQ >= 100 )); then
  echo "native 序号必须小于 100" >&2
  exit 2
fi

FNOS_PATCH=$((10#$UP_PATCH * 100 + 10#$PACK_SEQ))
FNOS_VERSION="${UP_MAJOR}.${UP_MINOR}.${FNOS_PATCH}"

echo "======================================"
echo "biliLive-tools 上游 : $VERSION"
echo "fnOS 封装修订       : $PACK_REV"
echo "fnOS manifest版本   : $FNOS_VERSION"
echo "======================================"

WORK="$ROOT/.build"
PKG="$WORK/package"
DIST="$ROOT/dist"

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

cp -a "$ROOT/package-template" "$PKG"

python3 - "$PKG/app/native/bootstrap.py" "$VERSION" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
version = sys.argv[2]

s = p.read_text(encoding="utf-8")

s, n1 = re.subn(
    r'^TARGET_VERSION\s*=\s*"[^"]+"',
    f'TARGET_VERSION = "{version}"',
    s,
    flags=re.M,
)

s, n2 = re.subn(
    r'^CLI_VERSION\s*=\s*"[^"]+"',
    f'CLI_VERSION = "{version}"',
    s,
    flags=re.M,
)

if n1 != 1 or n2 != 1:
    raise SystemExit(
        "无法更新 bootstrap.py 中的 TARGET_VERSION/CLI_VERSION"
    )

p.write_text(s, encoding="utf-8")
PY

python3 \
  - "$PKG/manifest" \
  "$FNOS_VERSION" \
  "$VERSION" \
  "$PACK_REV" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
fnos_version, upstream_version, pack_rev = sys.argv[2:]

lines = p.read_text(
    encoding="utf-8"
).splitlines()

replace = {
    "version": fnos_version,
    "desc": (
        f"biliLive-tools {upstream_version} x86 原生飞牛版。"
        "无需 Docker；native2 修复监控时间段提前录制问题，"
        "并提供文件管理器可见日志。"
    ),
    "changelog": (
        f"自动跟随上游 biliLive-tools {upstream_version}；"
        f"fnOS 原生 x86 封装 {pack_rev}；"
        "修复 startRecord 反向时间判断与 Bilibili 批量查询绕过监控时间段；"
        "日志写入录像目录/biliLive-tools-Logs。"
    ),
    "checksum": "",
}

out = []
seen = set()

for line in lines:
    key = line.split("=", 1)[0] if "=" in line else ""

    if key in replace:
        out.append(f"{key}={replace[key]}")
        seen.add(key)
    else:
        out.append(line)

for key, value in replace.items():
    if key not in seen:
        out.append(f"{key}={value}")

p.write_text(
    "\n".join(out) + "\n",
    encoding="utf-8",
)
PY

tar -czf "$PKG/app.tgz" -C "$PKG/app" .

APP_MD5="$(
  md5sum "$PKG/app.tgz" |
  awk '{print $1}'
)"

python3 - "$PKG/manifest" "$APP_MD5" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
md5 = sys.argv[2]

s = p.read_text(encoding="utf-8")

s, n = re.subn(
    r'^checksum=.*$',
    f'checksum={md5}',
    s,
    flags=re.M,
)

if n != 1:
    raise SystemExit(
        "manifest checksum 字段异常"
    )

p.write_text(s, encoding="utf-8")
PY

rm -rf "$PKG/app"

for f in "$PKG"/cmd/*; do
  bash -n "$f"
done

python3 -m py_compile \
  "$ROOT/package-template/app/native/bootstrap.py"

/opt/hostedtoolcache/node/22.*/x64/bin/node \
  --check \
  "$ROOT/package-template/app/native/web_server.js" \
  2>/dev/null \
  || node --check \
     "$ROOT/package-template/app/native/web_server.js"

python3 - <<PY
import json

for p in [
    r"$PKG/config/privilege",
    r"$PKG/config/resource",
    r"$PKG/wizard/config",
    r"$PKG/wizard/install",
]:
    json.load(
        open(
            p,
            encoding="utf-8",
        )
    )
PY

grep -q '^platform=x86$' "$PKG/manifest"
grep -q "^version=${FNOS_VERSION}$" "$PKG/manifest"
grep -q "^checksum=${APP_MD5}$" "$PKG/manifest"

MANIFEST_VERSION="$(
  awk -F= \
    '$1=="version"{print $2}' \
    "$PKG/manifest"
)"

if [[ ! "$MANIFEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "manifest version 格式错误：$MANIFEST_VERSION" >&2
  exit 1
fi

OUT="$DIST/biliLive-tools_${VERSION}_${PACK_REV}_fnOS_x86.fpk"

tar -czf "$OUT" -C "$PKG" .

VERIFY="$WORK/verify"

mkdir -p "$VERIFY"
tar -xzf "$OUT" -C "$VERIFY"

EXPECTED="$(
  awk -F= \
    '$1=="checksum"{print $2}' \
    "$VERIFY/manifest"
)"

ACTUAL="$(
  md5sum "$VERIFY/app.tgz" |
  awk '{print $1}'
)"

[[ "$EXPECTED" == "$ACTUAL" ]] || {
  echo "checksum 校验失败" >&2
  exit 1
}

VERIFY_VERSION="$(
  awk -F= \
    '$1=="version"{print $2}' \
    "$VERIFY/manifest"
)"

[[ "$VERIFY_VERSION" == "$FNOS_VERSION" ]] || {
  echo "manifest 版本复核失败" >&2
  exit 1
}

gzip -t "$OUT"

sha256sum "$OUT" |
  tee "$DIST/SHA256SUMS.txt"

echo
echo "======================================"
echo "构建成功: $OUT"
echo "上游版本: $VERSION"
echo "封装修订: $PACK_REV"
echo "fnOS安装版本: $FNOS_VERSION"
echo "======================================"
