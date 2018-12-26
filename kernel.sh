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
if [ "${WORKER}" = raphielbox ]; then
	kernelbox
else
	semaphorebox
fi

if [ "${EXEC}" = mido ]; then
	mido
fi

if [ "${EXEC}" = beryllium ]; then
	beryllium
fi

if [ "${EXEC}" = dipper ]; then
    dipper
fi

if [ "${CC}" = Clang ]; then
	prepare_clang
else
	prepare_gcc
fi

ARCH="arm64"
SUBARCH="arm64"
IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb"

export ARCH SUBARCH IMAGE

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

# Set Kerneldir Plox
if [ ! "${KERNELDIR}" ]; then
	echo "Please set KERNELDIR"
	exit 1
fi

# Toolchain Thrower
# shellcheck disable=SC2086
TCVERSION1="$(${CROSS_COMPILE}gcc --version | head -1 |
	awk -F '(' '{print $2}' | awk '{print tolower($1)}')"

# shellcheck disable=SC2086
TCVERSION2="$(${CROSS_COMPILE}gcc --version | head -1 |
	awk -F ')' '{print $2}' | awk '{print tolower($1)}')"

export TCVERSION1 TCVERSION2

# Zipname
ZIPNAME="Bash-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M).zip"

# Final Zip
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

# Prepping
colorize "${RED}"
[ ! -d "${ZIP_DIR}" ] && mkdir -pv "${ZIP_DIR}"
if [ ! -d "${OUTDIR}" ] && [ "${WORKER}" != semaphore ]; then
	mkdir -pv "${OUTDIR}"
fi
decolorize

# Here we go
cd "${SRCDIR}" || exit

# Delett old image
colorize "${RED}"
delett "${IMAGE}"
decolorize

START=$(date +"%s")

colorize "${LIGHTRED}"
	build "${DEFCONFIG}"
	build 
	# FIXME : We don't need DTBs for now
	# build dtbs
decolorize

export exitCode="$?"
END=$(date +"%s")

DIFF=$((END - START))

# AnyKernel cleanups
header "Bringing-up AnyKernel~"
colorize "${YELLOW}"
if [ "${WORKER}" = raphielbox ]; then
	if [ "${SDM845}" = true ]; then
		cd "${WORKDIR}/AnyKernel2-git" || return
		header "It's sdm845, checking out..."
		git checkout sdm845
	else
		cd "${WORKDIR}/AnyKernel2-git" || return
		header "It's common, checking out..."
		git checkout master
	fi
	
	delett "${ANYKERNEL}"
		copy "${WORKDIR}/AnyKernel2-git" "${ANYKERNEL}"
			cd "${ANYKERNEL}" || return
			delett -v zImage
			delett ".git"
		cd "${ANYKERNEL}/patch" || return
			delett -- *
	cd - || return
else
	cd "${ANYKERNEL}" || return
		delett zImage
		delett ".git"
		cd "${ANYKERNEL}"/patch || return
			delett -- *
	cd - || return
fi
decolorize

# Copy the image to AnyKernel
header "Copying kernel..." "${BLUE}"
colorize "${LIGHTCYAN}"
		copy "${IMAGE}" "${ANYKERNEL}"
	cd - || return
decolorize

# Zip the wae
header "Zipping AnyKernel..." "${BLUE}"
cd "${ANYKERNEL}" || return
colorize "${CYAN}"
		command zip -rT9 "${FINAL_ZIP}" -- *
	cd - || return
decolorize

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]; then
	if [ "${ZIP_UPLOAD}" = true ]; then
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
