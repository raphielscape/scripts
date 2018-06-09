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

# For ccache (ANGERY)
export PATH="/usr/lib/ccache/bin/:$PATH"

# Sourcedir
export SRCDIR="${KERNELDIR}"
export OUTDIR="${KERNELDIR}/out"

# AnyKernel and Aroma Location
if [[ ${WORKER} == raphielbox ]]; then
    export ANYKERNEL="${HOME}/working/aroma/anykernel/"
    export AROMA="${HOME}/working/aroma/"
else
    export ANYKERNEL="${KERNELDIR}/chewy/aroma/anykernel/"
    export AROMA="${KERNELDIR}/chewy/aroma/"
fi

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

# Where will the zip go?
if [[ ${WORKER} == semaphore ]]; then
    export ZIP_DIR="${KERNELDIR}/chewy/files/"
else
    export ZIP_DIR="${HOME}/working/weeb_zip"
fi

# Image result
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image-dtb"

# When it's Clang, do rolls
if [[ ${CC} == Clang ]]; then
    echo -e "We're building Clang bois"
    
    # Clang configurations
    export CLANG_TCHAIN="ccache clang"
    export TCHAIN_PATH="aarch64-linux-gnu-"
    export CLANG_TRIPLE="aarch64-linux-gnu-"
    
    # Kbuild Sets
    export KBUILD_COMPILER_STRING="$(${CLANG_TCHAIN} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')";
    export CROSS_COMPILE="${TCHAIN_PATH}"
    
    # Export the make
    export MAKE="make O=${OUTDIR} CC="clang""
    
    # Scream out the Clang compiler used
    echo -e "Using toolchain: $(${CLANG_TCHAIN} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
else
    # We're using GCC, So throw normal make script
    export MAKE="make O=${OUTDIR}"
fi

# Caster configurations

# Messageworks
if [[ ${CC} == Clang ]]; then
MSG="I'm gotta working with Clang at commit $(git log --pretty=format:'%h : %s' -1) Under $(hostname) and it's"
else
MSG="I'm gotta working with GCC at commit $(git log --pretty=format:'%h : %s' -1) Under $(hostname) and it's"
fi

MAIN=-1001371047577
BUILD=-1001153251064
STICKER=CAADBAADNwADp8uuGBHV2tl40w7WAg

# Set Performance as governor when compiling
function setperf() {
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >> /dev/null
}

# Play Cartoon Network Summer Music when execution happen
if [[ ${WORKER} == raphielbox ]]; then
	while $@; do play -q ${WIRESLOCATION};done >> /dev/null
else
echo -e "No music for you, Semaphore"
fi

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
    tg_intstick
    tg_intstickmain
    exit 130
}' INT

# Interruption Happen, report with sticker
function tg_intstick() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker \
         -d sticker="CAADAQADFQADlS0LHvIFwsaTaVjGAg" \
         -d chat_id=${BUILD} >> /dev/null
}

function tg_intstickmain() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker \
         -d sticker="CAADAQADFQADlS0LHvIFwsaTaVjGAg" \
         -d chat_id=${MAIN} >> /dev/null
}

# Whenever errors occured, report them
function tg_senderror() {
    tg_channelcast "$(echo -e "Build Throwing Error(s)\n*put my regular badwords here*")"
    tg_channelcast "$(echo -e "Build Throwing Error(s)\nBangsat...")"
    [[ ! -z ${STATUS} ]] && \
    exit ${STATUS} || \
    exit 1
}

# Announce the completion
function tg_yay() {
    tg_sendinfo "$(echo -e "Compilation Completed yay!~\n@raphielscape Will you give me cookies?")"
    tg_channelcast "$(echo -e "${MSG} Completed yay!~\nAnd I will got cookies!")"
}

# Fin Prober
function fin() {
    echo -e "Yay!~"
    echo -e "My works took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
    tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
    tg_yay
}

# Toolchain Checks (GCC)
function check_gcc_toolchain() {
    export TC="$(find ${TOOLCHAIN}/bin -type f -name *-gcc)"
	if [[ -f "${TC}" ]]; then
		export CROSS_COMPILE="${TOOLCHAIN}/bin/$(echo ${TC} | \
		awk -F '/' '{print $NF'} | \
        sed -e 's/gcc//')"
		echo -e "Using toolchain: $(${CROSS_COMPILE}gcc --version | head -1)";
	else
		echo -e "No suitable toolchain found in ${TOOLCHAIN}"
		exit 1;
	fi
}

# Errored Prober
function finerr() {
    echo -e "Eeehhh?"
    echo -e "My works took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error..."
    tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error...")"
    tg_senderror
    exit 1
}