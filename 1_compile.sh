#!/usr/bin/sh

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
    [ "${IGNORE_COMMITS}" != '0' ] || [ "${_COMMIT}" = "${_COMMIT_IS}" ] || ( echo "Commit mismatch"; exit 1)
}

patch_config() {
    key="$1"
    val="$2"

    if [ -z "$key" ] || [ -z "$val" ] ; then
        exit 1
    fi

    echo "CONFIG_${key}=${val}" >> linux-build/.config
}

for DEP in riscv64-linux-gnu-gcc swig cpio ; do
    check_deps ${DEP}
done

mkdir -p build
mkdir -p "${OUT_DIR}"
cd build

if [ ! -f "${OUT_DIR}/boot0_sdcard_sun20iw1p1.bin" ] ; then
    # build Boot0
    DIR='sun20i_d1_spl'
    clean_dir ${DIR}

    git clone "${SOURCE_BOOT0}"
    cd "${DIR}"
    git checkout "${COMMIT_BOOT0}"
    make CROSS_COMPILE="${CROSS_COMPILE}" p=sun20iw1p1 mmc
    cd ..
    cp ${DIR}/nboot/boot0_sdcard_sun20iw1p1.bin "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/u-boot.toc1" ] ; then
    # build OpenSBI
    DIR='opensbi'
    clean_dir ${DIR}

    git clone "${SOURCE_OPENSBI}" -b d1-wip
    cd ${DIR}
    make CROSS_COMPILE="${CROSS_COMPILE}" PLATFORM=generic FW_PIC=y FW_OPTIONS=0x2
    cd ..
    # cp opensbi/build/platform/generic/firmware/fw_dynamic.bin ${OUT_DIR}

    # build U-Boot
    DIR='u-boot'
    clean_dir ${DIR}

    git clone "${SOURCE_UBOOT}"
    cd ${DIR}
    git checkout d1-wip
    pin_commit "${COMMIT_UBOOT}"
    # patch for binutils 2.38
    git apply ../../uboot-makefile.patch

    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" nezha_defconfig
    # make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} lichee_rv_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" -j "${NPROC}"
    cd ..
    # cp u-boot/arch/riscv/dts/sun20i-d1-lichee-rv-dock.dtb ${OUT_DIR}

    # build u-boot toc
    cat << EOF > licheerv_toc1.cfg
[opensbi]
file = opensbi/build/platform/generic/firmware/fw_dynamic.bin
addr = 0x40000000
[dtb]
file = u-boot/arch/riscv/dts/sun20i-d1-lichee-rv-dock.dtb
addr = 0x44000000
[u-boot]
file = u-boot/u-boot-nodtb.bin
addr = 0x4a000000
EOF
    ${DIR}/tools/mkimage -T sunxi_toc1 -d licheerv_toc1.cfg u-boot.toc1
    cp u-boot.toc1 "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/boot.scr" ] ; then
    DIR='u-boot'

    # https://andreas.welcomes-you.com/boot-sw-debian-risc-v-lichee-rv/
    cat << 'EOF' > bootscr.txt
setenv bootargs earlycon=sbi console=ttyS0,115200n8 root=/dev/mmcblk0p2 rootwait cma=96M
echo "Loading kernel from mmc 0:1 to address ${kernel_addr_r}"
load mmc 0:1 ${kernel_addr_r} Image
echo "Booting kernel with bootargs as $bootargs; and fdtcontroladdr is $fdtcontroladdr"
if load mmc 0:1 ${ramdisk_addr_r} /initramfs-linux.img; then
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdtcontroladdr}
else
    booti ${kernel_addr_r} - ${fdtcontroladdr}
