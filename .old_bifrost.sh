#!/bin/bash
# MIT License
#
# Copyright (c) 2023-2025 Vinicius Rodrigo May
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#-------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------
#
# Title:        Cloning, Installing and Building NuttX for ESP32-C3
# Author:       Vinicius Rodrigo May (vmay23 ~QsiX Embedded Labs~)
# Date:         2023/05/16
#
# rev date:    
# Rev Reason:   integrated script
#
# referencies:  Nuttx Channel (Alan Carvalho de Assis - https://www.youtube.com/@nuttxchannel)
#               Embarcados TV (Sara Cunha - https://www.youtube.com/watch?v=B3fKhR7tsVM)
#
# Table of Contemts
#  1 - create_project (ok)
#  2 - open_ocd       (ok)
#  3 - nuttx
#           download  (ok)
#           config    (ok)
#           compile   (ok)
#  4 - configure_env
#			install_tools 		 	  (ok) 		# Instalar Python3 e configurar aliases
#			setup_virtualenv  		  (ok)		# Criar e configurar o ambiente virtual
#			activate_virtualenv       (ok)
#			install_esptool  		  (ok)		# Instalar ESPTool no ambiente virtual
#			download_riscv_tools      (ok)		# Instalar ferramentas SiFive RISC-V
#			download_esp32_bin        (ok)
#			add_to_bashrc  			  (ok)		# Adicionar ao .bashrc permanentemente
#			add_user_to_dialout  	  (ok)		# Adicionar o usuário ao grupo dialout
#
#   5 - build_nuttx_for_esp32 	 	  (ok)		# compiling nuttx port for esp23
#   6 - write_firmware                (ok)
#
#
#-------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------

#===========================================================================#
#============================= variables ===================================#
PROJECT_DIR="$HOME/Documents/embedded_sys"
OPENOCD_DIR="$HOME/Documents/embedded_sys/openocd"
NUTTX_DIR="$HOME/Documents/embedded_sys/nuttxspace/nuttx"
RISC_V_DIR="$HOME/Documents/embedded_sys/risc_v_toolchain"
ESP32_VIRTUAL_ENV="$HOME/Documents/embedded_sys/.esp32_venv"
ESP32_STUFF="$HOME/Documents/embedded_sys/esp32_stuff"
#___________________________________________________________________________#


#============================================================================#
#===========================   aux functions  ===============================#
#-------------------------
#-      menu help        -
show_help() {
    echo "********************************************************************"
    echo "                                                                    "
    echo "  Usage: $0 -option                                                 "
    echo "                                                                    "
    echo "  Options:                                                          "
    echo "                                                                    "
    echo "  -s:     Just do automatically everything                          "
    echo "                                                                    "
    echo "  -p:     Prepare the project directory                             "
    echo "  -o:     Install OpenOCD                                           "
    echo "  -n:     Download and Configure NuttX OS                           "
    echo "  -c:     Configure the environment                                 "  
    echo "  -b:     Build NuttX for the ESP32-C3.                             "
    echo "  -f:     Write the firmware to the ESP32-C3.                       "
    echo "  -a:     activate python virtual env                               "
    echo "  -d:     deactivate python virtual env                             "
    echo "                                                                    "
    echo "                                                                    "
    echo "  -u:     Undo all actions performed by the script                  "
    echo "  -r:     Undo all actions performed by the script and start again. "  
    echo "  -H      Display this help message and exit.                       "
    echo "  --help: Display this help message and exit.                       "
    echo "                                                                    "
    echo "                                                                    "
    echo " please, remind to run: source $ESP32_VIRTUAL_ENV/bin/activate      "
    echo "                                                                    "
    echo "                                                                    "
    echo " to change the default configration, run: make menuconfig           "
    echo "                                                                    "
    echo "                                                                    "
    echo "********************************************************************"
}



