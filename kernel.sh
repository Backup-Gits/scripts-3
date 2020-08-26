#!/bin/bash

# Script by Lau <laststandrighthere@gmail.com>

# Usage: [zip name] [gcc|clang] [tc_ver] [*_defconfig] [aosp|miui] [CI] [device ID]

# Functions

if [ "$7" == "" ]; then
    echo "Enter all the needed parameters"
    exit 1
fi

tg()
{
    ACTION=$1
    EXTRA=$2
    URL="https://api.telegram.org/bot$BOT_TOKEN/"

    case "$ACTION" in
        msg)
            curl \
            -d parse_mode=HTML \
            -X POST ${URL}sendMessage \
            -d chat_id=$CHANNEL_ID \
            -d text="$EXTRA"
            ;;
        file)
            curl \
            -F chat_id=$CHANNEL_ID \
            -F document=@$EXTRA ${URL}sendDocument \
            ;;
        sticker)
            curl \
            -X POST ${URL}sendSticker \
            -d sticker="$EXTRA" \
            -d chat_id="$CHANNEL_ID"
            ;;
    esac
}

check()
{
    KERN_IMG="$DIR/out/arch/arm64/boot/Image.gz-dtb"
    PRIMA="$DIR/flasher/modules/system/lib/modules/pronto/pronto_wlan.ko"

    if ! [ -a $KERN_IMG ]; then
        tg msg "Compilation failed, check logs"
        tg file $DIR/logs.log
        tg sticker $STICKER
        exit 1
    fi

    cp $KERN_IMG $DIR/flasher

    if [ "$TYPE" == "miui" ]; then
        WLAN_MOD="$DIR/out/drivers/staging/prima/wlan.ko"
        cp $WLAN_MOD $PRIMA
    fi
}

zip_upload()
{
    if [ $CI == "drone" ]; then
        ZIP_NAME="${NAME}-${BRANCH}-r${DRONE_BUILD_NUMBER}.zip"
    elif [ $CI == "semaphore" ]; then
        ZIP_NAME="${NAME}-${BRANCH}-r${SEMAPHORE_BUILD_NUMBER}.zip"
    fi

    cd $DIR/flasher
    rm -rf .git
    zip -r $ZIP_NAME ./
    tg file $ZIP_NAME
}

kernel()
{
    JOBS=$(grep -c '^processor' /proc/cpuinfo)
    rm -rf out .git
    mkdir -p out

    START=$(date +"%s")

    case "$COMPILER" in
        gcc)
            make O=out $DEFCONFIG
            make O=out -j$JOBS 2>&1 | tee logs.log
            ;;
        clang)
            make O=out $DEFCONFIG
            case "$TC_VER" in
                aosp)
                    make -j$JOBS O=out \
                        CC=clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-android- \
                        CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee logs.log
                    ;;
                proton)
                    make -j$JOBS O=out \
                        CC=clang \
                        CROSS_COMPILE=aarch64-linux-gnu- \
                        CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee logs.log
                    ;;
            esac
            ;;
    esac

    END=$(date +"%s")
    DIFF=$((END - START))
    TIME="Build took $((DIFF / 60))m and $((DIFF % 60))s"

    check
    zip_upload
    sleep 2
    tg file $DIR/logs.log
    tg msg "$TIME"
    tg sticker $STICKER
}

setup()
{
    if [ "$CI" == "semaphore" ]; then
        sudo install-package --update-new \
            ccache bc bash git-core gnupg build-essential zip curl make \
            automake autogen autoconf autotools-dev libtool shtool python m4 \
            gcc libtool zlib1g-dev
    fi

    case "$COMPILER" in
        gcc)
            case "$TC_VER" in
                arm)
                    git clone https://github.com/RaphielGang/aarch64-none-elf-9.x --depth=1 gcc
                    git clone https://github.com/RaphielGang/arm-none-eabi-9.x --depth=1 gcc32
                    export CROSS_COMPILE="$DIR/gcc/bin/aarch64-none-elf-"
                    export CROSS_COMPILE_ARM32="$DIR/gcc32/bin/arm-none-eabi-"
                    ;;
                9.1)
                    git clone https://github.com/laststandrighthere/aarch64-elf-gcc --depth=1 -b 9.1 gcc
                    git clone https://github.com/laststandrighthere/arm-eabi-gcc --depth=1 -b 9.1 gcc32
                    export CROSS_COMPILE="$DIR/gcc/bin/aarch64-elf-"
                    export CROSS_COMPILE_ARM32="$DIR/gcc32/bin/arm-eabi-"
                    ;;
                9.3)
                    git clone https://github.com/laststandrighthere/arm64-gcc -b 9.3 --depth=1 gcc
                    git clone https://github.com/laststandrighthere/arm32-gcc -b 9.3 --depth=1 gcc32
                    export CROSS_COMPILE="$DIR/gcc/bin/aarch64-elf-"
                    export CROSS_COMPILE_ARM32="$DIR/gcc32/bin/arm-eabi-"
                    ;;
                4.9)
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r39 --depth=1 gcc
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r39 --depth=1 gcc32
                    export CROSS_COMPILE="$DIR/gcc/bin/aarch64-linux-android-"
                    export CROSS_COMPILE_ARM32="$DIR/gcc32/bin/arm-linux-androideabi-"
                    ;;
            esac
            ;;
        clang)
            case "$TC_VER" in
                aosp)
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b ndk-r19 --depth=1 gcc
                    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b ndk-r19 --depth=1 gcc32
                    git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1 clang
                    export PATH="$DIR/clang/clang-r377782d/bin:$DIR/gcc/bin:$DIR/gcc32/bin:$PATH"
                    export KBUILD_COMPILER_STRING="$($DIR/clang/clang-r377782d/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')";
                    ;;
                proton)
                    git clone https://github.com/kdrag0n/proton-clang.git --depth=1 clang
                    export PATH="$DIR/clang/bin:$PATH"
                    export KBUILD_COMPILER_STRING="$($DIR/clang/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')";
                    ;;
            esac
            ;;
    esac

    case "$TYPE" in
        aosp)
            case "$FLASHER" in
                vince)
                    git clone https://github.com/laststandrighthere/flasher -b ak3 --depth=1 flasher
                ;;
                whyred)
                    git clone https://github.com/laststandrighthere/flasher -b whyred --depth=1 flasher
                ;;
            esac
            ;;
        miui)
            git clone https://github.com/laststandrighthere/flasher -b miui --depth=1 flasher
            ;;
    esac
}

main_msg()
{
    TEXT="New kernel build!%0AAt branch <code>$BRANCH</code>%0AUnder commit <code>$HASH</code>"
    tg msg "$TEXT"
}

DIR=$PWD
NAME=$1
COMPILER=$2
TC_VER=$3
DEFCONFIG="${4}_defconfig"
TYPE=$5
CI=$6
FLASHER=$7
HASH=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git log --pretty=format:'%h : %s' -1)

export ARCH=arm64 && SUBARCH=arm64
export KBUILD_BUILD_USER=sleepy
export KBUILD_BUILD_HOST=builder

# Main Process -------

setup
main_msg
kernel

# End ----------------
