# /bin/bash

# prepare image file
dd if=/dev/zero of=./archlinux_riscv.img bs=1M count=2048
sudo losetup /dev/loop17 ./archlinux_riscv.img

# compile files
docker run --name build_riscv riscv-arch-image:${1}
docker cp build_riscv:/home/runner/work/d1-riscv-arch-image-builder/d1-riscv-arch-image-builder/output .

# create linux image
sudo CI_BUILD=1 ./2_create_sd.sh /dev/loop17

sync
sudo losetup -d /dev/loop17
tar -zcvf archlinux_riscv.img.tar.gz archlinux_riscv.img
