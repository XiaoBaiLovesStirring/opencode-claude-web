#!/usr/bin/env bash
#
# install.sh — 把 opencode-web 注册成全局命令
#
#   ./install.sh                注册 opencode-web
#   ./install.sh --with-alias   额外注入 shell 函数，让 `opencode web` 也能用
#

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="${OCW_BIN_DIR:-$HOME/.local/bin}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WITH_ALIAS=0
for a in "$@"; do [ "$a" = "--with-alias" ] && WITH_ALIAS=1; done

info(){ printf '\033[2m  %s\033[0m\n' "$*"; }
ok()  { printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[33m! %s\033[0m\n' "$*"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

printf '\n\033[1mOpenCode Claude Web — 注册全局命令\033[0m\n\n'

[ -f "$ROOT/start.sh" ] || die "找不到 $ROOT/start.sh，请在解压后的目录里运行本脚本"
chmod +x "$ROOT/start.sh"

# ---------- 写入包装脚本 ----------
mkdir -p "$BIN"
cat > "$BIN/opencode-web" <<EOF
#!/usr/bin/env bash
# 由 install.sh 生成，指向 $ROOT
exec "$ROOT/start.sh" "\$@"
EOF
chmod +x "$BIN/opencode-web"
ok "已注册命令：$BIN/opencode-web"

# ---------- PATH 检查 ----------
case ":$PATH:" in
  *":$BIN:"*) ok "可以直接运行：opencode-web" ;;
  *)
    warn "$BIN 不在 PATH 里，把这行加到 shell 配置（~/.bashrc 或 ~/.zshrc）：
      export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

# ---------- 可选：opencode web ----------
if [ "$WITH_ALIAS" -eq 1 ]; then
  case "${SHELL:-}" in
    */zsh)  RC="$HOME/.zshrc" ;;
    */bash) RC="$HOME/.bashrc" ;;
    *)      if [ -f "$HOME/.zshrc" ]; then RC="$HOME/.zshrc"; else RC="$HOME/.bashrc"; fi ;;
  esac

  if grep -q "opencode-web 注入" "$RC" 2>/dev/null; then
    info "shell 配置里已有该函数，跳过"
  else
    [ -f "$RC" ] && cp "$RC" "$RC.bak.$STAMP"
    cat >> "$RC" <<'SH'

# --- opencode-web 注入：让 `opencode web` 直接启动网页界面 ---
opencode() {
  if [ "${1:-}" = "web" ]; then
    shift
    command opencode-web "$@"
  else
    command opencode "$@"
  fi
}
# --- end ---
SH
    ok "已写入 $RC（备份：$(basename "$RC").bak.$STAMP）"
    info "执行 source $RC 或重开终端后生效"
  fi
fi

printf '\n\033[32m完成\033[0m\n\n'
printf '  opencode-web                在当前目录启动\n'
printf '  opencode-web ~/myproj       指定工作目录\n'
printf '  OCW_WEB_PORT=8899 opencode-web   换端口\n'
[ "$WITH_ALIAS" -eq 1 ] && printf '  opencode web                同上（需先 source）\n'
printf '\n'
