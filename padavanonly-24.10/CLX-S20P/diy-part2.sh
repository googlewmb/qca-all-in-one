
#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2
#
# H68K + iStoreOS 24.10
#
# 常规来源优先级：
#   1. package/myapp
#   2. DIY1 第三方集合源
#   3. 官方 feeds
#
# 特殊来源锁定：
#   dae / daed       -> kenzok8/small
#   rtp2httpd        -> stackia 官方 Feed
#   luci-app-rtp2httpd -> stackia 官方 Feed
#
# 其他配置保持不变
#

set -e

echo "DIY2 - H68K + iStoreOS 24.10"
echo "第三方插件 / 依赖 / 来源优先级处理"

###############################################################################
# 0. 基础目录
###############################################################################

[ -d "$TOPDIR" ] || TOPDIR="$(pwd)"
cd "$TOPDIR"

echo "TOPDIR: $TOPDIR"

###############################################################################
# 1. 核心依赖与第三方源码拉取
###############################################################################

echo
echo "========================================"
echo "拉取/更新核心依赖与 PassWall 组件"
echo "========================================"

# 1.1 移除官方旧库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls}

rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/passwall-packages package/passwall-luci

# 1.2 拉取 PassWall
git clone --depth 1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages \
    package/passwall-packages

git clone --depth 1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall \
    package/passwall-luci

# 1.3 修复 Rust download-ci-llvm 404
echo
echo "==== 修复 Rust download-ci-llvm 404 ===="

RUST_MK="feeds/packages/lang/rust/Makefile"

if [ -f "$RUST_MK" ]; then

    sed -i \
        's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' \
        "$RUST_MK"

    if grep -q 'download-ci-llvm=false' "$RUST_MK"; then
        echo "已设置 llvm.download-ci-llvm=false"
    else
        echo "[警告] 未匹配到 download-ci-llvm=true"
        grep -n 'download-ci-llvm' "$RUST_MK" || true
    fi

else

    echo "[警告] 未找到 $RUST_MK，跳过"

fi

# 1.4 拉取 kenzok8 Go 1.27
rm -rf feeds/packages/lang/golang

git clone \
    https://github.com/kenzok8/golang \
    -b 1.27 \
    feeds/packages/lang/golang

# 1.5 更新和安装 feeds
echo
echo "更新并安装新依赖索引..."

# 更新 DIY1 添加的 stackia 官方 rtp2httpd Feed
./scripts/feeds update rtp2httpd

# 保留原有依赖安装逻辑
./scripts/feeds install -p packages golang || true
./scripts/feeds install -f microsocks || true
./scripts/feeds install -a

###############################################################################
# 2. 公共函数与来源优先级配置
###############################################################################

echo
echo "========================================"
echo "初始化第三方依赖处理"
echo "========================================"

REMOVE_OFFICIAL_DEPS=""

OFFICIAL_FEEDS="
packages
luci
routing
telephony
store
third
"

THIRD_PARTY_FEEDS="
nas
nas_luci
jjm2473_apps
kenzo
small
"

# 检查软件包安装入口
package_entry_exists()
{
    local feed="$1"
    local pkg="$2"
    local entry="package/feeds/${feed}/${pkg}"

    [ -e "$entry" ] || [ -L "$entry" ]
}

# 删除软件包安装入口
remove_package_entry()
{
    local feed="$1"
    local pkg="$2"
    local entry="package/feeds/${feed}/${pkg}"

    if [ -e "$entry" ] || [ -L "$entry" ]; then
        echo "删除安装入口: ${feed}/${pkg}"
        rm -rf "$entry"
    fi
}

# 获取软件包 Makefile 实际路径
package_makefile()
{
    local feed="$1"
    local pkg="$2"
    local makefile="package/feeds/${feed}/${pkg}/Makefile"

    if [ -f "$makefile" ]; then
        readlink -f "$makefile" 2>/dev/null || true
    fi
}

