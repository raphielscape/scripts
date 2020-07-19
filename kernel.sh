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
case ${WORKER} in
    raphielbox)
        ANYKERNEL="${HOME}/working/AnyKernel2"
        ZIP_DIR="${HOME}/working/weeb_zip"
    ;;
    docker)
        ANYKERNEL="$(pwd)/anykernel"
        ZIP_DIR="$(pwd)/files"
        KBUILD_BUILD_USER="drone-ci"
        ZIP_UPLOAD=true
esac

export KBUILD_BUILD_USER

prepare_compiler
compilerannounce

# Export the kernel architecture
ARCH="arm64"
SUBARCH="arm64"

# Image location
IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb"

export ARCH SUBARCH IMAGE

# Announce what device we works on
header "You're working with $DEVICE on $PARSE_BRANCH" "$GREEN"

# First-post works
if [ ! "${WORKER}" = raphielbox ]; then
	case $COMMIT_POINT in
		*"[REL]"*)
			kickstart_release
		;;
		*"[CHECKPOINT]"*)
			checkpoint_pub
		;;
		*)
			kickstart_pub
	esac
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
TEMPZIPNAME="NightlyHat-${DEVICE}-${CU}-$(date +%Y%m%d-%H%M)-unsigned.zip"
TEMP_ZIP="${ZIP_DIR}/${TEMPZIPNAME}"

case $COMMIT_POINT in
	*"[REL]"*)
		ZIPNAME="Disrupt-${DEVICE}-$(date +%Y%m%d-%H%M).zip"
		export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
	;;
	*"[CHECKPOINT]"*)
		ZIPNAME="PointOfDisrupt-${DEVICE}-$(date +%Y%m%d-%H%M).zip"
		export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
	;;
	*)
		ZIPNAME="NightlyHat-${DEVICE}-$(date +%Y%m%d-%H%M).zip"
		export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
esac

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

case $WORKER in
	raphielbox)
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
	;;
	*)
		cd "${ANYKERNEL}" || return
			delett zImage
			delett ".git"
			cd "${ANYKERNEL}"/patch || return
				delett -- *
		cd - || return
esac
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
		java -jar "$SCRIPTDIR"/zipsigner-3.0.jar "${TEMP_ZIP}" "${FINAL_ZIP}"
		SHA1_SUM="$(sha1sum "${FINAL_ZIP}" | awk '{print $1}')"
		export SHA1_SUM
		delett "${TEMP_ZIP}"
	cd - || return
decolorize

# Finalize the zip down
if [ -f "$FINAL_ZIP" ]; then
	if [ "${ZIP_UPLOAD}" = true ]; then
		header "Uploading ${ZIPNAME}" "${LIGHTGREEN}"
		# HACK : Telegram ranting that our action is too fast
		# Telegram want 10 seconds pause per-commands
		# Sleep for 10 Second before pushing
		sleep 10
		push
	fi
	header "${ZIPNAME} can be found at ${FINAL_ZIP}" "${LIGHTGREEN}"
	fin
else
	header "Zip Creation Failed =("
	die "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds\\nbut it's error..."
	finerr
fi
