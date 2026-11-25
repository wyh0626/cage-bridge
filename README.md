# cage-bridge

用 Mac 上的 [T3 Code](https://t3.codes) 桌面端，操作 [Cage](https://github.com/Lee-xeo/Claude-Cage) 虚拟机里的 Claude Code。Cage 不用改。

```
Mac                              Cage 虚拟机
T3 桌面端（只当界面） ── SSH ──→ T3 服务端（T3 自动安装）
                                   └→ claude ──→ 联网走 Cage 的代理
```

目前**只支持 macOS**，只支持 Claude。这是个人项目，与 T3 Tools、Cage、Anthropic 均无关联。

## 准备

- macOS 14 以上，Cage 已打开，左下角显示“环境运行正常”
- Mac 上已装 [T3 Code 桌面端](https://t3.codes/download)
- 在 Cage 里用**自己的** Claude 账号登录过
- 要用的项目文件夹已在 Cage 左侧“项目”里添加

## 使用

1. 下载 [connect.command](connect.command)，先看一遍内容。打开 Mac 自带的“终端”（不是 Cage 的），输入 `bash` 加空格，把文件拖进去，回车。

   它会显示要往 `~/.ssh/config` 加的内容，你输入 `y` 才写入，原文件先备份。连上后会给出下面要填的三样东西：**环境名**、**登录目录**、**项目路径**。

2. T3：Settings → Environments → Add environment → SSH。只填 **SSH host or alias**（环境名），Username 和 Port 留空。第一次会在虚拟机里下载 T3 服务端（约 177 MB）。

3. T3：Settings → Providers，环境选刚加的那台，点 Claude，把登录目录填到 **CLAUDE_CONFIG_DIR path**，Binary path 不动，点右上角刷新。脚本说“留空”就不填。

4. Add project，环境选 Cage 那台，填项目路径（和 Mac 上一样）。

5. 新建会话选 Claude，发“运行 hostname 和 pwd”。主机名和脚本显示的一致，就跑在虚拟机里。

撤销：在 T3 里删除这个环境，然后：

```bash
bash connect.command undo
```

## 注意

- **环境不要选本机**，从访达拖文件夹进 T3 也算本机，agent 会直接跑在 Mac 上。
- **权限先别用 Full access**。共享的项目和 `.git` 会被直接修改，重要仓库先备份。
- **先用 Current checkout，不用 worktree**。worktree 建在虚拟机里，却登记在共享的 `.git`。
- 在 T3 里自己打开的外部网页由 Mac 加载，**不走 Cage 的代理**。
- 不要在 Cage 环境里开 T3 Connect。
- Cage 里所有项目共用一台虚拟机，彼此没有隔离；别把 SSH 私钥等凭据放进去。
- 用自己的账号，不要共用或拷贝别人的登录目录，并遵守 Claude 的服务条款。
- 求助时脚本输出里有你的路径和主机名，截图前遮一下。

## 常见问题

| 现象 | 原因 | 办法 |
|---|---|---|
| 脚本说“这里不是 Mac” | 在 Cage 的终端里运行了 | 用 Mac 自带的“终端” |
| `Connection refused`，名字是 `lima-base…` | 选到了 Cage 的模板 | 换成脚本给出的名字 |
| 重启后 `Connection refused` | 端口变了，或 Cage 没打开 | 打开 Cage；T3 里 Port 留空重新添加 |
| Claude 灰色，Not authenticated | T3 没用到 Cage 的登录 | 填 CLAUDE_CONFIG_DIR path 再刷新 |
| 突然变成未登录 | 在 Cage 里换了账号或重建了环境 | 重新运行脚本，改成新目录 |
| 找不到项目目录 | 没在 Cage 里添加 | 先在 Cage 添加 |

## 手动做法

在 `~/.ssh/config` **开头**加一行：

```
Include ~/.claude-cage/state/lima/*/ssh.config
```

查环境名（忽略 `lima-base` 开头的）：

```bash
awk '/^Host /{print $2}' ~/.claude-cage/state/lima/*/ssh.config
```

查登录目录：

```bash
ssh 环境名 'ls -d ~/.local/share/cage/claude-accounts/*/config'
```

登录目录由 Cage 在添加账号时生成，每个人不同。

## 脚本做了什么

- 读 Cage 生成的 `ssh.config`，找到环境名；跳过模板。
- 经你确认，在 `~/.ssh/config` 开头加 `Include`。
- SSH 进虚拟机，只查：`claude` 是否安装、哪个账号目录已登录（`claude auth status`）、共享了哪些项目。不读取登录凭据，不改 Cage。
