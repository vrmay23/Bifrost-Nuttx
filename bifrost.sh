#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# MIT License
#
# Copyright (c) 2023-2026 Vinicius Rodrigo May (@vrmay23)
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#--------------------------------------------------------------------------
#
# Title:   Bifrost - NuttX host environment bootstrap
# Author:  Vinicius Rodrigo May (vmay23 ~QsiX Embedded Labs~)
# Created: 2023/05/16
# Rev:     2026/11/21 - full rewrite
#            - ARM, RISC-V and Xtensa toolchains (STM32, RP2040, RP2350,
#              ESP32, ESP32-S2/S3, ESP32-C3/C6)
#            - kconfiglib (pip, inside a venv) replaces kconfig-frontends
#            - Espressif "Simple Boot": no external bootloader needed,
#              flashing goes through "make flash"
#            - pico-sdk 2.x + picotool for UF2 generation
#            - single env file instead of scattered ~/.bashrc edits
#            - strict mode, idempotent steps, 78-column limit
#            - folder menu restored with its bugs fixed
#            - Haindall (festival) speaks every question and every step
#            - STM32H7 flashing with OpenOCD DUAL_BANK=1
#            - optional docker mode on the NuttX CI image
#
# Step-by-step guides followed for the original version (2023):
#   - NuttX Channel (Alan C. Assis):
#       https://www.youtube.com/@nuttxchannel
#   - Embarcados TV (Sara Cunha):
#       https://www.youtube.com/watch?v=B3fKhR7tsVM
#
# Current references (all open source / public documentation):
#   - NuttX install guide:
#       https://nuttx.apache.org/docs/latest/quickstart/install.html
#   - NuttX ESP32-C3 / ESP32-S3 / RP2040 / RP2350 platform pages:
#       https://nuttx.apache.org/docs/latest/platforms/
#   - NuttX CI Dockerfile (toolchain versions):
#       nuttx/tools/ci/docker/linux/Dockerfile
#
# Layout (root overridable with BIFROST_ROOT):
#
#   $BIFROST_ROOT/                     default: ~/embedded_sys
#     env.sh                           source this in your shell
#     nuttxspace/
#       nuttx/
#       apps/
#     tools/
#       arm-none-eabi-gcc/
#       riscv-none-elf-gcc/
#       xtensa-esp-elf-gcc/
#       openocd-esp32/
#       picotool/
#       pico-sdk/
#     nuttx_venv/                      kconfiglib + esptool
#
# Usage: see "bifrost.sh help". Commands can be chained, e.g.:
#   ./bifrost.sh deps src venv tc-arm env
#   ./bifrost.sh conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0
#
#--------------------------------------------------------------------------

set -Eeuo pipefail

#==========================================================================
# Configuration
#
# Every value below can be overridden from the environment, e.g.:
#   BIFROST_ROOT=/opt/nx ARM_TC_VER=14.2.Rel1 ./bifrost.sh tc-arm
#
# Toolchain versions should track the NuttX CI Dockerfile. Check it
# before bumping: nuttx/tools/ci/docker/linux/Dockerfile
#==========================================================================

# Root directory. Priority: BIFROST_ROOT from the environment, then the
# root saved by the folder menu ("tree"), then ~/embedded_sys.

# Bifrost state lives outside the root, so "uninstall" can still read
# it after the root is gone:
#   root           root folder chosen in the folder menu
#   apt-installed  apt packages Bifrost itself installed (one per line);
#                  packages that were already present are never listed,
#                  so uninstall never removes something you had before

BIFROST_STATE="$HOME/.config/bifrost"
BIFROST_CONF="$BIFROST_STATE/root"
BIFROST_APT_LOG="$BIFROST_STATE/apt-installed"

if [[ -z "${BIFROST_ROOT:-}" && -r "$BIFROST_CONF" ]]; then
  BIFROST_ROOT="$(<"$BIFROST_CONF")"
fi
BIFROST_ROOT="${BIFROST_ROOT:-$HOME/embedded_sys}"

# set_paths: derive every path from BIFROST_ROOT. Called again by the
# folder menu when the root changes, so no variable keeps a stale path.

set_paths()
{
  NUTTXSPACE_DIR="$BIFROST_ROOT/nuttxspace"
  NUTTX_DIR="$NUTTXSPACE_DIR/nuttx"
  APPS_DIR="$NUTTXSPACE_DIR/apps"
  TOOLS_DIR="$BIFROST_ROOT/tools"
  VENV_DIR="$BIFROST_ROOT/nuttx_venv"
  ENV_FILE="$BIFROST_ROOT/env.sh"
  LAST_CONF="$BIFROST_ROOT/.last-conf"   # board:config of the tree
}
set_paths

# Haindall, the guardian of the Bifrost, speaks every question and every
# step through festival (text-to-speech). BIFROST_VOICE=0 silences him.

BIFROST_VOICE="${BIFROST_VOICE:-1}"

NUTTX_GIT="${NUTTX_GIT:-https://github.com/apache/nuttx.git}"
APPS_GIT="${APPS_GIT:-https://github.com/apache/nuttx-apps.git}"

# ARM GNU Toolchain (STM32, RP2040, RP2350 in Cortex-M33 mode).
# Source: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

ARM_TC_VER="${ARM_TC_VER:-13.2.Rel1}"
ARM_TC_URL="${ARM_TC_URL:-https://developer.arm.com/-/media/Files/\
downloads/gnu/${ARM_TC_VER}/binrel/\
arm-gnu-toolchain-${ARM_TC_VER}-x86_64-arm-none-eabi.tar.xz}"

# xPack RISC-V GCC (ESP32-C3, ESP32-C6). Version used by NuttX CI.

RISCV_TC_VER="${RISCV_TC_VER:-14.3.0-1}"
RISCV_TC_URL="${RISCV_TC_URL:-https://github.com/xpack-dev-tools/\
riscv-none-elf-gcc-xpack/releases/download/v${RISCV_TC_VER}/\
xpack-riscv-none-elf-gcc-${RISCV_TC_VER}-linux-x64.tar.gz}"

# Espressif unified Xtensa GCC (ESP32, ESP32-S2, ESP32-S3).

XTENSA_TC_VER="${XTENSA_TC_VER:-14.2.0_20241119}"
XTENSA_TC_URL="${XTENSA_TC_URL:-https://github.com/espressif/\
crosstool-NG/releases/download/esp-${XTENSA_TC_VER}/\
xtensa-esp-elf-${XTENSA_TC_VER}-x86_64-linux-gnu.tar.xz}"

# Espressif OpenOCD fork (JTAG debug of ESP chips). Optional.
# Releases: https://github.com/espressif/openocd-esp32/releases

OCD_ESP_VER="${OCD_ESP_VER:-v0.12.0-esp32-20241016}"
OCD_ESP_URL="${OCD_ESP_URL:-https://github.com/espressif/openocd-esp32/\
releases/download/${OCD_ESP_VER}/\
openocd-esp32-linux-amd64-${OCD_ESP_VER#v}.tar.gz}"

# Raspberry Pi pico-sdk (needed by RP2040 flash builds) and picotool
# (generates nuttx.uf2 for RP2350, optional loader for both).

