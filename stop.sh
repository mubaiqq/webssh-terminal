#!/bin/bash
echo "Stopping WebSSH..."
# 停止 pm2 进程
pm2 stop webssh-terminal 2>/dev/null && echo "  ✓ Server stopped (pm2)" || echo "  - Server not running"
# 停止隧道
pkill -f "ssh.*serveo.net" 2>/dev/null && echo "  ✓ Tunnel stopped" || echo "  - Tunnel not running"
fuser -k 9111/tcp 2>/dev/null || true
echo "Done."
