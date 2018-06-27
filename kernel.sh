#!/usr/bin/env bash
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# SPDX-License-Identifier: GPL-3.0-or-later

# Init da wae
if [[ ${WORKER} == semaphore ]]; then
    source "${HOME}/scripts/env"
else
    source "${HOME}/working/scripts/env"
fi

# First-post works
tg_sendstick
tg_sendinfo "${MSG} started on $(whoami)~"
tg_channelcast "${MSG} started on $(whoami)~"

# Whenever build is errored, report it, and killplay
trap '{
    STATUS=${?}
    tg_senderror
    finerr
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
if [[ ${branch} == MIUI ]]; then
    export ZIPNAME="kat-miui-$(date +%Y%m%d-%H%M).zip"
elif [[ ${CC} == Clang ]]; then
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
    END=$(date +"%s");
DIFF=$(($END - $START));

# AnyKernel cleanups
if [[ ${WORKER} == raphielbox ]]; then
  echo -e "Bringing-up AnyKernel~";
  $(rm -rf ${ANYKERNEL});
    $(cp -R "${WORKDIR}/AnyKernel2-git" "${ANYKERNEL}");
    cd ${ANYKERNEL};
      $(rm zImage);
      $(rm -rf ".git");
    cd ${ANYKERNEL}/patch;
      $(rm -rf *);
    cd -;
else
    cd ${ANYKERNEL};
      $(rm zImage);
      $(rm -rf ".git");
    cd ${ANYKERNEL}/patch;
      $(rm -rf *);
    cd -;
fi

# Copy the image to AnyKernel
echo -e "Copying kernel image...";
    cp "${IMAGE}" "${ANYKERNEL}/";
cd -;

# Delett old modules if exists and it's MIUI
if [[ ${branch} == MIUI ]]; then
  rm -rf "${MODULES}";
fi

# Copy modules used by MIUI
if [[ ${branch} == MIUI ]]; then
  echo -e "Copying modules for MehUI...";
    cp "${OUTDIR}/block/test-iosched.ko" "${MODULES}";
    cp "${OUTDIR}/crypto/ansi_cprng.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/char/rdbg.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/input/evbug.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/mmc/card/mmc_block_test.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/mmc/card/mmc_test.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/net/wireless/ath/wil6210/wil6210.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/scsi/ufs/ufs_test.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/video/backlight/backlight.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/video/backlight/lcd.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/video/backlight/generic_bl.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/spi/spidev.ko" "${MODULES}";
    cp "${OUTDIR}/net/bridge/br_netfilter.ko" "${MODULES}";
    cp "${OUTDIR}/net/ipv4/tcp_htcp.ko" "${MODULES}";
    cp "${OUTDIR}/drivers/staging/prima/wlan.ko" "${MODULES}";
    mkdir "${MODULES}/pronto";
    cp "${MODULES}/wlan.ko" "${MODULES}/pronto/pronsto_wlan.ko";
fi

# Zip the wae
cd ${ANYKERNEL};
  zip -rT9 ${FINAL_ZIP} *;
cd -;

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]; then
if [[ ${WORKER} == semaphore ]]; then
    echo -e "Uploading ${ZIPNAME} to Dropbox";
    transfer "${FINAL_ZIP}";
    push;
fi
    echo -e "${ZIPNAME} can be found at ${FINAL_ZIP}"
    fin
# Oh no
else
    echo -e "Zip Creation Failed =("
    finerr
fi
