#!/bin/bash

echo "========================= begin $0 ==========================="

# 载入打包时由外层脚本生成的环境变量
# make.env 里会包含 KERNEL_VERSION / WHOAMI / OPENWRT_VER / 各种 flow offload 参数
source make.env

# 载入打包公共函数
source public_funcs

# 初始化工作目录、挂载点、临时文件等
init_work_env


# =========================
# 目标设备基础信息
# =========================

# 盒子平台类型
PLATFORM=amlogic

# SoC 型号：Phicomm N1 为 s905d
SOC=s905d

# 板型标识
BOARD=n1


# =========================
# Wi-Fi 相关
# =========================

# 原脚本注释含义：
# 5.10(及以上)内核是否启用 Wi-Fi
# 1 = 启用
# 0 = 禁用
#
# 注意：这里当前值是 0，也就是“禁用”
# 这是原脚本既有逻辑，这里不改行为，只保留并明确说明
ENABLE_WIFI_K510=0


# 预留的附加版本后缀参数
# 例如外部调用脚本时传入某个子版本标记
SUBVER=$1


# =========================
# 内核相关文件
# =========================

# 历史字段：内核标签
# 这里保留原值，不改逻辑
# 当前实际使用哪个内核仓库、哪个内核版本，
# 主要由外层 openwrt_flippy.sh 根据 KERNEL_REPO_URL / KERNEL_VERSION_NAME / KERNEL_AUTO_LATEST 决定
KERNEL_TAGS="stable"

# 主线内核适用范围说明
KERNEL_BRANCHES="mainline:all:>=:5.4"

# 模块包
MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
check_file ${MODULES_TGZ}

# 启动内核包
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
check_file ${BOOT_TGZ}

# DTB 设备树包
DTBS_TGZ=${KERNEL_PKG_HOME}/dtb-amlogic-${KERNEL_VERSION}.tar.gz
check_file ${DTBS_TGZ}

# 从 boot 包中识别当前是否属于 K5.10+ 类别
K510=$(get_k510_from_boot_tgz "${BOOT_TGZ}" "vmlinuz-${KERNEL_VERSION}")
export K510


# =========================
# OpenWrt rootfs 源文件
# =========================

# 自动查找当前目录下的 OpenWrt rootfs 压缩包
OPWRT_ROOTFS_GZ=$(get_openwrt_rootfs_archive ${PWD})
check_file ${OPWRT_ROOTFS_GZ}
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"


# =========================
# 输出镜像文件名
# =========================

# 最终生成的镜像文件名
# 其中会包含：
# - SoC
# - 板型
# - OpenWrt 版本
# - 内核版本
# - 可选附加后缀
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"


# =========================
# 补丁、脚本、附加文件路径
# =========================

KMOD="${PWD}/files/kmod"
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"
MAC_SCRIPT2="${PWD}/files/find_macaddr.pl"
MAC_SCRIPT3="${PWD}/files/inc_macaddr.pl"
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"
INDEX_PATCH_HOME="${PWD}/files/index.html.patches"
GETCPU_SCRIPT="${PWD}/files/getcpu"
FLIPPY="${PWD}/files/scripts_deprecated/flippy_cn"
BANNER="${PWD}/files/banner"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# 20200930 add
SND_MOD="${PWD}/files/s905d/snd-meson-gx"
DAEMON_JSON="${PWD}/files/s905d/daemon.json"

# 20201006 add
FORCE_REBOOT="${PWD}/files/s905d/reboot"

# 20201017 add
BAL_ETH_IRQ="${PWD}/files/balethirq.pl"

# 20201026 add
FIX_CPU_FREQ="${PWD}/files/fixcpufreq.pl"
SYSFIXTIME_PATCH="${PWD}/files/sysfixtime.patch"

# 20201128 add
SSL_CNF_PATCH="${PWD}/files/openssl_engine.patch"

# 20201212 add
BAL_CONFIG="${PWD}/files/s905d/balance_irq"
CPUFREQ_INIT="${PWD}/files/s905d/cpufreq"

# 20210302 modify
FIP_HOME="${PWD}/files/meson_btld/with_fip/s905d"
UBOOT_WITH_FIP="${FIP_HOME}/n1-u-boot.bin.sd.bin"
UBOOT_WITHOUT_FIP_HOME="${PWD}/files/meson_btld/without_fip"
UBOOT_WITHOUT_FIP="u-boot-n1.bin"

# 20210307 add
SS_LIB="${PWD}/files/ss-glibc/lib-glibc.tar.xz"
SS_BIN="${PWD}/files/ss-glibc/armv8a_crypto/ss-bin-glibc.tar.xz"
JQ="${PWD}/files/jq"

# 20210330 add
DOCKERD_PATCH="${PWD}/files/dockerd.patch"