qsix_logo(){
clear⠀⠀⠀⠀
sleep 1
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣠⣤⣤⣤⣤⣤⣤⣤⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣶⣾⣿⣿⡿⠿⠿⠛⠛⠛⠛⠛⠻⠿⠿⣿⣿⣿⣷⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀       ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣿⣿⠿⠟⠛⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠿⢿⣿⣷⣶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣿⣿⠿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⢿⣿⣷⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠴⣿⡿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠿⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀       ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠄⡠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠐⠀⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠔⡀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠢⣔⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo " ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠪⡦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣐⠔⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣶⣿⣿⣿⣿⣷⣶⣦⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣤⣤⣤⣤⠀⠀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠘⢿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⠟⠋⠉⠉⠉⠉⠉⠛⠿⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠀⠀⠀⠀⠻⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⣠⣿⣿⣿⣿⡿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⣠⣴⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⡆⠀⠀⠀⢰⣶⣶⣶⣶⠀⠀⠀⠀⠀⠘⢿⣿⣿⣿⣿⣄⠀⢀⣴⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⡄⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣦⣾⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⡇⠀⠀⢸⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀         ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⡇⠀⠀⠸⣿⣿⣿⣿⣷⣦⣤⣄⣀⣀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⣸⣿⣿⣿⣿⠇⠀⠀⠀⠙⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠐⢶⣾⣿⣷⡀⠀⣰⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠉⠙⠛⠛⠻⠿⣿⣿⣿⣿⣷⡀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⢠⣾⣿⣿⣿⡿⠋⠻⣿⣿⣿⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠻⣿⣿⣿⣾⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⣿⣿⣿⡇⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⠟⠁⠀⠀⠙⢿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣷⣶⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⢰⣶⣶⣶⣶⣶⣶⣶⣶⣶⣿⣿⣿⣿⡿⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⠀⢠⣾⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠈⢻⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠋⠀⠀⠀⠀⢸⣿⣿⣿⣿⠀⠀⣴⣿⣿⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀    ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠁⠀⠀⠙⢿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠱⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠛⠛⠛⠛⠓⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀           ⠀⠘⠕⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⢻⣿⣿⡇⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⡺⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣶⣿⠀⠀⠀⠀⢸⣿⣿⡇⠀⠀⠀⠘⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠔⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣶⡿⠟⠋⠇⠀⠀⠀⠀⢸⣿⣿⡇⠀⠀⠀⠀⡏⠙⠻⣿⣦⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠢⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⡇⠀⠀⠀⠀⠃⠀⠀⠀⠉⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣾⣷⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡆⠀⠀⠀⠀⢸⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣶⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣿⣷⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⡿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⣿⣿⣷⣦⣤⣀⣀⠀⠀⠀⠀⠀⠸⠹⠏⠇⠀⠀⠀⠀⢀⣀⣠⣤⣶⣿⣿⡿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠻⠿⣿⣿⣿⣷⣶⣶⣦⣤⣤⣤⣤⣶⣶⣶⣿⣿⣿⡿⠿⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠙⠛⠛⠛⠛⠛⠛⠛⠛⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀      "

sleep 2
clear


}

#-------------------------
#-  project folder       -
show_options() {
    echo "The current folder already exists in this path. Please, choose one option to continue:  "
    echo "                                                                                        "
    echo " 1 - Clean everything inside $PROJECT_DIR                                               "
    echo " 2 - Create a new folder                                                                "
    echo " 3 - Rename the current folder to 'embedded_sys_old' and create a new 'embedded_sys'    "
    echo "                                                                                        " 
}

#-------------------------
#- print status messages -
        
print_status() {
    echo '============================================'
    echo "$1"
    echo '============================================'
    echo ''
}
#____________________________________________________________________________#



