#!/bin/bash
#
# 第三方插件 / 依赖 / 来源优先级处理
#
# 常规来源优先级：
#   1. package/myapp 独立第三方源码
#   2. DIY1 添加的第三方集合源
#   3. 官方 feeds
#
# dae / daed 特殊指定：
#   1. kenzok8/small
#   2. 不允许其他 feeds 覆盖
#
# rtp2httpd 特殊指定：
#   1. stackia 官方 rtp2httpd Feed
#   2. 不允许其他 feeds 覆盖
#
# 其他配置保持原样
#

set -e

echo "DIY2 - H68K + iStoreOS 24.10"
echo "第三方插件 / 依赖 / 来源优先"

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
echo "拉取/更新 核心依赖与 PassWall 组件"
echo "========================================"

# 1.2 移除官方旧库并拉取 PassWall
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall

rm -rf package/passwall-packages package/passwall-luci

git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci


echo "==== [diy-part2] 修复 rust download-ci-llvm 404 ===="
RUST_MK="feeds/packages/lang/rust/Makefile"
if [ -f "$RUST_MK" ]; then
  sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' "$RUST_MK"
  if grep -q 'download-ci-llvm=false' "$RUST_MK"; then
    echo "    已设置 llvm.download-ci-llvm=false"
  else
    echo "    [警告] 未匹配到 download-ci-llvm=true，可能上游已修改或路径变化"
    grep -n 'download-ci-llvm' "$RUST_MK" || true
  fi
else
  echo "    [警告] 未找到 $RUST_MK，跳过"
fi









# 拉取 kenzok8 Go 1.27
rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang -b 1.27 feeds/packages/lang/golang

# 1.3 刷新并注册新拉取的包索引
echo "更新并安装新依赖索引..."

# 更新 DIY1 添加的 stackia 官方 rtp2httpd Feed
./scripts/feeds update rtp2httpd

# 保留原有依赖安装逻辑
./scripts/feeds install -p packages golang || true
./scripts/feeds install -f microsocks || true
./scripts/feeds install -a

###############################################################################
# 1.4 rtp2httpd 强制使用 stackia 官方 Feed
#
# 指定来源：
#   feeds/rtp2httpd/openwrt-support/rtp2httpd
#   feeds/rtp2httpd/openwrt-support/luci-app-rtp2httpd
#
# 处理方式：
#   1. 检查 stackia 官方 Feed 源码
#   2. 删除其他 feeds 中的同名安装入口
#   3. 只从 stackia 官方 Feed 安装
#   4. 验证实际软链接目标
#   5. 检查其他 feeds 是否存在重复入口
#
# 不允许其他 feeds 覆盖。
###############################################################################

echo
echo "========================================"
echo "锁定 rtp2httpd 来源：stackia 官方 Feed"
echo "========================================"

RTP2HTTPD_PACKAGES="
rtp2httpd
luci-app-rtp2httpd
"

# 第一步：确认 stackia 官方 Feed 已更新
if [ ! -d feeds/rtp2httpd ]; then
    echo "ERROR: stackia 官方 rtp2httpd Feed 不存在"
    exit 1
fi

# 第二步：确认官方软件包源码存在
for pkg in $RTP2HTTPD_PACKAGES; do

    SOURCE="feeds/rtp2httpd/openwrt-support/${pkg}"

    if [ ! -f "${SOURCE}/Makefile" ]; then
        echo "ERROR: stackia 官方 Feed 缺少 ${pkg}"
        echo "检查路径: ${SOURCE}/Makefile"
        exit 1
    fi

    echo "确认官方源码存在: ${SOURCE}"

done

# 第三步：删除其他 feeds 中的同名安装入口
#
# 注意：
# 这里只删除 package/feeds 下的安装软链接，
# 不删除 feeds 中的原始源码。
#
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

# 第四步：只从 stackia 官方 Feed 安装
./scripts/feeds install -p rtp2httpd \
    rtp2httpd \
    luci-app-rtp2httpd

# 第五步：验证官方安装入口
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

# 第六步：检查其他 feeds，不允许存在重复安装入口
for pkg in $RTP2HTTPD_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "rtp2httpd" ] && continue

        echo "ERROR: ${pkg} 发现其他 Feed 重复入口：${feed}"
        exit 1

    done

done

echo
echo "rtp2httpd stackia 官方来源锁定完成"

###############################################################################
# 2. 第三方依赖预处理
###############################################################################

echo
echo "========================================"
echo "第三方依赖预处理"
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