PICO_SDK_VER="${PICO_SDK_VER:-2.2.0}"
PICO_SDK_GIT="https://github.com/raspberrypi/pico-sdk.git"
# Prebuilt picotool from Raspberry Pi, the same archive NuttX CI uses.

PICOTOOL_VER="${PICOTOOL_VER:-2.2.0-0}"
PICOTOOL_URL="${PICOTOOL_URL:-https://github.com/raspberrypi/\
pico-sdk-tools/releases/download/v${PICOTOOL_VER}/\
picotool-${PICOTOOL_VER%-*}-x86_64-lin.tar.gz}"

# Python tools installed in the venv. esptool follows the NuttX CI pin.
# esptool 5 still ships the "esptool.py" name the NuttX makefiles call
# (with a deprecation warning). Older NuttX trees may need
# PIP_ESPTOOL="esptool>=4.8,<5".

PIP_ESPTOOL="${PIP_ESPTOOL:-esptool==5.3.1}"
PIP_PACKAGES=("kconfiglib" "$PIP_ESPTOOL")

# Docker mode: conf/build/menuconfig/rebuild/clean/sim and flash-esp run
# inside the NuttX CI image, which already carries every toolchain,
# kconfig tool, esptool, pico-sdk and picotool. Enable it per run with
# the "docker" command (e.g. "./bifrost.sh docker conf ... build") or
# always with BIFROST_DOCKER=1. The image is large (several GB).

DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/apache/nuttx/\
apache-nuttx-ci-linux:latest}"
BIFROST_DOCKER="${BIFROST_DOCKER:-0}"

# Defaults used by flash commands.

ESP_PORT="${ESP_PORT:-/dev/ttyUSB0}"
STM32_OCD_IF="${STM32_OCD_IF:-interface/stlink.cfg}"

# flash-stm32 [chip]: default chip when none is given. See
# stm32_target() for the accepted names.

STM32_CHIP="${STM32_CHIP:-h7}"

# Image format used by flash-stm32 (argument, or STM32_FLASH_MODE):
#   elf - "program nuttx verify reset exit": addresses come from the
#         ELF, always present after a build, verified after writing
#   bin - nuttx.bin written at STM32_FLASH_ADDR (needs
#         CONFIG_RAW_BINARY=y), then verified, same as the old aliases
# Empty: Haindall asks on a terminal, elf otherwise.

STM32_FLASH_MODE="${STM32_FLASH_MODE:-}"
STM32_FLASH_ADDR="${STM32_FLASH_ADDR:-0x08000000}"

# STM32H743/H753 have two 1 MB flash banks. Without DUAL_BANK=1 the
# stm32h7x.cfg target only maps bank 1 and images above 1 MB fail to
# program. Only applied to H7; set 0 for single-bank parts (e.g. H750).

STM32_DUAL_BANK="${STM32_DUAL_BANK:-1}"

# Host packages (Debian/Ubuntu). Based on the NuttX install guide, with
# libncurses5-dev/libncursesw5-dev replaced by libncurses-dev, which is
# the only name available on Ubuntu 24.04 and later.
#
# kconfig-frontends-nox is still required even with kconfiglib: NuttX
# tools/sethost.sh calls "kconfig-tweak", which kconfiglib does not
# provide. NuttX prefers kconfiglib whenever "menuconfig" (from the
# venv) is in PATH, so the two do not conflict.

APT_PACKAGES=(
  bison flex gettext texinfo libncurses-dev gperf automake autoconf
  libtool pkg-config build-essential genromfs libgmp-dev libmpc-dev
  libmpfr-dev libisl-dev binutils-dev libelf-dev libexpat1-dev
  gcc-multilib g++-multilib picocom minicom u-boot-tools util-linux
  git curl xz-utils xxd cmake ninja-build libusb-1.0-0-dev
  python3 python3-pip python3-venv openocd kconfig-frontends-nox
  festival
)

#==========================================================================
# Helpers
#==========================================================================

#--------------------------------------------------------------------------
# Haindall's voice
#
# Speech runs in the background so long steps are not delayed, but each
# phrase waits for the previous one: phrases never overlap and keep
# their order. Questions are spoken synchronously, before the prompt.
# Without festival, or with BIFROST_VOICE=0, everything stays silent and
# the script behaves exactly the same.
#--------------------------------------------------------------------------

VOICE_PID=""

voice_on()
{
  [[ "$BIFROST_VOICE" == "1" ]] && command -v festival >/dev/null 2>&1
}

# voice_wait: block until the phrase being spoken (if any) ends.

voice_wait()
{
  if [[ -n "$VOICE_PID" ]]; then
    wait "$VOICE_PID" 2>/dev/null || true
    VOICE_PID=""
  fi
}

# speak <text>: queue a phrase. speak_sync <text>: speak and wait.

speak()
{
  voice_on || return 0
  voice_wait
  printf '%s\n' "$*" | festival --tts >/dev/null 2>&1 &
  VOICE_PID=$!
}

speak_sync()
{
  speak "$@"
  voice_wait
}

# spell <text>: make board names pronounceable ("esp32c3-devkit:nsh"
# becomes "esp32c3 devkit nsh").

spell()
{
  local s="$1"
  printf '%s' "${s//[:_\/-]/ }"
}

# log: detail line, printed only. say: a step, printed and spoken.
# warn / die: printed to stderr and spoken; die() aborts the script.

log() { printf '[bifrost] %s\n' "$*"; }

say()
{
  printf '[haindall] %s\n' "$*"
  speak "$*"
}

warn()
{
  printf '[bifrost] WARNING: %s\n' "$*" >&2
  speak "Warning. $*"
}

die()
{
  printf '[bifrost] ERROR: %s\n' "$*" >&2
  speak_sync "Something went wrong. $*"
  exit 1
}

# ask <prompt> <var> [spoken]: speak the question (or [spoken], when the
# printed prompt does not read well aloud), then read the answer into
# the variable named <var>. Aborts cleanly on end of input (Ctrl-D).

ask()
{
  local prompt="$1" __var="$2" __spoken="${3:-$1}" __ans

  speak_sync "$__spoken"
  read -r -p "[haindall] $prompt " __ans || die "no answer, leaving"
  printf -v "$__var" '%s' "$__ans"
}

# confirm <question>: true only on an explicit "y" or "yes".

