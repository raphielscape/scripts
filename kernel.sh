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
if [[ ${branch} == qc ]]; then
disclaimer
fi

# Whenever build is errored, report it, and killplay
trap '{
    STATUS=${?}
    tg_senderror
    finerr
}' ERR

# When the Cross-compiler is GCC
if [[ ${CC} != Clang ]]; then
    check_gcc_toolchain
fi

# Set Kerneldir Plox
if [[ -z ${KERNELDIR} ]]; then
    echo "Please set KERNELDIR"
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
elif [[ ${branch} == qc ]]; then
    export ZIPNAME="kat-QC-$(date +%Y%m%d-%H%M).zip"
elif [[ ${CC} == Clang ]]; then
    export ZIPNAME="kat-clang-oreo-$(date +%Y%m%d-%H%M).zip"
elif [[ ${branch} == penkek ]]; then
    export ZIPNAME="kat-clang-penkek-$(date +%Y%m%d-%H%M).zip"
else
    export ZIPNAME="kat-combo-oreo-$(date +%Y%m%d-%H%M).zip"
fi

# Final Zip
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

# Prepping
colorize "${RED}"
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}
decolorize

# Link out directory to cache directory as per Semaphore documentation
if [[ ${WORKER} == semaphore ]]; then
  ln -s ${SEMAPHORE_CACHE_DIR}/out ${KERNELDIR}/out
fi

# Here we go
cd "${SRCDIR}"

# Delett old image
colorize "${RED}"
delett ${IMAGE}
decolorize

# How 2 be Mr.Proper 101
if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi

# How 2 cleanups things 101
if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi

# Relatable
colorize "${CYAN}"
${MAKE} $DEFCONFIG
decolorize

START=$(date +"%s")
header "Using ${JOBS} threads to compile" "${LIGHTCYAN}"

colorize ${LIGHTRED}
${MAKE} -j${JOBS}
${MAKE} -j${JOBS} dtbs
decolorize

exitCode="$?"
END=$(date +"%s")

DIFF=$(($END - $START))

# AnyKernel cleanups
header "Bringing-up AnyKernel~"
colorize ${YELLOW}
  if [[ ${WORKER} == raphielbox ]]; then
    delett ${ANYKERNEL}
      copy "${WORKDIR}/AnyKernel2-git" "${ANYKERNEL}"
        cd ${ANYKERNEL} >> /dev/null
          delett -v zImage
          delett ".git"
        cd ${ANYKERNEL}/patch >> /dev/null
          delett *
        cd - >> /dev/null
  else
    cd ${ANYKERNEL} >> /dev/null
      delett zImage
      delett ".git"
    cd ${ANYKERNEL}/patch >> /dev/null
      delett *
    cd - >> /dev/null
  fi
decolorize

# Copy the image to AnyKernel
if [[ ${branch} == penkek ]]; then
header "Copying kernel..." "${BLUE}"
    colorize ${LIGHTCYAN}
        copy "${IMAGE}" "${ANYKERNEL}"
    decolorize
else
header "Copying kernel image..." "${BLUE}"
    colorize ${LIGHTCYAN}
        copy "${IMAGE}" "${ANYKERNEL}/kernel"
        copy "${DTB_TREBLE}" "${ANYKERNEL}/treble/${DTB_T}"
        copy "${DTB_NONTREBLE}" "${ANYKERNEL}/nontreble/${DTB_NT}"
    decolorize
fi
cd - >> /dev/null

# Delett old modules if exists and it's MIUI
if [[ ${branch} == MIUI ]]; then
    delett "${MODULES}"
fi

# Copy modules used by MIUI
if [[ ${branch} == MIUI ]]; then
  header "Copying modules for MehUI..." "${BLUE}"
    copy "${OUTDIR}/block/test-iosched.ko" "${MODULES}"
    copy "${OUTDIR}/crypto/ansi_cprng.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/char/rdbg.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/input/evbug.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/mmc/card/mmc_block_test.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/mmc/card/mmc_test.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/net/wireless/ath/wil6210/wil6210.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/scsi/ufs/ufs_test.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/video/backlight/backlight.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/video/backlight/lcd.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/video/backlight/generic_bl.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/spi/spidev.ko" "${MODULES}"
    copy "${OUTDIR}/net/bridge/br_netfilter.ko" "${MODULES}"
    copy "${OUTDIR}/net/ipv4/tcp_htcp.ko" "${MODULES}"
    copy "${OUTDIR}/drivers/staging/prima/wlan.ko" "${MODULES}"
    mkdir "${MODULES}/pronto"
    copy "${MODULES}/wlan.ko" "${MODULES}/pronto/pronto_wlan.ko"
fi

# Zip the wae
header "Zipping AnyKernel..." "${BLUE}"
cd ${ANYKERNEL}
   colorize "${CYAN}"
   command zip -rT9 ${FINAL_ZIP} *
   decolorize
cd - >> /dev/null

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]; then
if [[ ${ZIP_UPLOAD} == true ]]; then
    header "Uploading ${ZIPNAME} to Dropbox" "${LIGHTGREEN}"
    transfer "${FINAL_ZIP}"
    push
fi
    header "${ZIPNAME} can be found at ${FINAL_ZIP}" "${LIGHTGREEN}"
    fin
# Oh no
else
    header "Zip Creation Failed =("
    die "My works took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error..."
    finerr
fi
