#!/bin/sh

# ================= 🔧 构建自定义配置区 =================
WAN_IFACE=""
ENABLE_PPPOE=0
PPPOE_USER="<PLACEHOLDER_USER>"
PPPOE_PASS="<PLACEHOLDER_PASS>"
LAN_IP="192.168.100.1"
LAN_NETMASK="255.255.255.0"
ENABLE_DHCP_SERVER=0

# ================= 🚀 初始化执行逻辑 =================
# 1. 基础防火墙配置
uci set firewall.@zone[1].input='ACCEPT'
uci commit firewall

# 2. 网卡探测
interfaces=$(ls /sys/class/net | grep -E '^(eth|en)' | sort)
valid_ifaces=""
count=0
for iface in $interfaces; do
    if [ -e "/sys/class/net/$iface/device" ]; then
        count=$((count + 1))
        valid_ifaces="$valid_ifaces $iface"
    fi
done
valid_ifaces=$(echo "$valid_ifaces" | sed 's/^ //')

# 3. 模式分支
if [ "$count" -eq 1 ]; then
    uci delete network.wan 2>/dev/null
    uci delete network.wan6 2>/dev/null
    uci set network.lan.proto='dhcp'
    uci set dhcp.lan.ignore='1'
    
elif [ "$count" -gt 1 ]; then
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$LAN_IP"
    uci set network.lan.netmask="$LAN_NETMASK"
    
    if [ -n "$WAN_IFACE" ]; then
        wan_iface="$WAN_IFACE"
    else
        wan_iface=$(echo "$valid_ifaces" | awk '{print $1}')
    fi
    
    uci delete network.wan6 2>/dev/null
    uci set network.wan=interface
    uci set network.wan.device="$wan_iface"
    
    if [ "$ENABLE_PPPOE" -eq 1 ]; then
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$PPPOE_USER"
        uci set network.wan.password="$PPPOE_PASS"
        uci set network.wan.peerdns='1'
        uci set network.wan.defaultroute='1'
    else
        uci set network.wan.proto='dhcp'
    fi
    
    lan_ifaces=""
    for iface in $valid_ifaces; do
        if [ "$iface" != "$wan_iface" ]; then
            lan_ifaces="$lan_ifaces $iface"
        fi
    done
    lan_ifaces=$(echo "$lan_ifaces" | sed 's/^ //')
    
    uci delete network.lan.ifname 2>/dev/null
    for iface in $lan_ifaces; do
        uci add_list network.lan.ifname="$iface"
    done
    
    if [ "$ENABLE_DHCP_SERVER" -eq 1 ]; then
        uci set dhcp.lan.ignore='0'
    else
        uci set dhcp.lan.ignore='1'
    fi
fi

# 提交所有更改
uci commit network
uci commit dhcp

# 4. [关键] 自毁逻辑，防止重启后重复执行覆盖配置
rm -f /etc/uci-defaults/99-network-init

exit 0
