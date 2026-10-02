默认编译
daede全内核依赖
部分机型内核调整了，需要大分区才能正常使用。具体看diy2调整内核的机型。
默认集成
CONFIG_PACKAGE_luci-app-daede=y
CONFIG_PACKAGE_luci-app-daed=y
配合smartdns使用更佳。

upstream {
  cn_dns: 'udp://127.0.0.1:6053'
  foreign_dns: 'tcp://127.0.0.1:6553'
}

routing {
  request {
    qname(geosite:category-ads-all) -> reject
    qname(geosite:cn) -> cn_dns
    fallback: foreign_dns
  }

  response {
    upstream(foreign_dns) -> accept
    !qname(geosite:cn) && ip(geoip:private) -> foreign_dns
    !qname(geosite:cn) && ip(geoip:cn) -> foreign_dns
    fallback: accept
  }
}



AX6-3600-9000-AP8220-雅典娜等
全满血nss
默认192.168.1.1
无线12345678

带完整daede内核配置，插件请自行ssh一键安装脚本。
https://raw.githubusercontent.com/kenzok8/openwrt-daede/refs/heads/main/scripts/install.sh



wget --no-check-certificate -O - https://ghfast.top/https://raw.githubusercontent.com/kenzok8/openwrt-daede/refs/heads/main/scripts/install.sh | ash



openwrt主线专用
wget -qO- https://down.dllkids.xyz/openwrt-feed/openwrt-feed-setup.sh | sh