confirm()
{
  local ans

  ask "$1 (y/n)" ans
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

# Report the failing line when strict mode aborts; let the last phrase
# finish before the script exits.

trap 'printf "[bifrost] failed at line %s: %s\n" "$LINENO" \
  "$BASH_COMMAND" >&2; speak "A step failed."' ERR
trap 'voice_wait' EXIT

# need <cmd>: abort if a host command is missing.

need()
{
  command -v "$1" >/dev/null 2>&1 || die "'$1' not found; run 'deps'"
}

# pkg_installed <pkg>: exact dpkg status check. "dpkg -l | grep -w"
# gives false positives (e.g. "libusb" matches "libusb-1.0-0-dev").

pkg_installed()
{
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null \
    | grep -q 'install ok installed'
}

# git_sync <url> <dir> [git clone args...]: clone if absent, otherwise
# fast-forward. Never touches local changes: a non fast-forward pull
# fails loudly instead of merging.

git_sync()
{
  local url="$1" dir="$2"
  shift 2

  if [[ -d "$dir/.git" ]]; then
    log "updating $(basename "$dir")"
    git -C "$dir" pull --ff-only
    git -C "$dir" submodule update --init --recursive
  else
    log "cloning $url"
    git clone "$@" "$url" "$dir"
  fi
}

# install_tarball <url> <dest>: download an archive to a temp file and
# extract it into <dest>, stripping the top-level directory. Skips the
# download if <dest>/bin already exists (delete <dest> to reinstall).
# tar auto-detects gz/xz from the file, so one helper fits all.

install_tarball()
{
  local url="$1" dest="$2" tmp

  if [[ -d "$dest/bin" ]]; then
    log "$(basename "$dest") already installed, skipping"
    return 0
  fi

  need curl
  tmp="$(mktemp)"
  log "downloading $url"
  if ! curl -fL --retry 3 -o "$tmp" "$url"; then
    rm -f "$tmp"
    die "download failed; check the version variable for this tool"
  fi

  mkdir -p "$dest"
  tar -xf "$tmp" -C "$dest" --strip-components 1
  rm -f "$tmp"
  log "installed into $dest"
}

# load_env: make toolchains, venv and PICO_SDK_PATH visible to the
# commands run by this script. Uses the same file the user sources.

load_env()
{
  [[ -f "$ENV_FILE" ]] || write_env
  # shellcheck source=/dev/null
  source "$ENV_FILE"
}

# in_nuttx: enter the NuttX tree or abort.

in_nuttx()
{
  [[ -d "$NUTTX_DIR" ]] || die "NuttX not found; run 'src' first"
  cd "$NUTTX_DIR"
}


#==========================================================================
# Haindall setup
#==========================================================================

# voice: install festival only, so Haindall can speak before "deps".

cmd_voice()
{
  if ! command -v festival >/dev/null 2>&1; then
    log "installing festival"
    sudo apt-get install -y festival </dev/null
    record_apt festival
  fi
  say "Hi. I am Haindall. I can speak now."
}

# greet: first words of every run. Offers to install festival when it
# is missing, like the original Raindal_Guide did.

greet()
{
  if [[ "$BIFROST_VOICE" == "1" ]] && [[ -t 0 ]] \
     && ! command -v festival >/dev/null 2>&1; then
    if confirm "Haindall needs festival to speak. Install it now?"; then
      cmd_voice
    else
      log "silent run; set BIFROST_VOICE=0 to skip this question"
    fi
  fi

  say "Hi. I am Haindall, guardian of the Bifrost."
  say "Today I am going to help you with Nuttx."
}

#==========================================================================
# Host setup
#==========================================================================

# deps: install missing apt packages in a single apt call. Serial port
# access (dialout group) is handled by check_dialout() at start-up.
#
# Every apt-get call reads stdin from /dev/null: dpkg otherwise consumes
# the terminal input meant for the next questions (seen in uninstall).
# sudo still asks for the password through /dev/tty.

cmd_deps()
{
  local missing=() p

  say "Checking the host packages."

  for p in "${APT_PACKAGES[@]}"; do
    pkg_installed "$p" || missing+=("$p")
  done

  if ((${#missing[@]})); then
    say "Installing ${#missing[@]} missing packages."
    log "installing: ${missing[*]}"
    sudo apt-get update </dev/null
    sudo apt-get install -y "${missing[@]}" </dev/null
    record_apt "${missing[@]}"
  else
    say "All host packages are already installed."
  fi

}

#--------------------------------------------------------------------------
# Serial port access
#
# /dev/ttyUSB* and /dev/ttyACM* belong to the "dialout" group; without it
# esptool, picocom and minicom fail with "Permission denied". Two states
# matter:
#   - user not in dialout at all (/etc/group): offer to add him
#   - user added, but this login session predates it: the group only
#     shows up after a new login. Offer a reboot; if declined, re-run
#     this same command line under "sg dialout", which grants the group
#     to this run only. ("newgrp" is not used: it opens a new shell and
#     blocks the script.) BIFROST_SG marks the re-run, so it can never
#     loop.
#--------------------------------------------------------------------------

check_dialout()
{
  local me

  me="$(id -un)"   # $USER is not always set (containers, cron)
  id -nG | grep -qw dialout && return 0

  if ! id -nG "$me" | grep -qw dialout; then
    if [[ ! -t 0 ]]; then
      warn "$me is not in the dialout group; serial ports will fail."
      return 0
    fi
    if ! confirm "To use serial ports, $me must be in the dialout \
group. Add it now?"; then
      say "Ok. Serial ports will not work until you are in dialout."
      return 0
    fi
    sudo usermod -aG dialout "$me"
    say "Added $me to the dialout group."
  fi

  [[ -t 0 && -z "${BIFROST_SG:-}" ]] || return 0

  if confirm "The dialout group needs a new login (log out and in, or \
reboot). Reboot now?"; then
    speak_sync "Rebooting. See you soon."
    sudo reboot
    exit 0
  fi

  say "Ok. Using the dialout group for this run only."
  export BIFROST_SG=1
  voice_wait
  exec sg dialout -c "$(printf '%q ' "$0" "$@")"
}
#
# Fixes over the original menu:
#   - "clean" deletes the contents with one rm per top-level entry and
#     refuses to run on "/", $HOME or an empty path
#   - "new folder" re-derives every path (set_paths) and saves the new
#     root, so later runs keep using it
#   - every option recreates the full layout
#   - new option 1 keeps the existing folder, so "setup" can run again
#     without destroying anything
#   - non-interactive runs (no terminal) always keep the folder
#--------------------------------------------------------------------------

make_tree()
{
  mkdir -p "$NUTTXSPACE_DIR" "$TOOLS_DIR"
  log "layout ready under $BIFROST_ROOT"
}

save_root()
{
  mkdir -p "$(dirname "$BIFROST_CONF")"
  printf '%s\n' "$BIFROST_ROOT" > "$BIFROST_CONF"
  log "root saved in $BIFROST_CONF"
}

# record_apt <pkg...>: remember packages installed by Bifrost, for
# "uninstall". Duplicates are dropped.

record_apt()
{
  mkdir -p "$BIFROST_STATE"
  printf '%s\n' "$@" >> "$BIFROST_APT_LOG"
  sort -u -o "$BIFROST_APT_LOG" "$BIFROST_APT_LOG"
}

# root_is_safe: guard for destructive options.

root_is_safe()
{
  local r

  r="$(realpath -m -- "$BIFROST_ROOT")"
  [[ -n "$r" && "$r" != "/" && "$r" != "$(realpath -m -- "$HOME")" ]]
}

show_folder_menu()
{
  printf ' 1 - Keep it and use it as it is\n'
  printf ' 2 - Clean everything inside it\n'
  printf ' 3 - Use a new folder in %s\n' "$HOME"
  printf ' 4 - Rename it to %s_old and start a new one\n' \
    "$(basename "$BIFROST_ROOT")"
}

# folder_option <1-4>: run one folder menu option. Shared by "tree" and
# "--menu". Returns 0 when done, 1 when the user should choose again.
# Every option ends with the full layout in place.

folder_option()
{
  local name new old

  case "$1" in
    1)
      say "Ok. Keeping the current folder."
      ;;

    2)
      if [[ -d "$BIFROST_ROOT" ]]; then
        root_is_safe || die "refusing to clean $BIFROST_ROOT"
        if ! confirm "Delete everything inside $BIFROST_ROOT?"; then
          say "It seems you are not so sure. Let us try once more."
          return 1
        fi
        say "Ok. Cleaning the whole folder."
        find "$BIFROST_ROOT" -mindepth 1 -maxdepth 1 \
          -exec rm -rf -- {} +
      fi
      ;;

    3)
      ask "New folder name (created in $HOME):" name \
        "Please, tell me the new folder name."
      if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ \
            || "$name" == "." || "$name" == ".." ]]; then
        say "Invalid name. Use letters, numbers, dot, dash or \
underscore."
        return 1
      fi
      new="$HOME/$name"
      if [[ -e "$new" ]]; then
        say "The folder $name already exists. Try another name."
        return 1
      fi
      BIFROST_ROOT="$new"
      set_paths
      save_root
      say "The new folder $name was created."
      ;;

    4)
      if [[ -d "$BIFROST_ROOT" ]]; then
        root_is_safe || die "refusing to rename $BIFROST_ROOT"
        old="${BIFROST_ROOT}_old"
        if [[ -e "$old" ]]; then
          old="${old}_$(date +%Y%m%d_%H%M%S)"
        fi
        mv -- "$BIFROST_ROOT" "$old"
        say "Renamed the old folder to $(basename "$old")."
      fi
      ;;

    *)
      say "Wrong option. Please, try again."
      return 1
      ;;
  esac

  make_tree
}

