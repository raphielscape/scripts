#!/usr/bin/env bash
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

# Validate things for proper configurations
if [[ ${WORKER} == semaphore ]]; then
	install-package ccache bc bash libncurses5-dev git-core gnupg flex bison gperf build-essential \
		zip curl libc6-dev ncurses-dev binfmt-support libllvm-3.6-ocaml-dev llvm-3.6 llvm-3.6-dev llvm-3.6-runtime \
		cmake automake autogen autoconf autotools-dev libtool shtool python m4 gcc libtool zlib1g-dev
fi

# Clone needed components
clone https://github.com/raphielscape/AnyKernel2.git "${KERNELDIR}"/anykernel
clone https://github.com/krasCGQ/aarch64-linux-android.git --branch "opt-linaro-7.x" "${HOME}"/GNU/GCC

# Going to start
cd "${KERNELDIR}" || exit

# Play Wires bois
"${HOME}"/scripts/kernel.sh
