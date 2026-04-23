#!/bin/bash
# WebSSH Terminal — 一键部署 / 更新
# 用法:
#   bash deploy.sh              # 部署或更新（保留数据）
#   bash deploy.sh --fresh      # 全新安装（清除旧进程）
#   PORT=8080 bash deploy.sh    # 自定义端口
set -e

PORT="${PORT:-9111}"
REPO="https://github.com/mubaiqq/webssh-terminal.git"
INSTALL_DIR="$HOME/webssh-terminal"
APP_NAME="webssh-terminal"
NPM_REGISTRY="https://registry.npmmirror.com"
GH_PROXY="https://ghfast.top"
ENABLE_TUNNEL="${ENABLE_TUNNEL:-true}"
BASE_PATH="${BASE_PATH:-}"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   ⚡ WebSSH Terminal Deploy   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# ── 1. 确定代码来源 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAS_GIT=false
[ -d "$SCRIPT_DIR/.git" ] && HAS_GIT=true

# ── 2. Node.js 检查 ──
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install: https://nodejs.org"
  exit 1
fi
echo "   ✓ Node.js $(node -v)"

# ── 3. 安装依赖（本地目录） ──
if [ "$HAS_GIT" = true ]; then
  cd "$SCRIPT_DIR"
  if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
    echo "   ✓ Dependencies installed"
  else
    echo "📦 Dependencies OK"
  fi
fi

# ── 4. 安装 pm2 ──
if ! command -v pm2 &>/dev/null; then
  echo "🔧 Installing pm2..."
  npm install -g pm2 --registry="$NPM_REGISTRY" 2>&1 | tail -3
fi

# ── 5. 停止旧进程 + 释放端口 ──
echo "🛑 Stopping old processes..."
pm2 stop "$APP_NAME" 2>/dev/null && echo "   ✓ pm2 stopped" || true
pm2 delete "$APP_NAME" 2>/dev/null && echo "   ✓ pm2 deleted" || true

# 杀掉占用端口的进程（不管是不是自己的）
if command -v fuser &>/dev/null; then
  if fuser "$PORT/tcp" &>/dev/null; then
    echo "   ⚠ Port $PORT in use, freeing..."
    fuser -k "$PORT/tcp" 2>/dev/null || true
    sleep 1
    echo "   ✓ Port $PORT freed"
  fi
elif command -v lsof &>/dev/null; then
  PID=$(lsof -ti :"$PORT" 2>/dev/null)
  if [ -n "$PID" ]; then
    echo "   ⚠ Port $PORT in use by PID $PID, killing..."
    kill -9 $PID 2>/dev/null || true
    sleep 1
    echo "   ✓ Port $PORT freed"
  fi
fi

# 停掉旧隧道
pkill -f "ssh.*serveo.net" 2>/dev/null || true

# ── 6. 同步文件到安装目录 ──
if [ "$HAS_GIT" = true ]; then
  # 从本地仓库目录部署
  if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    echo "📂 Copying files to $INSTALL_DIR ..."
    mkdir -p "$INSTALL_DIR"

    # 排除 data/、node_modules/、.git/，其余全部覆盖
    rsync -a --delete \
      --exclude '.git/' \
      --exclude 'node_modules/' \
      --exclude 'data/' \
      "$SCRIPT_DIR/" "$INSTALL_DIR/"
    echo "   ✓ Files synced (data/ preserved)"

    # 如果安装目录没有 node_modules，装一下
    cd "$INSTALL_DIR"
    if [ ! -d "node_modules" ]; then
      echo "📦 Installing dependencies in $INSTALL_DIR ..."
      npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
    fi
  else
    cd "$INSTALL_DIR"
    echo "📂 Using local directory: $INSTALL_DIR"
  fi
