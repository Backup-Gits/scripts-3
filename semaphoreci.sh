#!/bin/bash

# Script by Lau <laststandrighthere@gmail.com>

# Usage: [cfs|eas|muqss] [gcc|clang] [defconfig]

# Functions

if [ "$3" == "" ]; then
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
            curl -s -X POST ${URL}sendSticker -d sticker="CAADAQADNgADWO60HuUx8T8ZaqhyAg" -d chat_id="$CHANNEL_ID"
            ;;
    esac
}

check()
{
    KERN_IMG="${DIR}/out/arch/arm64/boot/Image.gz-dtb"

    if ! [ -a $KERN_IMG ]; then
        echo -e "Kernel compilation failed, See buildlog to fix errors"
        exit 1
    fi

    cp $KERN_IMG ${DIR}/flasher
}

kernel()
{
    JOBS=$(grep -c '^processor' /proc/cpuinfo)
    export JOBS
    rm -rf out
    mkdir -p out

    case "$COMPILER" in
    gcc)
        make O=out $DEFCONFIG
        make O=out -j$JOBS
        ;;
    clang)
        #TODO
        ;;
    esac

    check

    cd ${DIR}/flasher
    rm -rf .git
    zip -r $ZIP_NAME ./
    tg file $ZIP_NAME
}

# Set up the enviroment

sudo install-package --update-new ccache bc bash git-core gnupg build-essential \
		zip curl make automake autogen autoconf autotools-dev libtool shtool python \
		m4 gcc libtool zlib1g-dev

DIR=$PWD
TYPE=$1
COMPILER=$2
DEFCONFIG="${3}_defconfig"

case "$COMPILER" in
    gcc)
        git clone https://github.com/kdrag0n/aarch64-elf-gcc --depth=2 gcc
        git clone https://github.com/kdrag0n/arm-eabi-gcc --depth=2 gcc32
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
    clang)
        #TODO
        ;;
esac

git clone https://github.com/laststandrighthere/flasher.git --depth=1 flasher

export ARCH=arm64 && SUBARCH=arm64
export KBUILD_BUILD_USER=vimb
export KBUILD_BUILD_HOST=drone

# Variables

HASH=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TEXT="[ VIMB 4.9 ] kernel new build!
At branch ${BRANCH}
Under commit ${HASH}"
ZIP_NAME="VIMB-${TYPE^^}-r${SEMAPHORE_BUILD_NUMBER}.zip"

# Main Process

tg msg "$TEXT"
kernel
tg sticker $STICKER

# End