# 获取软件包版本
get_package_version()
{
    local makefile="$1"
    local version=""

    [ -f "$makefile" ] || {
        echo "unknown"
        return
    }

    version="$(
        sed -nE \
            's/^[[:space:]]*PKG_VERSION[[:space:]]*:?=[[:space:]]*(.*)$/\1/p' \
            "$makefile" |
        head -n 1
    )"

    if [ -z "$version" ]; then

        version="$(
            sed -nE \
                's/^[[:space:]]*PKG_RELEASE[[:space:]]*:?=[[:space:]]*(.*)$/release-\1/p' \
                "$makefile" |
            head -n 1
        )"

    fi

    [ -n "$version" ] || version="unknown"

    echo "$version"
}

###############################################################################
# 3. 移除明确指定的官方依赖入口
###############################################################################

echo
echo "========================================"
echo "清理指定官方依赖入口"
echo "========================================"

for pkg in $REMOVE_OFFICIAL_DEPS; do

    [ -n "$pkg" ] || continue

    echo "移除官方依赖入口: $pkg"

    for official_feed in $OFFICIAL_FEEDS; do
        remove_package_entry "$official_feed" "$pkg"
    done

done

###############################################################################
# 4. rtp2httpd 强制锁定 stackia 官方 Feed
#
# 指定源码：
#   feeds/rtp2httpd/openwrt-support/rtp2httpd
#   feeds/rtp2httpd/openwrt-support/luci-app-rtp2httpd
#
# 不允许其他 feeds 覆盖
###############################################################################

echo
echo "========================================"
echo "锁定 rtp2httpd 来源：stackia 官方 Feed"
echo "========================================"

RTP2HTTPD_PACKAGES="
rtp2httpd
luci-app-rtp2httpd
"

# 4.1 检查官方 Feed
if [ ! -d feeds/rtp2httpd ]; then
    echo "ERROR: stackia 官方 rtp2httpd Feed 不存在"
    exit 1
fi

# 4.2 检查官方源码
for pkg in $RTP2HTTPD_PACKAGES; do

    SOURCE="feeds/rtp2httpd/openwrt-support/${pkg}"

    if [ ! -f "${SOURCE}/Makefile" ]; then
        echo "ERROR: stackia 官方 Feed 缺少 ${pkg}"
        echo "检查路径: ${SOURCE}/Makefile"
        exit 1
    fi

    echo "确认官方源码存在: ${SOURCE}"

done

# 4.3 删除其他 feeds 的同名安装入口
for pkg in $RTP2HTTPD_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "rtp2httpd" ] && continue

        echo "删除其他来源安装入口: ${feed}/${pkg}"

        rm -rf "$entry"

    done

done

# 4.4 只从 stackia 官方 Feed 安装
./scripts/feeds install -p rtp2httpd \
    rtp2httpd \
    luci-app-rtp2httpd

# 4.5 验证实际安装来源
for pkg in $RTP2HTTPD_PACKAGES; do

    STACKIA_ENTRY="package/feeds/rtp2httpd/${pkg}"
    STACKIA_SOURCE="feeds/rtp2httpd/openwrt-support/${pkg}"

    if [ ! -f "${STACKIA_ENTRY}/Makefile" ]; then
        echo "ERROR: ${pkg} 官方安装入口不存在"
        exit 1
    fi

    ENTRY_REAL="$(readlink -f "$STACKIA_ENTRY" 2>/dev/null || true)"
    SOURCE_REAL="$(readlink -f "$STACKIA_SOURCE" 2>/dev/null || true)"

    if [ -z "$ENTRY_REAL" ] || [ "$ENTRY_REAL" != "$SOURCE_REAL" ]; then
        echo "ERROR: ${pkg} 实际来源不是 stackia 官方 Feed"
        echo "安装入口: ${ENTRY_REAL}"
        echo "官方源码: ${SOURCE_REAL}"
        exit 1
    fi

    echo
    echo "✓ ${pkg}"
    echo "  指定来源: stackia/rtp2httpd"
    echo "  实际路径: ${ENTRY_REAL}"

done

