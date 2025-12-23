#!/usr/bin/sh

if [ -f /etc/os-release ]; then
    . /etc/os-release
fi

# Dependency list
DEP_LIST_arch="riscv64-linux-gnu-gcc swig cpio"
DEP_LIST_debian="gcc-riscv64-linux-gnu bison flex python3-dev libssl-dev"

export CROSS_COMPILE='riscv64-linux-gnu-'
export ARCH='riscv'
PWD="$(pwd)"
NPROC="$(nproc)"
export PWD
export NPROC

export ROOT_FS='archriscv-2025-06-12.tar.zst'
export ROOT_FS_DL="https://archriscv.felixc.at/images/${ROOT_FS}"

# select 'arch', 'defconfig'
export KERNEL='defconfig'
# export KERNEL='arch'

# Device Tree:
# In the current pinned U-Boot Commit the following device trees are available
# for the D1:
# sun20i-d1-clockworkpi-v3.14
# sun20i-d1-devterm-v3.14
# sun20i-d1-dongshan-nezha-stu
# sun20i-d1-lichee-rv-86-panel-480p
# sun20i-d1-lichee-rv-86-panel-720p
# sun20i-d1-lichee-rv-dock
# sun20i-d1-lichee-rv
# sun20i-d1-mangopi-mq-pro
# sun20i-d1-nezha
export DEVICE_TREE=sun20i-d1-lichee-rv-dock

# folder to mount rootfs
export MNT="${PWD}/mnt"
# folder to store compiled artifacts
export OUT_DIR="${PWD}/output"

# run as root
export SUDO='sudo'

# use arch-chroot?
export USE_CHROOT=1

# use extlinux ('extlinux') or boot.scr ('script') for loading the kernel?
export BOOT_METHOD='extlinux'

export VERSION_OPENSBI='1.7'
export VERSION_KERNEL='6.18'

export SOURCE_OPENSBI="https://github.com/riscv-software-src/opensbi/releases/download/v${VERSION_OPENSBI}/opensbi-${VERSION_OPENSBI}-rv-bin.tar.xz"
export SOURCE_UBOOT='https://github.com/MartinHerren/u-boot'
export SOURCE_KERNEL="https://github.com/torvalds/linux/archive/refs/tags/v${VERSION_KERNEL}.tar.gz"
export SOURCE_RTL8723='https://github.com/amazingfate/rtl8723ds.git'
# https://github.com/karabek/xradio

# pinned commits (no notice when things change)
export COMMIT_UBOOT='d35a660d5c26559a4e10e30e2780a566629c13e9' # equals d1-2022-10-31
export TAG_UBOOT='d1-wip-python-fix'
export TAG_RTL8723='fix-6.18'
# use this (set to something != 0) to override the check
export IGNORE_COMMITS=0
export DEBUG='n'

check_deps() {
    case $ID in
    arch)
        if ! pacman -Qi "${1}" >/dev/null; then
            echo "Please install '${1}'"
            exit 1
        fi
    ;;
    debian)
        if ! dpkg -l "${1}" >/dev/null; then
            echo "Please install '${1}'"
            exit 1
        fi
    ;;
    *)
        echo "This script is running on not supported distro!"
        exit 1
    ;;
    esac
}

if [ -n "${CI_BUILD}" ]; then
    export USE_CHROOT=0
fi
