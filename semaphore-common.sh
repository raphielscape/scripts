#!/usr/bin/env bash
# shellcheck disable=SC2199
#
# Copyright (C) 2018 Raphielscape LLC.
#
# Licensed under the Raphielscape Public License, Version 1.0 (the "License");
# you may not use this file except in compliance with the License.
#
# Server Initializations container

## Import environment container
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/env

# Semaphore drunk without this
export KERNELDIR=${SEMAPHORE_PROJECT_DIR}

# Separated dipper exec
if [[ "$@" =~ "dipper" ]]; then
	export EXEC=dipper
fi

# Separated beryllium exec
if [[ "$@" =~ "beryllium" ]]; then
	export EXEC=beryllium
fi

# Separated mido exec
if [[ "$@" =~ "mido" ]]; then
	export EXEC=mido
fi

# Well, fuck
if [[ "$@" =~ "clang" ]]; then
	export CC=Clang
else
	export CC=GCC
fi

# Validate things for proper configurations
sudo install-package --update-new ccache bc bash git-core gnupg build-essential \
		zip curl make automake autogen autoconf autotools-dev libtool shtool python \
		m4 gcc libtool zlib1g-dev dash

# Clone needed components
if [[ "$@" =~ "sdm845" ]]; then
	clone https://github.com/raphielscape/AnyKernel2.git --branch "sdm845" "${KERNELDIR}"/anykernel
else
	clone https://github.com/raphielscape/AnyKernel2.git "${KERNELDIR}"/anykernel
fi

clone https://github.com/RaphielGang/arm-linux-gnueabi-8.x.git "${HOME}/GNU/ARMGCC"
clone https://github.com/RaphielGang/aarch64-raph-linux-android.git "${HOME}/GNU/GCC"

if [[ "$@" =~ "clang" ]]; then
	clone https://github.com/RaphielGang/aosp-clang.git "${HOME}/LLVM/CLANG"
fi

cd "$KERNELDIR" && "${HOME}/scripts/kernel.sh"
