# /bin/bash
dd if=/dev/zero of=./archlinux_riscv.img bs=1M count=2048
sudo losetup /dev/loop17 ./archlinux_riscv.img
docker run --name build_riscv riscv-arch-image:${1}
docker cp build_riscv:/home/runner/work/riscv-arch-image-builder/riscv-arch-image-builder/output .
pwd
echo 'ls'
ls 
echo 'ls output'
ls output
echo 'ls riscv-arch-image-builder'
ls riscv-arch-image-builder
echo 'ls riscv-arch-image-builder/output'
ls riscv-arch-image-builder/output
sudo CI_BUILD=1 ./2_create_sd.sh /dev/loop17
tar -zcvf archlinux_riscv.img.tar.gz archlinux_riscv.img
