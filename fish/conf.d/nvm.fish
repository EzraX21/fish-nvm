# fish 里的 nvm，不装任何包
# nvm.sh 是 bash 脚本 fish 跑不了，但它只干两件事：
#   1. 切换版本 = 改 PATH 指向 ~/.nvm/versions/node/<版本>/bin
#   2. 安装版本 = 得用 bash 跑官方安装器
# 所以 PATH 自己处理，需要 bash 的部分直接转发，
# 思路和 edc/bass 一样，只是省掉 env diff 那一步。

set -gx NVM_DIR "$HOME/.nvm"

function __nvm_apply --argument-names ver quiet --description '把 PATH 切到指定版本'
    # 支持模糊匹配：写 26 就找已装的 v26.* 里版本号最大的那个，
    # 和 nvm 官方行为一致。多个候选时挑最新的那个。
    # 用 glob 不用正则：正则里的 $ 锚点在双引号里会被 fish 当变量展开报错，
    # glob 靠 * 通配即可表达"前缀匹配"，26 能匹配 v26.10.0 但匹配不到 v260.1
    # 用 command ls 绕开 config.fish 里的 ls 覆盖（你把 ls 换成 eza 了，
    # eza 不认 -1，会返回空列表）；也可以用 fish 内置通配，但路径不存在时
    # 内置通配会保留字面量，反而更麻烦
    set -l installed (command ls -1 $NVM_DIR/versions/node/ 2>/dev/null)
    # 注意两点：
    # 1) 不能加 --，加了会按字面量比较整个字符串
    # 2) 末尾不能写 .*，因为目录名 v26.10.0 到这就结束了，
    #    glob 要求后面还有字符，结果精确匹配反而找不到。
    #    所以只写前缀 + *，既能模糊匹配也能精确命中。
    set -l matches (string match "v$ver*" $installed | sort -V)
    if test (count $matches) -eq 0
        # 这里不能调 nvm ls，nvm 内部还会调 __nvm_apply，会无限递归
        set -l show (string replace -r '^v' '' $installed | string join ', ')
        test -n "$quiet"; or echo "nvm: 没找到 v$ver，已装的是：$show" >&2
        return 1
    end
    # 用匹配到的完整版本名建目录，不能用 $ver：
    # ver 可能是 "26" 这种模糊写法，v26/bin 并不存在，
    # 要用 matches 里那个实际的 v26.10.0
    set -l dir "$NVM_DIR/versions/node/$matches[-1]/bin"
    if not test -d "$dir"
        test -n "$quiet"; or echo "nvm: 版本 v$ver 没装，先 nvm install $ver" >&2
        return 1
    end
    # 剔掉 PATH 里所有 nvm 版本的 bin，避免越切越长
    # 注意：下面这个 pattern 必须是【一个】字符串。
    # 写成 set -l p '^' $NVM_DIR '/...' fish 会当成三元素列表，
    # string match 只取第一个 '^' 当正则，等于匹配一切，PATH 会被清空。
    # 所以用双引号把三段真正拼起来。
    set -l pattern "^$NVM_DIR/versions/node/[^/]+/bin(/|\$)"
    set -gx PATH (string match -v -r "$pattern" $PATH)
    # 必须用 set -gx 直接赋值：fish_add_path --global 在函数体内不生效，
    # 函数一返回 PATH 就丢了，这是 fish 的作用域规则
    set -gx PATH "$dir" $PATH
    test -n "$quiet"; or echo "现在用的 Node -> v$ver"
    # 关键：test -n "$quiet" 在 quiet 为空时返回 1，会把整个函数的
    # 退出状态变成非零，调用方以为失败了。成功路径必须显式返回 0。
    return 0
end

function nvm --description 'node 版本管理器（fish 版）'
    set -l cmd "$argv[1]"
    switch "$cmd"
        case use
            if test -z "$argv[2]"
                echo "用法: nvm use <版本>" >&2
                return 1
            end
            __nvm_apply (string replace -r '^v' '' "$argv[2]")
        case install
            # 装版本必须用 bash 跑 nvm.sh，这步没得绕
            bash -c 'source "$HOME/.nvm/nvm.sh"; nvm "$@"' -- $argv
            # 装完自动切过去，省得再敲一次 use
            if test $status -eq 0
                set -l latest (command ls -1 $NVM_DIR/versions/node/ 2>/dev/null | tail -1)
                test -n "$latest"; and __nvm_apply (string replace -r '^v' '' $latest) 1
            end
        case ls
            echo "已装版本："
            command ls -1 $NVM_DIR/versions/node/ 2>/dev/null | string replace -r '^v' ''
        case current
            node -v
        case ''
            echo "用法: nvm <use|install|ls|current|...>" >&2
        case '*'
            # 其余子命令转给 bash 版 nvm，保持完整兼容
            bash -c 'source "$HOME/.nvm/nvm.sh"; nvm "$@"' -- $argv
    end
end

# 启动时自动切版本，静默执行不打扰。
# 直接读 ~/.nvm/alias/default，那才是你 bash 里真正在用的版本。
# 注意它是个普通文本文件不是符号链接，内容通常就写 "26" 这种模糊版本号，
# 正好走我们的模糊匹配，跟官方行为一致。
set -l boot_ver ""
if test -f "$NVM_DIR/alias/default"
    set boot_ver (command cat "$NVM_DIR/alias/default" 2>/dev/null | string trim)
end
if test -z "$boot_ver"
    set boot_ver (command ls -1 $NVM_DIR/versions/node/ 2>/dev/null | sort -V | tail -1)
end
if test -n "$boot_ver"
    __nvm_apply (string replace -r '^v' '' "$boot_ver") 1
end
# 收尾显式返回 0：否则文件整体退出码会继承最后那个 if 的状态，
# source 它的地方（比如 conf.d 自动加载）会当成失败
true
