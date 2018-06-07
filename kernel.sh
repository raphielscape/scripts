#!/usr/bin/env bash
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# SPDX-License-Identifier: GPL-3.0-or-later

# Init da wae
if [[ ${WORKER} == semaphore ]]; then
    source "chewy/scripts/env.sh"
else
    source "${HOME}/working/scripts/env.sh"
fi

# First-post works
setperf
tg_sendstick
tg_sendinfo "${MSG} started on $(whoami)."
tg_channelcast "${MSG} started on $(whoami)."

# Whenever build is errored, report it
trap '{
    STATUS=${?}
    tg_senderror
}' ERR

# Toolchain Checkups
function check_toolchain() {
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

# When the worker is Semaphore
if [[ ${WORKER} == semaphore ]]; then
    check_toolchain;
fi

# Set Kerneldir Plox
if [[ -z ${KERNELDIR} ]]; then
    echo -e "Please set KERNELDIR"
    exit 1
fi

# How much jobs we need?
if [[ -z "${JOBS}" ]]; then
    export JOBS="$(grep -c '^processor' /proc/cpuinfo)"
fi

# Toolchain Thrower
export TCVERSION1="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F '(' '{print $2}' | awk '{print tolower($1)}')"

export TCVERSION2="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F ')' '{print $2}' | awk '{print tolower($1)}')"

# Zipname
if [[ ${CC} == Clang ]]; then
    export ZIPNAME="weeb-clang-oreo-$(date +%Y%m%d-%H%M).zip"
else
    export ZIPNAME="weeb-treble-oreo-$(date +%Y%m%d-%H%M).zip"
fi

# Final Zip 
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

# Prepping
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}

# Here we go
cd "${SRCDIR}";

# Delett old image
rm -fv ${IMAGE};

# How 2 be Mr.Proper 101
if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi

# How 2 cleanups things 101
if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi

# Relatable
${MAKE} $DEFCONFIG;
START=$(date +"%s");
    echo -e "Using ${JOBS} threads to compile"
${MAKE} -j${JOBS};
    exitCode="$?";
    END=$(date +"%s")
DIFF=$(($END - $START))

# Copy the image to AnyKernel 
echo -e "Copying kernel image..."
    cp -v "${IMAGE}" "${ANYKERNEL}/"
cd - 

# Zip the wae
cd ${AROMA} 
    zip -r9 ${FINAL_ZIP} * $BLUE
cd - 

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]
then
echo -e "$ZIPNAME zip can be found at $FINAL_ZIP"
if [[ ${success} == true && ${WORKER} == semaphore ]]; then
    echo -e "Uploading ${ZIPNAME} to Dropbox"
    transfer "${FINAL_ZIP}"
    push
fi

# Oh no
else
    echo -e "Zip Creation Failed =("
    tg_senderror
fi

# Finalize things
if [[ ! -f "$FINAL_ZIP" ]]; then
    echo -e "Eeehhh?"
    echo -e "My works took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error..."
    tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error...")"
    tg_senderror
    success=false;
    exit 1;
else
    echo -e "Yay!~"
    echo -e "My works took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
    tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
    tg_yay
    success=true;
fi
