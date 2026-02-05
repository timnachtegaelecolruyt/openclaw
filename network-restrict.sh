#!/bin/sh
set -e

echo "Setting up network restrictions..."

# Check if we're root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must run as root to configure iptables"
    echo "Skipping network restrictions"
    exec "$@"
fi

# Apply iptables rules to block home network
if command -v iptables >/dev/null 2>&1; then
    # Allow localhost
    iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
    
    # Allow OpenClaw network
    iptables -A OUTPUT -d 172.25.0.0/16 -j ACCEPT
    iptables -A OUTPUT -d 172.18.0.0/16 -j ACCEPT  # Default network too
    
    # Allow Ollama
    iptables -A OUTPUT -d 172.29.208.1 -j ACCEPT
    
    # Dynamically allow Docker's DNS server (read from /etc/resolv.conf)
    DOCKER_DNS=$(grep "ExtServers" /etc/resolv.conf | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    if [ -n "$DOCKER_DNS" ]; then
        echo "  Allowing Docker DNS: $DOCKER_DNS"
        iptables -A OUTPUT -d $DOCKER_DNS -j ACCEPT
    fi
    
    # Block OTHER home network devices (but allow DNS above)
    iptables -A OUTPUT -d 10.0.0.0/8 -j REJECT
    iptables -A OUTPUT -d 172.16.0.0/12 -j REJECT  
    iptables -A OUTPUT -d 192.168.0.0/16 -j REJECT
    iptables -A OUTPUT -d 169.254.0.0/16 -j REJECT
    
    # Allow everything else (internet, DNS, Discord, etc.)
    iptables -A OUTPUT -j ACCEPT
    
    echo "Home network blocking applied"
fi

# Drop to node user and exec
exec setpriv --reuid=1000 --regid=1000 --clear-groups -- "$@"
