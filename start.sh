#!/usr/bin/env bash
#
# opencode-web — 启动 OpenCode 无头服务 + 网页界面
#
#   ./start.sh              在管道目录启动
#   ./start.sh ~/myproj     指定工作目录
#   OCW_WEB_PORT=8899 ./start.sh
#
# 做三件事：
#   1. opencode serve 拉起无头服务（--cors 放行网页来源）
#   2. 读取服务密码，生成 web/config.js
#   3. 起一个静态服务托管网页，并打开浏览器
#
# Ctrl+C 会一并关闭以上进程。

set -uo pipefail

OC_PORT="${OCW_OPENCODE_PORT:-4096}"
WEB_PORT="${OCW_WEB_PORT:-7788}"
HOST="127.0.0.1"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WEB="$ROOT/web"
DIR="${1:-$PWD}"
URL="http://$HOST:$WEB_PORT"

die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
info() { printf '\033[2m  %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }

# 端口探活（bash 内建 /dev/tcp，不依赖 curl / nc）
port_open() { (exec 3<>"/dev/tcp/$HOST/$1") 2>/dev/null; }

# ---------- 前置检查 ----------
command -v opencode >/dev/null 2>&1 || die "找不到 opencode。请先安装 OpenCode V2：
  curl -fsSL https://opencode.ai/v2/install | bash"

if command -v python3 >/dev/null 2>&1; then
  STATIC_SERVER=(python3 -m http.server "$WEB_PORT" --bind "$HOST")
elif command -v python >/dev/null 2>&1; then
  STATIC_SERVER=(python -m http.server "$WEB_PORT" --bind "$HOST")
else
  die "需要一个静态文件服务器来托管网页，请安装 python3：
    Termux  →  pkg install python
    Debian  →  sudo apt install python3
    macOS   →  brew install python3"
fi

[ -d "$WEB" ] || die "找不到网页目录：$WEB"
[ -d "$DIR" ] || die "目录不存在：$DIR"

open_browser() {
  if command -v open >/dev/null 2>&1; then open "$1"                        # macOS
  elif command -v termux-open-url >/dev/null 2>&1; then termux-open-url "$1" >/dev/null 2>&1   # Termux (Android)
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1                 # Linux
  elif command -v wslview >/dev/null 2>&1; then wslview "$1" >/dev/null 2>&1                   # WSL
  else info "请手动打开：$1"; fi
}

# ---------- 1. 无头服务 ----------
info "启动 OpenCode 无头服务（$HOST:$OC_PORT）…"
LOG="${TMPDIR:-/tmp}/ocw-serve.$$.log"
: > "$LOG"
cd "$DIR" || die "无法进入 $DIR"
opencode serve --port "$OC_PORT" --hostname "$HOST" --cors "$URL" > "$LOG" 2>&1 &
OC_PID=$!

cleanup() {
  kill "$OC_PID" "${WEB_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ---------- 2. 读取密码 ----------
PW=""
for _ in $(seq 1 80); do
  PW="$(grep -m1 -o 'server password .*' "$LOG" 2>/dev/null | awk '{print $NF}')"
  [ -n "$PW" ] && break
  kill -0 "$OC_PID" 2>/dev/null || die "无头服务启动失败，日志：$LOG"
  sleep 0.5
done
[ -n "$PW" ] || die "没读到服务密码（40 秒超时）。日志：$LOG"
ok "无头服务已就绪"

# ---------- 3. 生成前端配置 ----------
AUTH="$(printf 'opencode:%s' "$PW" | base64 | tr -d '\n')"
cat > "$WEB/config.js" <<EOF
/* 由 start.sh 自动生成，包含服务地址与凭据 */
window.OCW_CONFIG = {
  baseUrl: "http://$HOST:$OC_PORT",
  auth: "$AUTH"
};
EOF
ok "已生成 web/config.js"

# ---------- 4. 托管网页 ----------
info "启动网页服务（$HOST:$WEB_PORT）…"
( cd "$WEB" && "${STATIC_SERVER[@]}" >/dev/null 2>&1 ) &
WEB_PID=$!

for _ in $(seq 1 40); do
  port_open "$WEB_PORT" && break
  sleep 0.5
done
port_open "$WEB_PORT" || die "网页服务没起来（端口 $WEB_PORT 被占用？）"

# ---------- 5. 打开 ----------
printf '\n  \033[1mOpenCode Web\033[0m  →  %s\n' "$URL"
printf '  \033[2m工作目录：%s\033[0m\n\n' "$DIR"

open_browser "$URL"
info "按 Ctrl+C 停止"

wait "$OC_PID"
