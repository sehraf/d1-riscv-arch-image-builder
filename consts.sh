#!/usr/bin/sh
export CROSS_COMPILE='riscv64-linux-gnu-'
export ARCH='riscv'
PWD="$(pwd)"
NPROC="$(nproc)"
export PWD
export NPROC

export ROOT_FS='archriscv-20210601.tar.zst'
export ROOT_FS_DL="https://mirror.iscas.ac.cn/archriscv/images/${ROOT_FS}"

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

# use extlinux ('extlinux') or boot.scr ('script')?
export BOOT_METHOD='extlinux'

# pinned commits (no notice when things change)
export COMMIT_BOOT0='882671fcf53137aaafc3a94fa32e682cb7b921f1' # from 14.06.2022
export COMMIT_UBOOT='afc07cec423f17ebb4448a19435292ddacf19c9b' # equals d1-wip (28.05.2022)
export COMMIT_KERNEL='fe178cf0153d98b71cb01a46c8cc050826a17e77' # equals riscv/d1-wip head
export KERNEL_TAG='riscv/d1-wip'
export KERNEL_RELEASE='5.19.0-rc1-gfe178cf0153d-dirty' # must match commit!
# use this (set to something != 0) to override the check
export IGNORE_COMMITS=0

check_deps() {
    if ! pacman -Qi "${1}" > /dev/null ; then
        echo "Please install '${1}'"
        exit 1
    fi
}