# 4.6 检查其他 feeds 是否存在重复入口
for pkg in $RTP2HTTPD_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "rtp2httpd" ] && continue

        echo "ERROR: ${pkg} 发现其他 Feed 重复入口: ${feed}"
        exit 1

    done

done

echo
echo "rtp2httpd stackia 官方来源锁定完成"

###############################################################################
# 5. dae / daed 强制锁定 kenzok8/small
#
# 指定源码：
#   feeds/small/dae
#   feeds/small/daed
#
# 不允许其他 feeds 覆盖
# luci-app-daede 不在本段强制修改范围内
###############################################################################

echo
echo "========================================"
echo "锁定 dae / daed 来源：kenzok8/small"
echo "========================================"

DAE_CORE_PACKAGES="
dae
daed
"

# 5.1 检查 small 源码
for pkg in $DAE_CORE_PACKAGES; do

    SMALL_SOURCE="feeds/small/${pkg}"

    if [ ! -f "${SMALL_SOURCE}/Makefile" ]; then
        echo "ERROR: small feed 中不存在 ${pkg}"
        echo "检查路径: ${SMALL_SOURCE}/Makefile"
        exit 1
    fi

    echo "确认 small 源码存在: ${SMALL_SOURCE}"

done

# 5.2 检查 package/myapp 是否存在同名核心包
if [ -d package/myapp ]; then

    for pkg in $DAE_CORE_PACKAGES; do

        if grep -rqE \
            "^[[:space:]]*define[[:space:]]+Package/${pkg}([[:space:]]|$)" \
            --include=Makefile \
            package/myapp 2>/dev/null; then

            echo "ERROR: package/myapp 中发现同名核心包 ${pkg}"
            echo "small 和 package/myapp 存在重复定义风险"
            echo "请在 DIY1 中取消添加该核心包"
            exit 1

        fi

    done

fi

# 5.3 删除其他 feeds 中的同名安装入口
for pkg in $DAE_CORE_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        echo "删除旧安装入口: ${feed}/${pkg}"

        rm -rf "$entry"

    done

done

# 5.4 只建立 small 来源软链接
mkdir -p package/feeds/small

for pkg in $DAE_CORE_PACKAGES; do

    SMALL_SOURCE="feeds/small/${pkg}"
    SMALL_ENTRY="package/feeds/small/${pkg}"

    if [ -e "$SMALL_ENTRY" ] || [ -L "$SMALL_ENTRY" ]; then
        rm -rf "$SMALL_ENTRY"
    fi

    ln -s "../../../feeds/small/${pkg}" "$SMALL_ENTRY"

    if [ ! -f "${SMALL_ENTRY}/Makefile" ]; then
        echo "ERROR: ${pkg} small 软链接创建失败"
        exit 1
    fi

    SMALL_REAL="$(readlink -f "$SMALL_ENTRY" 2>/dev/null || true)"
    FEED_REAL="$(readlink -f "$SMALL_SOURCE" 2>/dev/null || true)"

    if [ -z "$SMALL_REAL" ] || [ "$SMALL_REAL" != "$FEED_REAL" ]; then
        echo "ERROR: ${pkg} 实际链接目标不是 feeds/small"
        echo "安装入口: ${SMALL_REAL}"
        echo "源码目录: ${FEED_REAL}"
        exit 1
    fi

    echo
    echo "✓ ${pkg}"
    echo "  指定来源: small/${pkg}"
    echo "  实际路径: ${SMALL_REAL}"
    echo "  软件包版本: $(get_package_version "${SMALL_ENTRY}/Makefile")"

done

# 5.5 检查其他 feeds 是否存在重复入口
for pkg in $DAE_CORE_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "small" ] && continue

        echo "ERROR: 发现其他 Feed 重复入口: ${feed}/${pkg}"
        exit 1

    done

done

echo
echo "dae / daed 核心来源锁定完成"

###############################################################################
# 6. H68K DTS 处理
###############################################################################

# echo
# echo "========================================"
# echo "H68K DTS"
# echo "========================================"

