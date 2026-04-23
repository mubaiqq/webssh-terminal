#!/bin/bash
# WebSSH One-Click Deploy (from GitHub or local)
set -e
PORT=9111
REPO="https://github.com/mubaiqq/webssh-terminal.git"
INSTALL_DIR="$HOME/webssh-terminal"
APP_NAME="webssh-terminal"

# ── 国内加速配置 ──
NPM_REGISTRY="https://registry.npmmirror.com"
GH_PROXY="https://ghfast.top"
ENABLE_TUNNEL="${ENABLE_TUNNEL:-true}"
# 子目录反代路径（留空则部署到根路径，设为 /ssh 则访问 域名/ssh）
BASE_PATH="${BASE_PATH:-}"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   ⚡ WebSSH Terminal Deploy   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# 1. Clone or use local
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/server.js" ]; then
  DIR="$SCRIPT_DIR"
  echo "📂 Using local directory: $DIR"
else
  echo "📥 Cloning from GitHub..."
  if [ -d "$INSTALL_DIR" ]; then
    echo "   ✓ Already cloned, pulling latest..."
    cd "$INSTALL_DIR" && git pull 2>&1 | tail -2
  else
    CLONE_URL="${GH_PROXY}/${REPO}"
    echo "   Trying proxy: $CLONE_URL"
    if ! git clone "$CLONE_URL" "$INSTALL_DIR" 2>&1 | tail -3; then
      echo "   ⚠ Proxy failed, falling back to direct clone..."
      git clone "$REPO" "$INSTALL_DIR" 2>&1 | tail -3
    fi
    cd "$INSTALL_DIR"
  fi
  DIR="$INSTALL_DIR"
fi

cd "$DIR"

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install: https://nodejs.org"
  exit 1
fi
echo "   ✓ Node.js $(node -v)"

# 2. Install dependencies (使用镜像加速)
echo "📦 Installing dependencies..."
if [ ! -d "node_modules" ]; then
  npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
else
  echo "   ✓ node_modules exists"
fi

# 3. Install pm2 (进程守护)
echo "🔧 Setting up pm2..."
if ! command -v pm2 &>/dev/null; then
  npm install -g pm2 --registry="$NPM_REGISTRY" 2>&1 | tail -3
fi
echo "   ✓ pm2 $(pm2 -v)"

# 4. Clean up old processes
echo "🧹 Cleaning port $PORT..."
pm2 delete "$APP_NAME" 2>/dev/null || true
pkill -f "ssh.*serveo.net" 2>/dev/null || true
fuser -k $PORT/tcp 2>/dev/null || true
sleep 1

# 5. Start with pm2 (进程守护 + 崩溃自重启)
echo "🚀 Starting server with pm2..."
if [ -n "$BASE_PATH" ]; then
  echo "   📂 Base path: $BASE_PATH"
fi
pm2 start server.js --name "$APP_NAME" \
  --max-memory-restart 300M \
  --exp-backoff-restart-delay=100 \
  --time \
  --env BASE_PATH="$BASE_PATH" \
  2>&1 | tail -5

# Save pm2 process list
pm2 save 2>&1 | tail -1

# 6. Setup pm2-startup (开机自启)
echo "⚡ Configuring auto-start on boot..."
PM2_STARTUP=$(pm2 startup 2>&1)
if echo "$PM2_STARTUP" | grep -q "sudo"; then
  # Extract and run the startup command
  STARTUP_CMD=$(echo "$PM2_STARTUP" | grep "sudo" | head -1)
  echo "   Running: $STARTUP_CMD"
  eval "$STARTUP_CMD" 2>&1 | tail -2
fi
pm2 save 2>&1 | tail -1
echo "   ✓ Auto-start configured"

# 7. Detect public IP (优先国内服务)
echo "🌐 Detecting network..."
PUBLIC_IP=""
for svc in "myip.ipip.net" "ip.sb" "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
  PUBLIC_IP=$(curl -s --connect-timeout 2 "https://$svc" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
  [ -n "$PUBLIC_IP" ] && break
done

LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# 8. Create tunnel (可选)
TUNNEL_URL=""
TUNNEL_PID=""
if [ "$ENABLE_TUNNEL" = "true" ]; then
  echo "🔗 Creating tunnel via serveo.net..."
  nohup ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -R 80:localhost:$PORT serveo.net > tunnel.log 2>&1 &
  TUNNEL_PID=$!

  for i in $(seq 1 10); do
    sleep 2
    TUNNEL_URL=$(grep -oP 'https?://[a-zA-Z0-9.-]+\.serveo[a-z.]*' tunnel.log 2>/dev/null | head -1)
    [ -n "$TUNNEL_URL" ] && break
  done
  if [ -z "$TUNNEL_URL" ]; then
    echo "   ⚠ Tunnel timeout, skipping (server still works via IP)"
  fi
else
  echo "⏭  Tunnel disabled (ENABLE_TUNNEL=false)"
fi

# 9. Show status
echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║              ✅ Deploy Complete!               ║"
echo "  ╠═══════════════════════════════════════════════╣"
printf "  ║  Local:   http://localhost:%-19s ║\n" "$PORT"
if [ -n "$LAN_IP" ]; then
  printf "  ║  LAN:     http://%-28s ║\n" "${LAN_IP}:${PORT}"
fi
if [ -n "$PUBLIC_IP" ]; then
  printf "  ║  Public:  http://%-28s ║\n" "${PUBLIC_IP}:${PORT}"
fi
if [ -n "$TUNNEL_URL" ]; then
  printf "  ║  Tunnel:  %-34s ║\n" "$TUNNEL_URL"
fi
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
echo "    pm2 stop            # 停止服务"
echo "    bash stop.sh        # 停止所有（含隧道）"
echo ""
