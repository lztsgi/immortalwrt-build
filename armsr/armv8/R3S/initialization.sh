#!/bin/sh

# =========================================================
# R3S 首次启动初始化脚本
# 用途：
# 1. 按网卡数量自动决定单口/多口模式
# 2. 多口模式下自动挑选 WAN 口，其余口并入 LAN
# 3. 支持可选 PPPoE / DHCP Server
# 4. 首次执行后自毁，避免后续普通重启重复覆盖配置
#
# 说明：
# - 本脚本放在 /etc/uci-defaults/ 下运行，适合首次启动初始化
# - 已按 OpenWrt / ImmortalWrt 24.10 的 device / bridge 写法调整
# - 尽量保持你原有逻辑不变，只修正 24.10 下 LAN 口桥接配置方式
# =========================================================


# ================= 🔧 构建自定义配置区 =================

# 手动指定 WAN 网口。
# 留空时自动取检测到的第一个物理网口作为 WAN。
WAN_IFACE=""

# 是否启用 PPPoE：
# 0 = WAN 走 DHCP
# 1 = WAN 走 PPPoE
ENABLE_PPPOE=0

# PPPoE 账号密码（仅在 ENABLE_PPPOE=1 时使用）
PPPOE_USER="<PLACEHOLDER_USER>"
PPPOE_PASS="<PLACEHOLDER_PASS>"

# 多口模式下 LAN 默认静态地址
LAN_IP="192.168.100.2"
LAN_NETMASK="255.255.255.0"

# 是否启用 LAN DHCP Server：
# 0 = 关闭
# 1 = 开启
ENABLE_DHCP_SERVER=0


# ================= 🧰 辅助函数 =================

# 按 device.name 查找 network 配置里对应的 device section。
# 目的：
# - 24.10 下 br-lan 的成员口写在 config device 里
# - 这里先找已有的 br-lan 设备段，找到就复用，找不到再创建
find_device_section_by_name() {
    target_name="$1"

    for sec in $(uci -q show network | sed -n "s/^network\.\([^.]*\)=device$/\1/p"); do
        current_name="$(uci -q get "network.${sec}.name")"
        [ "$current_name" = "$target_name" ] && {
            echo "$sec"
            return 0
        }
    done

    return 1
}


# ================= 🚀 初始化执行逻辑 =================

# ---------------------------------------------------------
# 1. 基础防火墙配置
# ---------------------------------------------------------
# 保持你原有逻辑：
# 直接把默认防火墙中的 @zone[1] 的 input 改成 ACCEPT。
#
# 注意：
# OpenWrt 默认配置顺序通常是：
# - @zone[0] = lan
# - @zone[1] = wan
# 所以这里默认等价于“放开 wan zone 的 input”。
#
# 如果你以后手动改过 /etc/config/firewall 的 zone 顺序，
# 这里就要跟着改，避免改错分区。
uci set firewall.@zone[1].input='ACCEPT'
uci commit firewall


# ---------------------------------------------------------
# 2. 网卡探测
# ---------------------------------------------------------
# 仅统计真实物理网口（eth* / en* 且存在 device 节点）
interfaces=$(ls /sys/class/net | grep -E '^(eth|en)' | sort)
valid_ifaces=""
count=0

for iface in $interfaces; do
    if [ -e "/sys/class/net/$iface/device" ]; then
        count=$((count + 1))
        valid_ifaces="$valid_ifaces $iface"
    fi
done

# 去掉前导空格
valid_ifaces=$(echo "$valid_ifaces" | sed 's/^ //')


# ---------------------------------------------------------
# 3. 模式分支
# ---------------------------------------------------------

# =========================
# 单网口模式
# =========================
# 原逻辑保持不变：
# - 删除 wan / wan6
# - 把 lan 改成 DHCP 客户端
# - 关闭 LAN DHCP Server
#
# 说明：
# 这里不强行改 LAN 的 bridge/device 结构，
# 尽量保持和你原脚本行为一致，只处理协议与 DHCP 状态。
if [ "$count" -eq 1 ]; then
    uci delete network.wan 2>/dev/null
    uci delete network.wan6 2>/dev/null

    uci set network.lan.proto='dhcp'
    uci set dhcp.lan.ignore='1'