# DTS_SOURCE="$GITHUB_WORKSPACE/test-istore/diy/H68K-DTS Linux6.1-6.6.dts"

# if [ -f "$DTS_SOURCE" ]; then
#
#     mkdir -p target/linux/rockchip/dts/rk3568
#     mkdir -p target/linux/rockchip/files/arch/arm64/boot/dts/rockchip
#
#     cp -f "$DTS_SOURCE" \
#         target/linux/rockchip/dts/rk3568/rk3568-opc-h68k.dts
#
#     cp -f "$DTS_SOURCE" \
#         target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3568-opc-h68k.dts
#
#     cp -f "$DTS_SOURCE" \
#         target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3568-hinlink-opc-h68k.dts
#
#     echo "H68K DTS 已复制"
#
# else
#
#     echo "WARNING: 未找到 H68K DTS:"
#     echo "$DTS_SOURCE"
#
# fi

###############################################################################
# 7. 扫描 package/myapp 真正的 Package
###############################################################################

echo
echo "========================================"
echo "扫描 DIY1 独立第三方插件"
echo "========================================"

MYAPP_PACKAGES=""

if [ -d package/myapp ]; then

    while IFS= read -r pkg; do

        [ -n "$pkg" ] || continue

        case "$pkg" in
            '\( ('*|*' \))'|*'/'*)
                continue
                ;;
        esac

        MYAPP_PACKAGES="$MYAPP_PACKAGES
$pkg"

        echo "✓ $pkg"

    done < <(
        find package/myapp \
            -type f \
            -name Makefile \
            -print0 2>/dev/null |
        xargs -0 -r sed -nE \
            's/^[[:space:]]*define[[:space:]]+Package\/([A-Za-z0-9_.+@:-]+)[[:space:]]*$/\1/p' |
        sort -u || true
    )

else

    echo "WARNING: package/myapp 不存在"

fi

###############################################################################
# 8. 收集 .config 中实际启用的 Package
###############################################################################

echo
echo "========================================"
echo "读取当前 .config"
echo "========================================"

CONFIG_PACKAGES=""

if [ -f .config ]; then

    CONFIG_PACKAGES="$(
        sed -nE \
            's/^CONFIG_PACKAGE_([A-Za-z0-9_.+@:-]+)=(y|m)$/\1/p' \
            .config |
        sort -u
    )"

fi

echo "当前启用的第三方/官方 Package 数量：$(printf '%s\n' "$CONFIG_PACKAGES" | sed '/^$/d' | wc -l)"

###############################################################################
# 9. 独立第三方插件优先
#
# package/myapp > 第三方 feeds > 官方 feeds
###############################################################################

echo
echo "========================================"
echo "独立第三方插件优先"
echo "========================================"

for pkg in $MYAPP_PACKAGES; do

    [ -n "$pkg" ] || continue

    echo
    echo "检查独立第三方插件: $pkg"

    MYAPP_MAKEFILE=""

    while IFS= read -r -d '' mf; do

        [ -f "$mf" ] || continue

        if grep -q \
            "^[[:space:]]*define[[:space:]]\+Package/${pkg}[[:space:]]*$" \
            "$mf" 2>/dev/null; then

            MYAPP_MAKEFILE="$mf"
            break

        fi

    done < <(
        find package/myapp \
            -type f \
            -name Makefile \
            -print0 2>/dev/null || true
    )

    if [ -z "$MYAPP_MAKEFILE" ] &&
       [ -f "package/myapp/${pkg}/Makefile" ]; then

        MYAPP_MAKEFILE="package/myapp/${pkg}/Makefile"

    fi

    if [ -n "$MYAPP_MAKEFILE" ]; then
        MYAPP_VERSION="$(get_package_version "$MYAPP_MAKEFILE")"
        echo "package/myapp 版本: $MYAPP_VERSION"
    else
        MYAPP_VERSION="unknown"
    fi

    for feed in $THIRD_PARTY_FEEDS $OFFICIAL_FEEDS; do

        if package_entry_exists "$feed" "$pkg"; then

            MAKEFILE="$(package_makefile "$feed" "$pkg")"
            VERSION="$(get_package_version "$MAKEFILE")"

            echo "发现重复来源:"
            echo "  $feed/$pkg"
            echo "  版本: $VERSION"
            echo "选择: package/myapp"
            echo "原因: 独立第三方源码优先"

            remove_package_entry "$feed" "$pkg"

        fi

    done

