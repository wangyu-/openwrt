#!/bin/bash
BIN_DIR="../bin/targets/ipq807x/generic/"
BUILD_DIR="../build_dir/target-aarch64_cortex-a53_musl/linux-ipq807x_generic/"
STAGING_DIR_HOST="../staging_dir/host/"
KERNEL_IMG="netgear_rax120-fit-uImage.itb"
ROOTFS_IMG="root.squashfs"

# copy root.squashfs and kernel to current dir
cp ${BUILD_DIR}/${ROOTFS_IMG} ./rootfs.img
cp ${BUILD_DIR}/${KERNEL_IMG} ./kernel.itb

# prepare a dummy uimage header with empty squashfs, to cheat the uboot
mkdir -p ./dummy_squashfs_root
mksquashfs dummy_squashfs_root  dummy.squashfs -comp xz -b 262144 -no-xattrs
${STAGING_DIR_HOST}/bin/mkimage -A arm64 -O linux -C lzma -T kernel -a 0x40908000 -e 0x40908000 -n 'Linux-5.15' -d ./dummy.squashfs ./dummy.uImage

# pad kernel to multiple of 128k with minus 64
cp ./kernel.itb ./kernel.itb.new
KERNEL_SIZE=`wc -c ./kernel.itb|awk '{print $1}'`
echo ORIGINAL_SIZE=${KERNEL_SIZE}
KERNEL_SIZE_NEW=`echo "(${KERNEL_SIZE}/1024/128+1)*1024*128-64"|bc`
echo NEW_SIZE=${KERNEL_SIZE_NEW}
dd if=/dev/zero of=kernel.itb.new bs=1 count=0 seek=${KERNEL_SIZE_NEW}

# append the dummy uimage header with empty squashfs
cat kernel.itb.new dummy.uImage > combined.img

# pad the image to size of kernel partition
# 30408704 is 0x1d00000, the kernel partition size
cp combined.img combined.img.new
dd if=/dev/zero of=combined.img.new bs=1 count=0 seek=30408704

# append the real rootfs image
cat combined.img.new rootfs.img > combined_again.img
rm -f ./final.img
${STAGING_DIR_HOST}/bin/mkdniimg -B RAX120 -v 1.2.3.28 -r "" -H 29765589+0+512+1024+4x4+8x8  -i combined_again.img -o final.img