else
  # 没有 .git → 从 GitHub 克隆/拉取
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "🔄 Updating from GitHub..."
    cd "$INSTALL_DIR"
    # 暂存本地修改，拉取后恢复 data/
    if [ -d "data" ]; then
      cp -a data /tmp/_webssh_data_bak
    fi
    git fetch origin
    git reset --hard origin/main 2>&1 | tail -3
    if [ -d "/tmp/_webssh_data_bak" ]; then
      cp -a /tmp/_webssh_data_bak/* data/ 2>/dev/null || true
      rm -rf /tmp/_webssh_data_bak
    fi
    echo "   ✓ Code updated (data/ preserved)"
  else
    echo "📥 First install, cloning..."
    CLONE_URL="${GH_PROXY}/${REPO}"
    echo "   Trying proxy: $CLONE_URL"
    if ! git clone "$CLONE_URL" "$INSTALL_DIR" 2>&1 | tail -3; then
      echo "   ⚠ Proxy failed, trying direct..."
      git clone "$REPO" "$INSTALL_DIR" 2>&1 | tail -3
    fi
    cd "$INSTALL_DIR"
  fi

  # 安装依赖
  NEED_INSTALL=false
  [ ! -d "node_modules" ] && NEED_INSTALL=true
  if [ "$NEED_INSTALL" = true ]; then
    echo "📦 Installing dependencies..."
    npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
    echo "   ✓ Dependencies installed"
  fi
fi

cd "$INSTALL_DIR"

# ── 7. 启动服务 ──
echo "🚀 Starting $APP_NAME on port $PORT..."
pm2 start server.js --name "$APP_NAME" \
  --max-memory-restart 300M \
  --exp-backoff-restart-delay=100 \
  --time \
  --env PORT="$PORT" \
  --env BASE_PATH="$BASE_PATH" \
  2>&1 | tail -5

pm2 save 2>&1 | tail -1
ACTION="started"

# ── 8. 开机自启 ──
echo "⚡ Configuring auto-start on boot..."
PM2_STARTUP=$(pm2 startup 2>&1)
if echo "$PM2_STARTUP" | grep -q "sudo"; then
  STARTUP_CMD=$(echo "$PM2_STARTUP" | grep "sudo" | head -1)
  echo "   Running: $STARTUP_CMD"
  eval "$STARTUP_CMD" 2>&1 | tail -2
fi
pm2 save 2>&1 | tail -1
echo "   ✓ Auto-start configured"

# ── 9. 网络探测 ──
echo "🌐 Detecting network..."
PUBLIC_IP=""
for svc in "myip.ipip.net" "ip.sb" "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
  PUBLIC_IP=$(curl -s --connect-timeout 2 "https://$svc" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
  [ -n "$PUBLIC_IP" ] && break
done
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

TUNNEL_URL=""
if [ "$ENABLE_TUNNEL" = "true" ]; then
  echo "🔗 Creating tunnel via serveo.net..."
  nohup ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -R 80:localhost:$PORT serveo.net > tunnel.log 2>&1 &
  for i in $(seq 1 10); do
    sleep 2
    TUNNEL_URL=$(grep -oP 'https?://[a-zA-Z0-9.-]+\.serveo[a-z.]*' tunnel.log 2>/dev/null | head -1)
    [ -n "$TUNNEL_URL" ] && break
  done
  [ -z "$TUNNEL_URL" ] && echo "   ⚠ Tunnel timeout, skipping"
else
  echo "⏭  Tunnel disabled"
fi

# ── 10. 显示结果 ──
echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║              ✅ Deploy Complete!               ║"
echo "  ╠═══════════════════════════════════════════════╣"
printf "  ║  Local:   http://localhost:%-19s ║\n" "$PORT"
[ -n "${LAN_IP:-}" ] && printf "  ║  LAN:     http://%-28s ║\n" "${LAN_IP}:${PORT}"
[ -n "${PUBLIC_IP:-}" ] && printf "  ║  Public:  http://%-28s ║\n" "${PUBLIC_IP}:${PORT}"
[ -n "${TUNNEL_URL:-}" ] && printf "  ║  Tunnel:  %-34s ║\n" "${TUNNEL_URL}"
echo "  ╠═══════════════════════════════════════════════╣"
echo "  ║  Default password: 123456                     ║"
echo "  ╠═══════════════════════════════════════════════╣"
echo "  ║  🔒 pm2 守护进程: ✅                          ║"
echo "  ║  ⚡ 开机自启:     ✅                          ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""
echo "  常用命令："
echo "    pm2 status          # 查看状态"
echo "    pm2 logs            # 查看日志"
echo "    pm2 restart         # 重启服务"
echo "    bash deploy.sh      # 更新到最新版"
echo ""
