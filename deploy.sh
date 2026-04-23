#!/bin/bash
# WebSSH One-Click Deploy
set -e
PORT=9111
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   ⚡ WebSSH Terminal Deploy   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# 1. Install deps
echo "📦 Installing dependencies..."
if [ ! -d "node_modules" ]; then
  npm install --production 2>&1 | tail -3
else
  echo "   ✓ node_modules exists"
fi

# 2. Kill existing
echo "🧹 Cleaning port $PORT..."
fuser -k $PORT/tcp 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "ssh.*serveo.net" 2>/dev/null || true
sleep 1

# 3. Start server
echo "🚀 Starting server on port $PORT..."
nohup node server.js > server.log 2>&1 &
SERVER_PID=$!
sleep 2

if ! kill -0 $SERVER_PID 2>/dev/null; then
  echo "❌ Server failed. Check: cat server.log"
  exit 1
fi
echo "   ✓ Server running (PID: $SERVER_PID)"

# 4. Create tunnel
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
echo "  ╚═══════════════════════════════════════╝"
echo ""
echo "  Server PID: $SERVER_PID | Tunnel PID: $TUNNEL_PID"
echo "  Logs: tail -f server.log / tunnel.log"
echo "  Stop: bash stop.sh"
echo ""
