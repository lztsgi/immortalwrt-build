# 项目简介
本固件适配斐讯 N1 旁路由模式，追求轻量，不具备 PPPoE、WiFi 相关功能。<br>
固件仅包含默认皮肤以及下列 luci-app：<br>
[luci-app-amlogic](https://github.com/ophub/luci-app-amlogic)：系统更新、文件传输、CPU 调频等<br>
[luci-app-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall)：科学上网<br>
[luci-app-podman](https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman)：容器管理<br>
luci-app-samba4：存储共享
如果不要修改下面设置：
  修改预装插件：armsr/armv8/N1/.config
    CONFIG_PACKAGE_luci-app-passwall=n
    CONFIG_PACKAGE_luci-app-podman=n
    CONFIG_PACKAGE_luci-app-samba4=n
  修改预备脚本：armsr/armv8/diy/diy.sh
    git clone https://github.com/Openwrt-Passwall/openwrt-passwall --depth=1 clone/passwall
    git clone https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman --depth=1 feeds/luci/applications/luci-app-podman
    修改：cp -rf clone/amlogic/luci-app-amlogic clone/passwall/luci-app-passwall feeds/luci/applications/改为下面
    cp -rf clone/amlogic/luci-app-amlogic feeds/luci/applications/

### 📌 项目简介
本固件专为 **斐讯 N1** 旁路由模式适配，追求极简、稳定与高效。
* **核心理念**：彻底移除 PPPoE、WiFi 等旁路由环境下冗余的功能，最大化系统资源利用率。
* **技术底座**：基于 [ImmortalWrt-25.12](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12) 源码编译，集成原生 `apk` 包管理器支持。

---

### 🚀 本版本自定义特性
为了满足高性能需求，本固件已完成以下底层优化：
* **存储扩容**：根文件系统（Rootfs）已由默认值扩容至 **1024 MB**，为后续安装复杂插件留足空间。
* **网络预设**：
    * [cite_start]**默认后台 IP**：`192.168.101.2` [cite: 2]
    * [cite_start]**默认网关**：`192.168.101.1` [cite: 2]
* **内置软件源**：镜像中已预先注入了 `momo` 与 `nikki` 的第三方 APK 软件源配置及安全密钥。
    * *使用方法：刷机后确保 N1 联网，直接运行 `apk add luci-app-nikki` 等命令即可按需快速安装，无需再手动添加源。*

---

### 📦 插件清单
目前固件仅物理预装了以下底层控制插件：
* [luci-app-amlogic](https://github.com/ophub/luci-app-amlogic)：负责系统更新、CPU 频率调整、存储管理及文件传输。

---

### 🛠️ 自定义与维护路径
如果你需要进一步调整固件配置，请参考以下代码位置：

#### 1. 插件增减控制
修改文件：`armsr/armv8/N1/.config`
* 若要禁用特定插件：找到对应项将 `=y` 改为 `=n`。
* 本固件已默认精简：`passwall`、`podman`、`samba4`。

#### 2. 源码拉取逻辑
修改文件：`armsr/armv8/diy/diy.sh`
* 本版本已优化：仅保留 `amlogic` 源码克隆逻辑，修复了因路径不存在导致的编译中断问题。

#### 3. 分区容量调整
修改文件：`armsr/armv8/N1/mk_s905d_n1.sh`
* 通过修改 `ROOTFS_MB=1024` 变量来控制生成的 `.img` 镜像体积。

***
# 致谢
本项目基于 [ImmortalWrt-25.12](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12) 源码编译，使用 flippy 的[脚本](https://github.com/unifreq/openwrt_packit)和 breakingbadboy 维护的[内核](https://github.com/breakingbadboy/OpenWrt/releases/tag/kernel_stable)打包成完整固件，感谢开发者们的无私分享。<br>
flippy 固件的更多细节参考[恩山论坛帖子](https://www.right.com.cn/forum/thread-4076037-1-1.html)。
