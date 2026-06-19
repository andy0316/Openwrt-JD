#!/usr/bin/env bash
set -Eeuo pipefail

# 1. 基础系统设定：修改默认IP & 固件名称 & 编译署名
sed -i 's/192.168.1.1/192.168.199.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='ImmortalWrt'/g" package/base-files/files/bin/config_generate
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
            _('Firmware Version'),\n \
            E('span', {}, [\n \
                (L.isObject(boardinfo.release)\n \
                ? boardinfo.release.description + ' / '\n \
                : '') + (luciversion || '') + ' / ',\n \
            E('a', {\n \
                href: 'https://github.com/laipeng668/openwrt-ci-roc/releases',\n \
                target: '_blank',\n \
                rel: 'noopener noreferrer'\n \
                }, [ 'Built by Roc Custom $(date "+%Y-%m-%d %H:%M:%S")' ])\n \
            ]),#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# 2. 调整 NSS 驱动 q6_region 内存区域预留大小为 64MB
sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# 3. 调节 IPQ60XX 的 1.5GHz 频率电压至 0.95V
sed -i 's/opp-microvolt = <937500>;/opp-microvolt = <950000>;/' target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch

# 4. 移除不再需要的第三方包，防止冲突
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/aria2
rm -rf feeds/packages/net/nginx
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

# Git 稀疏克隆函数
function git_sparse_clone() {
  local branch="$1"
  local repourl="$2"
  local repodir
  shift 2

  repodir="$(basename "${repourl%.git}")"
  rm -rf "$repodir"
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"
  (
    cd "$repodir"
    git sparse-checkout set "$@"
    mv -f "$@" ../package
  )
  rm -rf "$repodir"
}

# 5. 保留核心优化的组件
git_sparse_clone aria2 https://github.com/laipeng668/packages net/aria2
mv -f package/aria2 feeds/packages/net/aria2
git_sparse_clone nginx https://github.com/laipeng668/packages net/nginx
mv -f package/nginx feeds/packages/net/nginx
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
mv -f package/ariang feeds/packages/net/ariang
git_sparse_clone master https://github.com/laipeng668/packages lang/golang
mv -f package/golang feeds/packages/lang/golang

# 6. 强制清理默认代理组件
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

# 7. 从官方精准拉取目标组件
git clone --depth=1 -b master https://github.com/vernesong/OpenClash package/luci-app-openclash
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/luci-app-easytier
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/linkease/istore.git package/istore
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2

./scripts/feeds update -a
./scripts/feeds install -a