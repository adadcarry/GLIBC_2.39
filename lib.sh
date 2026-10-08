#!/bin/bash

set -e  # 遇到错误退出
set -o pipefail

[[ -f /etc/apt/sources.list.d/noble-temp.list ]] && rm -f /etc/apt/sources.list.d/noble-temp.list

## 只针对 Ubuntu 22.04
source /etc/os-release
if [[ "$ID" == "ubuntu" ]]; then
    if [[ "$VERSION_ID" == "20.04" ]] || [[ "$VERSION_ID" == "22.04" ]]; then
        echo "✅ 当前系统是 Ubuntu 20.04 | 22.04"
    fi
else
    echo "❌ 当前系统不是 Ubuntu 20.04 | 22.04"
    exit 1
fi


## 删除可能影响 apt 的仓库
[[ -f /etc/apt/sources.list.d/openvpn-aptrepo.list ]] && mv /etc/apt/sources.list.d/openvpn-aptrepo.list /etc/apt/sources.list.d/openvpn-aptrepo.list.bak

echo "检查当前 GLIBC 版本..."
if strings /lib/x86_64-linux-gnu/libc.so.6 | grep -q "GLIBC_2.39"; then
    echo "当前已是 GLIBC 2.39，无需升级。"
    exit 0
fi


echo "开始安装依赖..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 \
    libevent-dev libboost-dev libsqlite3-dev libminiupnpc-dev libnatpmp-dev \
    libzmq3-dev systemtap-sdt-dev dirmngr gnupg gpg

echo "导入 Ubuntu Noble GPG 密钥并添加临时源..."
KEYRING_PATH="/usr/share/keyrings/ubuntu-noble.gpg"
SOURCE_LIST="/etc/apt/sources.list.d/noble-temp.list"

echo "deb [signed-by=$KEYRING_PATH] http://archive.ubuntu.com/ubuntu noble main universe" | tee "$SOURCE_LIST"

gpg --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 || { echo "获取密钥失败"; exit 1; }
gpg --export 3B4FE6ACC0B21F32 | tee "$KEYRING_PATH" > /dev/null

gpg --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C || { echo "获取密钥失败"; exit 1; }
gpg --export 871920D1991BC93C | tee -a "$KEYRING_PATH" > /dev/null

echo "更新源并安装目标库..."
apt update 
DEBIAN_FRONTEND=noninteractive apt install -y -t noble libjansson4 libstdc++6

echo "清理临时源..."
rm -f "$SOURCE_LIST"
# apt update

echo "验证 GLIBC 升级结果..."

sleep 5
strings /lib/x86_64-linux-gnu/libc.so.6 | grep GLIBC_
if strings /lib/x86_64-linux-gnu/libc.so.6 | grep -q "GLIBC_2.39"; then
    echo "✅ GLIBC 升级成功！"
    exit 0
else
    echo "❌ GLIBC 未成功升级，请检查问题。"
    exit 1
fi