done

###############################################################################
# 10. 第三方集合源优先
#
# THIRD_PARTY_FEEDS > OFFICIAL_FEEDS
###############################################################################

echo
echo "========================================"
echo "第三方集合源优先"
echo "========================================"

for pkg in $CONFIG_PACKAGES; do

    [ -n "$pkg" ] || continue

    # dae / daed 使用 small 专属来源
    case "$pkg" in
        dae|daed)
            echo "跳过普通来源处理: $pkg（已锁定 small）"
            continue
            ;;
    esac

    # package/myapp 优先，不参与普通来源处理
    case "
$MYAPP_PACKAGES
" in
        *"
$pkg
"*)
            continue
            ;;
    esac

    THIRD_SOURCE=""

    for third_feed in $THIRD_PARTY_FEEDS; do

        if package_entry_exists "$third_feed" "$pkg"; then
            THIRD_SOURCE="$third_feed"
            break
        fi

    done

    [ -n "$THIRD_SOURCE" ] || continue

    THIRD_MAKEFILE="$(package_makefile "$THIRD_SOURCE" "$pkg")"
    THIRD_VERSION="$(get_package_version "$THIRD_MAKEFILE")"

    echo
    echo "发现第三方重复包: $pkg"
    echo "第三方来源: ${THIRD_SOURCE}/${pkg}"
    echo "第三方版本: $THIRD_VERSION"

    for official_feed in $OFFICIAL_FEEDS; do

        if package_entry_exists "$official_feed" "$pkg"; then

            OFFICIAL_MAKEFILE="$(package_makefile "$official_feed" "$pkg")"
            OFFICIAL_VERSION="$(get_package_version "$OFFICIAL_MAKEFILE")"

            echo "官方来源: ${official_feed}/${pkg}"
            echo "官方版本: $OFFICIAL_VERSION"

            if [ "$THIRD_VERSION" = "$OFFICIAL_VERSION" ]; then
                echo "版本相同 -> 选择第三方 ${THIRD_SOURCE}/${pkg}"
            else
                echo "版本不同 -> 选择第三方 ${THIRD_SOURCE}/${pkg}"
                echo "原因: 第三方来源优先，不按版本号自动选择"
            fi

            remove_package_entry "$official_feed" "$pkg"

        fi

    done

done

###############################################################################
# 11. SmartDNS Rust Makefile 修复
###############################################################################

echo
echo "========================================"
echo "修复 SmartDNS Rust Makefile"
echo "========================================"

for smartdns_mk in \
    package/myapp/smartdns/package/openwrt/Makefile \
    package/myapp/smartdns/Makefile
do

    if [ -f "$smartdns_mk" ]; then

        sed -i \
            's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' \
            "$smartdns_mk"

        echo "已修复: $smartdns_mk"

    fi

done

###############################################################################
# 12. 自动添加 LuCI 中文语言包
###############################################################################

echo
echo "========================================"
echo "添加 LuCI 中文语言包"
echo "========================================"

if [ -f .config ]; then

    for pkg in $(
        grep '^CONFIG_PACKAGE_luci-app-.*=y' .config |
        sed 's/^CONFIG_PACKAGE_//;s/=y//' |
        sort -u
    ); do

        trans="luci-i18n-${pkg#luci-app-}"

        if grep -q \
            "^CONFIG_PACKAGE_${trans}-zh-cn=y" \
            .config 2>/dev/null; then
            continue
        fi

        if grep -rnq \
            "Package.*${trans}-zh-cn" \
            package feeds 2>/dev/null; then

            echo "添加中文语言包: ${trans}-zh-cn"

            echo \
                "CONFIG_PACKAGE_${trans}-zh-cn=y" \
                >> .config

        fi

    done

