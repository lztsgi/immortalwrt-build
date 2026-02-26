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
***
# 致谢
本项目基于 [ImmortalWrt-25.12](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12) 源码编译，使用 flippy 的[脚本](https://github.com/unifreq/openwrt_packit)和 breakingbadboy 维护的[内核](https://github.com/breakingbadboy/OpenWrt/releases/tag/kernel_stable)打包成完整固件，感谢开发者们的无私分享。<br>
flippy 固件的更多细节参考[恩山论坛帖子](https://www.right.com.cn/forum/thread-4076037-1-1.html)。