# 20200416 add
FIRMWARE_TXZ="${PWD}/files/firmware_armbian.tar.xz"
BOOTFILES_HOME="${PWD}/files/bootfiles/amlogic"
GET_RANDOM_MAC="${PWD}/files/get_random_mac.sh"

# 20210618 add
DOCKER_README="${PWD}/files/DockerReadme.pdf"

# 20210704 add
SYSINFO_SCRIPT="${PWD}/files/30-sysinfo.sh"

# 20210923 add
OPENWRT_INSTALL="${PWD}/files/openwrt-install-amlogic"
OPENWRT_UPDATE="${PWD}/files/openwrt-update-amlogic"
OPENWRT_KERNEL="${PWD}/files/openwrt-kernel"
OPENWRT_BACKUP="${PWD}/files/openwrt-backup"

# 20211019 add
FIRSTRUN_SCRIPT="${PWD}/files/first_run.sh"

# 20211020 add
BTLD_BIN="${PWD}/files/s905d/u-boot-2015-phicomm-n1.bin"

# 20211024 add
MODEL_DB="${PWD}/files/amlogic_model_database.txt"

# 20211214 add
P7ZIP="${PWD}/files/7z"

# 20211217 add
DDBR="${PWD}/files/openwrt-ddbr"

# 20220225 add
SSH_CIPHERS="aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr,chacha20-poly1305@openssh.com"
SSHD_CIPHERS="aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"


# =========================
# 检查依赖文件
# =========================

check_depends


# =========================
# 镜像分区布局
# =========================

# 跳过前导保留空间（单位 MB）
SKIP_MB=4

# BOOT 分区大小（单位 MB）
BOOT_MB=256

# ROOTFS 分区大小（单位 MB）
ROOTFS_MB=960

# 镜像总大小
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB))

# 创建目标镜像文件
create_image "$TGT_IMG" "$SIZE"

# 创建分区表与分区
# 参数含义：
# - 设备
# - 分区表类型
# - 前导保留
# - boot 分区大小
# - boot 文件系统
# - 起始分区编号
# - 结束分区编号
# - root 文件系统
create_partition "$TGT_DEV" "msdos" "$SKIP_MB" "$BOOT_MB" "fat32" "0" "-1" "btrfs"

# 格式化文件系统
make_filesystem "$TGT_DEV" "B" "fat32" "BOOT" "R" "btrfs" "ROOTFS"

# 挂载 BOOT 分区
mount_fs "${TGT_DEV}p1" "${TGT_BOOT}" "vfat"

# 挂载 ROOTFS 分区，并启用 btrfs zstd 压缩
mount_fs "${TGT_DEV}p2" "${TGT_ROOT}" "btrfs" "compress=zstd:${ZSTD_LEVEL}"

# 创建 /etc 子卷
echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc


# =========================
# 写入 rootfs 与启动文件
# =========================

# 解包 OpenWrt rootfs 到目标根文件系统
extract_rootfs_files

# 解包 Amlogic 启动文件到 BOOT 分区
extract_amlogic_boot_files


# =========================
# 修改 BOOT 分区配置
# =========================

echo "修改引导分区相关配置 ... "
cd $TGT_BOOT
rm -f uEnv.ini

cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

# 下列 dtb，用到哪个就把哪个的#删除，其它的则加上 # 在行首

# 用于 Phicomm N1
FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb

# 用于 Phicomm N1 (thresh)
#FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1-thresh.dtb

APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd:${ZSTD_LEVEL} console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

echo "uEnv.txt -->"
echo "==============================================================================="
cat uEnv.txt
echo "==============================================================================="
echo


# =========================
# 修改根文件系统配置
# =========================

echo "修改根文件系统相关配置 ... "
cd $TGT_ROOT

# 复制补充文件
copy_supplement_files

# 解包 glibc 程序
extract_glibc_programs

# 调整 Docker 配置
adjust_docker_config

# 调整 OpenSSL 配置
adjust_openssl_config

# 调整 getty 配置
adjust_getty_config

# 调整 Samba 配置
adjust_samba_config

# 调整 OpenSSH 配置
adjust_openssh_config

# 用 xrayplug 替换 v2rayplug
use_xrayplug_replace_v2rayplug

# 创建 fstab 配置
create_fstab_config

# 调整 mosdns 配置
adjust_mosdns_config

# 打补丁修改后台状态页
patch_admin_status_index_html

# 调整内核环境
adjust_kernel_env

# 复制 u-boot 到文件系统
copy_uboot_to_fs

# 写入发行版信息
write_release_info

# 写入 Banner
write_banner

# 首次启动相关配置
config_first_run

# 创建 etc 快照
create_snapshot "etc-000"

# 将 u-boot 写入磁盘
write_uboot_to_disk

# 清理临时环境
clean_work_env

# 移动最终镜像到输出目录
mv ${TGT_IMG} ${OUTPUT_DIR} && sync

echo "镜像已生成! 存放在 ${OUTPUT_DIR} 下面!"
echo "========================== end $0 ================================"
echo
