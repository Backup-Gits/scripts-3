#!/bin/bash

# Script by Lau <laststandrighthere@gmail.com>

# Usage: [gcc|clang] [tc_version] [defconfig] [aosp|miui]

# Functions

if [ "$4" == "" ]; then
    echo -e "Enter all the needed parameters"
    exit 1
fi

tg()
{
    ACTION=$1
    EXTRA=$2
    URL="https://api.telegram.org/bot${BOT_TOKEN}/"

    case "$ACTION" in
        msg)
            curl -X POST ${URL}sendMessage -d chat_id=$CHANNEL_ID -d text="$EXTRA"
            ;;
        file)
            cd ${DIR}/flasher
            curl -F chat_id=$CHANNEL_ID -F document=@$EXTRA ${URL}sendDocument
            ;;
        sticker)
            curl -s -X POST ${URL}sendSticker -d sticker="$EXTRA" -d chat_id="$CHANNEL_ID"
            ;;
    esac
}

check()
{
    KERN_IMG="${DIR}/out/arch/arm64/boot/Image.gz-dtb"

    if ! [ -a $KERN_IMG ]; then
        echo -e "Kernel compilation failed, See buildlogs to fix errors"
        tg file buildlogs.txt
        exit 1
    fi

    cp $KERN_IMG ${DIR}/flasher

    if [ "$TYPE" == "miui" ]; then
        WLAN_MOD="${DIR}/out/drivers/staging/prima/wlan.ko"
        cp $WLAN_MOD ${DIR}/flasher/modules/system/lib/modules/pronto/pronto_wlan.ko
    fi
}

zip_upload()
{
    ZIP_NAME="VIMB-${BRANCH^^}2-r${DRONE_BUILD_NUMBER}.zip"
    cd ${DIR}/flasher
    rm -rf .git
    zip -r $ZIP_NAME ./
    tg file $ZIP_NAME
}

kernel()
{
    JOBS=$(grep -c '^processor' /proc/cpuinfo)
    rm -rf out
    mkdir -p out

    START=$(date +"%s")

    case "$COMPILER" in
        gcc)
            make O=out $DEFCONFIG
            make O=out -j$JOBS 2>&1 | tee buildlogs.txt
            ;;
        clang)
            make O=out ARCH=arm64 ${DEFCONFIG}
            case "$TC_VER" in
                aosp)
                    make -j$JOBS O=out \
                            ARCH=arm64 \
                            CC="${DIR}/clang/clang-r353983c/bin/clang" \
                            CLANG_TRIPLE="aarch64-linux-gnu-" \
                            CROSS_COMPILE="${DIR}/gcc/bin/aarch64-linux-android-" \
                            CROSS_COMPILE_ARM32="${DIR}/gcc32/bin/arm-linux-androideabi-"
                    ;;
                proton)
                    export PATH="${DIR}/clang/bin:$PATH"
                    make -j$JOBS O=out \
                            ARCH=arm64 \
                            CC=clang \
                            CROSS_COMPILE=aarch64-linux-gnu- \
                            CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                            AR=llvm-ar \
                            NM=llvm-nm \
                            OBJCOPY=llvm-objcopy \
                            OBJDUMP=llvm-objdump \
                            STRIP=llvm-strip
                    ;;
            esac
            ;;
    esac

    END=$(date +"%s")
    DIFF=$((END - START))
    TIME="Job took $((DIFF / 60))m and $((DIFF % 60))s"

    check
    zip_upload
    tg msg "$TIME"
}

setup()
{
    case "$COMPILER" in
        gcc)
            case "$TC_VER" in
                9)
                    git clone https://github.com/kdrag0n/aarch64-elf-gcc --depth=3 gcc
                    git clone https://github.com/kdrag0n/arm-eabi-gcc --depth=3 gcc32
                    cd gcc
                    git checkout 14e746a95f594cf841bdf8c2e6122c274da7f70b
                    cd ../gcc32
                    git checkout 76c68effb613ff240ecad714f6c6f63368e91478
                    cd ..
                    CROSS_COMPILE="${DIR}/gcc/bin/aarch64-elf-"
                    CROSS_COMPILE_ARM32="${DIR}/gcc32/bin/arm-eabi-"
                    export CROSS_COMPILE
                    export CROSS_COMPILE_ARM32
                    ;;
                4.9)
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r39 --depth=1 gcc
                    CROSS_COMPILE="${DIR}/gcc/bin/aarch64-linux-android-"
                    export CROSS_COMPILE
                    ;;
            esac
            ;;
        clang)
            case "$TC_VER" in
                aosp)
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b ndk-r19 --depth=1 gcc
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b ndk-r19 --depth=1 gcc32
                    git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1 clang
                    cd clang
                    find . | grep -v 'clang-r353983c' | xargs rm -rf
                    cd ..
                    ;;
                proton)
                    git clone https://github.com/kdrag0n/proton-clang.git --depth=1 clang
                    ;;
            esac
            ;;
    esac

    case "$TYPE" in
        aosp)
            git clone https://github.com/laststandrighthere/flasher.git -b master --depth=1 flasher
            ;;
        miui)
            git clone https://github.com/laststandrighthere/flasher.git -b miui --depth=1 flasher
            ;;
    esac
}

main_msg()
{
    HASH=$(git rev-parse --short HEAD)
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    TEXT="[ VIMB 4.9 ] kernel new build!
    At branch ${BRANCH}
    Under commit ${HASH}"

    tg msg "$TEXT"
}

DIR=$PWD
COMPILER=$1
TC_VER=$2
DEFCONFIG="${3}_defconfig"
TYPE=$4

export ARCH=arm64 && SUBARCH=arm64
export KBUILD_BUILD_USER=vimb
export KBUILD_BUILD_HOST=builder

# Main Process

setup
main_msg
kernel
tg sticker $STICKER

# End