fi

###############################################################################
# 13. conntrack 调优
###############################################################################

echo
echo "========================================"
echo "设置 conntrack"
echo "========================================"

sed -i \
    '/^[[:space:]]*net\.netfilter\.nf_conntrack_max[[:space:]]*=/d' \
    package/base-files/files/etc/sysctl.conf

echo \
    'net.netfilter.nf_conntrack_max=655550' \
    >> package/base-files/files/etc/sysctl.conf

echo "nf_conntrack_max = 655550"

###############################################################################
# 14. Wi-Fi 首次启动自动开启
###############################################################################

echo
echo "========================================"
echo "设置 Wi-Fi 首次启动自动开启"
echo "========================================"

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/zz-enable-wifi <<'EOF'
#!/bin/sh

. /lib/functions.sh

# 等待无线配置真正出现（最多约 30 秒）
i=0

while [ $i -lt 30 ]; do

    [ -s /etc/config/wireless ] && break

    sleep 1
    i=$((i + 1))

done

# 仍不存在则尝试生成
[ -s /etc/config/wireless ] || wifi config 2>/dev/null || true

[ -s /etc/config/wireless ] || exit 0

config_load wireless

enable_all()
{
    local cfg="$1"
    uci -q set "wireless.${cfg}.disabled=0"
}

# 同时处理 wifi-device 和 wifi-iface
config_foreach enable_all wifi-device
config_foreach enable_all wifi-iface

uci -q commit wireless

# 拉起无线
wifi up 2>/dev/null || wifi 2>/dev/null || true

exit 0
EOF

chmod +x files/etc/uci-defaults/zz-enable-wifi

echo "Wi-Fi 首次启动自动开启已设置（带等待 + wifi up）"

###############################################################################
# 15. 最终第三方插件来源检查
###############################################################################

echo
echo "========================================"
echo "最终第三方插件来源检查"
echo "========================================"

for pkg in $MYAPP_PACKAGES; do

    [ -n "$pkg" ] || continue

    echo
    echo "[$pkg]"

    if [ -d package/myapp ]; then

        FOUND_MYAPP=""

        while IFS= read -r -d '' mf; do

            [ -f "$mf" ] || continue

            if grep -q \
                "^[[:space:]]*define[[:space:]]\+Package/${pkg}[[:space:]]*$" \
                "$mf" 2>/dev/null; then

                FOUND_MYAPP="$mf"
                break

            fi

        done < <(
            find package/myapp \
                -type f \
                -name Makefile \
                -print0 2>/dev/null || true
        )

        if [ -z "$FOUND_MYAPP" ] &&
           [ -f "package/myapp/${pkg}/Makefile" ]; then

            FOUND_MYAPP="package/myapp/${pkg}/Makefile"

        fi

        if [ -n "$FOUND_MYAPP" ]; then

            echo "  package/myapp"
            echo "  Makefile: $FOUND_MYAPP"
            echo "  version: $(get_package_version "$FOUND_MYAPP")"

        else

            echo "  WARNING: 未找到对应的独立源码 Makefile"

        fi

    fi

done

###############################################################################
# 16. dae / daed 最终来源检查
###############################################################################

echo
echo "========================================"
echo "dae / daed 最终来源检查"
echo "========================================"

for pkg in dae daed; do

    SMALL_DIR="package/feeds/small/${pkg}"
    SMALL_MAKEFILE="${SMALL_DIR}/Makefile"

    if [ ! -f "$SMALL_MAKEFILE" ]; then
        echo "ERROR: ${pkg} small 来源丢失"
        exit 1
    fi

    SMALL_REAL="$(readlink -f "$SMALL_DIR" 2>/dev/null || true)"
    FEED_REAL="$(readlink -f "feeds/small/${pkg}" 2>/dev/null || true)"

    if [ -z "$SMALL_REAL" ] || [ "$SMALL_REAL" != "$FEED_REAL" ]; then
        echo "ERROR: ${pkg} 来源不是 small"
        exit 1
    fi

    echo "✓ ${pkg}"
    echo "  来源: package/feeds/small/${pkg}"
    echo "  版本: $(get_package_version "$SMALL_MAKEFILE")"

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "small" ] && continue

        echo "ERROR: 发现其他 Feed 重复入口: ${feed}/${pkg}"
        exit 1

    done

