# fish 主配置
#
# install.sh 会覆盖这个文件，想加东西请写到 conf.d/ 下，那边不会被覆盖

set fish_greeting ""

# ~/.local/bin 放用户自己装的脚本
fish_add_path ~/.local/bin

# 提示符和目录跳转
starship init fish | source
zoxide init fish --cmd cd | source

# 常用别名
abbr fa fastfetch
abbr reboot 'systemctl reboot'
abbr grub 'LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 sudo grub-mkconfig -o /boot/grub/grub.cfg'

# 用 yazi 选目录，退出后自动 cd 到那里
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# 更顺手的 ls
function ls
    command eza --icons=auto $argv
end

function lt
    command eza --icons=auto --tree $argv
end

function la
    command eza -l --icons=auto $argv
end

# cat 走 bat
function cat
    command bat --theme="base16" -- $argv
end

# 滚屏动画
function sl
    command sl | lolcat
end

# 更新系统
function 滚
    sysup
end

# 随机动漫壁纸脚本，需要自己把那个脚本放到 ~/.local/bin/
function raw
    command ~/.local/bin/random-anime-wallpaper-dms $argv
end
