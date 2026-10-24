#!/bin/bash
set -e
#
# nss
# 第三方插件源码
#

echo "DIY1 - 下载第三方插件"

mkdir -p package/myapp
cd package/myapp

# OpenClash
git clone -b master --depth 1 \
https://github.com/vernesong/OpenClash.git \
openclash

# HomeProxy
git clone -b master --depth 1 \
https://github.com/immortalwrt/homeproxy.git \
homeproxy

# SmartDNS 核心（官方 OpenWrt 软件包）
# 上游核心源码：https://github.com/pymumu/smartdns
# OpenWrt 软件包：https://github.com/pymumu/openwrt-smartdns
git clone -b master --depth 1 \
https://github.com/pymumu/openwrt-smartdns.git \
smartdns

# SmartDNS LuCI 管理界面
git clone -b master --depth 1 \
https://github.com/pymumu/luci-app-smartdns.git \
luci-app-smartdns

# MosDNS
#git clone -b v5 --depth 1 \
#https://github.com/sbwml/luci-app-mosdns.git \
#mosdns

# V2Ray GeoData
#git clone --depth 1 \
#https://github.com/sbwml/v2ray-geodata.git \
#v2ray-geodata

# H68K / jjm2473
git clone -b master --depth 1 \
https://github.com/jjm2473/luci-app-oled.git \
luci-app-oled

git clone -b main --depth 1 \
https://github.com/jjm2473/lcdsimple.git \
lcdsimple

git clone -b dev --depth 1 \
https://github.com/jjm2473/luci-app-diskman.git \
luci-app-diskman

git clone -b dev7 --depth 1 \
https://github.com/jjm2473/OpenAppFilter.git \
OpenAppFilter

# NATMap 后端
git clone -b master --depth 1 \
https://github.com/muink/openwrt-natmapt.git \
natmapt

# STUNTMAN 客户端
git clone -b master --depth 1 \
https://github.com/muink/openwrt-stuntman.git \
stuntman

# NATMap LuCI
git clone -b master --depth 1 \
https://github.com/muink/luci-app-natmapt.git \
luci-app-natmapt

# Lucky
#git clone -b main --depth 1 \
#https://github.com/gdy666/luci-app-lucky.git \
#lucky

# TimeControl
#git clone -b main --depth 1 \
#https://github.com/sirpdboy/luci-app-timecontrol.git \
#timecontrol

# Nikki
git clone -b main --depth 1 \
https://github.com/nikkinikki-org/OpenWrt-nikki.git \
nikki

# Momo
#git clone -b main --depth 1 \
#https://github.com/nikkinikki-org/OpenWrt-momo.git \
#momo

###############################################################################
# dae / daed / luci-app-daede
# 来源：https://github.com/kenzok8/openwrt-daede
###############################################################################

echo "下载 kenzok8/openwrt-daede"

DAEDE_TMP=".openwrt-daede-src"

git clone -b main --depth 1 \
https://github.com/kenzok8/openwrt-daede.git \
"$DAEDE_TMP"

# 检查所需软件包目录
for pkg in dae daed luci-app-daede; do
    if [ ! -d "$DAEDE_TMP/$pkg" ]; then
        echo "ERROR: openwrt-daede 缺少软件包目录: $pkg"
        exit 1
    fi

    if [ -e "$pkg" ] || [ -L "$pkg" ]; then
        echo "ERROR: 目标目录已存在，拒绝覆盖: package/myapp/$pkg"
        exit 1
    fi
done

# 将三个软件包放到 package/myapp 一级目录
mv "$DAEDE_TMP/dae" ./dae
mv "$DAEDE_TMP/daed" ./daed
mv "$DAEDE_TMP/luci-app-daede" ./luci-app-daede

# 删除临时仓库
rm -rf "$DAEDE_TMP"

echo "已添加 dae、daed、luci-app-daede"

# Aurora
#git clone -b master --depth 1 \
#https://github.com/eamonxg/luci-theme-aurora.git \
#aurora

# HelloWorld
#git clone -b master --depth 1 \
#https://github.com/fw876/helloworld.git \
#helloworld

# PassWall Packages
git clone -b main --depth 1 \
https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
passwall-packages

# PassWall
git clone -b main --depth 1 \
https://github.com/Openwrt-Passwall/openwrt-passwall.git \
passwall

# PassWall2
#git clone -b main --depth 1 \
#https://github.com/Openwrt-Passwall/openwrt-passwall2.git \
#passwall2

cd ../..

echo "添加插件集合源"

# iStore Packages
#echo 'src-git istore https://github.com/linkease/istore-packages.git;main' >> feeds.conf.default

# NAS Packages
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default

# jjm2473 Apps
echo 'src-git jjm2473_apps https://github.com/jjm2473/openwrt-apps.git;main' >> feeds.conf.default

# Kenzok8
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages.git' >> feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small.git' >> feeds.conf.default
# echo 'src-git small_package https://github.com/kenzok8/small-package.git' >> feeds.conf.default

# Kiddin9
#echo 'src-git kiddin9 https://github.com/kiddin9/op-packages.git' >> feeds.conf.default

# VIKINGYFY
# echo 'src-git vikingyfy https://github.com/VIKINGYFY/packages.git' >> feeds.conf.default

# Modem
# echo 'src-git modem https://github.com/FUjr/modem_feeds.git' >> feeds.conf.default

echo "package/myapp:"
find package/myapp \
    -maxdepth 1 \
    -mindepth 1 \
    -type d \
    -printf '%f\n' | sort

echo "DIY1 OK"