# tree: the folder menu only appears when it is needed: the root
# already exists AND there is a terminal to answer it. A missing root is
# simply created; without a terminal the existing root is kept. It runs
# from "tree", "src" and "setup" (or any time from "--menu").

cmd_tree()
{
  local opt

  if [[ ! -d "$BIFROST_ROOT" ]]; then
    say "Creating the project folder."
    make_tree
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log "$BIFROST_ROOT exists; no terminal, keeping it"
    make_tree
    return 0
  fi

  while true; do
    printf '\n The folder %s already exists.\n\n' "$BIFROST_ROOT"
    show_folder_menu
    printf '\n'
    say "The project folder already exists."
    ask "Choose an option (1/2/3/4):" opt \
      "Choose one option. One, keep it. Two, clean it. \
Three, use a new folder. Four, rename it and start a new one."
    folder_option "$opt" && return 0
  done
}

# src: clone or update nuttx and apps side by side, as NuttX expects.

cmd_src()
{
  need git
  cmd_tree
  say "Downloading the Nuttx kernel."
  git_sync "$NUTTX_GIT" "$NUTTX_DIR"
  say "Downloading the Nuttx applications."
  git_sync "$APPS_GIT" "$APPS_DIR"
}

# venv: Python virtual environment with kconfiglib and esptool. A venv
# avoids PEP 668 "externally managed environment" errors on Ubuntu
# 23.04+ and keeps host Python untouched. kconfiglib provides the
# menuconfig/olddefconfig/... entry points NuttX calls during
# configure and build, so the venv must be active (see env.sh).

cmd_venv()
{
  need python3

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    say "Creating the Python virtual environment."
    python3 -m venv "$VENV_DIR"
  fi

  say "Installing kconfiglib and esptool."
  "$VENV_DIR/bin/python" -m pip install --upgrade pip
  "$VENV_DIR/bin/python" -m pip install --upgrade "${PIP_PACKAGES[@]}"
}

#==========================================================================
# Toolchains
#==========================================================================

cmd_tc_arm()
{
  say "Installing the ARM toolchain."
  install_tarball "$ARM_TC_URL" "$TOOLS_DIR/arm-none-eabi-gcc"
}

cmd_tc_riscv()
{
  say "Installing the RISC-V toolchain."
  install_tarball "$RISCV_TC_URL" "$TOOLS_DIR/riscv-none-elf-gcc"
}

cmd_tc_xtensa()
{
  say "Installing the Xtensa toolchain."
  install_tarball "$XTENSA_TC_URL" "$TOOLS_DIR/xtensa-esp-elf-gcc"
}

cmd_tc_all()
{
  cmd_tc_arm
  cmd_tc_riscv
  cmd_tc_xtensa
}

#==========================================================================
# Raspberry Pi Pico (RP2040 / RP2350)
#==========================================================================

# pico-sdk: RP2040 flash builds stop with an error if PICO_SDK_PATH is
# unset; the SDK is also needed to build picotool.

cmd_pico_sdk()
{
  need git
  say "Downloading the Raspberry Pi Pico SDK."
  git_sync "$PICO_SDK_GIT" "$TOOLS_DIR/pico-sdk" \
    -b "$PICO_SDK_VER" --recurse-submodules
}

# picotool: needed to produce nuttx.uf2 on RP2350, optional loader for
# both chips. Prebuilt binary, extracted into tools/picotool/bin so the
# env.sh PATH logic finds it like every other tool.

cmd_picotool()
{
  if [[ -x "$TOOLS_DIR/picotool/bin/picotool" ]]; then
    log "picotool already installed, skipping"
    return 0
  fi
  say "Installing picotool."
  install_tarball "$PICOTOOL_URL" "$TOOLS_DIR/picotool/bin"
}

#==========================================================================
# Debug tools
#==========================================================================

# ocd-esp: prebuilt Espressif OpenOCD fork. Upstream OpenOCD (installed
# by "deps") covers STM32 and RP2040; ESP chips need this fork.

cmd_ocd_esp()
{
  say "Installing the Espressif OpenOCD."
  install_tarball "$OCD_ESP_URL" "$TOOLS_DIR/openocd-esp32"
}

#==========================================================================
# Environment file
#==========================================================================

# env: write env.sh. Only directories that exist are added to PATH, so
# the file stays valid whatever subset of toolchains is installed.
# The quoted heredoc keeps $VARS literal; they expand when sourced.

write_env()
{
  mkdir -p "$BIFROST_ROOT"

  cat > "$ENV_FILE" <<'EOF'
# Generated by bifrost.sh - source it: ". <bifrost root>/env.sh"

BIFROST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BIFROST_ROOT

for _bf in arm-none-eabi-gcc riscv-none-elf-gcc xtensa-esp-elf-gcc \
           openocd-esp32 picotool; do
  _bf="$BIFROST_ROOT/tools/$_bf/bin"
  if [ -d "$_bf" ]; then
    case ":$PATH:" in
      *":$_bf:"*) ;;
      *) PATH="$_bf:$PATH" ;;
    esac
  fi
done
unset _bf
export PATH

if [ -d "$BIFROST_ROOT/tools/pico-sdk" ]; then
  export PICO_SDK_PATH="$BIFROST_ROOT/tools/pico-sdk"
fi

if [ -f "$BIFROST_ROOT/nuttx_venv/bin/activate" ] && [ -z "${VIRTUAL_ENV:-}" ]
then
  . "$BIFROST_ROOT/nuttx_venv/bin/activate"