# =========================
# 多网口模式
# =========================
# 核心逻辑：
# - LAN 使用静态地址
# - 选一个物理口作为 WAN
# - 其余物理口全部并入 br-lan
# - 按你的开关决定 WAN 是 PPPoE 还是 DHCP
# - 按你的开关决定 LAN DHCP Server 是否启用
elif [ "$count" -gt 1 ]; then
    # ---------- 3.1 LAN 基础地址 ----------
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$LAN_IP"
    uci set network.lan.netmask="$LAN_NETMASK"

    # ---------- 3.2 确定 WAN 口 ----------
    # 优先使用手动指定的 WAN_IFACE；
    # 如果未指定，则默认取检测到的第一个物理网口作为 WAN。
    if [ -n "$WAN_IFACE" ]; then
        wan_iface="$WAN_IFACE"
    else
        wan_iface=$(echo "$valid_ifaces" | awk '{print $1}')
    fi

    # ---------- 3.3 配置 WAN 接口 ----------
    uci delete network.wan6 2>/dev/null

    # 重新声明/覆盖 wan interface
    uci set network.wan=interface

    # 使用 24.10 常见写法：WAN 直接绑定 device
    uci delete network.wan.ifname 2>/dev/null
    uci delete network.wan.type 2>/dev/null
    uci set network.wan.device="$wan_iface"

    if [ "$ENABLE_PPPOE" -eq 1 ]; then
        # WAN 走 PPPoE
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$PPPOE_USER"
        uci set network.wan.password="$PPPOE_PASS"
        uci set network.wan.peerdns='1'
        uci set network.wan.defaultroute='1'
    else
        # WAN 走 DHCP
        uci set network.wan.proto='dhcp'
    fi

    # ---------- 3.4 计算 LAN 物理口 ----------
    # 除 WAN 口外，其余物理口全部加入 LAN
    lan_ifaces=""
    for iface in $valid_ifaces; do
        if [ "$iface" != "$wan_iface" ]; then
            lan_ifaces="$lan_ifaces $iface"
        fi
    done
    lan_ifaces=$(echo "$lan_ifaces" | sed 's/^ //')

    # ---------- 3.5 按 24.10 方式维护 br-lan ----------
    # OpenWrt / ImmortalWrt 24.10 下，LAN 桥成员口应写在：
    #   config device
    #       option name 'br-lan'
    #       option type 'bridge'
    #       list ports 'xxx'
    #
    # 因此这里不再使用旧式的 network.lan.ifname 写法，
    # 改为直接维护 br-lan 对应的 device section。

    brlan_section="$(find_device_section_by_name "br-lan")"

    # 找不到已有 br-lan 设备段时，创建一个具名 device section
    if [ -z "$brlan_section" ]; then
        brlan_section="r3s_brlan"
        uci set "network.${brlan_section}=device"
    fi

    # 明确声明 br-lan 是 bridge 设备
    uci set "network.${brlan_section}.name=br-lan"
    uci set "network.${brlan_section}.type=bridge"

    # 清空旧的 ports 列表，再重建
    uci delete "network.${brlan_section}.ports" 2>/dev/null
    for iface in $lan_ifaces; do
        uci add_list "network.${brlan_section}.ports=$iface"
    done

    # ---------- 3.6 LAN 接口绑定到 br-lan ----------
    # 清理旧式字段，避免和新写法混用
    uci delete network.lan.ifname 2>/dev/null
    uci delete network.lan.type 2>/dev/null

    # LAN interface 指向 br-lan
    uci set network.lan.device='br-lan'

    # ---------- 3.7 DHCP Server 开关 ----------
    if [ "$ENABLE_DHCP_SERVER" -eq 1 ]; then
        uci set dhcp.lan.ignore='0'
    else
        uci set dhcp.lan.ignore='1'
    fi
fi


# ---------------------------------------------------------
# 4. 提交配置
# ---------------------------------------------------------
uci commit network
uci commit dhcp


# ---------------------------------------------------------
# 5. Cron 日志静音
# ---------------------------------------------------------
# 将 Cron 日志级别调低，屏蔽常规 started 提示
uci set system.@system[0].cronloglevel='9'
uci commit system


# ---------------------------------------------------------
# 6. 自毁逻辑
# ---------------------------------------------------------
# 首次启动执行完成后删除自己，避免普通重启时再次覆盖配置。
# 但“恢复出厂 / 重新刷同一固件”后，该脚本仍会重新出现并再执行一次。
rm -f /etc/uci-defaults/99-network-init

exit 0
