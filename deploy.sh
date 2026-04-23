#!/bin/bash
# WebSSH Terminal — 一键部署 / 更新
# 用法:
#   海外服务器:
#     bash <(curl -sL https://raw.githubusercontent.com/mubaiqq/webssh-terminal/main/deploy.sh)
#   国内服务器（加速）:
#     bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/mubaiqq/webssh-terminal/main/deploy.sh)
#   自定义端口:
#     PORT=8080 bash <(curl -sL ...)
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

# ── 1. Node.js 检查 ──
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install: https://nodejs.org"
  exit 1
fi
echo "   ✓ Node.js $(node -v)"

# ── 2. 安装 pm2 ──
if ! command -v pm2 &>/dev/null; then
  echo "🔧 Installing pm2..."
  npm install -g pm2 --registry="$NPM_REGISTRY" 2>&1 | tail -3
fi

# ── 3. 停止旧进程 + 释放端口 ──
echo "🛑 Stopping old processes..."
pm2 stop "$APP_NAME" 2>/dev/null && echo "   ✓ pm2 stopped" || true
pm2 delete "$APP_NAME" 2>/dev/null && echo "   ✓ pm2 deleted" || true

if command -v fuser &>/dev/null; then
  if fuser "$PORT/tcp" &>/dev/null; then
    echo "   ⚠ Port $PORT in use, freeing..."
    fuser -k "$PORT/tcp" 2>/dev/null || true
    sleep 1
  fi
elif command -v lsof &>/dev/null; then
  PID=$(lsof -ti :"$PORT" 2>/dev/null)
  if [ -n "$PID" ]; then
    echo "   ⚠ Port $PORT in use, killing PID $PID..."
    kill -9 $PID 2>/dev/null || true
    sleep 1
  fi
fi
pkill -f "ssh.*serveo.net" 2>/dev/null || true

# ── 4. 获取代码 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/server.js" ]; then
  # 从本地仓库目录部署（在仓库里直接运行 deploy.sh）
  if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    echo "📂 Syncing from $SCRIPT_DIR ..."
    mkdir -p "$INSTALL_DIR"
    rsync -a --delete \
      --exclude '.git/' \
      --exclude 'node_modules/' \
      --exclude 'data/' \
      --exclude 'tunnel.log' \
      "$SCRIPT_DIR/" "$INSTALL_DIR/"
    echo "   ✓ Files synced"
  else
    echo "📂 Using $INSTALL_DIR"
  fi
  cd "$INSTALL_DIR"
else
  # 一键部署（curl 运行）— 从 GitHub 克隆或更新
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "🔄 Updating from GitHub..."
    cd "$INSTALL_DIR"
    [ -d "data" ] && cp -a data /tmp/_webssh_data_bak
    git fetch origin && git reset --hard origin/main 2>&1 | tail -3
    [ -d "/tmp/_webssh_data_bak" ] && { cp -a /tmp/_webssh_data_bak/* data/ 2>/dev/null; rm -rf /tmp/_webssh_data_bak; }
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
fi

# ── 5. 安装依赖 ──
if [ ! -d "node_modules" ] || [ -f "package.json" ] && [ "package.json" -nt "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
  echo "   ✓ Dependencies installed"
else
  echo "📦 Dependencies OK"
fi

# ── 6. 启动服务 ──
echo "🚀 Starting $APP_NAME on port $PORT..."
pm2 start server.js --name "$APP_NAME" \
  --max-memory-restart 300M \
  --exp-backoff-restart-delay=100 \
  --time \
  --env PORT="$PORT" \
  --env BASE_PATH="$BASE_PATH" \
  2>&1 | tail -5
pm2 save 2>&1 | tail -1

# ── 7. 开机自启 ──
echo "⚡ Configuring auto-start..."
PM2_STARTUP=$(pm2 startup 2>&1)
if echo "$PM2_STARTUP" | grep -q "sudo"; then
  eval "$(echo "$PM2_STARTUP" | grep "sudo" | head -1)" 2>&1 | tail -2
fi
pm2 save 2>&1 | tail -1

# ── 8. 网络探测 ──
echo "🌐 Detecting network..."
PUBLIC_IP=""
for svc in "myip.ipip.net" "ip.sb" "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
  PUBLIC_IP=$(curl -s --connect-timeout 2 "https://$svc" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
  [ -n "$PUBLIC_IP" ] && break
done
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

TUNNEL_URL=""
if [ "$ENABLE_TUNNEL" = "true" ]; then
  echo "🔗 Creating tunnel..."
  nohup ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -R 80:localhost:$PORT serveo.net > tunnel.log 2>&1 &
  for i in $(seq 1 8); do
    sleep 2
    TUNNEL_URL=$(grep -oP 'https?://[a-zA-Z0-9.-]+\.serveo[a-z.]*' tunnel.log 2>/dev/null | head -1)
    [ -n "$TUNNEL_URL" ] && break
  done
  [ -z "$TUNNEL_URL" ] && echo "   ⚠ Tunnel timeout, skipping"
fi

# ── 9. 结果 ──
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
echo "  ║  🔒 pm2 守护进程 · ⚡ 开机自启               ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""
echo "  更新: 重新运行此脚本即可"
echo "  卸载: bash <(curl -sL $GH_PROXY/$REPO/raw/main/uninstall.sh)"
echo ""
