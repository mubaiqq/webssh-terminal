#!/bin/bash
# WebSSH Uninstall
set -e
INSTALL_DIR="$HOME/webssh-terminal"
APP_NAME="webssh-terminal"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   🗑️  WebSSH Terminal Remove   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# 1. Stop and delete pm2 process
echo "🛑 Stopping services..."
pm2 stop "$APP_NAME" 2>/dev/null && echo "   ✓ Server stopped" || echo "   - Server not running"
pm2 delete "$APP_NAME" 2>/dev/null && echo "   ✓ Process removed" || echo "   - Process not found"
pm2 save 2>&1 | tail -1

# 2. Stop tunnel
pkill -f "ssh.*serveo.net" 2>/dev/null && echo "   ✓ Tunnel stopped" || echo "   - Tunnel not running"
fuser -k 9111/tcp 2>/dev/null || true

# 3. Remove pm2 startup (开机自启)
echo "⚡ Removing auto-start..."
pm2 unstartup systemd 2>/dev/null && echo "   ✓ Auto-start removed" || echo "   - No auto-start found"

# 4. Remove files
echo "🗑️  Removing files..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/server.js" ]; then
  echo "   ⚠️  You are in the project directory: $SCRIPT_DIR"
  echo "   Run: rm -rf $SCRIPT_DIR"
else
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "   ✓ Removed $INSTALL_DIR"
  else
    echo "   - Directory not found: $INSTALL_DIR"
  fi
fi

echo ""
echo "  ✅ Uninstall complete!"
echo ""
