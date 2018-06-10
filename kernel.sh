#!/usr/bin/env bash
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# SPDX-License-Identifier: GPL-3.0-or-later

# Init da wae
if [[ ${WORKER} == semaphore ]]; then
    source "${HOME}/scripts/env"
else
    source "${HOME}/working/scripts/env"
fi

# Play Cartoon Network Summer Music when execution happen
if [[ ${WORKER} == raphielbox ]]; then
    tg_sendinfo "Playing Wires!~"
    wires
else
    echo -e "No music for you, Semaphore"
fi

# First-post works
tg_sendstick
tg_sendinfo "${MSG} started on $(whoami)."
tg_channelcast "${MSG} started on $(whoami)."

# Whenever build is errored, report it
trap '{
    STATUS=${?}
    killplay
    tg_senderror
}' ERR

# When the worker is Semaphore
if [[ ${WORKER} == semaphore ]]; then
    check_gcc_toolchain;
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
    export ZIPNAME="kat-clang-oreo-$(date +%Y%m%d-%H%M).zip"
else
    export ZIPNAME="kat-treble-oreo-$(date +%Y%m%d-%H%M).zip"
fi

# Final Zip
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

# Prepping
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}

# Link out directory to cache directory as per Semaphore documentation
if [[ ${WORKER} == semaphore ]]; then
  ln -s ${SEMAPHORE_CACHE_DIR}/out ${KERNELDIR}/out
fi

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
if [ -f "$FINAL_ZIP" ]; then
if [[ ${WORKER} == semaphore ]]; then
    echo -e "Uploading ${ZIPNAME} to Dropbox"
    transfer "${FINAL_ZIP}"
    push
fi
    echo -e "$ZIPNAME zip can be found at $FINAL_ZIP"
    fin
    killplay
# Oh no
else
    echo -e "Zip Creation Failed =("
    finerr
    killplay
fi
