# Bifrost Setup Script

This repository contains a full automation script for setting up and building [Apache NuttX RTOS](https://nuttx.apache.org/) on the following targets:

- **ESP32-C3** (RISC-V)
- **Raspberry Pi Pico** (RP2040)
- **NuttX Simulator** (for PC testing)

It also automates installation and configuration of essential tools, toolchains, and environments.

---

## 🔧 What the script does

This script handles all steps required to build and run NuttX from scratch, including:

- Installing all required Linux packages and development dependencies
- Creating the `~/embedded_sys` workspace folder structure
- Cloning the official NuttX kernel, apps, and tools repositories
- Setting up the Raspberry Pi Pico SDK
- Downloading and configuring the RISC-V toolchain for ESP32-C3
- Downloading ESP32-C3 bootloader and partition binaries
- Setting up and activating a Python virtual environment for ESP32-C3
- Installing and building OpenOCD with ST-Link support
- Building and running NuttX for all three targets
- Flashing firmware to Raspberry Pi Pico and ESP32-C3

---

## 📁 Project Structure
```bash
After setup, your filesystem will look like this:
~/embedded_sys
~/embedded_sys/tools
~/embedded_sys/nuttxspace
~/embedded_sys/nuttxspace/nuttx
~/embedded_sys/nuttxspace/apps
~/embedded_sys/nuttxspace/tools
```


## 🛠️ Usage
```bash
You can run the script with multiple flags.  
Use `--help` to see all available options:

./bifrost.sh --help

Usage: ./bifrost.sh [option]

General setup:
  -pr                  Install all required packages
  -mf                  Create the base project folder ~/embedded_sys

NuttX core:
  -nut-tools           Clone nuttx/tools repo
  -nut-rtos            Clone nuttx kernel repo
  -nut-apps            Clone nuttx apps repo
  -nut-sim             Configure NuttX for simulator (sim:nsh)
  -nut-build           Build NuttX (must be configured first)
  -nut-clean           Run distclean on NuttX
  -nut-run             Run NuttX simulator binary

Raspberry Pi Pico:
  -pico-pr             Install required packages for Pico SDK
  -pico-tc             Clone pico-sdk toolchain
  -pico-path           Add pico-sdk path to ~/.bashrc
  -pico-conf-nuttx     Configure NuttX for Raspberry Pi Pico
  -pico-build-nuttx    Compile NuttX for Raspberry Pi Pico
  -pico-flash          Flash .uf2 manually to Pico over USB

ESP32-C3:
  -esp-riscv-tc        Download and extract RISC-V toolchain
  -esp-get-bin         Download bootloader and partition binaries
  -esp-elf2bin         Convert NuttX ELF to .bin using esptool
  -esp-conf-nuttx      Configure NuttX for ESP32-C3 (esp32c3-devkit)
  -esp-build-nuttx     Build and convert NuttX for ESP32-C3
  -esp-flash           Flash ESP32-C3 over serial with esptool

Python & Virtualenv:
  -py-conf             Configure python3 + alias + pip3
  -venv-esp            Setup virtualenv for ESP32
  -venv-esp-act        Activate virtualenv for ESP32
  -venv-esptool-install Install esptool in ESP32 virtualenv

External tools:
  -tool-ocd-pr         Install OpenOCD dependencies
  -tool-ocd-get        Clone and init OpenOCD repo
  -tool-ocd-build      Build and install OpenOCD
  -tool-minicom-pr     Install minicom and set user permissions

Other:
  -H, --help           Show this help message
```



## 🛠️ Examples


# configure everything for run the NuttX sim:
./bifrost.sh -pr -mf -nut-tools -nut-rtos -nut-apps -nut-sim -nut-build -nut-run