fi
EOF

  log "wrote $ENV_FILE"
}

cmd_env()
{
  say "Writing the environment file."
  write_env
}

# rc: add a single "source env.sh" line to ~/.bashrc (opt-in).

cmd_rc()
{
  local line=". \"$ENV_FILE\""

  [[ -f "$ENV_FILE" ]] || write_env
  if grep -qxF "$line" "$HOME/.bashrc" 2>/dev/null; then
    say "Your bashrc already loads the environment."
  else
    printf '\n# Bifrost NuttX environment\n%s\n' "$line" \
      >> "$HOME/.bashrc"
    say "Added the environment to your bashrc. Open a new terminal."
  fi
}

#==========================================================================
# NuttX build
#==========================================================================

# nx_run <script>: run a shell snippet inside nuttx/, either on the
# host (with env.sh loaded) or inside the CI container (docker mode).
# Extra "docker run" options can be added through the DOCKER_EXTRA
# array (flash-esp uses it to pass the serial device).
#
# In docker mode nuttxspace/ is mounted at the SAME absolute path it
# has on the host: NuttX writes absolute paths into the build tree
# (.config, Make.defs links), so host and container stay interchangeable.
# The container runs with the caller's UID/GID, so no root-owned files
# are left behind.

DOCKER_EXTRA=()

nx_run()
{
  local script="$1" tty=()

  [[ -d "$NUTTX_DIR" ]] || die "NuttX not found; run 'src' first"

  if [[ "$BIFROST_DOCKER" != "1" ]]; then
    load_env
    in_nuttx
    bash -ec "$script"
    return
  fi

  need docker
  if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    say "Downloading the Nuttx CI image. It is large, please wait."
    docker pull "$DOCKER_IMAGE"
  fi

  [[ -t 0 ]] && tty=(-it)
  docker run --rm "${tty[@]}" \
    -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$NUTTXSPACE_DIR:$NUTTXSPACE_DIR" -w "$NUTTX_DIR" \
    "${DOCKER_EXTRA[@]}" "$DOCKER_IMAGE" bash -ec "$script"
}

# conf <board:config>: distclean then configure. List all boards with
# "./tools/configure.sh -L" inside nuttx/.
#
# configure.sh already runs "make olddefconfig" (via sethost.sh). The
# second pass is a cheap safety net: if a previous configure aborted
# half-way (e.g. kconfig-tweak missing), the .config may lack derived
# symbols and a parallel "make" fails in odd places. It is a no-op on a
# healthy tree.

cmd_conf()
{
  local cfg="${1:-}"

  [[ -n "$cfg" ]] || die "usage: conf <board:config>"
  say "Configuring Nuttx for $(spell "$cfg")."
  nx_run "make distclean >/dev/null 2>&1 || true
          ./tools/configure.sh $(printf '%q' "$cfg")
          make olddefconfig"

  # Remember which board:config is in the tree, so the flash menu can
  # tell whether the current image matches the chosen board.

  printf '%s\n' "$cfg" > "$LAST_CONF"
}

cmd_menuconfig()
{
  say "Opening menuconfig."
  nx_run "make menuconfig"
}

cmd_build()
{
  say "Compiling Nuttx. This can take a while."
  # Single quotes on purpose: nproc must expand where make runs
  # (host or container), not here.
  # shellcheck disable=SC2016
  nx_run 'make -j"$(nproc)"'
  say "Build finished."
}

# rebuild: full rebuild keeping the current .config (the old
# CLEAN_FLASH_STM32H7 alias, minus the flash: chain "flash-stm32").

cmd_rebuild()
{
  say "Cleaning Nuttx and the applications, keeping the configuration."
  nx_run "make clean && make apps_clean"
  cmd_build
}

cmd_clean()
{
  say "Cleaning the Nuttx configuration and binaries."
  nx_run "make distclean"
}

# sim: configure, build and run the native simulator.

cmd_sim()
{
  cmd_conf sim:nsh
  cmd_build
  speak_sync "Starting the simulator. Type poweroff to leave."
  nx_run "./nuttx"
}

#==========================================================================
# Docker
#==========================================================================

# docker-deps: Docker engine from the Ubuntu archive plus "docker" group
# membership (log out and back in to use docker without sudo).

cmd_docker_deps()
{
  local me

  me="$(id -un)"
  if ! command -v docker >/dev/null 2>&1; then
    say "Installing Docker."
    sudo apt-get update </dev/null
    sudo apt-get install -y docker.io </dev/null
    record_apt docker.io
  else
    say "Docker is already installed."
  fi

  if ! id -nG "$me" | grep -qw docker; then
    sudo usermod -aG docker "$me"
    warn "you were added to the docker group. Log out and back in."
  fi
}

cmd_docker_pull()
{
  need docker
  say "Downloading the Nuttx CI image. It is large, please wait."
  docker pull "$DOCKER_IMAGE"
}

# docker-shell: interactive shell in the CI image, inside nuttx/.

cmd_docker_shell()
{
  BIFROST_DOCKER=1
  say "Opening a shell inside the Nuttx CI container."
  nx_run "exec bash"
}

#==========================================================================
# Flashing
#==========================================================================

# flash-esp [port]: all Espressif chips. With Simple Boot the build
# produces nuttx.bin with everything needed to boot; "make flash"
# calls esptool from the venv. ESPTOOL_BINDIR=./ is what the NuttX
# docs use when no external 2nd stage bootloader is built.

# In docker mode the serial device is passed into the container, with
# the group that owns it, so esptool can open it as a normal user.

cmd_flash_esp()
{
  local port="${1:-$ESP_PORT}"

  [[ -e "$port" ]] || die "serial port $port not found"
  if [[ "$BIFROST_DOCKER" == "1" ]]; then
    DOCKER_EXTRA=(--device "$port" --group-add "$(stat -c %g "$port")")
  fi

  say "Flashing the Espressif board."
  nx_run "make flash ESPTOOL_PORT=$(printf '%q' "$port") \
          ESPTOOL_BINDIR=./"
  DOCKER_EXTRA=()
  say "Flash done."
}

# flash-pico: RP2040 / RP2350. Uses picotool when available (board must
# be in BOOTSEL mode), otherwise guides the drag-and-drop procedure.

cmd_flash_pico()
{
  load_env
  in_nuttx
  [[ -f nuttx.uf2 ]] || die "nuttx.uf2 not found; build first"

  if command -v picotool >/dev/null 2>&1; then
    say "Put the board in BOOTSEL mode. Flashing with picotool."
    picotool load -x nuttx.uf2
    say "Flash done."
  else
    say "Unplug the board."
    say "Hold the BOOTSEL button and plug it back in."
    say "Release the button. A USB drive appears."
    say "Copy nuttx dot u f 2 to that drive."
    log "file: $NUTTX_DIR/nuttx.uf2"
  fi
}

# stm32_target <chip>: map a short chip name to an OpenOCD script.
# Anything ending in ".cfg" is passed through unchanged, so any other
# family works too, e.g. "flash-stm32 target/stm32g4x.cfg".
#
# Blue Pill: upstream OpenOCD 0.12 has no "target/bluepill.cfg"; the
# board file below sets FLASH_SIZE 128K and sources stm32f1x.cfg.
# Clone chips (CKS32/CS32) report another SWD ID; run with
# STM32_OCD_EXTRA="set CPUTAPID 0x2ba01477" for those.