fi;
# booti ${kernel_addr_r} - ${fdtcontroladdr}
# ramdisk_addr_r
EOF
    ${DIR}/tools/mkimage -T script -C none -O linux -A "${ARCH}" -d bootscr.txt boot.scr
    rm bootscr.txt
    cp boot.scr "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/Image" ] || [ ! -f "${OUT_DIR}/Image.gz" ] ; then
    # TODO use archlinux-riscv kernel

    # build kernel
    DIR='linux'
    clean_dir ${DIR}
    clean_dir ${DIR}-build

    # try not to clone complete linux source tree here!
    git clone --depth 1 "${SOURCE_KERNEL}" -b "${KERNEL_TAG}"
    cd ${DIR}
    pin_commit "${COMMIT_KERNEL}"
    # fix kernel version
    touch .scmversion
    cd ..

    # LicheeRV defconfig
    # mkdir -p linux-build/arch/riscv/configs
    # cp ../licheerv_linux_defconfig linux-build/arch/riscv/configs/licheerv_defconfig
    # make ARCH=${ARCH} -C linux O=../linux-build licheerv_defconfig

    case "$KERNEL" in
        'nezha_defconfig')
            # Nezha defconfig
	        # setting kernel release name
            echo "CONFIG_LOCALVERSION=${KERNEL_RELEASE}" >> ${DIR}/arch/riscv/configs/nezha_defconfig
	    echo "CONFIG_LOCALVERSION_AUTO=n" >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # enable WiFi
            echo 'CONFIG_WIRELESS=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_CFG80211=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # enable /proc/config.gz
            echo 'CONFIG_IKCONFIG=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_IKCONFIG_PROC=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # There is no LAN. so let there be USB-LAN
            echo 'CONFIG_USB_NET_DRIVERS=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_CATC=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_KAWETH=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_PEGASUS=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_RTL8150=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_RTL8152=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_LAN78XX=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_USBNET=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_AX8817X=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_AX88179_178A=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDCETHER=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDC_EEM=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDC_NCM=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_HUAWEI_CDC_NCM=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDC_MBIM=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_DM9601=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_SR9700=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_SR9800=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_SMSC75XX=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_SMSC95XX=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_GL620A=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_NET1080=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_PLUSB=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_MCS7830=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_RNDIS_HOST=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDC_SUBSET_ENABLE=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CDC_SUBSET=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_ALI_M5632=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_AN2720=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_BELKIN=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_ARMLINUX=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_EPSON2888=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_KC2190=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_ZAURUS=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CX82310_ETH=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_KALMIA=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_QMI_WWAN=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_INT51X1=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_IPHETH=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_SIERRA_NET=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_VL600=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_CH9200=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_NET_AQC111=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_USB_RTL8153_ECM=m' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # enable systemV IPC (needed by fakeroot during makepkg)
            echo 'CONFIG_SYSVIPC=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_SYSVIPC_SYSCTL=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # enable swap
            echo 'CONFIG_SWAP=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_ZSWAP=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
	        #enable Cedrus VPU Drivers
            echo 'CONFIG_MEDIA_SUPPORT=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_MEDIA_CONTROLLER=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_MEDIA_CONTROLLER_REQUEST_API=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_V4L_MEM2MEM_DRIVERS=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            echo 'CONFIG_VIDEO_SUNXI_CEDRUS=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            # debug options
            if [ $DEBUG = 'y' ]; then
                echo 'CONFIG_DEBUG_INFO=y' >> ${DIR}/arch/riscv/configs/nezha_defconfig
            fi

            make ARCH="${ARCH}" -C linux O=../linux-build nezha_defconfig
        ;;

    # Archlinux PR #1001 https://github.com/felixonmars/archriscv-packages/pull/1001 config
    # https://github.com/felixonmars/archriscv-packages/blob/6689a4fdcd76dbbab777803493873f65e127e3e6/linux-nezha-git/config
    # mkdir -p linux-build/arch/riscv/configs
    # cp ../arch_nezha_git_config linux-build/arch/riscv/configs/licheerv_defconfig
    # make ARCH=${ARCH} -C linux O=../linux-build licheerv_defconfig

        'arch')
            # https://archriscv.felixc.at/repo/core/linux-5.17.3.arch1-1-riscv64.pkg.tar.zst
            # setup linux-build
            make ARCH="${ARCH}" -C linux O=../linux-build nezha_defconfig
            # deploy config
            cp ../../linux-5.17.3.arch1-1-riscv64.config linux-build/.config
            # apply defaults
            make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" -j "${NPROC}" -C linux-build olddefconfig

            # patch config
            patch_config ARCH_FLATMEM_ENABLE y
            patch_config RISCV_DMA_NONCOHERENT y
            patch_config RISCV_SBI_V01 y
            patch_config HVC_RISCV_SBI y
            patch_config SERIAL_EARLYCON_RISCV_SBI y
            patch_config BROKEN_ON_SMP y

            patch_config ARCH_SUNXI y
            patch_config ERRATA_THEAD y

            patch_config DRM_SUN4I m
            patch_config DRM_SUN6I_DSI m
            patch_config DRM_SUN8I_DW_HDMI m
            patch_config DRM_SUN8I_MIXER m
            patch_config DRM_SUN4I_HDMI n
            patch_config DRM_SUN4I_BACKEND n

            patch_config CRYPTO_DEV_SUN8I_CE y
            patch_config CRYPTO_DEV_SUN8I_CE_HASH y
            patch_config CRYPTO_DEV_SUN8I_CE_PRNG y
            patch_config CRYPTO_DEV_SUN8I_CE_TRNG y

            patch_config SPI_SUN6I m
            patch_config PHY_SUN4I_USB m

            patch_config SUN50I_IOMMU y
            patch_config SUN8I_DE2_CCU y
            patch_config SUN8I_DSP_REMOTEPROC y
            patch_config SUN8I_THERMAL y
            patch_config SUNXI_WATCHDOG y

            patch_config GPIO_SYSFS y
            # patch_config EXPORT y
            # patch_config VMLINUX_MAP y

            # these needs to be built-in (probably)
            patch_config EXT4_FS y
            patch_config MMC y
            patch_config MMC_SUNXI y

            # apply defaults
            make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" -j "${NPROC}" -C linux-build olddefconfig
        ;;

        *)
            echo "Unknown kernel option '$KERNEL'"
            exit 1
        ;;
    esac

    # compile it!
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" -j "${NPROC}" -C linux-build
    cp linux-build/arch/riscv/boot/Image.gz "${OUT_DIR}"
    cp linux-build/arch/riscv/boot/Image "${OUT_DIR}"
fi

if [ ! -f "${OUT_DIR}/8723ds.ko" ] ; then
    # build WiFi driver
    DIR='rtl8723ds'
    clean_dir ${DIR}

    git clone https://github.com/lwfinger/rtl8723ds.git
    cd ${DIR}
    make CROSS_COMPILE="${CROSS_COMPILE}" ARCH="${ARCH}" KSRC=../linux-build -j "${NPROC}"  modules || true
    cd ..
    cp ${DIR}/8723ds.ko "${OUT_DIR}"
fi
