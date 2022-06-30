FROM archlinux:base

ADD 1_compile.sh 1_compile.sh
ADD 2_create_sd.sh 2_create_sd.sh
ADD consts.sh consts.sh
ADD licheerv_linux_defconfig licheerv_linux_defconfig
ADD uboot-makefile.patch uboot-makefile.patch
ADD upload_kernel.sh upload_kernel.sh

RUN sed -i 's/^/Server = https:\/\/mirrors.tuna.tsinghua.edu.cn\/archlinux\/$repo\/os\/$arch&\/\n/g' /etc/pacman.d/mirrorlist
RUN pacman -Syy --noconfirm riscv64-linux-gnu-gcc swig cpio python3 python-setuptools base-devel bc git
RUN sh 1_compile.sh output


CMD "/bin/bash"
