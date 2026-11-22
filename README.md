# Bifrost Setup Script

This repository contains a full automation script for setting up,
building and flashing [Apache NuttX RTOS](https://nuttx.apache.org/) on
the following targets:

- **STM32** (F1, F3, F4, F7, H7, Blue Pill, any OpenOCD target)
- **ESP32-C3 / ESP32-C6** (RISC-V)
- **ESP32 / ESP32-S2 / ESP32-S3** (Xtensa), including the Waveshare
  ESP32-S3-Touch-LCD-7
- **Raspberry Pi Pico** (RP2040) and **Pico 2** (RP2350)
- **NuttX Simulator** (for PC testing)

It also automates installation and configuration of essential tools,
toolchains and environments. Haindall, the guardian of the Bifrost,
speaks every question and every step along the way.

Author: Vinicius Rodrigo May (@vrmay23) - QsiX Embedded Labs

---

## 🔧 What the script does

- Installs all required Linux packages (one apt call, only what is
  missing)
- Checks serial port access (`dialout` group) at every start and offers
  to add you and reboot
- Removes everything it installed with `uninstall`, asking at each step
- Creates the `~/embedded_sys` workspace, with an interactive menu when
  it already exists
- Clones or updates the official NuttX kernel and apps repositories
- Downloads the ARM, RISC-V and Xtensa toolchains (versions from the
  NuttX CI)
- Sets up the Raspberry Pi Pico SDK and picotool
- Creates a Python virtual environment with kconfiglib and esptool
- Writes a single `env.sh` with every tool on `PATH`
- Configures, builds and runs NuttX for every target
- Flashes STM32 (OpenOCD + ST-Link, ELF or BIN), ESP32 (esptool) and
  Raspberry Pi Pico (picotool or BOOTSEL)
- Optionally builds everything inside the NuttX CI Docker image

Toolchain versions follow the NuttX CI Dockerfile
(`nuttx/tools/ci/docker/linux/Dockerfile`). Toolchains are installed
under `tools/` and never touch system paths. `env.sh` only adds the
directories that exist, so an apt toolchain (e.g. `gcc-arm-none-eabi`)
is used when the matching `tc-*` command was not run.

### Requirements

- Ubuntu 22.04 or later (Debian-based, x86_64)
- sudo rights (apt packages, `dialout` / `docker` groups)
- Internet access to github.com, developer.arm.com and the Ubuntu
  archive (ghcr.io as well for docker mode)

---

## 📁 Project Structure

After setup, your filesystem will look like this:

```
~/embedded_sys/                  root (see "Folder menu")
  env.sh                         source this in your shell
  nuttxspace/
    nuttx/                       apache/nuttx
    apps/                        apache/nuttx-apps
  tools/
    arm-none-eabi-gcc/
    riscv-none-elf-gcc/
    xtensa-esp-elf-gcc/
    openocd-esp32/
    picotool/
    pico-sdk/
  nuttx_venv/                    kconfiglib + esptool
```

---

## 🛠️ Usage

Commands run left to right and can be chained in one call. Use `help`
to see all available commands:

```
./bifrost.sh help
Usage: bifrost.sh <command> [args] [<command> [args] ...]

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
  pico-sdk             clone pico-sdk 2.2.0
  picotool             install prebuilt picotool 2.2.0-0

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
  env                  (re)write ~/embedded_sys/env.sh
  rc                   source env.sh from ~/.bashrc

NuttX:
  conf <board:cfg>     distclean + configure
  menuconfig           run menuconfig
  build                make -j$(nproc)
  rebuild              make clean + apps_clean + build (keeps .config)
  clean                make distclean
  sim                  configure, build and run sim:nsh

Flash:
  flash-esp [port]     ESP32 family via esptool (default /dev/ttyUSB0)
  flash-pico           RP2040/RP2350 via picotool or BOOTSEL
  flash-stm32 [chip] [elf|bin]
                       STM32 via OpenOCD + ST-Link; chip: f1 f3 f4 f7
                       h7 bluepill or any .cfg (default h7);
                       no format given: asks (terminal) or uses elf

Examples:
  bifrost.sh setup
  bifrost.sh conf nucleo-h753zi:nsh build flash-stm32
  bifrost.sh rebuild flash-stm32 h7 elf
  bifrost.sh flash-stm32 bluepill bin
  bifrost.sh docker conf nucleo-h753zi:nsh build flash-stm32 h7
  bifrost.sh conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0
  bifrost.sh conf esp32c6-devkitc:nsh build flash-esp
  bifrost.sh conf esp32s3-devkit:nsh build flash-esp
  bifrost.sh conf raspberrypi-pico:nsh build flash-pico
  bifrost.sh conf raspberrypi-pico-2:nsh build flash-pico
```

---

## 🛠️ Examples

Commands run left to right, so one line can go from a clean machine to
a flashed board. Each target below has two forms:

- **from zero**: installs only what that target needs, then configures,
  builds and flashes
- **daily**: everything already installed, just configure, build, flash

Serial ports need the `dialout` group. Every run checks it first: if you
are not in the group, Haindall offers to add you; if the group is not
active yet in this login, he offers to reboot, or runs the command with
the group for this run only (`sg dialout`). Serial console after flashing:
`picocom -b 115200 /dev/ttyACM0` (or `minicom`).

### Everything at once

```sh
# install every package, source, toolchain and tool for all targets
./bifrost.sh setup

# load the environment in the current shell / in every new shell
. ~/embedded_sys/env.sh
./bifrost.sh rc
```

### NuttX simulator (no board, host GCC)

```sh
# from zero: packages, sources, venv, configure, build and run NSH
./bifrost.sh deps src venv env sim

# daily: configure, build and run NSH (leave with "poweroff")
./bifrost.sh sim
```

### STM32 (ARM toolchain, OpenOCD + ST-Link)

```sh
# from zero: Nucleo-H753ZI (ODIN), ELF image
./bifrost.sh deps src venv tc-arm env \
  conf nucleo-h753zi:nsh build flash-stm32 h7 elf

# daily: Nucleo-H753ZI, BIN image at 0x08000000
./bifrost.sh conf nucleo-h753zi:nsh build flash-stm32 h7 bin

# daily: Nucleo-H743ZI
./bifrost.sh conf nucleo-h743zi:nsh build flash-stm32 h7

# from zero: Nucleo-F767ZI
./bifrost.sh deps src venv tc-arm env \
  conf nucleo-f767zi:nsh build flash-stm32 f7 elf

# daily: Nucleo-F767ZI (nsh, or netnsh with Ethernet)
./bifrost.sh conf nucleo-f767zi:nsh build flash-stm32 f7
./bifrost.sh conf nucleo-f767zi:netnsh build flash-stm32 f7 bin

# daily: STM32F4 Discovery / Nucleo-F446RE
./bifrost.sh conf stm32f4discovery:nsh build flash-stm32 f4
./bifrost.sh conf nucleo-f446re:nsh build flash-stm32 f4

# daily: STM32F3 Discovery / Nucleo-F303RE
./bifrost.sh conf stm32f3discovery:nsh build flash-stm32 f3
./bifrost.sh conf nucleo-f303re:nsh build flash-stm32 f3

# daily: Blue Pill (STM32F103C8)
./bifrost.sh conf stm32f103-minimum:nsh build flash-stm32 bluepill

# daily: Blue Pill with a clone chip (CKS32 / CS32)
STM32_OCD_EXTRA="set CPUTAPID 0x2ba01477" \
  ./bifrost.sh conf stm32f103-minimum:nsh build flash-stm32 bluepill

# daily: any other STM32, passing the OpenOCD target script
./bifrost.sh flash-stm32 target/stm32g4x.cfg elf

# full rebuild keeping .config, then flash (old CLEAN_FLASH_STM32H7)
./bifrost.sh rebuild flash-stm32 h7 bin
```

### ESP32-C3 / ESP32-C6 (RISC-V toolchain, esptool)

```sh
# from zero: ESP32-C3 DevKit
./bifrost.sh deps src venv tc-riscv env \
  conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0

# daily: ESP32-C3 DevKit
./bifrost.sh conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0

# from zero: ESP32-C6 DevKitC
./bifrost.sh deps src venv tc-riscv env \
  conf esp32c6-devkitc:nsh build flash-esp /dev/ttyUSB0

# daily: ESP32-C6 DevKitC
./bifrost.sh conf esp32c6-devkitc:nsh build flash-esp /dev/ttyUSB0
```

### ESP32 / ESP32-S2 / ESP32-S3 (Xtensa toolchain, esptool)

```sh
# from zero: ESP32-S3 DevKit
./bifrost.sh deps src venv tc-xtensa env \
  conf esp32s3-devkit:nsh build flash-esp /dev/ttyUSB0

# daily: ESP32-S3 DevKit
./bifrost.sh conf esp32s3-devkit:nsh build flash-esp /dev/ttyUSB0

# from zero: Waveshare ESP32-S3-Touch-LCD-7 (7" 800x480 panel)
./bifrost.sh deps src venv tc-xtensa env \
  conf esp32s3-touch-lcd7:lcd build flash-esp /dev/ttyACM0

# daily: ESP32-S3-Touch-LCD-7, framebuffer on /dev/fb0 (run "fb" in NSH)
./bifrost.sh conf esp32s3-touch-lcd7:lcd build flash-esp /dev/ttyACM0

# daily: ESP32-S3-Touch-LCD-7, NSH over the native USB (CDC/ACM)
./bifrost.sh conf esp32s3-touch-lcd7:usbnsh build flash-esp /dev/ttyACM0

# daily: ESP32-S2 Saola-1
./bifrost.sh conf esp32s2-saola-1:nsh build flash-esp /dev/ttyUSB0

# daily: ESP32 DevKitC (classic ESP32)
./bifrost.sh conf esp32-devkitc:nsh build flash-esp /dev/ttyUSB0
```

### Raspberry Pi Pico / Pico 2 (ARM toolchain, UF2)

```sh
# from zero: Pico (RP2040), needs pico-sdk for nuttx.uf2
./bifrost.sh deps src venv tc-arm pico-sdk picotool env \
  conf raspberrypi-pico:nsh build flash-pico

# daily: Pico (RP2040) / Pico W
./bifrost.sh conf raspberrypi-pico:nsh build flash-pico
./bifrost.sh conf raspberrypi-pico-w:nsh build flash-pico

# from zero: Pico 2 (RP2350), needs picotool for nuttx.uf2
./bifrost.sh deps src venv tc-arm pico-sdk picotool env \
  conf raspberrypi-pico-2:nsh build flash-pico

# daily: Pico 2 (RP2350)
./bifrost.sh conf raspberrypi-pico-2:nsh build flash-pico
```

With picotool, put the board in BOOTSEL mode before `flash-pico`.
Without it, Haindall guides the drag-and-drop copy of `nuttx.uf2`.

### Docker mode (NuttX CI image, no local toolchains)

```sh
# from zero: Docker, sources, then build inside the CI container
./bifrost.sh docker-deps        # once, then log out and back in
./bifrost.sh deps src docker-pull

# simulator
./bifrost.sh docker sim

# STM32: build in the container, flash from the host
./bifrost.sh docker conf nucleo-h753zi:nsh build flash-stm32 h7

# ESP32 family: build and flash from the container
./bifrost.sh docker conf esp32c3-devkit:nsh build flash-esp /dev/ttyACM0
./bifrost.sh docker conf esp32s3-devkit:nsh build flash-esp /dev/ttyUSB0

# Pico: build in the container, flash from the host
./bifrost.sh docker conf raspberrypi-pico:nsh build flash-pico

# shell inside the container, in nuttx/
./bifrost.sh docker-shell
```

### Other useful commands

```sh
# change the configuration of the current board
./bifrost.sh menuconfig build

# remove configuration and binaries
./bifrost.sh clean

# update nuttx and nuttx-apps
./bifrost.sh src

# test in a separate folder, without touching ~/embedded_sys
BIFROST_ROOT=~/bifrost_test ./bifrost.sh deps src venv env sim

# silent run (no Haindall voice)
BIFROST_VOICE=0 ./bifrost.sh conf sim:nsh build

# list every board configuration
cd ~/embedded_sys/nuttxspace/nuttx && ./tools/configure.sh -L
```

---

## Configuration (kconfig)

NuttX is configured with **kconfiglib**, installed with pip inside the
venv. NuttX prefers it automatically whenever `menuconfig` from the venv
is in `PATH`.

The apt package `kconfig-frontends-nox` is still installed, only for
`kconfig-tweak`: `tools/sethost.sh` calls it during `configure.sh`, and
kconfiglib does not provide it.

## Flashing details

### ESP32 family

NuttX boots Espressif chips with **Simple Boot**: no external bootloader
or partition table is needed. `make flash` converts the ELF and writes
`nuttx.bin` through esptool:

```sh
./bifrost.sh flash-esp /dev/ttyUSB0
```

ESP32-S3-Touch-LCD-7 (VER1.1): flash through the USB-C connector
labeled `USB`. It goes through a WCH CH343 USB-to-UART bridge
(`1a86:55d3` in `dmesg`) wired to UART0, and the CH343 is a CDC/ACM
device, so it shows up as `/dev/ttyACM0`, not `/dev/ttyUSB0`.
With the `lcd` configuration the NSH console is on that same port
(115200 8N1). With `usbnsh` the console moves to the ESP32-S3 native
USB, a second CDC/ACM device (press ENTER three times if the prompt
does not show).

### Raspberry Pi Pico

- RP2040: the build needs `PICO_SDK_PATH` (set by `env.sh`) to create
  `nuttx.uf2`.
- RP2350: `nuttx.uf2` is created by picotool.

`flash-pico` loads the UF2 with picotool when the board is in BOOTSEL
mode. Without picotool, Haindall guides the drag-and-drop procedure:
hold BOOTSEL, plug the board in, copy `nuttx.uf2` to the USB drive.

### STM32

`flash-stm32 [chip] [elf|bin]`, both arguments optional, any order.

| Chip       | OpenOCD script                     |
|------------|------------------------------------|
| `f1`       | `target/stm32f1x.cfg`              |
| `f3`       | `target/stm32f3x.cfg`              |
| `f4`       | `target/stm32f4x.cfg`              |
| `f7`       | `target/stm32f7x.cfg`              |
| `h7`       | `target/stm32h7x.cfg` (default)    |
| `bluepill` | `board/stm32f103c8_blue_pill.cfg`  |
| `*.cfg`    | used as given, e.g. `target/stm32g4x.cfg` |

Image format:

- `elf`: `program nuttx verify reset exit`. Addresses come from the ELF,
  so it stays correct with bootloaders or extra memory regions (e.g.
  QSPI).
- `bin`: `nuttx.bin` written at `0x08000000` (`STM32_FLASH_ADDR`), then
  verified. Needs `CONFIG_RAW_BINARY=y`; if `nuttx.bin` is missing,
  Bifrost offers to enable it and rebuild.
- No format given: Haindall asks (Enter = `elf`); without a terminal,
  `elf` is used.

Both formats use the same OpenOCD flash driver and end with
`exit` / `shutdown`, so the ST-Link is released.

Notes:

- **STM32H743/H753 dual bank**: `set DUAL_BANK 1` is passed before the
  target script (on by default for `h7`), otherwise images above 1 MB
  fail. `STM32_DUAL_BANK=0` for single-bank parts (e.g. H750).
- **Blue Pill**: upstream OpenOCD 0.12 has no `target/bluepill.cfg`;
  the board script sets the 128 KB flash size. Clone chips (CKS32 /
  CS32): `STM32_OCD_EXTRA="set CPUTAPID 0x2ba01477"`.

The old `CLEAN_FLASH_STM32H7` alias becomes:

```sh
./bifrost.sh rebuild flash-stm32 h7 bin
```

## Interactive menu

```sh
./bifrost.sh --menu
```

One screen with two parts:

- **1-4, folder**: the same options as the folder menu below (keep,
  clean, new folder, rename).
- **5 and up, flash only**: one entry per board preset (STM32, ESP32,
  Pico; the same boards as in Examples). The tree remembers which
  `board:config` it was last configured for (`.last-conf` in the root).
  If the chosen board does not match, or there is no image yet, Haindall
  offers to configure and build it first, so a wrong image is never
  flashed. ESP boards ask for the serial port (default: the first
  `/dev/ttyACM*` / `/dev/ttyUSB*` found); STM32 boards ask `elf` or
  `bin`.

A failed build or flash returns to the menu instead of ending the
script. `0` exits. New boards are added to the `BOARD_PRESETS` list in
`bifrost.sh`.

## Folder menu

The folder menu appears only when it is needed: the root folder already
exists **and** the command touches it (`tree`, `src`, `setup`) **and**
there is a terminal to answer. `conf`, `build` and the flash commands
never show it. `--menu` shows it at any time. When it appears, it asks
what to do:

1. Keep it and use it as it is
2. Clean everything inside it (asks for confirmation; refuses `/` and
   `$HOME`)
3. Use a new folder in `$HOME` (the new root is saved in
   `~/.config/bifrost/root` and used by later runs)
4. Rename it to `<root>_old` (a timestamp is added if that name exists)
   and start a new one

Without a terminal (CI, scripts) the folder is always kept.

## Haindall

Every question and every step is spoken through festival (text to
speech). Phrases play in the background, one at a time and in order, so
long steps are not delayed. Questions are spoken before the prompt.

- missing festival: Haindall offers to install it on the first run
- `./bifrost.sh voice` installs festival only
- `BIFROST_VOICE=0` silences him; output is otherwise identical

## Docker mode

Optional. `conf`, `menuconfig`, `build`, `rebuild`, `clean`, `sim` and
`flash-esp` run inside the NuttX CI image
(`ghcr.io/apache/nuttx/apache-nuttx-ci-linux`), which already carries
every toolchain, kconfig tool, esptool, pico-sdk and picotool. The image
is large (several GB).

```sh
./bifrost.sh docker-deps                  # once, then log out/in
./bifrost.sh docker conf nucleo-h753zi:nsh build flash-stm32 h7
BIFROST_DOCKER=1 ./bifrost.sh conf sim:nsh build
./bifrost.sh docker-shell
```

- `nuttxspace/` is mounted at the same absolute path as on the host,
  so host and docker builds can share the same tree.
- The container runs with your UID/GID: no root-owned files.
- `flash-esp` passes the serial device into the container.
- `flash-stm32` and `flash-pico` always run on the host.

## Uninstall

```sh
./bifrost.sh uninstall
```

Undoes everything Bifrost did, asking before each step:

1. Toolchains, tools, venv and `env.sh` in the root folder. The NuttX
   sources (`nuttx/`, `apps/`) are asked separately, because they may
   hold your work.
2. The `env.sh` line added to `~/.bashrc` by `rc` (a backup is kept in
   `~/.bashrc.bifrost.bak`).
3. The NuttX CI Docker image.
4. apt packages. Only the ones Bifrost itself installed are listed
   (recorded in `~/.config/bifrost/apt-installed`); packages you already
   had before are never removed.
5. `dialout` / `docker` group membership (default answer: keep).
6. Bifrost settings in `~/.config/bifrost`.

It needs a terminal: nothing is deleted without an answer.

## Environment variables

| Variable           | Default                       | Purpose                  |
|--------------------|-------------------------------|--------------------------|
| `BIFROST_ROOT`     | `~/embedded_sys`              | root folder              |
| `BIFROST_VOICE`    | `1`                           | Haindall on/off          |
| `BIFROST_DOCKER`   | `0`                           | docker mode always on    |
| `DOCKER_IMAGE`     | NuttX CI image `:latest`      | container image          |
| `ARM_TC_VER`       | `13.2.Rel1`                   | ARM GNU version          |
| `RISCV_TC_VER`     | `14.3.0-1`                    | xPack RISC-V version     |
| `XTENSA_TC_VER`    | `14.2.0_20241119`             | Xtensa GCC version       |
| `OCD_ESP_VER`      | `v0.12.0-esp32-20241016`      | openocd-esp32 version    |
| `PICO_SDK_VER`     | `2.2.0`                       | pico-sdk tag             |
| `PICOTOOL_VER`     | `2.2.0-0`                     | picotool release         |
| `PIP_ESPTOOL`      | `esptool==5.3.1`              | esptool pin              |
| `ESP_PORT`         | `/dev/ttyUSB0`                | default ESP serial port  |
| `STM32_CHIP`       | `h7`                          | default STM32 chip       |
| `STM32_FLASH_MODE` | empty (ask)                   | `elf` or `bin`           |
| `STM32_FLASH_ADDR` | `0x08000000`                  | `bin` load address       |
| `STM32_DUAL_BANK`  | `1`                           | H7 dual bank             |
| `STM32_OCD_IF`     | `interface/stlink.cfg`        | OpenOCD adapter          |
| `STM32_OCD_EXTRA`  | empty                         | extra pre-target command |

Older NuttX trees may need esptool 4.x:
`PIP_ESPTOOL="esptool>=4.8,<5" ./bifrost.sh venv`.

## References

Step-by-step guides followed for the original version (2023):

- NuttX Channel (Alan C. Assis):
  https://www.youtube.com/@nuttxchannel
- Embarcados TV (Sara Cunha):
  https://www.youtube.com/watch?v=B3fKhR7tsVM

Current references:

- NuttX install guide:
  https://nuttx.apache.org/docs/latest/quickstart/install.html
- NuttX platform pages (ESP32, RP2040, RP2350, STM32):
  https://nuttx.apache.org/docs/latest/platforms/
- NuttX CI Dockerfile: `nuttx/tools/ci/docker/linux/Dockerfile`

## License

MIT - Copyright (c) 2023-2026 Vinicius Rodrigo May (@vrmay23).
See the header of `bifrost.sh`.
