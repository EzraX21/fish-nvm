#!/usr/bin/env bash
# 把仓库里的配置复制到正确位置。可反复运行，不会重复叠加内容。
#
# 幂等做法：直接覆盖目标文件，不做追加。
# config.fish 覆盖前先备份，原版本会留在 fish/backup.* 里。
#
# 用法:
#   ./scripts/install.sh            交互式，缺依赖会问你要不要继续
#   ./scripts/install.sh --force    缺依赖也直接装

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FISH_DIR="${HOME}/.config/fish"
CONF_D="${FISH_DIR}/conf.d"
STAMP="$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;31m警告:\033[0m %s\n' "$1"; }
ok()   { printf '  \033[1;32m%s\033[0m\n' "$1"; }

# ---------- 依赖检查 ----------
info "检查依赖"
missing=()
for cmd in fish starship zoxide eza bat yazi fd; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
[[ -d "${HOME}/.nvm" ]] || missing+=("nvm")

if (( ${#missing[@]} > 0 )); then
    warn "缺少: ${missing[*]}"
    echo "  Arch 安装命令: sudo pacman -S fish starship zoxide eza bat yazi fd ttf-font-nerd"
    echo "  nvm 单独装: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
    if [[ "${1:-}" != "--force" ]]; then
        read -rp "  缺这些也能继续，配置装上但命令用不了。继续？[y/N] " ans
        [[ "${ans,,}" == "y" ]] || { echo "已取消。"; exit 1; }
    fi
    echo
fi

# ---------- 备份 ----------
info "备份现有配置"
BACKUP_DIR="${FISH_DIR}/backup.${STAMP}"
count=0
mkdir -p "$BACKUP_DIR"   # 没人备份的话下面会 rmdir 掉

# 只备份"内容与仓库不同"的文件。
# 重复运行 install.sh 时完全一致的文件跳过，既不浪费时间也不攒垃圾备份。
backup_if_differs() {
    local src="$1" dst="$2" rel="$3"
    [[ -f "$dst" ]] || return 0
    # 仓库里没有对应源文件的东西（比如本机私有的），一律备份
    if [[ -f "$src" ]] && cmp -s "$src" "$dst"; then
        return 0
    fi
    mkdir -p "${BACKUP_DIR}/$(dirname "$rel")"
    cp "$dst" "${BACKUP_DIR}/${rel}"
    count=$((count + 1))
}

backup_if_differs "${REPO_DIR}/fish/config.fish"         "${FISH_DIR}/config.fish"      "config.fish"
backup_if_differs "${REPO_DIR}/fish/conf.d/nvm.fish"     "${CONF_D}/nvm.fish"           "conf.d/nvm.fish"
backup_if_differs "${REPO_DIR}/starship.toml"            "${HOME}/.config/starship.toml" "starship.toml"

if (( count > 0 )); then
    ok "已备份 ${count} 个文件到 ${BACKUP_DIR#"$HOME"/}"
else
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    ok "配置已是最新，没有需要备份的东西"
fi
if (( count == 0 )); then
    ok "配置已是最新，没有需要备份的东西"
fi

# ---------- 安装 ----------
info "安装配置"
mkdir -p "$CONF_D"

install_file() {
    local src="$1" dst="$2" label="$3"
    if [[ ! -f "$src" ]]; then
        warn "${label} 源文件不存在: ${src}"
        return 0
    fi
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        ok "${label} 已是最新，跳过"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    ok "${label}"
}

# config.fish 整体替换，不做合并——合并会让函数重复定义
install_file "${REPO_DIR}/fish/config.fish" "${FISH_DIR}/config.fish" "fish/config.fish"
install_file "${REPO_DIR}/fish/conf.d/nvm.fish" "${CONF_D}/nvm.fish" "fish/conf.d/nvm.fish"
install_file "${REPO_DIR}/starship.toml" "${HOME}/.config/starship.toml" "starship.toml"

# ---------- 冲突提醒 ----------
# 早期版本把 nvm 函数直接写在 config.fish 里，conf.d 再加载一次就重复定义了
if grep -q "^function nvm" "${FISH_DIR}/config.fish" 2>/dev/null; then
    warn "config.fish 里还有旧的 nvm 函数定义，建议手动删掉，否则会覆盖 conf.d 的版本"
fi

# ---------- 验证 ----------
info "验证"
if fish -c "source '${CONF_D}/nvm.fish'; type -q nvm" >/dev/null 2>&1; then
    ok "nvm.fish 语法正常"
else
    warn "nvm.fish 有语法错误，检查一下"
fi

if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    latest=$(command ls -1 "${HOME}/.nvm/versions/node/" 2>/dev/null | sort -V | tail -1)
    ok "检测到 nvm 版本: ${latest:-无}"
fi

# ---------- 完成 ----------
echo
info "完成"
echo "  开一个新终端，或执行 exec fish 生效。"
echo
echo "  试试:"
echo "    node -v          当前 node 版本"
echo "    nvm ls           已装版本"
echo "    nvm use 26       切版本（支持模糊匹配）"
echo
echo "  恢复备份:"
echo "    cp -a ${BACKUP_DIR#"$HOME"/} ~/.config/fish/"
