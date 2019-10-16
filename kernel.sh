#!/usr/bin/env bash
#
# Copyright (C) 2019 Raphielscape LLC.
#
# Licensed under the Raphielscape Public License, Version 1.c (the "License");
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
	docker
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

# Export the kernel architecture
ARCH="arm64"
SUBARCH="arm64"

# Image location
IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb"

export ARCH SUBARCH IMAGE

# Announce what device we works on
header "You're working with $DEVICE on $PARSE_BRANCH" "$GREEN"

# First-post works
if [ "${ZIP_UPLOAD}" = true ]; then
	kickstart_pub
else
	if [ "${RELEASE}" = true ]; then
		kickstart_release
	fi
fi

# Whenever build is errored, report it.
trap '{
    STATUS=${?}
    tg_senderror
    finerr
}' ERR

# Set Kernel Building Directory
if [ ! "${KERNELDIR}" ]; then
	echo "Please set KERNELDIR"
	exit 1
fi

# Zipname
ZIPNAME="NightlyHat-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M).zip"
TEMPZIPNAME="NightlyHat-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M)-unsigned.zip"
TEMP_ZIP="${ZIP_DIR}/${TEMPZIPNAME}"
ZIPNAMEREL="Disrupt-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M).zip"

# Final Zip
if [ "${RELEASE}" = true ]; then
	export FINAL_ZIP="${ZIP_DIR}/${ZIPNAMEREL}"
else
	export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
fi

# Create zip directory if it's not exists
[ ! -d "${ZIP_DIR}" ] && mkdir -pv "${ZIP_DIR}"

# Here we go
cd "${SRCDIR}" || exit

# Delete old image if exists
colorize "${RED}"
	delett "${IMAGE}"
decolorize

START=$(date +"%s")

colorize "${LIGHTRED}"
	# Start the compilation
	build "${DEFCONFIG}"
		build
		build dtbs
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
		git checkout sdm845 >> /dev/null
	else
		cd "${WORKDIR}/AnyKernel2-git" || return
		header "It's common, checking out..."
		git checkout master >> /dev/null
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
		command zip -rT9 "${TEMP_ZIP}" -- *
	cd - || return
decolorize

# Finalize the zip down
if [ -f "$TEMP_ZIP" ]; then
	if [ "${ZIP_UPLOAD}" = true ]; then
		java -jar zipsigner-3.0.jar "${TEMP_ZIP}" "${FINAL_ZIP}"
		header "Uploading ${ZIPNAME}" "${LIGHTGREEN}"
		push
	fi
	header "${ZIPNAME} can be found at ${FINAL_ZIP}" "${LIGHTGREEN}"
	fin
else
	header "Zip Creation Failed =("
	die "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds\\nbut it's error..."
	finerr
fi