package_entry_exists()
{
    local feed="$1"
    local pkg="$2"
    local entry="package/feeds/${feed}/${pkg}"

    [ -e "$entry" ] || [ -L "$entry" ]
}

remove_package_entry()
{
    local feed="$1"
    local pkg="$2"
    local entry="package/feeds/${feed}/${pkg}"

    if [ -e "$entry" ] || [ -L "$entry" ]; then
        echo "删除安装入口: ${feed}/${pkg}"
        rm -f "$entry"
    fi
}

package_makefile()
{
    local feed="$1"
    local pkg="$2"
    local makefile="package/feeds/${feed}/${pkg}/Makefile"

    if [ -f "$makefile" ]; then
        readlink -f "$makefile" 2>/dev/null || true
    fi
}

is_enabled()
{
    local pkg="$1"

    grep -Eq \
        "^CONFIG_PACKAGE_${pkg}=(y|m)" \
        .config 2>/dev/null
}

###############################################################################
# 2.1 获取包版本函数
#
# 修复原脚本函数定义晚于首次调用的问题
###############################################################################

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
# 2.2 明确要求移除的官方依赖入口
###############################################################################

for pkg in $REMOVE_OFFICIAL_DEPS; do

    [ -n "$pkg" ] || continue

    echo "明确要求：移除官方依赖入口 -> $pkg"

    for official_feed in $OFFICIAL_FEEDS; do
        remove_package_entry "$official_feed" "$pkg"
    done

done

###############################################################################
# 2.3 dae / daed 核心强制使用 kenzok8/small
#
# 指定来源：
#   dae  -> feeds/small/dae
#   daed -> feeds/small/daed
#
# 处理方式：
#   1. 检查 small 源码
#   2. 删除所有 feeds 中已有的同名安装入口
#   3. 只建立 small 来源软链接
#   4. 验证实际链接目标
#   5. 检查 package/myapp 是否存在同名核心包
#
# 不允许其他 feeds 覆盖。
# luci-app-daede 不在本段强制修改范围内。
###############################################################################

echo
echo "========================================"
echo "锁定 dae / daed 核心来源：kenzok8/small"
echo "========================================"

DAE_CORE_PACKAGES="
dae
daed
"

###############################################################################
# 第一步：确认 small feed 源码存在
###############################################################################

for pkg in $DAE_CORE_PACKAGES; do

    SMALL_SOURCE="feeds/small/${pkg}"

    if [ ! -f "${SMALL_SOURCE}/Makefile" ]; then
        echo "ERROR: small feed 中不存在 ${pkg}"
        echo "检查路径: ${SMALL_SOURCE}/Makefile"
        exit 1
    fi

    echo "确认 small 源码存在: ${SMALL_SOURCE}"

done

###############################################################################
# 第二步：检查 package/myapp 是否存在同名核心包
###############################################################################

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

###############################################################################
# 第三步：删除所有 feeds 中已有的 dae / daed 安装入口
###############################################################################

echo
echo "清理其他 feeds 中的 dae / daed 安装入口..."

for pkg in $DAE_CORE_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        echo "删除旧安装入口: ${feed}/${pkg}"

        rm -rf "$entry"

    done

done

###############################################################################
# 第四步：只建立 small 来源软链接
###############################################################################

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

    SMALL_VERSION="$(get_package_version "${SMALL_ENTRY}/Makefile")"

    echo
    echo "✓ ${pkg}"
    echo "  指定来源: small/${pkg}"
    echo "  实际路径: ${SMALL_REAL}"
    echo "  软件包版本: ${SMALL_VERSION}"

done

###############################################################################
# 第五步：检查所有其他 feeds，不允许重复入口
###############################################################################

for pkg in $DAE_CORE_PACKAGES; do

    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "small" ] && continue

        echo "ERROR: 发现其他 feed 重复入口: ${feed}/${pkg}"
        exit 1

    done

done

echo
echo "dae / daed 核心来源锁定完成"

###############################################################################
# 3. H68K DTS 处理
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
# 4. 扫描 package/myapp 真正的 Package
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
# 5. 收集当前 .config 中实际启用的 Package
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
# 6. 独立第三方插件优先
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
# 7. 第三方集合源优先 (THIRD_PARTY_FEEDS > OFFICIAL_FEEDS)
###############################################################################

echo
echo "========================================"
echo "第三方集合源优先"
echo "========================================"