#=============================================================================#
#===========================  other functions  ===============================#
#_____________________________________________________________________________#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#              AMBIENT CONFIGURATION              #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
create_project_main_folder(){
    if [ ! -d "$PROJECT_DIR" ]; then  # Check if the directory ~/Documents/projects already exist.
        echo "Creating project folder '$PROJECT_DIR' ..."
        mkdir -p "$PROJECT_DIR"  # if it does not exist, create such folder
    else
        while true; do
            show_options
            read -p "Please, enter with one option (1/2/3): " option
            case $option in
                1) # Confirmation
                    read -p "Are you sure you want to delete the folder '$PROJECT_DIR' contents? (y/n): " confirmation
                    if [ "$confirmation" == "y" ]; then  # If answer = y
                        echo "Ok. Let's clean the whole directory '$PROJECT_DIR'..."
                        rm -rf "$PROJECT_DIR"/*  # Clean everything
                        break  # Skip to the next instruction
                    else  # If answer = n
                        echo "It seems you are not so sure. Let's try once more..."
                    fi
                    ;;
				2) # Create a new folder
					read -p "Please, insert the new directory name: " new_name
					new_dir="$HOME/Documents/$new_name"  # Full path to the new directory
					
					# Verifica se o diretório já existe antes de atualizar a variável
					if [ -d "$new_dir" ]; then  # Check if the new folder exists
						echo "The folder '$new_dir' already exists. Try another name."
					else
						# Atualiza PROJECT_DIR e cria o diretório
						PROJECT_DIR="$new_dir"
						mkdir -p "$PROJECT_DIR"  # Create the new folder
						echo "The new folder '$PROJECT_DIR' was created."
						break
					fi
					;;
                3) # Rename the current folder to 'embedded_sys_old' and create the new one
                    if [ -d "${PROJECT_DIR}_old" ]; then
                        echo "The folder '${PROJECT_DIR}_old' already exists. Renaming it to a new name based on the current date."
                        mv "$PROJECT_DIR" "${PROJECT_DIR}_old_$(date +%Y%m%d_%H%M%S)"
                    else
                        mv "$PROJECT_DIR" "${PROJECT_DIR}_old"
                    fi
                    mkdir -p "$PROJECT_DIR"
                    break
                    ;;
                *)
                    echo "Wrong option. Please try again."
                    ;;
            esac
        done
    fi
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                 OPEN OCD STUFF                  #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
open_ocd_packages(){
    REQUIRED_PACKAGES="automake bison build-essential flex gcc-arm-none-eabi gperf libtool libncurses5-dev libusb-dev libusb-1.0-0-dev pkg-config"
    for package in $REQUIRED_PACKAGES; do
        if ! dpkg -l | grep -qw $package; then
            echo "Installing missing package: $package"
            sudo apt-get install -y $package
        else
            echo "Package $package is already installed."
        fi
    done
}

open_ocd_download(){
    cd "$PROJECT_DIR"
    sudo apt install -y git libtool
    if ! git clone https://git.code.sf.net/p/openocd/code openOCD; then
        echo "Failed to clone OpenOCD repository."
        exit 1
    fi
    cd openOCD
    echo "Initializing and updating submodules..."
    git submodule init
    git submodule update --recursive  # Garantir que os submódulos sejam atualizados corretamente
}

open_ocd_install(){
    cd "$PROJECT_DIR/openOCD"
    
    # Verificar se o bootstrap já foi executado
    if [ -f "bootstrap" ]; then
        echo "Running bootstrap..."
        if ! ./bootstrap; then
            echo "Bootstrap failed. Check the errors above."
            exit 1
        fi
    else
        echo "Bootstrap is not required or has already been run."
    fi

    echo "Configuring OpenOCD..."
    if ! ./configure --enable-internal-jimtcl --enable-maintainer-mode --disable-werror --disable-shared --enable-stlink --disable-jlink --enable-rlink --enable-vslink --enable-ti-icdi --enable-remote-bitbang; then
        echo "Configuration failed. Check the errors above."
        exit 1
    else
        echo "Configuration done."
    fi

    echo "Compiling OpenOCD..."
    if ! make -j$(nproc); then
        echo "Compilation failed. Check the errors above."
        exit 1
    fi

    echo "Installing OpenOCD..."
    if ! sudo make install; then
        echo "Installation failed. Check the errors above."
        exit 1
    fi

    echo "OpenOCD installation completed successfully."
}
open_ocd() {
    echo "Downloading and configuring the OpenOCD tool ..."
    open_ocd_packages
    open_ocd_download
    open_ocd_install
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                  NUTTX STUFF                    #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
nuttx_draw_logo(){
}


nuttx_download(){
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Cloning Nuttx Kernel and 
    # Application Repositories
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    print_status "Cloning Nuttx Kernel and Application repositories..."
    
    #download packages
    sudo apt-get install jimtcl jimtcl libjim-dev autoconf automake flex bison pkg-config -y


    # Verificar se o diretório NUTTX_DIR existe. Se não, cria-lo.
    if [ ! -d "$NUTTX_DIR" ]; then
        echo "Diretório $NUTTX_DIR não encontrado. Criando..."
        mkdir -p "$NUTTX_DIR" || { echo "Falha ao criar o diretório."; exit 1; }
    fi

    # Navegar para o diretório NUTTX_DIR
    cd "$NUTTX_DIR" || { echo "Falha ao entrar no diretório $NUTTX_DIR"; exit 1; }

    # Clonar o repositório 'tools' (se não existir) ou atualizar
    if [ ! -d "tools" ]; then
        echo "Clonando o repositório 'tools'..."
        if ! git clone https://bitbucket.org/nuttx/tools.git; then
            echo "Falha ao clonar o repositório 'tools'."
            exit 1
        fi
    else
        echo "'tools' já existe, atualizando..."
        cd tools && git pull && cd ..
    fi

    # Clonar o repositório 'nuttx' (se não existir) ou atualizar
    if [ ! -d "nuttx" ]; then
        echo "Clonando o repositório 'nuttx'..."
        if ! git clone https://github.com/apache/incubator-nuttx.git nuttx; then
            echo "Falha ao clonar o repositório 'nuttx'."
            exit 1
        fi
    else
        echo "'nuttx' já existe, atualizando..."
        cd nuttx && git pull && cd ..
    fi

    # Clonar o repositório 'apps' (se não existir) ou atualizar
    if [ ! -d "apps" ]; then
        echo "Clonando o repositório 'apps'..."
        if ! git clone https://github.com/apache/incubator-nuttx-apps.git apps; then
            echo "Falha ao clonar o repositório 'apps'."
            exit 1
        fi
    else
        echo "'apps' já existe, atualizando..."
        cd apps && git pull && cd ..
    fi
}


nuttx_config(){
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Configuring kconfig-frontends
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	print_status "Configuring kconfig-frontends..."
	echo '========================================'
	echo 'cd ~/nuttxspace/tools/kconfig-frontends/'
	echo '========================================'
	echo ''


	echo '===================================='
	echo 'configuring...                      '
	echo '===================================='
	echo ''
	cd "$NUTTX_DIR/tools/kconfig-frontends/"
	
	if ! ./configure --enable-mconf; then
		echo "Configuration of kconfig-frontends failed."
		exit 1
	fi



	aclocal 			# with any option needed (such as -I m4)
	autoconf
	automake --add-missing --force-missing

	sudo ln -s /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libcc1.so /usr/local/lib/libcc1.so.0
	sudo ln -s /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libexpat.so.1 /usr/local/lib/libexpat.so.1
}

nuttx_compile(){
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Compiling and Installing 
	# kconfig-frontends
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	print_status "Compiling kconfig-frontends..."

	if ! make; then
		echo "Compilation of kconfig-frontends failed."
		exit 1
	fi

	print_status "Installing kconfig-frontends..."

	if ! sudo make install; then
		echo "Installation of kconfig-frontends failed."
		exit 1
	fi

	sudo ldconfig
}

nuttx_world(){
	nuttx_draw_logo
	nuttx_download
	nuttx_config
	nuttx_compile
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               ESP32_RISC-V STUFF                #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
install_tools() {
	#-------------------------
	#- Install Python3 
	#  pip e configura aliases
	#-------------------------
    print_status "Installing Python 3 and pip..."
    sudo apt update
    sudo apt install -y minicom python3 python3-pip

    # Cria o alias para que 'python' seja igual a 'python3'
    if ! grep -q "alias python='python3'" ~/.bashrc; then
        echo "alias python='python3'" >> ~/.bashrc
    fi

    # Cria o alias para que 'pip' seja igual a 'pip3'
    if ! grep -q "alias pip='pip3'" ~/.bashrc; then
        echo "alias pip='pip3'" >> ~/.bashrc
    fi

    # Define o Python 3 como o padrão (caso não esteja configurado)
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

    # Atualiza o .bashrc para os aliases
    source ~/.bashrc
}

setup_virtualenv() {
    # Verifica se o Python3 e o pip estão instalados
    if ! command -v python3 &> /dev/null; then
        echo "Python3 não encontrado. Instale o Python3 antes de continuar."
        exit 1
    fi
    if ! command -v pip &> /dev/null; then
        echo "pip não encontrado. Instale o pip antes de continuar."
        exit 1
    fi

    # Preparar o ambiente virtual
    print_status "Preparando o ambiente virtual..."
    
    # Verifica se o diretório do ambiente virtual já existe
    if [ ! -d "$ESP32_VIRTUAL_ENV" ]; then
        print_status "Criando o diretório .esp32_venv..."
        mkdir -p "$ESP32_VIRTUAL_ENV"  # Cria a pasta para o ambiente virtual
        
        print_status "Configurando o ambiente virtual..."
        python3 -m venv "$ESP32_VIRTUAL_ENV"  # Cria o ambiente virtual
    else
        print_status "O ambiente virtual já existe."
    fi

    # Ativa o ambiente virtual
    source "$ESP32_VIRTUAL_ENV/bin/activate"

    # Verifica se o ambiente virtual está ativado corretamente
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "Erro: o ambiente virtual não está ativado corretamente."
        exit 1
    fi
}


activate_virtualenv() {
    # Verifica se o diretório do ambiente virtual existe
    if [ -d "$ESP32_VIRTUAL_ENV" ]; then
        # Ativa o ambiente virtual
        echo "Ativando o ambiente virtual '$ESP32_VIRTUAL_ENV'..."
        source "$ESP32_VIRTUAL_ENV/bin/activate"
    else
        echo "O ambiente virtual não foi encontrado. Certifique-se de que ele foi criado corretamente."
    fi
}


install_esptool() {
    # Instala o esptool dentro do ambiente virtual
    print_status "Instalando o esptool..."

    # Verifica se o esptool já está instalado no ambiente virtual
    if ! pip show esptool &> /dev/null; then
        pip install esptool
    else
        print_status "esptool já está instalado no ambiente virtual."
    fi
}


download_riscv_tools(){
    print_status "Installing SiFive RISC-V Toolchain..."
 
    if [ ! -d "$RISC_V_DIR" ]; then
        echo "Criando diretório $RISC_V_DIR..."
        mkdir -p "$RISC_V_DIR"
    fi
 
    cd "$RISC_V_DIR"
    wget https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz

    # Extrair a toolchain
    tar -xvzf riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz

	echo '=========================================================='
	echo ' Installing RISC-V GCC Compiler and Tools System-wide...  '
	echo '=========================================================='
	sudo cp -a * /usr/local/
	sleep 2

    # Adicionar a toolchain ao PATH
    echo 'export PATH=$PATH:~/riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14/bin' >> ~/.bashrc
    source ~/.bashrc
}


download_esp32_bin(){
    # Baixar o bootloader e tabela de partições (caso não tenha sido feito antes)
    echo "Baixando bootloader e tabela de partições para ESP32-C3..."
    cd "$ESP32_STUFF"
    mkdir esp-bins
    wget https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/bootloader-esp32c3.bin
    wget https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/partition-table-esp32c3.bin
}


add_to_bashrc() {
#-------------------------
#- Add paths to .bashrc
#-------------------------
    print_status "Permanently exporting paths to .bashrc..."

    # Adiciona o caminho para o diretório do ambiente virtual
    if ! grep -q "$ESP32_VIRTUAL_ENV/bin" ~/.bashrc; then
        echo "export PATH=$ESP32_VIRTUAL_ENV/bin:\$PATH" >> ~/.bashrc
    fi

    # Atualiza o .bashrc
    source ~/.bashrc
}

add_user_to_dialout() {
#-------------------------
#- Add user to
# dialout group 
# (for serial port access)
#-------------------------
    print_status "Adding user to dialout group..."
    sudo usermod -aG dialout $USER
    newgrp dialout  # Atualiza o grupo imediatamente
}


configure_env(){
	install_tools 		 		# Instalar Python3 e configurar aliases
	setup_virtualenv  			# Criar e configurar o ambiente virtual
	activate_virtualenv
	install_esptool  			# Instalar ESPTool no ambiente virtual
	download_riscv_tools  	  	# Instalar ferramentas SiFive RISC-V
	download_esp32_bin     
	add_to_bashrc  				# Adicionar ao .bashrc permanentemente
	add_user_to_dialout  		# Adicionar o usuário ao grupo dialout
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#          BUILD NUTTX RTOS FOR ESP32             #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~# 
build_nuttx_for_esp32(){
	echo '=========================================================='
	echo ' Configure NuttX for ESP32-C3 with NSH                    '
	echo '=========================================================='
	
	cd $NUTTX_DIR/nuttx/tools
	./configure.sh esp32c3-devkit:nsh
	cd $NUTTX_DIR/nuttx
	make
	ls -la | grep -ai '.bin'
	sleep 2
}


convert_elf_to_bin() {
	echo '======================================================================='
	echo ' Lets converts the NuttX ELF executable (nuttx) into a mage nuttx.bin  '
	echo '======================================================================='
	   
	cd "$ESP32_VIRTUAL_ENV"
    source $ESP32_VIRTUAL_ENV/bin/activate
		
	cd "$NUTTX_DIR/nuttx"
	esptool.py --chip esp32-c3 elf2image --flash_mode dio --flash_size 4MB -o nuttx.bin nuttx

	sleep 2
}

build_nuttx(){
 	build_nuttx_for_esp32
 	convert_elf_to_bin
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#      Writing the firmware to ESP32-C3           #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
write_firmware() {
	cd "$ESP32_VIRTUAL_ENV"
    source $ESP32_VIRTUAL_ENV/bin/activate
    cd "$NUTTX_DIR/nuttx"

    print_status "Writing firmware to ESP32-C3..."
	echo '=============================================================================================================================='
	echo ' Now, lets use the esptool.py utility to write the NuttX firmware binary image (nuttx.bin) onto the ESP32-C3 microcontroller  '
	echo '=============================================================================================================================='
	esptool.py --chip esp32-c3 -p /dev/ttyACM0 -b 921600 write_flash 0x10000 nuttx.bin
	
	#deactivate
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#      Do everything in the right order           #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
starting_from_scratch(){
    clear 
    
    sudo apt-get install -y festival
    
    clear
    
    qsix_logo
    
    echo "Hi... I am Haindal..." | festival --tts
    echo "Today I'm gonna to help you to configure the Nuttx for ESP32 risv 5." | festival --tts
 

    
    #if [ "$(id -u)" -ne 0 ]; then
    #    echo "Este script precisa ser executado como root ou com sudo."
    #    exit 1
    #fi
	
	create_project_main_folder
	open_ocd
	nuttx_world
	configure_env
	echo "Please, restart your computer, connect the device by usb cable and run: bifrost.sh -b -f"
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#       remove all download files                 #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
undo() {
    print_status "Undoing changes..."
    # Exemplo: Reverter a criação do diretório
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"  # Ou outra ação de reversão
    fi
    # Adicione outras reversões conforme necessário
}

undo_redo(){
	undo
	starting_from_scratch
}
#____________________________________________________________________________#



deactivate_virtualenv() {
	deactivate
}


#=============================================================================#
#===========================   MAIN LOOP MENU  ===============================#

# Main script logic
while [[ $# -gt 0 ]]; do
    case $1 in
        -H|--help)          # Tratamento para o --help
            show_help
            exit 0
            ;;
        -s) starting_from_scratch ;;
        -p) create_project_main_folder ;;
        -o) open_ocd ;;
        -n) nuttx_world ;;
        -c) configure_env ;;
        -b) build_nuttx ;;
        -f) write_firmware ;;
        -a) activate_virtualenv ;;
        -d) deactivate_virtualenv ;;
        -u) undo ;;
        -r) undo_redo ;;
        *) echo "Invalid option. Use -H or --help for usage."; exit 1 ;;
    esac
    shift  # Move para a próxima opção
done
#_____________________________________________________________________________#








