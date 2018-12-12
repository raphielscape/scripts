#!/usr/bin/env bash
# shellcheck disable=SC2199
#
# Copyright (C) 2018 Raphielscape LLC.
#
# Licensed under the Raphielscape Public License, Version 1.0 (the "License");
# you may not use this file except in compliance with the License.
#
# Kernel-building execution stager

## Import environment container
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/env

# Init
if [[ ${WORKER} == raphielbox ]]; then
	kernelbox
else
	semaphorebox
fi

if [[ ${PARSE_ORIGIN} == *msm8953* ]]; then
	mido
fi

if [[ ${EXEC} == beryllium ]]; then
	beryllium
fi

if [[ ${EXEC} == dipper ]]; then
    dipper
fi

if [[ ${CC} == Clang ]]; then
	prepare_clang
else
	prepare_gcc
fi

ARCH="arm64"
SUBARCH="arm64"
IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb"

export ARCH SUBARCH DEFCONFIG IMAGE

header "You're working with $DEVICE on $PARSE_BRANCH" "$GREEN"

# First-post works
tg_sendstick
kickstart
debugtap

# Whenever build is errored, report it, and killplay
trap '{
    STATUS=${?}
    tg_senderror
    finerr
}' ERR

# When the Cross-compiler is GCC
if [[ ${CC} != Clang && ${WORKER} != raphielbox ]]; then
	check_gcc_toolchain
fi

# Set Kerneldir Plox
if [[ -z ${KERNELDIR} ]]; then
	echo "Please set KERNELDIR"
	exit 1
fi

# How much jobs we need?
if [[ -z "${JOBS}" ]]; then
	COUNT="$(grep -c '^processor' /proc/cpuinfo)"
	export JOBS="$((COUNT * 2))"
fi

# Toolchain Thrower
TCVERSION1="$(${CROSS_COMPILE}gcc --version | head -1 |
	awk -F '(' '{print $2}' | awk '{print tolower($1)}')"

TCVERSION2="$(${CROSS_COMPILE}gcc --version | head -1 |
	awk -F ')' '{print $2}' | awk '{print tolower($1)}')"

export TCVERSION1 TCVERSION2

# Zipname
ZIPNAME="Bash-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M).zip"

# Final Zip
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

# Prepping
colorize "${RED}"
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
if [[ ! -d "${OUTDIR}" && ${WORKER} != semaphore ]]; then
	mkdir -pv "${OUTDIR}"
	sudo mount -t tmpfs -o size=4g tmpfs out
	sudo chown "${USER}" out/ -R
fi
decolorize

# Here we go
cd "${SRCDIR}" || exit

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

export exitCode="$?"
END=$(date +"%s")

DIFF=$((END - START))

# AnyKernel cleanups
header "Bringing-up AnyKernel~"
colorize ${YELLOW}
if [[ ${WORKER} == raphielbox ]]; then
	delett ${ANYKERNEL}
	copy "${WORKDIR}/AnyKernel2-git" "${ANYKERNEL}"
	cd ${ANYKERNEL} || return
	delett -v zImage
	delett ".git"
	cd "${ANYKERNEL}/patch" || return
	delett *
	cd - || return
else
	cd "${ANYKERNEL}" || return
	delett zImage
	delett ".git"
	cd "${ANYKERNEL}"/patch || return
	delett *
	cd - || return
fi
decolorize

# Copy the image to AnyKernel
header "Copying kernel..." "${BLUE}"
colorize ${LIGHTCYAN}
copy "${IMAGE}" "${ANYKERNEL}"
cd - || return
decolorize

# Zip the wae
header "Zipping AnyKernel..." "${BLUE}"
cd ${ANYKERNEL} || return
colorize "${CYAN}"
command zip -rT9 "${FINAL_ZIP}" *
cd - || return
decolorize

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]; then
	if [[ ${ZIP_UPLOAD} == true ]]; then
		header "Uploading ${ZIPNAME}" "${LIGHTGREEN}"
		push
	fi
	header "${ZIPNAME} can be found at ${FINAL_ZIP}" "${LIGHTGREEN}"
	fin
	# Oh no
else
	header "Zip Creation Failed =("
	die "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds\\nbut it's error..."
	finerr
fi
