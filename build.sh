#!/bin/bash

set -e

# download toolchain from https://opensource.samsung.com/uploadSearch?searchValue=toolchain 
TOOLCHAIN=$(realpath "/home/kokuban/PlentyofToolchain/toolchainZ4/prebuilts")

export PATH=$TOOLCHAIN/build-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/build-tools/path/linux-x86:$PATH
export PATH=$TOOLCHAIN/clang/host/linux-x86/clang-r416183b/bin:$PATH
export PATH=$TOOLCHAIN/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin:$PATH

echo $PATH

LTO=full

TARGET_DEFCONFIG=${1:-taro_gki_defconfig}

cd "$(dirname "$0")"

LOCALVERSION=-android12-Kokuban-Bronya-HYD9-KSU

if [ "$LTO" == "thin" ]; then
  LOCALVERSION+="-thin"
fi

ARGS="
CROSS_COMPILE=aarch64-linux-gnu-
CC=clang
ARCH=arm64
SUBARCH=arm64
LLVM=1 LLVM_IAS=1
LOCALVERSION=$LOCALVERSION
"

# build kernel
make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS} $TARGET_DEFCONFIG

./scripts/config --file out/.config \
  -d UH \
  -d RKP \
  -d KDP \
  -d SECURITY_DEFEX \
  -d INTEGRITY \
  -d FIVE \
  -d TRIM_UNUSED_KSYMS \

if [ "$LTO" = "thin" ]; then
  ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS}

cd out
if [ ! -d AnyKernel3 ]; then
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b taro
fi
cp arch/arm64/boot/Image AnyKernel3/zImage
name=Z4_kernel_`cat include/config/kernel.release`_`date '+%Y_%m_%d'`
cd AnyKernel3
zip -r ${name}.zip * -x *.zip
cd ..
cd AnyKernel3/tools
chmod +x libmagiskboot.so
lz4 boot.img.lz4
./libmagiskboot.so unpack boot.img ${name}.img
rm -f ./kernel
cp ../../arch/arm64/boot/Image ./kernel
./libmagiskboot.so repack boot.img ${name}.img
echo "boot.img output to $(realpath $name).img"
cd ..
cd ..
echo "AnyKernel3 package output to $(realpath $name).zip"