for pkg in $CONFIG_PACKAGES; do

    [ -n "$pkg" ] || continue

    # dae / daed 使用 small 专属来源，不参与普通优先级处理
    case "$pkg" in
        dae|daed)
            echo "跳过普通来源处理: $pkg（已锁定 small）"
            continue
            ;;
    esac

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
                echo "版本相同 -> 选择: 第三方 ${THIRD_SOURCE}/${pkg}"
            else
                echo "版本不同 -> 选择: 第三方 ${THIRD_SOURCE}/${pkg}"
                echo "原因: 第三方来源优先，不按版本号自动选择"
            fi

            remove_package_entry "$official_feed" "$pkg"

        fi

    done

done

###############################################################################
# 8. SmartDNS Rust Makefile 修复
###############################################################################

echo
echo "========================================"
echo "修复 SmartDNS Rust Makefile"
echo "========================================"

if [ -f package/myapp/smartdns/package/openwrt/Makefile ]; then

    sed -i \
        's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' \
        package/myapp/smartdns/package/openwrt/Makefile

    echo "已修复: package/myapp/smartdns/package/openwrt/Makefile"

fi

if [ -f package/myapp/smartdns/Makefile ]; then

    sed -i \
        's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' \
        package/myapp/smartdns/Makefile

    echo "已修复: package/myapp/smartdns/Makefile"

fi

###############################################################################
# 9. 自动添加 LuCI 中文语言包
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
# 10. conntrack 调优
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
# 11. Wi-Fi 首次启动自动开启
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
# 12. 最终来源检查
###############################################################################

echo
echo "========================================"
echo "最终第三方插件来源检查"
echo "========================================"

for pkg in $MYAPP_PACKAGES; do

    [ -n "$pkg" ] || continue

    echo
    echo "[$pkg]"

    if [ -d "package/myapp" ]; then

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
# 12.1 dae / daed 最终来源检查
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

    # 检查所有 feeds，不允许存在其他同名入口
    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "small" ] && continue

        echo "ERROR: 发现其他 feed 重复入口: ${feed}/${pkg}"
        exit 1

    done

done

echo "dae / daed 最终来源验证通过"

###############################################################################
# 12.2 rtp2httpd 最终来源检查
###############################################################################

echo
echo "========================================"
echo "rtp2httpd 最终来源检查"
echo "========================================"

for pkg in rtp2httpd luci-app-rtp2httpd; do

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

    # 检查其他 feeds，不允许存在同名安装入口
    for entry in package/feeds/*/"$pkg"; do

        [ -e "$entry" ] || [ -L "$entry" ] || continue

        feed="${entry#package/feeds/}"
        feed="${feed%%/*}"

        [ "$feed" = "rtp2httpd" ] && continue

        echo "ERROR: ${pkg} 发现其他 Feed 重复入口：${feed}"
        exit 1

    done

done

echo "rtp2httpd stackia 官方来源验证通过"

###############################################################################
# 13. IPQ60xx 内核大小修改 + SKB Recycler
###############################################################################

echo
echo "========================================"
echo "修改 IPQ60xx 内核大小 / 开启 SKB Recycler"
echo "========================================"

###############################################################################
# 修改内核大小
###############################################################################

set_kernel_size() {

    # 修改 JDC AX1800 Pro 的内核大小为 12M
    image_file='./target/linux/qualcommax/image/ipq60xx.mk'

    if [ ! -f "$image_file" ]; then
        echo "WARNING: 未找到 $image_file"
        return 0
    fi

    sed -i "/^define Device\/emmc-common/,/^endef/ s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/" "$image_file"

    sed -i "/^define Device\/nand-common/,/^endef/ s/^endef/\tKERNEL_SIZE := 8192k\nendef/" "$image_file"

    sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"

    sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"

    sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"

    sed -i "/^define Device\/link_nn6000-common/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"

    sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" "$image_file"

    sed -i "/^define Device\/linksys_mr7350/,/^endef/ s/^endef/\tIMAGE_SIZE := 12288k\nendef/" "$image_file"

    echo "IPQ60xx 内核大小修改完成"
}

###############################################################################
# 开启内存回收补丁
###############################################################################

enable_skb_recycler() {

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

###############################################################################
# 执行内核修改
###############################################################################

set_kernel_size

if [ -f .config ]; then
    enable_skb_recycler ".config"
else
    echo "WARNING: .config 不存在，跳过 SKB Recycler 配置"
fi

###############################################################################
# 14. DIY2 完成
###############################################################################

echo
echo "========================================"
echo "DIY2 OK"
echo "========================================"
