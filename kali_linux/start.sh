#!/bin/bash
set -e

export HOME=/root
export USER=root

# Start SSH server
/usr/sbin/sshd &

# Ensure VNC password exists
if [ ! -f /root/.vnc/passwd ]; then
    echo "123456789" | vncpasswd -f > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd
fi

# Prepare xstartup
cat > /root/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
startxfce4 &
EOF
chmod +x /root/.vnc/xstartup

# Clean up old VNC lock files and sockets
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Kill any existing VNC session
vncserver -kill :1 > /dev/null 2>&1 || true

# Start VNC server
vncserver -geometry 1920x1080 -depth 24 -localhost no :1

# Wait until VNC is listening on port 5901
if ! command -v ss >/dev/null 2>&1; then
    echo "Error: 'ss' command not found. Please ensure iproute2 is installed in your Docker image." >&2
    echo "Attempting to use netstat as a fallback..."
    if ! command -v netstat >/dev/null 2>&1; then
        echo "Error: Neither 'ss' nor 'netstat' command found. Please install iproute2 or net-tools in your Docker image." >&2
        exit 1
    fi
    echo "Waiting for VNC server to start (using netstat)..."
    while ! netstat -an | grep -q ":5901"; do sleep 1; done
else
    echo "Waiting for VNC server to start..."
    while ! ss -tuln | grep -q ":5901"; do sleep 1; done
fi
echo "VNC server started."

# Start noVNC proxy
/usr/share/novnc/utils/novnc_proxy --listen 8080 --vnc localhost:5901 --ssl-only=no &

# Keep container running
tail -F /root/.vnc/*.log