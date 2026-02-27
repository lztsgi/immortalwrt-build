#!/bin/sh

# =============================================================
# 🔧 第一部分：基础网络环境变量 (根据您的需求配置)
# =============================================================

# [WAN口指定] 留空则脚本会自动探测第一个可用网卡作为 WAN
WAN_IFACE=""

# [拨号模式开关] 1 为开启 PPPoE 拨号，0 为使用 DHCP 自动获取
ENABLE_PPPOE=0
PPPOE_USER="<PLACEHOLDER_USER>"
PPPOE_PASS="<PLACEHOLDER_PASS>"

# [LAN口地址] 修改为您偏好的后台登录 IP
LAN_IP="192.168.100.2"
LAN_NETMASK="255.255.255.0"

# [DHCP服务器] 1 为开启 (作为主路由)，0 为关闭 (作为旁路网关)
ENABLE_DHCP_SERVER=0

# =============================================================
# 💾 第二部分：磁盘扩容环境变量 (R3S eMMC/SD卡 专用)
# =============================================================

# [扩容大小] 留空="" 使用剩余空间；指定大小如 "+2G" (必须带加号和单位)
NEW_PART_SIZE="+2G"

# [目标磁盘] R3S 的板载存储或 SD 卡通常识别为 mmcblk0
TARGET_DISK="/dev/mmcblk0"
# [目标分区] ImmortalWrt 官方镜像通常有 p1(引导) p2(系统)，p3 为扩容目标
TARGET_PART="${TARGET_DISK}p3"

# =============================================================
# 🚀 第三部分：执行逻辑 (请勿随意修改此段以下代码)
# =============================================================

echo ">> 正在初始化 R3S 硬件网络环境..."

# 1. 基础防火墙安全设置 (允许入站)
uci set firewall.@zone[1].input='ACCEPT'
uci commit firewall

# 2. 网卡物理设备探测 (兼容 R3S 的 RTL8153 USB 网口)
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

# 3. 模式判断与配置应用
if [ "$count" -eq 1 ]; then
    # --- 单网卡模式 (做旁路由/AP) ---
    uci delete network.wan 2>/dev/null
    uci delete network.wan6 2>/dev/null
    uci set network.lan.proto='dhcp'
    uci set dhcp.lan.ignore='1'
    
elif [ "$count" -gt 1 ]; then
    # --- 多网卡模式 (主路由) ---
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$LAN_IP"
    uci set network.lan.netmask="$LAN_NETMASK"
    
    # 确定 WAN 网卡
    if [ -n "$WAN_IFACE" ]; then
        wan_iface="$WAN_IFACE"
    else
        wan_iface=$(echo "$valid_ifaces" | awk '{print $1}')
    fi
    
    uci delete network.wan6 2>/dev/null
    uci set network.wan=interface
    uci set network.wan.device="$wan_iface"
    
    # 拨号协议配置
    if [ "$ENABLE_PPPOE" -eq 1 ]; then
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$PPPOE_USER"
        uci set network.wan.password="$PPPOE_PASS"
        uci set network.wan.peerdns='1'
        uci set network.wan.defaultroute='1'
    else
        uci set network.wan.proto='dhcp'
    fi
    
    # 将除 WAN 以外的所有网卡桥接到 LAN
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
    
    # DHCP 服务控制
    if [ "$ENABLE_DHCP_SERVER" -eq 1 ]; then
        uci set dhcp.lan.ignore='0'
    else
        uci set dhcp.lan.ignore='1'
    fi
fi

# 提交配置，确保迁移后生效
uci commit network
uci commit dhcp

# =============================================================
# 📦 第四部分：自动扩容 Overlay 逻辑 (核心)
# =============================================================

echo ">> 检查分区扩容状态..."

# 1. 检查 P3 分区是否已存在
if [ -e "$TARGET_PART" ]; then
    echo "⚠️ 扩容分区已存在，跳过。清理初始化任务..."
    # 这里的删除操作是防止脚本在后续意外触发
    rm -f /etc/uci-defaults/99-r3s-init
    exit 0
fi

echo ">> 正在磁盘 $TARGET_DISK 上创建 P3 分区..."
# 自动化 fdisk 指令流
printf "n\np\n3\n\n${NEW_PART_SIZE}\nw\n" | fdisk "$TARGET_DISK"

# 通知内核刷新分区表
partprobe "$TARGET_DISK" 2>/dev/null || true
sleep 2

# 再次验证分区节点是否生成
if [ ! -e "$TARGET_PART" ]; then
    echo "❌ 错误：分区节点生成失败，请检查 .config 是否包含 fdisk！"
    rm -f /etc/uci-defaults/99-r3s-init
    exit 1
fi

# 格式化并迁移数据
echo ">> 正在迁移 Overlay 数据到新分区..."
mkfs.ext4 -F "$TARGET_PART"
mkdir -p /tmp/new_overlay
mount "$TARGET_PART" /tmp/new_overlay
cp -a -f /overlay/. /tmp/new_overlay/
sync

# 抓取 UUID 并配置自动挂载
UUID=$(block info "$TARGET_PART" | grep -o -e 'UUID="[^"]*"' | cut -d'"' -f2)

if [ -z "$UUID" ]; then
    echo "❌ 无法获取分区 UUID"
    umount /tmp/new_overlay
    rm -f /etc/uci-defaults/99-r3s-init
    exit 1
fi

# 写入 fstab 挂载配置
uci -q delete fstab.overlay
uci commit fstab
uci -q batch << EOU
add fstab mount
set fstab.@mount[-1].target='/overlay'
set fstab.@mount[-1].uuid='$UUID'
set fstab.@mount[-1].fstype='ext4'
set fstab.@mount[-1].enabled='1'
commit fstab
EOU

# =============================================================
# 🏁 第五部分：收尾与重启
# =============================================================

umount /tmp/new_overlay
echo "✅ 全部设置已完成！自毁初始化任务并重启..."

# 关键：自毁脚本防止下次开机重复执行
rm -f /etc/uci-defaults/99-r3s-init

# 延迟 3 秒重启，确保系统有时间处理 exit 0
( sleep 3 ; reboot ) &

exit 0
