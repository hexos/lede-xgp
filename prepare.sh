#!/bin/bash
set -e
id
df -h
free -h
cat /proc/cpuinfo

LEDE_REPO="https://github.com/coolsnowwolf/lede.git"
LEDE_BRANCH="master"

if [ -d "lede" ]; then
    echo "repo dir exists"
    cd lede
    # 强制切换到 master 分支并同步（适配 coolsnowwolf/lede 的 master 分支）
    git checkout -B "${LEDE_BRANCH}" "origin/${LEDE_BRANCH}"
    git reset --hard "origin/${LEDE_BRANCH}"
    git pull origin "${LEDE_BRANCH}" || { echo "git pull failed"; exit 1; }
else
    echo "repo dir not exists"
    git clone -b "${LEDE_BRANCH}" --single-branch "${LEDE_REPO}" || { echo "git clone failed"; exit 1; }
    cd lede
fi

cat feeds.conf.default > feeds.conf
echo "" >> feeds.conf
echo "src-git qmodem https://github.com/FUjr/QModem.git;main" >> feeds.conf
#echo "src-git qmodem https://github.com/zzzz0317/QModem.git;stable202508" >> feeds.conf

# ---------------------------------------------------------------------------
# 集成自定义内容：
#   1. 将 files/ 作为 rootfs overlay 复制进 LEDE
#   2. 叠加 at-webserver / LuCI 应用的解包内容（来自 at-webserver-ubus.zip）
#   3. 将 TD-TECH USB Modem VID 内核补丁放入 rockchip 的补丁目录
# ---------------------------------------------------------------------------
rm -rf files
cp -r ../files .
if [ -d "../overlays/at-webserver" ]; then
    echo "overlay at-webserver into rootfs"
    cp -a ../overlays/at-webserver/. files/
fi

# 根据 rockchip 目标实际使用的内核版本动态放置补丁，避免内核升级后补丁失效
KERNEL_PATCHVER=$(grep -m1 '^KERNEL_PATCHVER:=' target/linux/rockchip/Makefile | sed 's/.*:=//' | tr -d '[:space:]')
if [ -z "${KERNEL_PATCHVER}" ]; then
    echo "cannot detect KERNEL_PATCHVER, fallback to 6.18"
    KERNEL_PATCHVER="6.18"
fi
echo "rockchip KERNEL_PATCHVER=${KERNEL_PATCHVER}"
TARGET_PATCH_DIR="target/linux/rockchip/patches-${KERNEL_PATCHVER}"
mkdir -p "${TARGET_PATCH_DIR}"
cp ../patches/999-add-TD-TECH-option-id.patch "${TARGET_PATCH_DIR}/"
echo "installed kernel patch -> ${TARGET_PATCH_DIR}/999-add-TD-TECH-option-id.patch"

if [ -d "package/zz/luci-app-argon-config" ]; then
    cd package/zz/luci-app-argon-config
    git pull || { echo "luci-app-argon-config git pull failed"; exit 1; }
    cd ../../..
else
    git clone https://github.com/jerrykuku/luci-app-argon-config.git package/zz/luci-app-argon-config || { echo "luci-app-argon-config git clone failed"; exit 1; }
fi
if [ -d "package/zz/luci-theme-alpha" ]; then
    cd package/zz/luci-theme-alpha
    git pull || { echo "luci-theme-alpha git pull failed"; exit 1; }
    cd ../../..
else
    git clone https://github.com/derisamedia/luci-theme-alpha.git package/zz/luci-theme-alpha || { echo "luci-theme-alpha git clone failed"; exit 1; }
fi
if [ -d "package/zz/kmod-fb-tft-gc9307" ]; then
    cd package/zz/kmod-fb-tft-gc9307
    git pull || { echo "kmod-fb-tft-gc9307 git pull failed"; exit 1; }
    cd ../../..
else
    git clone https://github.com/zzzz0317/kmod-fb-tft-gc9307.git package/zz/kmod-fb-tft-gc9307 || { echo "kmod-fb-tft-gc9307 git clone failed"; exit 1; }
fi
if [ -d "package/zz/xgp-v3-screen" ]; then
    cd package/zz/xgp-v3-screen
    git pull || { echo "xgp-v3-screen git pull failed"; exit 1; }
    cd ../../..
else
    git clone https://github.com/zzzz0317/xgp-v3-screen.git package/zz/xgp-v3-screen || { echo "xgp-v3-screen git clone failed"; exit 1; }
fi