stm32_target()
{
  case "$1" in
    f1)       echo "target/stm32f1x.cfg" ;;
    f3)       echo "target/stm32f3x.cfg" ;;
    f4)       echo "target/stm32f4x.cfg" ;;
    f7)       echo "target/stm32f7x.cfg" ;;
    h7)       echo "target/stm32h7x.cfg" ;;
    bluepill) echo "board/stm32f103c8_blue_pill.cfg" ;;
    *.cfg)    echo "$1" ;;
    *)        return 1 ;;
  esac
}

# stm32_pick_mode: resolve the image format. Order: argument, then
# STM32_FLASH_MODE, then ask (terminal only), then elf.

stm32_pick_mode()
{
  local ans

  if [[ -z "$STM32_FLASH_MODE" ]]; then
    if [[ -t 0 ]]; then
      ask "Flash which image, elf or bin? [elf]:" ans \
        "Which image should I flash? E L F, or bin?"
      STM32_FLASH_MODE="${ans:-elf}"
    else
      STM32_FLASH_MODE="elf"
    fi
  fi

  [[ "$STM32_FLASH_MODE" == "elf" || "$STM32_FLASH_MODE" == "bin" ]] \
    || die "image format must be elf or bin, not '$STM32_FLASH_MODE'"
}

# stm32_make_bin: nuttx.bin only exists with CONFIG_RAW_BINARY=y.
# Offer to enable it (kconfig-tweak + olddefconfig) and rebuild.

stm32_make_bin()
{
  [[ -f nuttx.bin ]] && return 0
  [[ -t 0 ]] || die "nuttx.bin not found; enable CONFIG_RAW_BINARY"

  confirm "nuttx.bin not found. Enable CONFIG_RAW_BINARY and rebuild?" \
    || die "nuttx.bin not found; enable CONFIG_RAW_BINARY"

  say "Enabling the raw binary output."
  nx_run "kconfig-tweak --file .config --enable CONFIG_RAW_BINARY
          make olddefconfig"
  cmd_build
  [[ -f nuttx.bin ]] || die "build did not produce nuttx.bin"
}

# flash-stm32 [chip] [elf|bin]: write the image through upstream
# OpenOCD with an ST-Link (STM32_OCD_IF). Both arguments are optional
# and may come in any order. Pre-target "set" commands (DUAL_BANK,
# STM32_OCD_EXTRA) must come before the target file is parsed. Every
# mode ends OpenOCD ("exit"/"shutdown") so the port is released.

cmd_flash_stm32()
{
  local chip="$STM32_CHIP" target a
  local args=(-f "$STM32_OCD_IF")

  for a in "$@"; do
    case "$a" in
      "")      ;;
      elf|bin) STM32_FLASH_MODE="$a" ;;
      *)       chip="$a" ;;
    esac
  done

  need openocd
  in_nuttx
  target="$(stm32_target "$chip")" \
    || die "unknown STM32 chip '$chip' (f1 f3 f4 f7 h7 bluepill or .cfg)"
  stm32_pick_mode

  if [[ "$chip" == "h7" && "$STM32_DUAL_BANK" == "1" ]]; then
    args+=(-c "set DUAL_BANK 1")
  fi
  if [[ -n "${STM32_OCD_EXTRA:-}" ]]; then
    args+=(-c "$STM32_OCD_EXTRA")
  fi
  args+=(-f "$target")

  case "$STM32_FLASH_MODE" in
    elf)
      [[ -f nuttx ]] || die "nuttx ELF not found; build first"
      args+=(-c "program nuttx verify reset exit")
      ;;
    bin)
      stm32_make_bin
      args+=(-c "init" -c "reset halt"
             -c "flash write_image erase nuttx.bin $STM32_FLASH_ADDR"
             -c "verify_image nuttx.bin $STM32_FLASH_ADDR"
             -c "reset run" -c "shutdown")
      ;;
  esac

  say "Flashing the STM32 board, $(spell "$chip"), \
from the $STM32_FLASH_MODE image."
  openocd "${args[@]}"
  say "Flash done."
}

#==========================================================================
# Interactive menu (--menu)
#
# Two parts:
#   1-4  folder options, the same ones "tree" offers
#   5..  flash only: one entry per board preset below
#
# Flash only never flashes a mismatched image: it compares the chosen
# board:config with the one the tree was last configured for
# ($LAST_CONF, written by "conf"). On mismatch, or with no image yet,
# it offers to configure and build first.
#==========================================================================

# Board presets: "label|board:config|flasher [chip]". The flasher is
# stm32 (with the flash-stm32 chip), esp or pico. Add a board here and
# it shows up in the menu.

BOARD_PRESETS=(
  "Nucleo-H753ZI (ODIN)|nucleo-h753zi:nsh|stm32 h7"
  "Nucleo-H743ZI|nucleo-h743zi:nsh|stm32 h7"
  "Nucleo-F767ZI|nucleo-f767zi:nsh|stm32 f7"
  "STM32F4 Discovery|stm32f4discovery:nsh|stm32 f4"
  "Nucleo-F446RE|nucleo-f446re:nsh|stm32 f4"
  "STM32F3 Discovery|stm32f3discovery:nsh|stm32 f3"
  "Nucleo-F303RE|nucleo-f303re:nsh|stm32 f3"
  "Blue Pill (STM32F103C8)|stm32f103-minimum:nsh|stm32 bluepill"
  "ESP32-C3 DevKit|esp32c3-devkit:nsh|esp"
  "ESP32-C6 DevKitC|esp32c6-devkitc:nsh|esp"
  "ESP32-S3 DevKit|esp32s3-devkit:nsh|esp"
  "ESP32-S3-Touch-LCD-7, lcd|esp32s3-touch-lcd7:lcd|esp"
  "ESP32-S3-Touch-LCD-7, usbnsh|esp32s3-touch-lcd7:usbnsh|esp"
  "ESP32-S2 Saola-1|esp32s2-saola-1:nsh|esp"
  "ESP32 DevKitC|esp32-devkitc:nsh|esp"
  "Raspberry Pi Pico|raspberrypi-pico:nsh|pico"
  "Raspberry Pi Pico W|raspberrypi-pico-w:nsh|pico"
  "Raspberry Pi Pico 2|raspberrypi-pico-2:nsh|pico"
)

MENU_FIRST_BOARD=5

# image_ready <flasher>: the build output that flasher needs exists.

image_ready()
{
  case "$1" in
    stm32) [[ -f "$NUTTX_DIR/nuttx" ]] ;;
    esp)   [[ -f "$NUTTX_DIR/nuttx.bin" ]] ;;
    pico)  [[ -f "$NUTTX_DIR/nuttx.uf2" ]] ;;
  esac
}

# default_port: first serial port that exists (CH343/CP210x boards
# show up as ttyACM or ttyUSB), or the ESP_PORT default.

