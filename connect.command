#!/bin/bash
# cage-bridge：让 Mac 上的 T3 Code 桌面端连接 Cage 虚拟机。在 Mac 上运行，不在 Cage 里运行。
#   接入：双击，或在“终端”里  bash connect.command
#   撤销：                    bash connect.command undo
# 只改一处：~/.ssh/config 开头加 Include 行（先备份、先询问）。不改 Cage，不读取登录凭据。
CONF="$HOME/.ssh/config"
MARK="# cage-bridge"
finish() { echo; [ -t 0 ] && read -r -p "按回车关闭" _; exit "$1"; }
[ "$(uname -s)" = Darwin ] || { echo "这里不是 Mac。请在 Mac 的访达里双击，或在 Mac 自带的“终端”里运行。"; finish 1; }

backup() { b="$CONF.bak-$(date +%Y%m%d-%H%M%S)"; cp -p "$CONF" "$b" && echo "原文件已备份：$b"; }

if [ "${1:-}" = undo ]; then
  grep -qsF "$MARK" "$CONF" || { echo "没有需要撤销的内容。"; finish 0; }
  backup || finish 1
  t="$(mktemp "$CONF.XXXXXX")" || finish 1
  # 删掉标记行和紧跟着的 Include 行，其他内容不动。
  awk -v m="$MARK" '$0==m{skip=1;next} skip{skip=0; if($1=="Include") next} {print}' "$CONF" > "$t"
  chmod 600 "$t" && mv "$t" "$CONF" && echo "已撤销。"
  finish 0
fi

list=(); names=()
add() {
  local x n
  for x in ${list[@]+"${list[@]}"}; do [ "$x" = "$1" ] && return; done
  n="$(awk 'tolower($1)=="host"{print $2; exit}' "$1")"
  case "$n" in ''|lima-base*) return ;; esac    # base 是 Cage 的模板，不是日常环境
  list+=("$1"); names+=("$n"); echo "找到环境：$n"
}
for f in "$HOME"/.claude-cage/state/lima/*/ssh.config; do [ -f "$f" ] && add "$f"; done
if [ ${#list[@]} -eq 0 ]; then
  echo "默认位置没有，正在查找 Cage 的数据目录（可能要一两分钟，弹窗问访问权限请点允许）……"
  while IFS= read -r f; do add "$f"; done < <(find "$HOME" /Volumes -maxdepth 8 -path '*/lima/*/ssh.config' 2>/dev/null)
fi
[ ${#list[@]} -gt 0 ] || { echo "没找到 Cage 环境。请先打开 Cage，等左下角显示“环境运行正常”，再运行一次。"; finish 1; }

todo=""
for f in "${list[@]}"; do
  grep -qsF "Include \"$f\"" "$CONF" || todo="${todo}${MARK}
Include \"$f\"
"
done
if [ -n "$todo" ]; then
  echo; echo "将在 ~/.ssh/config 开头加上："; printf '%s' "$todo"
  read -r -p "可以吗？[y/N] " a
  case "$a" in y|Y|yes) ;; *) echo "没有改动。"; finish 1 ;; esac
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  t="$(mktemp "$CONF.XXXXXX")" || finish 1
  printf '%s\n' "$todo" > "$t"
  if [ -f "$CONF" ]; then backup && cat "$CONF" >> "$t" || { rm -f "$t"; finish 1; }; fi
  chmod 600 "$t" && mv "$t" "$CONF" && echo "已写入。"
else
  echo "SSH 配置已经加过了。"
fi

# 在虚拟机里执行：只看 CLI 在不在、哪个目录已登录、共享了哪些项目。
probe='
echo "主机名  $(hostname)"
sh -lc "command -v claude" >/dev/null && echo "Claude  已安装" || echo "Claude  没找到"
st() { env -u CLAUDE_CONFIG_DIR $1 timeout 20 sh -lc "claude auth status" 2>/dev/null | grep -q "\"loggedIn\": *true"; }
if st ""; then echo "登录    默认目录已登录，T3 的 CLAUDE_CONFIG_DIR path 留空"; else
  n=0
  for d in "$HOME"/.local/share/cage/claude-accounts/*/config; do
    [ -d "$d" ] && st "CLAUDE_CONFIG_DIR=$d" && { n=$((n+1)); echo "登录    已登录，T3 的 CLAUDE_CONFIG_DIR path 填："; echo "        $d"; }
  done
  [ $n -gt 1 ] && echo "        （有 $n 个账号，选一个）"
  [ $n = 0 ] && echo "登录    还没登录，请先在 Cage 里登录 Claude 账号"
fi
echo "项目    已共享的目录："
mount | sed -n "s/^.* on \(.*\) type fuse.sshfs .*/        \1/p" | grep -v "/\.claude-cage-downloads$"
true'
echo; good=()
for n in "${names[@]}"; do
  if out="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$n" sh -s <<<"$probe" 2>&1)"; then
    echo "✓ $n 连接成功"; printf '%s\n' "$out" | sed 's/^/  /'; good+=("$n")
  else
    echo "✗ $n 连接失败：$out"
  fi
done
echo
[ ${#good[@]} -gt 0 ] || { echo "没有能连上的环境。请确认 Cage 已打开、左下角显示“环境运行正常”，再运行一次。"; finish 1; }
echo "T3：Settings → Environments → Add environment → SSH"
echo "只填 SSH host or alias，Username 和 Port 留空：${good[0]}"
[ ${#good[@]} -gt 1 ] && echo "（能连上多台：${good[*]}，按主机名选）"
command -v pbcopy >/dev/null && printf '%s' "${good[0]}" | pbcopy && echo "（名字已复制到剪贴板）"
finish 0
