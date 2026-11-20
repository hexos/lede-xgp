#!/bin/bash
cd lede
echo "update feeds"
./scripts/feeds update -a || { echo "update feeds failed"; exit 1; }
echo "install feeds"
./scripts/feeds install -a || { echo "install feeds failed"; exit 1; }
./scripts/feeds install -a -f -p qmodem || { echo "install qmodem feeds failed"; exit 1; }
cat ../xgp.config > .config
echo "make defconfig"
make defconfig || { echo "defconfig failed"; exit 1; }
echo "diff initial config and new config:"
diff ../xgp.config .config
echo "diff initial config and new config (from old config only):"
diff ../xgp.config .config | grep -e "^<" | grep -v "^< #"
echo "diff initial config and new config (from new config only):"
diff ../xgp.config .config | grep -e "^>" | grep -v "^> #"
echo "check device exist"
grep -Fxq "CONFIG_TARGET_rockchip_armv8_DEVICE_nlnet_xiguapi-v3=y" .config || exit 1
echo apply qmodem default setting
#cat feeds/qmodem/luci/luci-app-qmodem/root/etc/config/qmodem > files/etc/config/qmodem
cat feeds/qmodem/application/qmodem/files/etc/config/qmodem > files/etc/config/qmodem
cat >> files/etc/config/qmodem << EOF

config modem-slot 'wwan'
	option type 'usb'
	option slot '8-1'
	option net_led 'blue:net'
	option alias 'wwan'

config modem-slot 'mpcie1'
	option type 'pcie'
	option slot '0001:11:00.0'
	option net_led 'blue:net'
	option alias 'mpcie1'

config modem-slot 'mpcie2'
	option type 'pcie'
	option slot '0002:21:00.0'
	option net_led 'blue:net'
	option alias 'mpcie2'
EOF

year=$(date +%y)
month=$(date +%-m)
day=$(date +%-d)
hour=$(date +%-H)
zz_build_date=$(date "+%Y-%m-%d %H:%M:%S %z")
zz_build_uuid=$(uuidgen)

echo "zz_build_date=${zz_build_date}"
echo "zz_build_uuid=${zz_build_uuid}"
cat >> files/etc/uci-defaults/zzzz-version << EOF
echo "DISTRIB_REVISION='R${year}.${month}.${day}.${hour}'" >> /etc/openwrt_release
/bin/sync
EOF
echo "ZZ_BUILD_ID='${zz_build_uuid}'" > files/etc/zz_build_id
echo "ZZ_BUILD_HOST='$(hostname)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_USER='$(whoami)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_DATE='${zz_build_date}'" >> files/etc/zz_build_id
echo "ZZ_BUILD_REPO_HASH='$(cd .. && git rev-parse HEAD)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_LEDE_HASH='$(git rev-parse HEAD)'" >> files/etc/zz_build_id
echo "make download"
make download -j8 || { echo "download failed"; exit 1; }
echo "make lede"
if make V=0 -j$(nproc); then
    echo "make ok"
else
    echo "===== MAIN BUILD FAILED - retry key stages with V=s to expose the error ====="
    # V=0 隐藏具体错误；失败时用 V=s 重跑关键阶段，让日志显示真正出错的命令/包。
    # 包此时已编译完，重装/重打包很快，不会像 world 那样全量重编。
    echo "----- V=s package/install -----"
    make -j1 V=s package/install 2>&1 | tee /tmp/install_retry.log
    echo "----- V=s target/linux/install -----"
    make -j1 V=s target/linux/install 2>&1 | tee /tmp/target_install_retry.log
    echo "===== LAST 100 LINES: package/install ====="
    tail -100 /tmp/install_retry.log
    echo "===== LAST 100 LINES: target/linux/install ====="
    tail -100 /tmp/target_install_retry.log
    echo "make failed"
    exit 1
fi