done

echo "dae / daed 最终来源验证通过"

###############################################################################
# 17. rtp2httpd 最终来源检查
###############################################################################

echo
echo "========================================"
echo "rtp2httpd 最终来源检查"
echo "========================================"

for pkg in $RTP2HTTPD_PACKAGES; do

    STACKIA_DIR="package/feeds/rtp2httpd/${pkg}"
    STACKIA_SOURCE="feeds/rtp2httpd/openwrt-support/${pkg}"

    if [ ! -f "${STACKIA_DIR}/Makefile" ]; then
        echo "ERROR: ${pkg} stackia 官方安装入口丢失"
        exit 1
    fi

    STACKIA_REAL="$(readlink -f "$STACKIA_DIR" 2>/dev/null || true)"
    SOURCE_REAL="$(readlink -f "$STACKIA_SOURCE" 2>/dev/null || true)"

    if [ -z "$STACKIA_REAL" ] || [ "$STACKIA_REAL" != "$SOURCE_REAL" ]; then
        echo "ERROR: ${pkg} 实际来源不是 stackia 官方 Feed"
        exit 1
    fi

    echo "✓ ${pkg}"
    echo "  来源: stackia 官方 Feed"
    echo "  实际路径: ${STACKIA_REAL}"

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "rtp2httpd" ] && continue

        echo "ERROR: ${pkg} 发现其他 Feed 重复入口: ${feed}"
        exit 1

    done

done

echo "rtp2httpd stackia 官方来源验证通过"

###############################################################################
# 18. IPQ60xx 内核大小修改 + SKB Recycler
###############################################################################

echo
echo "========================================"
echo "修改 IPQ60xx 内核大小 / 开启 SKB Recycler"
echo "========================================"

# 18.1 修改内核大小
set_kernel_size()
{
    local image_file="./target/linux/qualcommax/image/ipq60xx.mk"

    if [ ! -f "$image_file" ]; then
        echo "WARNING: 未找到 $image_file"
        return 0
    fi

    # JDC AX1800 Pro 的内核大小修改为 12M
    sed -i \
        "/^define Device\/emmc-common/,/^endef/ s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/" \
        "$image_file"

    sed -i \
        "/^define Device\/nand-common/,/^endef/ s/^endef/\tKERNEL_SIZE := 8192k\nendef/" \
        "$image_file"

    sed -i \
        "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" \
        "$image_file"

    sed -i \
        "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" \
        "$image_file"

    sed -i \
        "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" \
        "$image_file"

    sed -i \
        "/^define Device\/link_nn6000-common/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" \
        "$image_file"

    sed -i \
        "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" \
        "$image_file"

    sed -i \
        "/^define Device\/linksys_mr7350/,/^endef/ s/^endef/\tIMAGE_SIZE := 12288k\nendef/" \
        "$image_file"

    echo "IPQ60xx 内核大小修改完成"
}

# 18.2 开启 SKB Recycler
enable_skb_recycler()
{
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        echo "WARNING: 未找到配置文件: $config_file"
        return 0
    fi

    # 防止重复配置
    sed -i '/^CONFIG_KERNEL_SKB_RECYCLER=/d' "$config_file"
    sed -i '/^CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=/d' "$config_file"

    cat >> "$config_file" <<EOF
CONFIG_KERNEL_SKB_RECYCLER=y
CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y
EOF

    echo "CONFIG_KERNEL_SKB_RECYCLER=y"
    echo "CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y"
}

# 执行内核修改
set_kernel_size

if [ -f .config ]; then
    enable_skb_recycler ".config"
else
    echo "WARNING: .config 不存在，跳过 SKB Recycler 配置"
fi

