#!/usr/bin/env sh

set -e
# set -x

. ./consts.sh

clean_dir() {
    _DIR=${1}

    # kind of dangerous ...
    [ "${_DIR}" = '/' ] && exit 1
    rm -rf "${_DIR}" || true
}

pin_commit() {
    _COMMIT=${1}
    _COMMIT_IS=$(git rev-parse HEAD)
    [ "${IGNORE_COMMITS}" != '0' ] || [ "${_COMMIT}" = "${_COMMIT_IS}" ] || (
        echo "Commit mismatch"
        exit 1
    )
}

patch_config() {
    # must be called when inside the `linux` dir
    key="$1"
    val="$2"

    if [ -z "$key" ] || [ -z "$val" ]; then
        exit 1
    fi

    case "$val" in
    'y')
        _OP='--enable'
        ;;
    'n')
        _OP='--disable'
        ;;
    'm')
        _OP='--module'
        ;;
    *)
        echo "Unknown kernel option value '$KERNEL'"
        exit 1
        ;;
    esac

    if [ -z "$_OP" ]; then
        exit 1
    fi

    ./scripts/config --file "../${DIR}-build/.config" "$_OP" "$key"
}

for DEP in riscv64-linux-gnu-gcc swig cpio; do
    check_deps ${DEP}
done

mkdir -p build
mkdir -p "${OUT_DIR}"
cd build

