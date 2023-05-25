#!/bin/bash

# set -e

# Reset commit
curl -s "https://api.github.com/repos/dopaemon/kernel_xiaomi_sweet" \
  -H "Accept: application/vnd.github.v3+json" \
  -o /tmp/repo_info.json
default_branch=$(jq -r '.default_branch' /tmp/repo_info.json)
curl -s "https://api.github.com/repos/dopaemon/kernel_xiaomi_sweet/commits/$default_branch" \
  -H "Accept: application/vnd.github.v3+json" \
  -o /tmp/commit_info.json
latest_commit_sha=$(jq -r '.sha' /tmp/commit_info.json)

echo "Latest commit SHA: $latest_commit_sha"
git reset --hard $latest_commit_sha

if [ "$1" = "OSS" ]; then
    git config --local user.name "dopaemon"
    git config --local user.email "polarisdp@gmail.com"
    git apply $PWD/scripts/github/ln8k.patch
elif [ "$1" = "OSS-LN8000" ]; then
    echo "oss"
elif [ "$1" = "MIUI" ]; then
    git config --local user.name "dopaemon"
    git config --local user.email "polarisdp@gmail.com"
    git apply $PWD/scripts/github/ln8k.patch
    git apply $PWD/scripts/github/miui.patch
elif [ "$1" = "MIUI-LN8000" ]; then
    git config --local user.name "dopaemon"
    git config --local user.email "polarisdp@gmail.com"
    git apply $PWD/scripts/github/miui.patch
else
    echo "OUT"
fi

## Kernel Version
linuxversion=$(make kernelversion)

sed -i "s/vLINUX_VERSION/$linuxversion/g" $PWD/scripts/Anykernel3/banner

## Copy this script inside the kernel directory
HERE=$PWD
KERNEL_DEFCONFIG=sweet-perf_defconfig
ANYKERNEL3_DIR=$PWD/scripts/Anykernel3
FINAL_KERNEL_ZIP=DoraCore-Kernel-$1-$(date '+%Y%m%d').zip
export PATH="$HOME/cosmic/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_COMPILER_STRING="$($HOME/cosmic/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

if ! [ -d "$HOME/cosmic" ]; then
echo "Cosmic clang not found! Cloning..."
if ! git clone -q https://gitlab.com/PixelOS-Devices/playgroundtc.git --depth=1 -b 17 ~/cosmic; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

# Speed up build process
MAKE="./makeparallel"

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "***********************************************$nocol"
make $KERNEL_DEFCONFIG O=out
make -j$(nproc --all) O=out \
                              ARCH=arm64 \
                              LLVM=1 \
                              LLVM_IAS=1 \
                              AR=llvm-ar \
                              NM=llvm-nm \
                              LD=ld.lld \
                              OBJCOPY=llvm-objcopy \
                              OBJDUMP=llvm-objdump \
                              STRIP=llvm-strip \
                              CC=clang \
                              CROSS_COMPILE=aarch64-linux-gnu- \
                              CROSS_COMPILE_ARM32=arm-linux-gnueabi

echo "**** Verify Image.gz-dtb & dtbo.img ****"
ls $PWD/out/arch/arm64/boot/Image.gz-dtb
ls $PWD/out/arch/arm64/boot/dtbo.img
ls $PWD/out/arch/arm64/boot/dtb.img

# Anykernel 3 time!!
# echo "**** Verifying AnyKernel3 Directory ****"
# ls $ANYKERNEL3_DIR
# echo "**** Removing leftovers ****"
# rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
# rm -rf $ANYKERNEL3_DIR/dtbo.img
# rm -rf $ANYKERNEL3_DIR/dtb.img
# rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP

rm -rf $ANYKERNEL3_DIR/*

git checkout $latest_commit_sha $ANYKERNEL3_DIR/

echo "**** Copying Image.gz-dtb & dtbo.img ****"
cp $PWD/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dtbo.img $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dtb.img $ANYKERNEL3_DIR/

echo "**** Time to zip up! ****"
mkdir -p $HERE/ZIPOUT
cd $ANYKERNEL3_DIR/
zip -r9 "$FINAL_KERNEL_ZIP" * -x README $FINAL_KERNEL_ZIP
mv -v $ANYKERNEL3_DIR/*.zip $HERE/ZIPOUT/
echo "**** Done, here is your sha1 ****"
cd $HERE

rm -rf $ANYKERNEL3_DIR

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
