# fish-nvm

fish 配置 + 一个不装插件就能用的 nvm。

## 为什么有这个项目

# 因为我自己也踩过这个坑，问ai搞了很久，想帮助你更快的搭建环境，少踩坑，希望这个项目可以帮到你，也希望你把这种精神传承下去

## 有什么

- `fish/conf.d/nvm.fish` — fish 里可用的 nvm，支持模糊匹配（`nvm use 26` 就够）
- `fish/config.fish` — 提示符、别名、常用函数
- `starship.toml` — 提示符样式
- `bashrc.example` — bash 里配 nvm 的参考，fish 用户其实用不上
- `scripts/install.sh` — 安装脚本，会先备份

## 安装

依赖（Arch）：

```bash
sudo pacman -S fish starship zoxide eza bat yazi fd ttf-font-nerd
```

nvm 官方装法：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

然后：

```bash
./scripts/install.sh
exec fish
```

## 用法

```bash
nvm ls              # 已装版本
nvm current         # 当前版本
nvm use 26          # 切版本，模糊匹配，取最新的
nvm install 22      # 装，转给 bash 版 nvm
nvm --version       # 任何没实现的子命令转给 bash 版
```

其他：`y` 打开 yazi 并自动 cd、`lt` 树状列表、`fa` fastfetch、`滚` 更新系统。

## 为什么不用 AUR 的 nvm-fish

那个包只有 2 票，新包，卸载时会 `sed -i` 改你的 config.fish。
手写这几十行更可控。原理和 edc/bass 一样：nvm 只改 PATH，不需要 diff 整个环境。

fish 里那几个坑写在 `nvm.fish` 的注释里了，别改坏。

## 许可证

[MIT](LICENSE)。随便拿去改，不用声明来源。