if [ ! -f "${OUT_DIR}/fw_dynamic.bin" ]; then
    # build OpenSBI
    clean_dir "opensbi-${VERSION_OPENSBI}-rv-bin"

    curl -O -L ${SOURCE_OPENSBI}
    tar -xf "opensbi-${VERSION_OPENSBI}-rv-bin.tar.xz"
    rm "opensbi-${VERSION_OPENSBI}-rv-bin.tar.xz"
    cp "opensbi-${VERSION_OPENSBI}-rv-bin/share/opensbi/lp64/generic/firmware/fw_dynamic.bin" "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/u-boot-sunxi-with-spl.bin" ]; then
    # build U-Boot
    DIR='u-boot'
    clean_dir ${DIR}

    git clone --depth 1 "${SOURCE_UBOOT}" -b "${TAG_UBOOT}"
    cd ${DIR}
    pin_commit "${COMMIT_UBOOT}"

    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" nezha_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" OPENSBI="${OUT_DIR}/fw_dynamic.bin" -j "${NPROC}"
    cd ..
    cp ${DIR}/u-boot-sunxi-with-spl.bin "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/Image" ] || [ ! -f "${OUT_DIR}/Image.gz" ]; then
    # build kernel
    DIR='linux'
    clean_dir ${DIR}
    clean_dir ${DIR}-build
    clean_dir ${DIR}-modules

    curl -O -L ${SOURCE_KERNEL}
    tar -xf "v${VERSION_KERNEL}.tar.gz"
    rm "v${VERSION_KERNEL}.tar.gz"
    mv linux-${VERSION_KERNEL} ${DIR}
    cd ${DIR}

    # fix kernel version
    touch .scmversion

    case "$KERNEL" in
    'defconfig')
        # generate default config
        make ARCH="${ARCH}" O=../linux-build defconfig

        # patch necessary options
        # patch_config LOCALVERSION_AUTO n #### not necessary with a release kernel

        # enable WiFi
        patch_config CFG80211 m

        # There is no LAN, so let there be USB-LAN
        patch_config USB_NET_DRIVERS m
        patch_config USB_CATC m
        patch_config USB_KAWETH m
        patch_config USB_PEGASUS m
        patch_config USB_RTL8150 m
        patch_config USB_RTL8152 m
        patch_config USB_LAN78XX m
        patch_config USB_USBNET m
        patch_config USB_NET_AX8817X m
        patch_config USB_NET_AX88179_178A m
        patch_config USB_NET_CDCETHER m
        patch_config USB_NET_CDC_EEM m
        patch_config USB_NET_CDC_NCM m
        patch_config USB_NET_HUAWEI_CDC_NCM m
        patch_config USB_NET_CDC_MBIM m
        patch_config USB_NET_DM9601 m
        patch_config USB_NET_SR9700 m
        patch_config USB_NET_SR9800 m
        patch_config USB_NET_SMSC75XX m
        patch_config USB_NET_SMSC95XX m
        patch_config USB_NET_GL620A m
        patch_config USB_NET_NET1080 m
        patch_config USB_NET_PLUSB m
        patch_config USB_NET_MCS7830 m
        patch_config USB_NET_RNDIS_HOST m
        patch_config USB_NET_CDC_SUBSET_ENABLE m
        patch_config USB_NET_CDC_SUBSET m
        patch_config USB_ALI_M5632 y
        patch_config USB_AN2720 y
        patch_config USB_BELKIN y
        patch_config USB_ARMLINUX y
        patch_config USB_EPSON2888 y
        patch_config USB_KC2190 y
        patch_config USB_NET_ZAURUS m
        patch_config USB_NET_CX82310_ETH m
        patch_config USB_NET_KALMIA m
        patch_config USB_NET_QMI_WWAN m
        patch_config USB_NET_INT51X1 m
        patch_config USB_IPHETH m
        patch_config USB_SIERRA_NET m
        patch_config USB_VL600 m
        patch_config USB_NET_CH9200 m
        patch_config USB_NET_AQC111 m
        patch_config USB_RTL8153_ECM m

        # enable systemV IPC (needed by fakeroot during makepkg)
        patch_config SYSVIPC y
        patch_config SYSVIPC_SYSCTL y

        # enable swap
        patch_config SWAP y
        patch_config ZSWAP y

        # enable Cedrus VPU Drivers
        patch_config MEDIA_SUPPORT y
        patch_config MEDIA_CONTROLLER y
        patch_config MEDIA_CONTROLLER_REQUEST_API y
        patch_config V4L_MEM2MEM_DRIVERS y
        patch_config VIDEO_SUNXI_CEDRUS y

        # enable binfmt_misc
        patch_config BINFMT_MISC y

        # debug options
        if [ $DEBUG = 'y' ]; then
            patch_config DEBUG_INFO y
        fi

        # default anything new
        make ARCH="${ARCH}" O=../linux-build olddefconfig

        ;;

    'arch')
        # generate default config (and directory)
        make ARCH="${ARCH}" O=../linux-build defconfig

        # deploy Arch's confi
        # TODO keep this up to date automatically somehow
        cp ../../6.3.5-arch1.config ../linux-build/.config

        # THIS DOESN'T WORK RIGHT NOW
        # TODO

        # default anything new
        make ARCH="${ARCH}" O=../linux-build olddefconfig

        ;;

    *)
        echo "Unknown kernel option '$KERNEL'"
        exit 1
        ;;
    esac

    # compile it!
    cd ..
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" -j "${NPROC}" -C ${DIR}-build

    KERNEL_RELEASE=$(make ARCH="${ARCH}" -C ${DIR}-build -s kernelversion)
    echo "compiled kernel version '$KERNEL_RELEASE'"

    cp ${DIR}-build/arch/riscv/boot/Image.gz "${OUT_DIR}"
    cp ${DIR}-build/arch/riscv/boot/Image "${OUT_DIR}"

    # prepare modules
    mkdir ${DIR}-modules
    make ARCH="${ARCH}" INSTALL_MOD_PATH="../${DIR}-modules" KERNELRELEASE="${KERNEL_RELEASE}" -C ${DIR}-build modules_install
    mv ${DIR}-modules/lib/modules "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/8723ds.ko" ]; then
    # build WiFi driver
    DIR='rtl8723ds'
    clean_dir ${DIR}

    git clone "${SOURCE_RTL8723}"
    cd ${DIR}
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" KSRC=../linux-build -j "${NPROC}" modules || true
    cd ..
    cp ${DIR}/8723ds.ko "${OUT_DIR}"
fi
