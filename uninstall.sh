#!/bin/bash
# WebSSH Uninstall
set -e
INSTALL_DIR="$HOME/webssh-terminal"

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   🗑️  WebSSH Terminal Remove   ║"
echo "  ╚══════════════════════════════╝"
echo ""

# 1. Stop services
echo "🛑 Stopping services..."
pkill -f "node.*server.js" 2>/dev/null && echo "   ✓ Server stopped" || echo "   - Server not running"
pkill -f "ssh.*serveo.net" 2>/dev/null && echo "   ✓ Tunnel stopped" || echo "   - Tunnel not running"
fuser -k 9111/tcp 2>/dev/null || true

# 2. Remove files
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
