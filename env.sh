#!/usr/bin/env bash
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# SPDX-License-Identifier: GPL-3.0-or-later

# Colors
black='\e[0;30m'
blue='\e[0;34m'
green='\e[0;32m'
cyan='\e[0;36m'
red='\e[0;31m'
purple='\e[0;35m'
brown='\e[0;33m'
lightgray='\e[0;37m'
darkgray='\e[1;30m'
lightblue='\e[1;34m'
lightgreen='\e[1;32m'
lightcyan='\e[1;36m'
lightred='\e[1;31m'
lightpurple='\e[1;35m'
yellow='\e[1;33m'
white='\e[1;37m'
nc='\e[0m'

# Default configurations

# Sourcedir
export SRCDIR="${KERNELDIR}"
export OUTDIR="${KERNELDIR}/out"

# AnyKernel and Aroma Location
export ANYKERNEL="${KERNELDIR}/chewy/aroma/anykernel/"
export AROMA="${KERNELDIR}/chewy/aroma/"

# Wot Arch
export ARCH="arm64"
export SUBARCH="arm64"

# Identifier
export KBUILD_BUILD_USER="raphielscape"

# Where's my damn Toolchain if it's Semaphore?
if [[ ${WORKER} == semaphore ]]; then
    export TOOLCHAIN="${HOME}/GNU/GCC9/"
fi

# Wot is my defconfig?
export DEFCONFIG="raph_defconfig"

# Where's the zip?
export ZIP_DIR="${KERNELDIR}/chewy/files/"
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb"

# When it's Clang, do rolls
if [[ ${CC} == Clang ]]; then
    echo -e "We're building Clang bois";
    
    # Clang configurations
    export CLANG_TCHAIN=clang
    export TCHAIN_PATH=aarch64-linux-gnu-
    export CLANG_TRIPLE="aarch64-linux-gnu-";
    
    # Kbuild Sets
    export KBUILD_COMPILER_STRING="$(${CLANG_TCHAIN} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')";
    export CROSS_COMPILE="${TCHAIN_PATH}";
    
    # Export the make
    export MAKE="make O=${OUTDIR} CC=clang";
    
    # Scream out the Clang compiler used
    echo -e "Using toolchain: $(${CLANG_TCHAIN} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')";
else
    # We're using GCC, So throw normal make script
    export MAKE="make O=${OUTDIR}";
fi

# Caster configurations
MSG="Memes staged with commit $(git log --pretty=format:'%h : %s' -1) Under $(hostname) has been"
MAIN=-1001371047577
BUILD=-1001153251064
STICKER=CAADBAADNwADp8uuGBHV2tl40w7WAg

# Set Performance as governor when compiling
function setperf() {
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >> /dev/null
}

# Dropbox Thrower
function transfer() {
	zipname="$(echo $1 | awk -F '/' '{print $NF}')";
	url="$(bash $KERNELDIR/chewy/scripts/dropbox_uploader.sh upload $1 /megalovania)";
	printf '\n';
	echo -e "Download ${zipname} at ${url}";
}

# Push to Channel
function push() {
    curl -F document=@"${ZIP_DIR}/$ZIPNAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument \
         -F chat_id="-1001153251064" 
}

# Send the Astolfo FTW Sticker
function tg_sendstick() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker \
         -d sticker="${STICKER}" \
         -d chat_id=${BUILD} >> /dev/null
}

# Send the info up
function tg_sendinfo() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage \
         -d text="${1}" \
         -d chat_id=${MAIN} >> /dev/null
}

# Local builder notification thrower
function local_done() {
    localdone="Raphielscaper build completed with the latest commit -";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage \
    -d text="$localdone $(git log --pretty=format:'%h : %s' -1)" \
    -d chat_id=@raphiel_ci >> /dev/null
}

# Report progress to a Telegram chat
function tg_sendinfo() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage \
         -d text="${1}" \
         -d chat_id=${MAIN} >> /dev/null
}

# Report progress to Channelcast
function tg_channelcast() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage \
         -d text="${1}" \
         -d chat_id=${BUILD} >> /dev/null
}


# Whenever build is interrupted by purpose, report it
trap '{
    tg_sendinfo "${MSG} stopped due to SIGINT, Meh, We will right back"
    tg_channelcast "${MSG} stopped due to SIGINT, Meh, We will right back"
    exit -1
}' INT

# Whenever errors occured, report them
function tg_senderror() {
    tg_sendinfo "${MSG} errored rrrrrreeeeeeeee."
    tg_channelcast "${MSG} errored rrrrrreeeeeeeee."
    exit 1
}

# Announce the completion
function tg_yay() {
    tg_sendinfo "Science Blaster Time~"
    tg_channelcast "Boi"
}

# Init
setperf
tg_sendstick
tg_sendinfo "${MSG} started by $(whoami)."
tg_channelcast "${MSG} started by $(whoami)."
