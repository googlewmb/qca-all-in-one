#!/bin/bash
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

# SmartDNS
git clone -b master --depth 1 \
https://github.com/pymumu/luci-app-smartdns.git \
luci-app-smartdns

git clone -b master --depth 1 \
https://github.com/pymumu/smartdns.git \
smartdns

# MosDNS
git clone -b v5 --depth 1 \
https://github.com/sbwml/luci-app-mosdns.git \
mosdns

# V2Ray GeoData
git clone --depth 1 \
https://github.com/sbwml/v2ray-geodata.git \
v2ray-geodata

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

# Lucky
#git clone -b main --depth 1 \
#https://github.com/gdy666/luci-app-lucky.git \
#lucky

# TimeControl
#git clone -b main --depth 1 \
#https://github.com/sirpdboy/luci-app-timecontrol.git \
#timecontrol

# Nikki
#git clone -b main --depth 1 \
#https://github.com/nikkinikki-org/OpenWrt-nikki.git \
#nikki

# Momo
#git clone -b main --depth 1 \
#https://github.com/nikkinikki-org/OpenWrt-momo.git \
#momo

# Daed
#git clone -b master --depth 1 \
#https://github.com/QiuSimons/luci-app-daed.git \
#daed

# Aurora
#git clone -b master --depth 1 \
#https://github.com/eamonxg/luci-theme-aurora.git \
#aurora

# HelloWorld
#git clone -b master --depth 1 \
#https://github.com/fw876/helloworld.git \
#helloworld

# PassWall Packages
#git clone -b main --depth 1 \
#https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
#passwall-packages

# PassWall
#git clone -b main --depth 1 \
#https://github.com/Openwrt-Passwall/openwrt-passwall.git \
#passwall

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
# echo 'src-git jjm2473_apps https://github.com/jjm2473/openwrt-apps.git;main' >> feeds.conf.default

# Kenzok8
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages.git' >> feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small.git' >> feeds.conf.default
#echo 'src-git small_package https://github.com/kenzok8/small-package.git' >> feeds.conf.default

# Kiddin9
#echo 'src-git kiddin9 https://github.com/kiddin9/op-packages.git' >> feeds.conf.default

# VIKINGYFY
echo 'src-git vikingyfy https://github.com/VIKINGYFY/packages.git' >> feeds.conf.default

# Modem
#echo 'src-git modem https://github.com/FUjr/modem_feeds.git' >> feeds.conf.default

echo "package/myapp:"
find package/myapp \
-maxdepth 1 \
-mindepth 1 \
-type d \
-printf '%f\n' | sort

echo "DIY1 OK"
