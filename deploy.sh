#!/bin/bash
# WebSSH One-Click Deploy / Update
set -e
PORT=9111
REPO="https://github.com/mubaiqq/webssh-terminal.git"
INSTALL_DIR="$HOME/webssh-terminal"
APP_NAME="webssh-terminal"

# ── 国内加速配置 ──
NPM_REGISTRY="https://registry.npmmirror.com"
GH_PROXY="https://ghfast.top"
ENABLE_TUNNEL="${ENABLE_TUNNEL:-true}"
BASE_PATH="${BASE_PATH:-}"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   ⚡ WebSSH Terminal Deploy   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# ── 1. 获取代码 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IS_UPDATE=false

if [ -f "$SCRIPT_DIR/server.js" ]; then
  DIR="$SCRIPT_DIR"
  echo "📂 Using local directory: $DIR"
else
  if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/server.js" ]; then
    IS_UPDATE=true
    echo "🔄 Updating existing installation..."
    cd "$INSTALL_DIR"
    BEFORE_HASH=$(md5sum package.json 2>/dev/null | cut -d' ' -f1)
    git pull 2>&1 | tail -3
    AFTER_HASH=$(md5sum package.json 2>/dev/null | cut -d' ' -f1)
    echo "   ✓ Code updated"
  else
    echo "📥 First install, cloning..."
    CLONE_URL="${GH_PROXY}/${REPO}"
    echo "   Trying proxy: $CLONE_URL"
    if ! git clone "$CLONE_URL" "$INSTALL_DIR" 2>&1 | tail -3; then
      echo "   ⚠ Proxy failed, falling back to direct clone..."
      git clone "$REPO" "$INSTALL_DIR" 2>&1 | tail -3
    fi
    cd "$INSTALL_DIR"
    BEFORE_HASH=""
    AFTER_HASH=""
  fi
  DIR="$INSTALL_DIR"
fi

cd "$DIR"

# ── 2. 检查 Node.js ──
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install: https://nodejs.org"
  exit 1
fi
echo "   ✓ Node.js $(node -v)"

# ── 3. 安装依赖 ──
NEED_INSTALL=false
if [ ! -d "node_modules" ]; then
  NEED_INSTALL=true
  echo "📦 Installing dependencies..."
elif [ "$IS_UPDATE" = true ] && [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
  NEED_INSTALL=true
  echo "📦 package.json changed, updating dependencies..."
else
  echo "📦 Dependencies OK"
fi

if [ "$NEED_INSTALL" = true ]; then
  npm install --production --registry="$NPM_REGISTRY" 2>&1 | tail -3
  echo "   ✓ Dependencies installed"
fi

# ── 4. 安装 pm2 ──
if ! command -v pm2 &>/dev/null; then
  echo "🔧 Installing pm2..."
  npm install -g pm2 --registry="$NPM_REGISTRY" 2>&1 | tail -3
fi

# ── 5. 启动/重启服务 ──
if pm2 describe "$APP_NAME" &>/dev/null; then
  # 已存在 → 平滑重载（零停机）
  echo "♻️  Reloading $APP_NAME (zero-downtime)..."
  pm2 reload "$APP_NAME" --update-env 2>&1 | tail -5
  ACTION="reloaded"
else
  # 首次启动
  echo "🚀 Starting $APP_NAME..."
  # 确保端口没被占用
  if fuser $PORT/tcp &>/dev/null; then
    echo "   ⚠ Port $PORT in use, freeing..."
    fuser -k $PORT/tcp 2>/dev/null || true
    sleep 1
  fi
  pm2 start server.js --name "$APP_NAME" \
    --max-memory-restart 300M \
    --exp-backoff-restart-delay=100 \
    --time \
    --env BASE_PATH="$BASE_PATH" \
    2>&1 | tail -5
  ACTION="started"
fi

pm2 save 2>&1 | tail -1

# ── 6. 开机自启 ──
if [ "$IS_UPDATE" = false ]; then
  echo "⚡ Configuring auto-start on boot..."
  PM2_STARTUP=$(pm2 startup 2>&1)
  if echo "$PM2_STARTUP" | grep -q "sudo"; then
    STARTUP_CMD=$(echo "$PM2_STARTUP" | grep "sudo" | head -1)
    echo "   Running: $STARTUP_CMD"
    eval "$STARTUP_CMD" 2>&1 | tail -2
  fi
  pm2 save 2>&1 | tail -1
  echo "   ✓ Auto-start configured"
fi

# ── 7. 网络探测 ──
if [ "$IS_UPDATE" = false ]; then
  echo "🌐 Detecting network..."
  PUBLIC_IP=""
  for svc in "myip.ipip.net" "ip.sb" "ifconfig.me" "ipinfo.io/ip" "icanhazip.com"; do
    PUBLIC_IP=$(curl -s --connect-timeout 2 "https://$svc" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
    [ -n "$PUBLIC_IP" ] && break
  done
  LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

  # 隧道
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
fi

# ── 8. 显示结果 ──
echo ""
if [ "$ACTION" = "reloaded" ]; then
  echo "  ╔═══════════════════════════════════════════════╗"
  echo "  ║              ✅ Update Complete!               ║"
  echo "  ╠═══════════════════════════════════════════════╣"
  printf "  ║  Local:   http://localhost:%-19s ║\n" "$PORT"
  echo "  ╠═══════════════════════════════════════════════╣"
  echo "  ║  数据已保留 | 服务已平滑重载                    ║"
  echo "  ╚═══════════════════════════════════════════════╝"
else
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
fi
echo ""
echo "  常用命令："
echo "    pm2 status          # 查看状态"
echo "    pm2 logs            # 查看日志"
echo "    pm2 restart         # 重启服务"
echo "    bash deploy.sh      # 更新到最新版"
echo ""