###############################################################################
# 19. DIY2 完成
###############################################################################

echo
echo "========================================"
echo "DIY2 核心配置完成"
echo "========================================"

###############################################################################
# 20. OpenAppFilter
###############################################################################

rm -rf feeds/packages/net/open-app-filter

git clone \
    https://github.com/destan19/OpenAppFilter \
    package/OpenAppFilter

###############################################################################
# 21. Go 26.x + OpenList2
###############################################################################

echo
echo "========================================"
echo "更新 Go 26.x / OpenList2"
echo "========================================"

rm -rf feeds/packages/lang/golang

git clone \
    https://github.com/sbwml/packages_lang_golang \
    -b 26.x \
    feeds/packages/lang/golang

git clone \
    https://github.com/sbwml/luci-app-openlist2 \
    package/openlist

###############################################################################
# 22. EasyTier
###############################################################################

git clone \
    https://github.com/EasyTier/luci-app-easytier \
    package/luci-app-easytier

###############################################################################
# 23. Lucky
###############################################################################

git clone \
    https://github.com/gdy666/luci-app-lucky \
    package/lucky

###############################################################################
# 24. QuickFile Nginx 配置修复
###############################################################################

echo
echo "========================================"
echo "修复 QuickFile Nginx 配置"
echo "========================================"

cat > feeds/packages/net/nginx-util/files/nginx.config <<'EOF'

config main global
	option uci_enable 'true'

config server '_lan'
	option server_name '_lan'
	list listen '80 default_server'
	list listen '[::]:80 default_server'
	list include 'conf.d/*.locations'
	option access_log 'off; # logd openwrt'
EOF

git clone \
    https://github.com/sbwml/luci-app-quickfile \
    package/quickfile

###############################################################################
# 25. LuCI 主题
###############################################################################

echo
echo "========================================"
echo "拉取 LuCI 主题"
echo "========================================"

# Fluent
git clone --depth=1 \
    https://github.com/LazuliKao/luci-theme-fluent \
    /tmp/luci-theme-fluent

cp -a /tmp/luci-theme-fluent/package/* package/

# Shadcn
git clone \
    https://github.com/eamonxg/luci-theme-shadcn \
    package/luci-theme-shadcn

# Argon
rm -rf feeds/luci/themes/luci-theme-argon

git clone \
    https://github.com/jerrykuku/luci-theme-argon \
    package/luci-theme-argon

###############################################################################
# 26. OpenClash Meta 内核
###############################################################################

echo
echo "========================================"
echo "添加 OpenClash Meta 内核"
echo "========================================"

curl -sL \
    -m 30 \
    --retry 2 \
    https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz \
    -o /tmp/clash.tar.gz

tar zxvf /tmp/clash.tar.gz -C /tmp >/dev/null 2>&1

chmod +x /tmp/clash >/dev/null 2>&1

mkdir -p \
    feeds/luci/applications/luci-app-openclash/root/etc/openclash/core

mv /tmp/clash \
    feeds/luci/applications/luci-app-openclash/root/etc/openclash/core/clash_meta \
    >/dev/null 2>&1

rm -rf /tmp/clash.tar.gz >/dev/null 2>&1

###############################################################################
# 27. 删除 DDNS 示例配置
###############################################################################

echo
echo "========================================"
echo "删除 DDNS 示例配置"
echo "========================================"

sed -i \
    '/myddns_ipv4/,$d' \
    feeds/packages/net/ddns-scripts/files/etc/config/ddns

###############################################################################
# 28. MT7986A CPU 频率显示修正
###############################################################################

echo
echo "========================================"
echo "修复 MT7986A CPU 频率显示"
echo "========================================"

sed -i \
    '/"mediatek"\/\*|"mvebu"\/\*)/i "mediatek/filogic")\n\tcpu_freq="2.0GHz" ;;' \
    package/emortal/autocore/files/generic/cpuinfo

###############################################################################
# 29. DIY2 全部完成
###############################################################################

echo
echo "========================================"
echo "DIY2 ALL OK"
echo "========================================"
