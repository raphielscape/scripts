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

# Declare that we're using Clang now
export CC=Clang

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

clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 "${HOME}/GNU/GCC"
clone https://github.com/RaphielGang/aosp-clang.git "${HOME}/LLVM/CLANG"

cd "$KERNELDIR" && "${HOME}/scripts/kernel.sh"
