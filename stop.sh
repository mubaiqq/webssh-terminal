#!/bin/bash
echo "Stopping WebSSH..."
pkill -f "node.*server.js" 2>/dev/null && echo "  ✓ Server stopped" || echo "  - Server not running"
pkill -f "ssh.*serveo.net" 2>/dev/null && echo "  ✓ Tunnel stopped" || echo "  - Tunnel not running"
fuser -k 9111/tcp 2>/dev/null || true
echo "Done."
