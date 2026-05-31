#!/bin/bash

# Adjust source code
patch -p1 -f < $(dirname "$0")/luci.patch

# Clone packages
git clone https://github.com/ophub/luci-app-amlogic --depth=1 clone/amlogic

# Adjust packages
rm -rf feeds/luci/applications/luci-app-passwall
cp -rf clone/amlogic/luci-app-amlogic feeds/luci/applications/
# N1 uses openwrt_packit/flippy Amlogic images; prefer luci-app-amlogic for upgrades.
# Disable generic LuCI attended sysupgrade to avoid producing incompatible armsr images.
sed -i '/luci-app-attendedsysupgrade/d' feeds/luci/collections/luci/Makefile

# Clean packages
rm -rf clone
