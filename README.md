# QCA All-in-One

Qualcomm IPQ60xx / IPQ807x 多设备 OpenWrt / LibWrt 自动编译项目。

本项目集成 Daede/Daed、Qualcomm NSS、BPF/XDP 以及多种常用网络、代理、存储和系统管理插件，无线默认无密码或者12345678，连接数655550，并提供多设备配置及 GitHub Actions 自动编译。

## 编译源码

本项目根据不同编译工作流使用以下源码：

### LibWrt

- 源码：https://github.com/LiBwrt/LibWrt
- 分支：`25.12-nss`

### VIKINGYFY ImmortalWrt

- 源码：https://github.com/VIKINGYFY/immortalwrt
- 分支：`owrt`切换原生 Qualcomm 硬件流加速&暂时保留nss的编译

### 项目源码

- https://github.com/googlewmb/qca-all-in-one

## 支持设备

本项目支持 Qualcomm IPQ60xx / IPQ807x 多款设备，已集成完整 Daede/Daed 环境、Qualcomm NSS、BPF/XDP 原生Qualcomm 硬件流加速以及常用插件。

### IPQ60xx

- 360 V6
- AnySafe E1
- CMIOT AX18
- DPTech AP3000-2C
- GL.iNet GL-AX1800
- GL.iNet GL-AXT1800
- JDCloud RE-CS-02
- JDCloud RE-SS-01
- Link NN6000 V1
- Link NN6000 V2
- Linksys MR7350
- Linksys MR7500
- Philips LY1800
- Redmi AX5
- Redmi AX5 JDCloud
- SY-Y6010
- Xiaomi AX1800
- ZN M2

### IPQ807x

- Aliyun AP8220
- Xiaomi AX9000
- Xiaomi AX9000 Stock

### IPQ807x 无 USB

- Redmi AX6
- Redmi AX6 Stock
- Xiaomi AX3600
- Xiaomi AX3600 Stock

## Daede / Daed

所有设备配置均已集成 Daede/Daed 相关环境，并根据不同平台提供对应的内核、BPF/XDP、Qualcomm NSS 等支持。

主要包括：

- Daede / Daed
- BPF
- CGROUP
- CGROUP_BPF
- BPF Events
- XDP
- XDP Sockets
- BPF Toolchain
- Qualcomm NSS
- NSS ECM
- NSS DP
- NSS Crypto
- NSS Bridge Manager
- NSS PPPoE
- NSS VLAN Manager
- NSS VXLAN
- NSS GRE
- NSS L2TP
- NSS PPTP
- NSS Qdisc
- NSS Netlink
- NSS Mirror
- NSS MAP-T
- NSS Tun6RD
- NSS TunIPIP6
- Qualcomm SSDK

不同设备根据硬件平台和内核版本使用对应的配置。

## 已集成插件

项目配置文件已经集成多种常用插件，包括：

- PassWall
- Daede / Daed
- SmartDNS
- MosDNS
- WireGuard
- UPnP
- DDNS-Go
- Lucky
- Samba4
- Diskman
- FileTransfer
- MiniDLNA
- TTYD
- WOLPlus
- CPUFreq
- RAMFree
- 自动重启
- 软件包管理器
- 时间控制
- HD Idle

不同设备的插件配置可能有所不同，以对应设备的 `.config` 为准。

## 第三方插件源码

项目通过 DIY 脚本及第三方 feeds 集成插件源码和相关依赖。

### PassWall

- https://github.com/Openwrt-Passwall/openwrt-passwall
- https://github.com/Openwrt-Passwall/openwrt-passwall-packages

### OpenClash

- https://github.com/vernesong/OpenClash

### SmartDNS

- https://github.com/pymumu/smartdns
- https://github.com/pymumu/luci-app-smartdns

### MosDNS

- https://github.com/sbwml/luci-app-mosdns

### HomeProxy

- https://github.com/immortalwrt/homeproxy

### V2Ray GeoData

- https://github.com/sbwml/v2ray-geodata

### OLED

- https://github.com/jjm2473/luci-app-oled

### LCDSimple

- https://github.com/jjm2473/lcdsimple

### Diskman

- https://github.com/jjm2473/luci-app-diskman

### OpenAppFilter

- https://github.com/jjm2473/OpenAppFilter

### NATMap

- https://github.com/muink/openwrt-natmapt

### STUNTMAN

- https://github.com/muink/openwrt-stuntman

### NATMap LuCI

- https://github.com/muink/luci-app-natmapt

## 第三方 Feeds

项目同时使用多个第三方 feeds：

### 官方 Feeds

- packages
- luci
- routing
- telephony
- store
- third

### 第三方 Feeds

- nas
- nas_luci
- jjm2473_apps
- kenzo
- small

项目通过 DIY 脚本对第三方插件及官方 feeds 中的重复软件包进行处理，并优先使用项目自定义源码。

## 自定义插件

需要增加其他插件时，直接在对应设备配置文件中添加：

```text
CONFIG_PACKAGE_插件名称=y
