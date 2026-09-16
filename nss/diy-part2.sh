name: ImmortalWrt-NSS

on:
  workflow_dispatch:
  schedule:
    - cron: "16 16 * * *"

permissions:
  contents: write

env:
  DIY_P1_SH: nss/diy-part1.sh
  DIY_P2_SH: nss/diy-part2.sh
  TZ: Asia/Shanghai

jobs:
  build:
    name: 编译 ${{ matrix.name }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        include:
          - name: IPQ807x
            repo_url: https://github.com/LiBwrt/LibWrt
            repo_branch: 25.12-nss
            config: nss/immortalwrt/ipq807x.config
            config_final: nss/immortalwrt/ipq807x.config.final

          # - name: H68K
          #   repo_url: https://github.com/LiBwrt/LibWrt
          #   repo_branch: 25.12-nss
          #   config: nss/immortalwrt/h68k.config
          #   config_final: nss/immortalwrt/h68k.config.final

          # - name: X86
          #   repo_url: https://github.com/immortalwrt/immortalwrt
          #   repo_branch: master
          #   config: nss/immortalwrt/x86.config
          #   config_final: nss/immortalwrt/x86.config.final

    steps:
      - name: 检出仓库
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: 释放Ubuntu磁盘空间
        uses: coder-xiaomo/free-disk-space@main
        with:
          tool-cache: false
          android: true
          dotnet: true
          haskell: true
          large-packages: true
          docker-images: true
          swap-storage: true

      - name: 安装依赖
        run: |
          sudo apt-get update
          sudo apt-get full-upgrade -y
          sudo apt-get install -y \
            ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
            bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
            g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
            libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
            libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
            ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
            python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
            upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

      - name: 设置时间
        run: |
          echo "DATE=$(date +%Y%m%d)" >> "$GITHUB_ENV"
          echo "DATETIME=$(date '+%Y-%m-%d %H:%M:%S')" >> "$GITHUB_ENV"

      - name: 克隆源码
        run: |
          git clone --depth=1 \
            -b "${{ matrix.repo_branch }}" \
            "${{ matrix.repo_url }}" openwrt

      - name: 检查 OpenWrt 源码树
        working-directory: openwrt
        run: |
          echo "========================================"
          echo "检查 OpenWrt 源码树"
          echo "========================================"
          echo "TOPDIR: $(pwd)"

          test -f Makefile
          test -f scripts/feeds
          test -d package
          test -d target
          test -d scripts

          echo
          echo "Makefile:"
          ls -lh Makefile

          echo
          echo "scripts/feeds:"
          ls -lh scripts/feeds

          echo
          echo "目录结构:"
          ls -ld \
            feeds \
            package \
            target \
            scripts

          echo
          echo "✅ OpenWrt 源码树检查通过"

      - name: DIY 第一阶段
        run: |
          if [ -f "$DIY_P1_SH" ]; then
            echo "========================================"
            echo "执行 DIY 第一阶段"
            echo "========================================"
            bash "$DIY_P1_SH"
          else
            echo "⚠️ 未找到 $DIY_P1_SH，跳过"
          fi

      - name: 更新 feeds
        working-directory: openwrt
        run: |
          echo "========================================"
          echo "更新 OpenWrt feeds"
          echo "========================================"

          ./scripts/feeds update -a
          ./scripts/feeds install -a

          echo
          echo "✅ feeds 更新完成"

      - name: 导入配置
        run: |
          echo "========================================"
          echo "导入编译配置"
          echo "========================================"

          test -f "${{ matrix.config }}"

          cp -f "${{ matrix.config }}" openwrt/.config

          echo "配置文件：${{ matrix.config }}"
          echo "目标文件：openwrt/.config"

          echo
          echo "配置大小："
          wc -l openwrt/.config

          echo
          echo "✅ 配置导入完成"

      - name: DIY 第二阶段
        working-directory: openwrt
        run: |
          echo "========================================"
          echo "执行 DIY 第二阶段"
          echo "========================================"
          echo "当前工作目录：$(pwd)"
          echo "DIY 脚本：../$DIY_P2_SH"

          test -f "../$DIY_P2_SH"

          echo
          echo "检查关键文件："
          test -f Makefile
          test -f scripts/feeds
          test -f .config

          echo "Makefile       : OK"
          echo "scripts/feeds  : OK"
          echo ".config        : OK"

          echo
          echo "开始执行 DIY2..."
          bash "../$DIY_P2_SH"

          echo
          echo "✅ DIY 第二阶段完成"

      - name: 生成最终配置
        working-directory: openwrt
        run: |
          echo "========================================"
          echo "生成最终配置"
          echo "========================================"

          make defconfig

          echo
          echo "✅ make defconfig 完成"

      - name: 保存最终配置
        run: |
          echo "========================================"
          echo "保存最终配置"
          echo "========================================"

          mkdir -p "final-config/${{ matrix.name }}"

          cp openwrt/.config \
            "final-config/${{ matrix.name }}/.config"

          echo "${{ matrix.config_final }}" \
            > "final-config/${{ matrix.name }}/TARGET"

          echo
          echo "最终配置："
          ls -lh "final-config/${{ matrix.name }}/"

      - name: 开始编译
        working-directory: openwrt
        run: |
          echo "========================================"
          echo "下载编译依赖"
          echo "========================================"

          make -j$(nproc) download

          echo
          echo "========================================"
          echo "开始正式编译"
          echo "========================================"

          make -j$(nproc) V=s

      - name: 获取设备名称
        run: |
          d=$(grep -E '^CONFIG_TARGET_.*_DEVICE_' openwrt/.config \
            | head -n1 \
            | sed -E 's/CONFIG_TARGET_([^=]+)=y/\1/' || true)

          echo "DEVICE_NAME=${d:-${{ matrix.name }}}" >> "$GITHUB_ENV"

          echo "设备名称：${d:-${{ matrix.name }}}"

      - name: 上传完整编译目录
        uses: actions/upload-artifact@v7
        with:
          name: 编译文件-${{ matrix.name }}-${{ env.DATE }}
          path: openwrt/bin/
          retention-days: 7
          compression-level: 1

      - name: 整理固件
        run: |
          echo "========================================"
          echo "整理固件"
          echo "========================================"

          mkdir -p firmware

          cp -a openwrt/bin/targets/. firmware/

          cp openwrt/.config firmware/.config

          echo
          echo "固件目录："
          find firmware -maxdepth 3 -type f -printf '%p\n' | sort

      - name: 上传固件
        uses: actions/upload-artifact@v7
        with:
          name: 固件-${{ matrix.name }}-${{ env.DATE }}
          path: firmware/
          retention-days: 7
          compression-level: 1

      - name: 发布 Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ matrix.name }}-${{ env.DATE }}
          name: "${{ matrix.name }} 固件 ${{ env.DATE }}"
          body: |
            ## 编译信息

            项目：${{ matrix.name }}
            源码：${{ matrix.repo_url }}
            分支：${{ matrix.repo_branch }}
            设备：${{ env.DEVICE_NAME }}
            配置：${{ matrix.config }}
            最终配置：${{ matrix.config_final }}
            编译时间：${{ env.DATETIME }}

          files: firmware/**
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: 上传最终配置
        uses: actions/upload-artifact@v7
        with:
          name: 最终配置-${{ matrix.name }}
          path: final-config/${{ matrix.name }}/
          retention-days: 7

  save-config:
    name: 保存最终配置
    needs: build
    if: always()
    runs-on: ubuntu-latest

    steps:
      - name: 检出仓库
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: 下载最终配置
        uses: actions/download-artifact@v5
        with:
          pattern: 最终配置-*
          path: final-configs
          merge-multiple: false

      - name: 写入最终配置
        run: |
          for d in final-configs/最终配置-*; do
            [ -f "$d/.config" ] || continue
            [ -f "$d/TARGET" ] || continue

            t=$(cat "$d/TARGET")

            mkdir -p "$(dirname "$t")"

            cp "$d/.config" "$t"
          done

      - name: 提交最终配置
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

          git add nss/immortalwrt/*.config.final

          git diff --cached --quiet && exit 0

          git commit -m "更新最终配置 ${GITHUB_RUN_NUMBER}"

          git push origin HEAD:main

  cleanup:
    name: 清理旧工作流
    needs: [build, save-config]
    if: always()
    runs-on: ubuntu-latest

    steps:
      - name: 清理工作流
        uses: Mattraks/delete-workflow-runs@main
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          repository: ${{ github.repository }}
          retain_days: 7
          keep_minimum_runs: 3
