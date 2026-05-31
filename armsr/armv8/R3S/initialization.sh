#!/bin/sh

# =========================================================
# R3S first boot initialization
# - Fixed two-port layout: eth0 = WAN, eth1 = LAN
# - Optional WAN PPPoE
# - Optional LAN DHCP server
# - BBR enabled by default when kmod-tcp-bbr is built in
# =========================================================


# ================= Custom settings =================

WAN_IFACE="eth0"
LAN_IFACE="eth1"

# 0 = WAN DHCP
# 1 = WAN PPPoE
ENABLE_PPPOE=0

# Used only when ENABLE_PPPOE=1
PPPOE_USER="<PLACEHOLDER_USER>"
PPPOE_PASS="<PLACEHOLDER_PASS>"

LAN_IP="192.168.100.2"
LAN_NETMASK="255.255.255.0"

# 0 = disable LAN DHCP server
# 1 = enable LAN DHCP server
ENABLE_DHCP_SERVER=0


# ================= Firewall =================

uci set firewall.@zone[1].input='ACCEPT'
uci commit firewall


# ================= Network =================

# Remove stale bridge devices from older configs/images.
for sec in $(uci -q show network | sed -n "s/^network\.\([^.]*\)=device$/\1/p"); do
    [ "$(uci -q get "network.${sec}.name")" = "br-lan" ] && uci delete "network.${sec}"
done

uci delete network.wan6 2>/dev/null

uci set network.wan=interface
uci delete network.wan.ifname 2>/dev/null
uci delete network.wan.type 2>/dev/null
uci delete network.wan.macaddr 2>/dev/null
uci set network.wan.device="$WAN_IFACE"

if [ "$ENABLE_PPPOE" -eq 1 ]; then
    uci set network.wan.proto='pppoe'
    uci set network.wan.username="$PPPOE_USER"
    uci set network.wan.password="$PPPOE_PASS"
    uci set network.wan.peerdns='1'
    uci set network.wan.defaultroute='1'
else
    uci set network.wan.proto='dhcp'
    uci delete network.wan.username 2>/dev/null
    uci delete network.wan.password 2>/dev/null
fi

uci set network.lan=interface
uci delete network.lan.ifname 2>/dev/null
uci delete network.lan.type 2>/dev/null
uci delete network.lan.macaddr 2>/dev/null
uci set network.lan.device="$LAN_IFACE"
uci set network.lan.proto='static'
uci set network.lan.ipaddr="$LAN_IP"
uci set network.lan.netmask="$LAN_NETMASK"

if [ "$ENABLE_DHCP_SERVER" -eq 1 ]; then
    uci set dhcp.lan.ignore='0'
else
    uci set dhcp.lan.ignore='1'
fi

uci commit network
uci commit dhcp


# ================= System tweaks =================

uci set system.@system[0].cronloglevel='9'
uci commit system

grep -q '^tcp_bbr$' /etc/modules.d/99-bbr 2>/dev/null || echo 'tcp_bbr' > /etc/modules.d/99-bbr
grep -q '^net.core.default_qdisc=' /etc/sysctl.conf 2>/dev/null || echo 'net.core.default_qdisc=fq_codel' >> /etc/sysctl.conf
grep -q '^net.ipv4.tcp_congestion_control=' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1 || true


# ================= Self cleanup =================

rm -f /etc/uci-defaults/99-network-init

exit 0