default_port()
{
  local p

  for p in /dev/ttyACM0 /dev/ttyUSB0 /dev/ttyACM1 /dev/ttyUSB1; do
    [[ -e "$p" ]] && { echo "$p"; return; }
  done
  echo "$ESP_PORT"
}

# menu_flash <preset index>: flash one preset, building first if the
# tree holds another board or no image.

menu_flash()
{
  local label cfg flasher chip last port

  IFS='|' read -r label cfg flasher <<< "${BOARD_PRESETS[$1]}"
  read -r flasher chip <<< "$flasher"
  [[ -d "$NUTTX_DIR" ]] || { say "Nuttx is not downloaded yet."; return; }

  last="$(cat "$LAST_CONF" 2>/dev/null || true)"
  if [[ "$last" != "$cfg" ]] || ! image_ready "$flasher"; then
    printf '\n Tree configured for: %s\n Chosen board:        %s\n\n' \
      "${last:-unknown}" "$cfg"
    if ! confirm "The current image is not for $label. Configure and \
build it now?"; then
      say "Ok. Nothing was flashed."
      return
    fi
    cmd_conf "$cfg"
    cmd_build
  fi

  case "$flasher" in
    stm32)
      cmd_flash_stm32 "$chip"
      ;;
    esp)
      port="$(default_port)"
      ask "Serial port [$port]:" port "Which serial port? Press enter \
for the default."
      cmd_flash_esp "${port:-$(default_port)}"
      ;;
    pico)
      cmd_flash_pico
      ;;
  esac
}

show_main_menu()
{
  local i n=$MENU_FIRST_BOARD label

  printf '\n Project folder: %s\n\n' "$BIFROST_ROOT"
  show_folder_menu
  printf '\n Flash only (builds first if the image is for another '
  printf 'board):\n'
  for i in "${!BOARD_PRESETS[@]}"; do
    label="${BOARD_PRESETS[$i]%%|*}"
    printf ' %2d - %s\n' "$n" "$label"
    n=$((n + 1))
  done
  printf '\n  0 - Exit\n\n'
}

cmd_menu()
{
  local opt rc last=$((MENU_FIRST_BOARD + ${#BOARD_PRESETS[@]} - 1))

  [[ -t 0 ]] || die "--menu needs a terminal"

  while true; do
    show_main_menu
    ask "Choose an option (0-$last):" opt "Choose an option."

    if [[ "$opt" == "0" ]]; then
      say "Leaving the menu."
      return 0
    elif [[ "$opt" =~ ^[1-4]$ ]]; then
      folder_option "$opt" || true
    elif [[ "$opt" =~ ^[0-9]+$ ]] && ((opt >= MENU_FIRST_BOARD \
         && opt <= last)); then
      # Subshell: a failed build/flash (die, set -e) ends only this
      # entry, not the menu. The parent turns errexit off to survive
      # the failure; the subshell turns it back on for itself (inside
      # an "if" or "||" bash would silently ignore it instead).
      set +e
      (set -e; menu_flash $((opt - MENU_FIRST_BOARD)))
      rc=$?
      set -e
      ((rc == 0)) || say "That step failed. Back to the menu."
    else
      say "Wrong option. Please, try again."
    fi
  done
}

#==========================================================================
# Uninstall
#
# Undoes everything Bifrost did, one confirmed step at a time:
#   1. root folder: toolchains, venv, tools, env.sh; the NuttX sources
#      (nuttx/, apps/) are asked separately, they may hold your work
#   2. the env.sh line "rc" added to ~/.bashrc (backup kept)
#   3. the NuttX CI Docker image
#   4. apt packages Bifrost installed (from the apt-installed record;
#      anything you already had is never touched)
#   5. dialout / docker group membership (default: keep, other tools
#      may rely on it)
#   6. Bifrost state in ~/.config/bifrost
# Needs a terminal: nothing is ever deleted without an answer.
#==========================================================================

uninstall_root()
{
  [[ -d "$BIFROST_ROOT" ]] || { log "no $BIFROST_ROOT, skipping"; return; }
  root_is_safe || die "refusing to delete $BIFROST_ROOT"

  confirm "Delete toolchains, tools and the venv in $BIFROST_ROOT?" \
    || { say "Keeping the project folder."; return; }

  if confirm "Delete the Nuttx sources too? Local changes in nuttx and \
apps will be lost."; then
    say "Deleting the whole project folder."
    rm -rf -- "$BIFROST_ROOT"
  else
    say "Deleting everything except the Nuttx sources."
    find "$BIFROST_ROOT" -mindepth 1 -maxdepth 1 ! -name nuttxspace \
      -exec rm -rf -- {} +
  fi
}

uninstall_rc()
{
  local line=". \"$ENV_FILE\"" rc="$HOME/.bashrc"

  grep -qxF "$line" "$rc" 2>/dev/null || return 0
  confirm "Remove the Bifrost line from your bashrc?" || return 0

  cp -- "$rc" "$rc.bifrost.bak"
  grep -vxF -e "$line" -e "# Bifrost NuttX environment" \
    "$rc.bifrost.bak" > "$rc" || true
  say "Removed. A backup is in bashrc dot bifrost dot bak."
}

uninstall_docker_image()
{
  command -v docker >/dev/null 2>&1 || return 0
  docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1 || return 0
  confirm "Delete the Nuttx CI Docker image?" || return 0
  docker rmi "$DOCKER_IMAGE"
}

uninstall_apt()
{
  local pkgs=()

  [[ -s "$BIFROST_APT_LOG" ]] || {
    log "no record of apt packages installed by Bifrost"
    return 0
  }
  mapfile -t pkgs < "$BIFROST_APT_LOG"

  printf '\n Packages installed by Bifrost:\n  %s\n\n' "${pkgs[*]}"
  if confirm "Remove these ${#pkgs[@]} packages?"; then
    say "Removing the packages."
    sudo apt-get remove -y "${pkgs[@]}" </dev/null
    rm -f -- "$BIFROST_APT_LOG"
    log "unused dependencies: sudo apt-get autoremove"
  fi
}

uninstall_groups()
{
  local me g

  me="$(id -un)"
  for g in dialout docker; do
    id -nG "$me" | grep -qw "$g" || continue
    if confirm "Remove $me from the $g group? Other tools may need it."
    then
      sudo gpasswd -d "$me" "$g"
    fi
  done
}

cmd_uninstall()
{
  [[ -t 0 ]] || die "uninstall needs a terminal to confirm each step"

  say "Uninstall. I will ask before each step."
  uninstall_root
  uninstall_rc
  uninstall_docker_image
  uninstall_apt
  uninstall_groups

  if [[ -d "$BIFROST_STATE" ]] \
     && confirm "Forget the saved Bifrost settings?"; then
    rm -rf -- "$BIFROST_STATE"
  fi

  say "Uninstall complete."
}

#==========================================================================
# Meta
#==========================================================================

# setup: everything needed for all supported targets.

cmd_setup()
{
  cmd_deps
  cmd_src
  cmd_venv
  cmd_tc_all
  cmd_pico_sdk
  cmd_picotool
  write_env
  say "Setup complete."
  log "run: . \"$ENV_FILE\""
}

cmd_help()
{
  cat <<EOF
Usage: $(basename "$0") <command> [args] [<command> [args] ...]

Haindall speaks every step (festival). Silence him: BIFROST_VOICE=0

Host setup:
  voice                install festival only (Haindall's voice)
  deps                 install missing apt packages
  tree                 create layout; menu if the folder already exists
  src                  clone/update nuttx and nuttx-apps
  venv                 create venv with kconfiglib and esptool
  setup                deps + src + venv + all toolchains + pico tools

Toolchains:
  tc-arm               ARM GNU (STM32, RP2040, RP2350)
  tc-riscv             xPack RISC-V (ESP32-C3, ESP32-C6)
  tc-xtensa            Espressif Xtensa (ESP32, ESP32-S2, ESP32-S3)
  tc-all               all of the above

Raspberry Pi Pico:
  pico-sdk             clone pico-sdk $PICO_SDK_VER
  picotool             install prebuilt picotool $PICOTOOL_VER

Debug:
  ocd-esp              Espressif OpenOCD fork (prebuilt)

Docker (NuttX CI image, every toolchain included):
  docker               run the following NuttX commands in the container
                       (conf menuconfig build rebuild clean sim flash-esp)
  docker-deps          install Docker, add user to the docker group
  docker-pull          download the NuttX CI image (DOCKER_IMAGE)
  docker-shell         interactive shell in the container, inside nuttx/
  flash-stm32 and flash-pico always run on the host (OpenOCD, picotool)

Menu:
  --menu, menu         folder options and flash-only for every board

Uninstall:
  uninstall            remove what Bifrost installed (asks each step)

Environment:
  env                  (re)write $ENV_FILE
  rc                   source env.sh from ~/.bashrc

NuttX:
  conf <board:cfg>     distclean + configure
  menuconfig           run menuconfig
  build                make -j\$(nproc)
  rebuild              make clean + apps_clean + build (keeps .config)
  clean                make distclean
  sim                  configure, build and run sim:nsh

Flash:
  flash-esp [port]     ESP32 family via esptool (default $ESP_PORT)
  flash-pico           RP2040/RP2350 via picotool or BOOTSEL
  flash-stm32 [chip] [elf|bin]
                       STM32 via OpenOCD + ST-Link; chip: f1 f3 f4 f7
                       h7 bluepill or any .cfg (default $STM32_CHIP);
                       no format given: asks (terminal) or uses elf

Examples:
  $(basename "$0") setup
  $(basename "$0") conf nucleo-h753zi:nsh build flash-stm32
  $(basename "$0") rebuild flash-stm32 h7 elf
  $(basename "$0") flash-stm32 bluepill bin
  $(basename "$0") docker conf nucleo-h753zi:nsh build flash-stm32 h7
  $(basename "$0") conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0
  $(basename "$0") conf esp32c6-devkitc:nsh build flash-esp
  $(basename "$0") conf esp32s3-devkit:nsh build flash-esp
  $(basename "$0") conf raspberrypi-pico:nsh build flash-pico
  $(basename "$0") conf raspberrypi-pico-2:nsh build flash-pico
EOF
}

#==========================================================================
# Entry point
#
# Commands are processed left to right. Commands taking an argument
# consume it only when the next word is not another command, so
# "flash-esp build" does not treat "build" as a port.
#==========================================================================

COMMANDS=" voice deps tree src venv setup tc-arm tc-riscv tc-xtensa
  tc-all pico-sdk picotool ocd-esp env rc conf menuconfig build
  rebuild clean sim flash-esp flash-pico flash-stm32 docker docker-deps
  docker-pull docker-shell uninstall menu --menu help "

is_command()
{
  [[ "$COMMANDS" =~ [[:space:]]"$1"[[:space:]] ]]
}

# validate_args: every word must be a command, or the argument of a
# command that takes one (conf, flash-esp, flash-stm32 x2). Same rules
# as the parser in main().

validate_args()
{
  local w max=0

  for w in "$@"; do
    if is_command "$w"; then
      case "$w" in
        conf|flash-esp) max=1 ;;
        flash-stm32)    max=2 ;;
        *)              max=0 ;;
      esac
    elif ((max > 0)); then
      max=$((max - 1))
    else
      die "unknown command '$w' (see 'help')"
    fi
  done
}

# needs_serial: true when a command on the line opens a serial port.

needs_serial()
{
  local w

  for w in "$@"; do
    case "$w" in
      flash-esp|menu|--menu) return 0 ;;
    esac
  done
  return 1
}

