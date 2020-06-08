#!/bin/bash

# Script by Lau <laststandrighthere@gmail.com>
#
# Usage: [Group/Channel ID] [Bot Token] [Action] [Extra]
#
# Action  ->  Extra
# ---------------------
# msg     ->  text
# file    ->  filename
# sticker ->  stickerid
#

if [ "$4" == "" ]; then
    echo -e "Enter all the needed parameters"
    exit 1
fi

CHANNEL_ID=$1
BOT_TOKEN=$2
ACTION=$3
EXTRA=$4

URL="https://api.telegram.org/bot${BOT_TOKEN}/"

case "$ACTION" in
    msg)
        curl  \
        -X POST ${URL}sendMessage  \
        -d chat_id=$CHANNEL_ID  \
        -d text=$EXTRA
        ;;
    file)
        curl  \
        -F chat_id=$CHANNEL_ID  \
        -F document=@$EXTRA ${URL}sendDocument
        ;;
    sticker)
        curl  \
        -X POST ${URL}sendSticker  \
        -d chat_id=$CHANNEL_ID \
        -d sticker=$EXTRA
        ;;
esac

# End
