#!/bin/bash
# WebSSH One-Click Deploy (from GitHub or local)
set -e
PORT=9111
REPO="https://github.com/mubaiqq/webssh-terminal.git"
INSTALL_DIR="$HOME/webssh-terminal"

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
    git clone "$REPO" "$INSTALL_DIR" 2>&1 | tail -3
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

# 2. Install deps
echo "📦 Installing dependencies..."
if [ ! -d "node_modules" ]; then
  npm install --production 2>&1 | tail -3
else
  echo "   ✓ node_modules exists"
fi

# 3. Kill existing
echo "🧹 Cleaning port $PORT..."
fuser -k $PORT/tcp 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "ssh.*serveo.net" 2>/dev/null || true
sleep 1

# 4. Start server
echo "🚀 Starting server on port $PORT..."
nohup node server.js > server.log 2>&1 &
SERVER_PID=$!
sleep 2

if ! kill -0 $SERVER_PID 2>/dev/null; then
  echo "❌ Server failed. Check: cat $DIR/server.log"
  exit 1
fi
echo "   ✓ Server running (PID: $SERVER_PID)"

# 5. Create tunnel
echo "🌐 Creating tunnel via serveo.net..."
nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -R 80:localhost:$PORT serveo.net > tunnel.log 2>&1 &
TUNNEL_PID=$!

# Wait for tunnel URL
TUNNEL_URL=""
for i in $(seq 1 15); do
  sleep 2
  TUNNEL_URL=$(grep -oP 'https?://[a-zA-Z0-9.-]+\.serveo[a-z.]*' tunnel.log 2>/dev/null | head -1)
  [ -n "$TUNNEL_URL" ] && break
done

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║         ✅ Deploy Complete!            ║"
echo "  ╠═══════════════════════════════════════╣"
printf "  ║  Local:  http://localhost:%-13s ║\n" "$PORT"
if [ -n "$TUNNEL_URL" ]; then
  printf "  ║  Tunnel: %-28s ║\n" "$TUNNEL_URL"
else
  echo "  ║  Tunnel: (check tunnel.log)           ║"
fi
echo "  ╠═══════════════════════════════════════╣"
echo "  ║  Default password: 123456             ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""
echo "  Server PID: $SERVER_PID | Tunnel PID: $TUNNEL_PID"
echo "  Logs: tail -f $DIR/server.log"
echo "  Stop: bash stop.sh"
echo ""
