#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck source=/dev/null
#
# Copyright (C) 2019 Raphielscape LLC.
#
# Licensed under the Raphielscape Public License, Version 1.c (the "License");
# you may not use this file except in compliance with the License.
#
# Drone specific build stager for Disrupt

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/stacks/stackies

cd /drone/src/ || exit

# Environment Vars
ANYKERNEL="/drone/src/anykernel"
ZIP_DIR="/drone/src/files"
KBUILD_BUILD_USER="raphielscape"
ARCH=arm64

export KBUILD_BUILD_USER

# Commands
copy() {
    command cp -R "${@}"
}

delett() {
    command rm -rf "${@}"
}

# Examine our compilation threads
# 2x of our available CPUs
CPU="$(grep -c '^processor' /proc/cpuinfo)"
JOBS="$(( CPU * 2 ))"

# Telegram path
TELEGRAM="${SCRIPTDIR}"/telegram/telegram

# Caster configurations
MAINGROUP_ID="-1001140871591"
BUILDSCAPERER_ID="-1001153251064"

# Push to Channel
push() {
    "${TELEGRAM}" -f "${ZIP_DIR}/$ZIPNAME" \
    -c ${BUILDSCAPERER_ID}
}

# sendcast to group
tg_sendinfo() {
    "${TELEGRAM}" -c ${MAINGROUP_ID} -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

# sendcast to channel
tg_channelcast() {
    "${TELEGRAM}" -c ${BUILDSCAPERER_ID} -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

# Fin Prober
fin() {
    header "Yay! My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.~"
    tg_sendinfo "Build for ${DEVICE} with ${COMPILER_USED} took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds"
    if [ "${ZIP_UPLOAD}" = true ]; then
        tg_channelcast "Build for ${DEVICE} with ${COMPILER_USED} took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds"
    fi
}

# Errored Prober
finerr() {
    header "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds but it's error..."
    tg_sendinfo "Build for ${DEVICE} with ${COMPILER_USED} took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds" \
                "but it is having error anyways xd"
    tg_senderror
    exit 1
}

kickstart_pub() {
    tg_sendinfo "Compilation Rolled! Clocked at $(date +%Y%m%d-%H%M)"
    tg_build_sendsticker

    tg_channelcast "Compiler <code>${COMPILER_USED}</code>" \
    "Device <b>${DEVICE}</b>" \
    "Branch <code>${PARSE_BRANCH}</code>" \
    "Commit Point <code>${COMMIT_POINT}</code>" \
    "Under <code>$(hostname)</code>" \
    "Clocked at <code>$(date +%Y%m%d-%H%M)</code>" \
    "Started on <code>$(whoami)</code>"
}

PATH="/drone/src/clang/bin:${PATH}"
START=$(date +"%s")

if [[ "${EXEC}" =~ "dipper" ]]; then
	make O=out ARCH=arm64 raph_dipper_defconfig
	DEVICE=dipper
fi

if [[ "${EXEC}" =~ "beryllium" ]]; then
	make O=out ARCH=arm64 raph_beryllium_defconfig
	DEVICE=beryllium
fi

make -j${JOBS} O=out ARCH=arm64 CC=clang O=out ARCH=arm64 CC=clang CLANG_TRIPLE="aarch64-linux-gnu-" CROSS_COMPILE="aarch64-linux-gnu-" CROSS_COMPILE_ARM32="/drone/src/armcc/bin/arm-linux-gnueabi-"

END=$(date +"%s")
DIFF=$(( END - START ))

IMAGE="/drone/src/out/arch/${ARCH}/boot/Image.gz-dtb"
# Zipname
ZIPNAME="NightlyHat-${DEVICE}-${CC}-$(date +%Y%m%d-%H%M).zip"
TEMP_ZIP="${ZIP_DIR}/${TEMPZIPNAME}"
FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

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

copy "${IMAGE}" "${ANYKERNEL}"
cd - || return

cd "${ANYKERNEL}" || return
command zip -rT9 "${TEMP_ZIP}" -- *
cd - || return

# Finalize the zip down
if [ -f "$TEMP_ZIP" ]; then
  curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
  java -jar zipsigner-3.0.jar ${TEMP_ZIP} ${FINAL_ZIP}
	header "Uploading ${ZIPNAME}" "${LIGHTGREEN}"
	push
	header "${ZIPNAME} can be found at ${FINAL_ZIP}" "${LIGHTGREEN}"
	fin
else
	header "Zip Creation Failed =("
	die "My works took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds\\nbut it's error..."
	finerr
fi
