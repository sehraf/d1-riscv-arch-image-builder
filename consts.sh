#!/usr/bin/sh
export CROSS_COMPILE='riscv64-linux-gnu-'
export ARCH='riscv'
PWD="$(pwd)"
NPROC="$(nproc)"
export PWD
export NPROC

export ROOT_FS='archriscv-20210601.tar.zst'
export ROOT_FS_DL="https://archriscv.felixc.at/images/${ROOT_FS}"

# select 'arch', 'nezha_defconfig'
export KERNEL='nezha_defconfig'

# folder to mount rootfs
export MNT='mnt'
# folder to store compiled artifacts
export OUT_DIR="${PWD}/output"

# run as root
export SUDO='sudo'

# use arch-chroot?
export USE_CHROOT=1

# pinned commits (no notice when things change)
export COMMIT_BOOT0='0ad88bfdb723b1ac74cca96122918f885a4781ac' # from 28.02.2022
export COMMIT_UBOOT='7446a47204fd8923b99ced0091667979c4fd27fa' # equals d1-wip (06.04.2022)
export COMMIT_KERNEL='cc63db754b218d3ef9b529a82e04b66252e9bca1' # equals d1-wip-v5.18-rc1
export KERNEL_RELEASE='5.18.0-rc1-gcc63db754b21-dirty' # must match commit!
# use this (set to something != '') to override the check
export IGNORE_COMMITS=0

check_deps() {
    if ! which "${1}" > /dev/null ; then
        echo "Please install '${1}'"
        exit 1
    fi
}