main()
{
  local cmd arg arg2

  (($#)) || { cmd_help; exit 0; }

  case "$1" in
    -h|--help|help) cmd_help; exit 0 ;;
  esac

  # Validate the whole command line before greeting or asking anything,
  # so a typo ("unistall") fails at once instead of after questions.

  validate_args "$@"

  if [[ -z "${BIFROST_SG:-}" ]]; then
    greet
  fi

  # Only serial-port commands need the dialout group. ST-Link (OpenOCD)
  # and picotool talk to USB directly and do not depend on it.

  if needs_serial "$@"; then
    check_dialout "$@"
  fi

  while (($#)); do
    cmd="$1"
    shift
    arg=""
    arg2=""

    case "$cmd" in
      conf|flash-esp|flash-stm32)
        if (($#)) && ! is_command "$1"; then
          arg="$1"
          shift
        fi
        ;;
    esac

    # flash-stm32 takes a second optional word ([chip] [elf|bin]).

    if [[ "$cmd" == "flash-stm32" ]] && (($#)) && ! is_command "$1"
    then
      arg2="$1"
      shift
    fi

    case "$cmd" in
      -h|--help|help) cmd_help ;;
      voice)          cmd_voice ;;
      deps)           cmd_deps ;;
      tree)           cmd_tree ;;
      src)            cmd_src ;;
      venv)           cmd_venv ;;
      setup)          cmd_setup ;;
      tc-arm)         cmd_tc_arm ;;
      tc-riscv)       cmd_tc_riscv ;;
      tc-xtensa)      cmd_tc_xtensa ;;
      tc-all)         cmd_tc_all ;;
      pico-sdk)       cmd_pico_sdk ;;
      picotool)       cmd_picotool ;;
      ocd-esp)        cmd_ocd_esp ;;
      docker)         BIFROST_DOCKER=1; say "Docker mode on." ;;
      docker-deps)    cmd_docker_deps ;;
      docker-pull)    cmd_docker_pull ;;
      docker-shell)   cmd_docker_shell ;;
      uninstall)      cmd_uninstall ;;
      menu|--menu)    cmd_menu ;;
      env)            cmd_env ;;
      rc)             cmd_rc ;;
      conf)           cmd_conf "$arg" ;;
      menuconfig)     cmd_menuconfig ;;
      build)          cmd_build ;;
      rebuild)        cmd_rebuild ;;
      clean)          cmd_clean ;;
      sim)            cmd_sim ;;
      flash-esp)      cmd_flash_esp "$arg" ;;
      flash-pico)     cmd_flash_pico ;;
      flash-stm32)    cmd_flash_stm32 "$arg" "$arg2" ;;
      *)              die "unknown command '$cmd' (see 'help')" ;;
    esac
  done

  say "All done. See you on the other side of the Bifrost."
}

main "$@"
