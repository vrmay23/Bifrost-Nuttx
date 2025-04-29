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

After setup, your filesystem will look like this:
~/embedded_sys
~/embedded_sys/tools
~/embedded_sys/nuttxspace
~/embedded_sys/nuttxspace/nuttx
~/embedded_sys/nuttxspace/apps
~/embedded_sys/nuttxspace/tools


## 🛠️ Usage

You can run the script with multiple flags.  
Use `--help` to see all available options:


## 🛠️ Examples

./setup.sh --help

# configure everything for run the NuttX sim:
/bifrost.sh -pr -mf -nut-tools -nut-rtos -nut-apps -nut-sim -nut-build -nut-run

