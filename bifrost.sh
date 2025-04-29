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
# Title:        Cloning, Installing and Building NuttX for ESP32-C3, Raspberry Pi Pico and Nuttx Simulation
# Author:       Vinicius Rodrigo May (vmay23 ~QsiX Embedded Labs~)
# Date:         2023/05/16
#
# rev date:     2025/02/17
# Rev Reason:   integrating RaspberryPI_Pico to Bifrost automation
#
# referencies:  Nuttx Channel (Alan Carvalho de Assis - https://www.youtube.com/@nuttxchannel)
#               Embarcados TV (Sara Cunha - https://www.youtube.com/watch?v=B3fKhR7tsVM)
#
#   0-Download pre-requirements (libs)
#   1-Download NuttX [SO, Apps, tools]
#   2-Download Tools [openOCD, minicom]
#   2-Download Toolchains [esp32-c3, rasps-pico]
#   3-Compile [simulator, esp32. rasp-pico]
#
#
#   ~/embedded_sys/
#                 /nuttxspace
#                            /nuttx
#                            /apps
#                            /tools
#                                 
#                 /tools
#                      /openocd
#                      /riscv
#                      /raspberry
#                                /pico-sdk
#                      /esp32
#                            /risc_v_toolchain
#                            /esp32_c3_bin
#                        
#                 /venv
#                      /.esp32_venv
#
#-------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------

#======================================================#
#=====               GLOBAL VARIABLES              ====#
#======================================================#
# root #
PROJECT_DIR="$HOME/embedded_sys"

# nuttx #
NUTTXSPACE_DIR="$HOME/embedded_sys/nuttxspace"
NUTTX_DIR="$HOME/embedded_sys/nuttxspace/nuttx"
APPS_DIR="$HOME/embedded_sys/nuttxspace/apps"
NUTTX_TOOLS_DIR="$HOME/embedded_sys/nuttxspace/nuttx/tools"

# tools #
TOOLS_DIR="$HOME/embedded_sys/tools"
OPENOCD_DIR="$HOME/embedded_sys/tools/openOCD"
RISCV_DIR="$HOME/embedded_sys/tools/riskv"
RASP_TOOLS_DIR="$HOME/embedded_sys/tools/raspberry"
RASP_TOOL_SDK_DIR="$HOME/embedded_sys/tools/raspberry/pico-sdk"
ESP32_TOOL_DIR="$HOME/embedded_sys/tools/esp32"
ESP32_RISC_V_DIR="$HOME/embedded_sys/tools/esp32/risc_v_toolchain"
ESP32_C3_BIN="$HOME/embedded_sys/tools/esp32/esp32_c3_bin"

# virtual emv #
VIRTUAL_ENV_DIR="$HOME/embedded_sys/venv"
ESP32_VIRTUAL_ENV_DIR="$HOME/embedded_sys/venv/.esp32_venv"

# aux commands #
CONFIGURE_SIM="$NUTTX_DIR/tools/configure.sh sim:nsh"
MAKE_MENUCONFIG="$HOME/embedded_sys/nuttxspace/nuttx/"
#======================================================#



#======================================================#
#=====           QsiX Welcome to Bifrost           ====#
#======================================================#
Raindal_Guide(){
    clear 
    sudo apt-get install -y festival
    clear

    #qsix_logo

    echo "Hi... I am Haindal..." | festival --tts
    echo "Today I'm gonna to help you to configure the Nuttx for ESP32 risv 5." | festival --tts
}
#======================================================#



#======================================================#
#===== Installing all packages needed by run NuttX ====#
#======================================================#
Install_Pre_Requirements(){
    REQUIRED_PACKAGES="jimtcl libjim-dev autoconf automake bison build-essential flex gcc-arm-none-eabi gperf libtool libncurses5-dev libusb-dev  \
                       libusb-1.0-0-dev pkg-config gettext texinfo libncursesw5-dev xxd git genromfs libgmp-dev libmpc-dev libmpfr-dev libisl-dev \
                       binutils-dev libelf-dev libexpat1-dev gcc-multilib g++-multilib picocom u-boot-tools util-linux python3 python3-pip kconfig-frontends festival"

    for package in $REQUIRED_PACKAGES; do
        if ! dpkg -l | grep -qw "$package"; then
            echo ""
            echo "Installing missing package: $package"
            sudo apt-get install -y "$package"
        else
            echo ""
            echo "Package $package is already installed."
        fi
    done
}
#======================================================#



#======================================================#
#===== Download Nuttx RTOS and its Applications    ====#
#======================================================#
show_options() {
    echo "The current folder already exists in this path. Please, choose one option to continue:  "
    echo "                                                                                        "
    echo " 1 - Clean everything inside $PROJECT_DIR                                               "
    echo " 2 - Create a new folder                                                                "
    echo " 3 - Rename the current folder to 'embedded_sys_old' and create a new 'embedded_sys'    "
    echo "                                                                                        " 
}
create_project_main_folder(){
    # Check if the directory ~/Documents/projects already exist.
    # if it does not exist, create such folder
    if [ ! -d "$PROJECT_DIR" ]; then                                                                                        
        echo "Creating project folder '$PROJECT_DIR' ..."   
        mkdir -p "$PROJECT_DIR"                                 # ~/embedded_sys
        mkdir -p "$NUTTXSPACE_DIR"                              # ~/embedded_sys/nuttxspace   
        mkdir -p "$TOOLS_DIR"                                   # ~/embedded_sys/tools                                                                  
    else
        while true; do
            show_options
            read -p "Please, enter with one option (1/2/3): " option
            case $option in

                # Confirmation
                1)                                                                                              
                    read -p "Are you sure you want to delete the folder '$PROJECT_DIR' contents? (y/n): " confirmation
                    # If answer = y
                    if [ "$confirmation" == "y" ]; then 
                        echo "Ok. Let's clean the whole directory '$PROJECT_DIR'..."
                        rm -rf "$PROJECT_DIR"/*  # Clean everything
                        break                    # Skip to the next instruction
                    # If answer = n/
                    else  
                        echo "It seems you are not so sure. Let's try once more..."
                    fi
                    ;;

                # Create a new folder
				2)                                                                                                          
					read -p "Please, insert the new directory name: " new_name
					new_dir="$HOME/Documents/$new_name"  # Full path to the new directory
					
					# Verifica se o diretório já existe antes de atualizar a variável
					if [ -d "$new_dir" ]; then  # Check if the new folder exists
						echo "The folder '$new_dir' already exists. Try another name."
					# Atualiza PROJECT_DIR e cria o diretório
                    else
						PROJECT_DIR="$new_dir"
                        mkdir -p "$PROJECT_DIR"                                 # ~/embedded_sys
                        mkdir -p "$NUTTXSPACE_DIR"                              # ~/embedded_sys/nuttxspace 
						echo "The new folder '$PROJECT_DIR' was created."
						break
					fi
					;;

                # Rename the current folder to 'embedded_sys_old' and create the new one
                3)  
                    if [ -d "${PROJECT_DIR}_old" ]; then
                        echo "The folder '${PROJECT_DIR}_old' already exists. Renaming it to a new name."
                        mv "$PROJECT_DIR" "${PROJECT_DIR}_old_$(date +%Y%m%d_%H%M%S)"
                    else
                        mv "$PROJECT_DIR" "${PROJECT_DIR}_old"
                    fi
                    mkdir -p "$PROJECT_DIR"                                 # ~/embedded_sys
                    mkdir -p "$NUTTXSPACE_DIR"                              # ~/embedded_sys/nuttxspace     
                    break
                    ;;

                # Invalid user input
                *)                                                                                                       
                    echo "Wrong option. Please try again."
                    ;;
            esac
        done
    fi
}
#======================================================#



#======================================================#
#===== Download Nuttx RTOS and its Applications    ====#
#======================================================#
#create_project_tree(){
#    # Diretórios globais
#    directory_tree=("$NUTTXSPACE_DIR" "$NUTTX_DIR" "$APPS_DIR" "$NUTTX_TOOLS_DIR" \
#                    "$TOOLS_DIR" "$OPENOCD_DIR" "$RISCV_DIR" "$RASP_TOOLS_DIR" "$RASP_TOOL_SDK_DIR" \
#                    "$ESP32_TOOL_DIR" "$ESP32_RISC_V_DIR" "$VIRTUAL_ENV_DIR" "$ESP32_VIRTUAL_ENV_DIR" \
#                    "$MAKE_MENUCONFIG")
#    
#    # Criação dos diretórios
#    for dir in "${directory_tree[@]}"; do           # garante que os espaços entre os itens não causem problemas.
#        if [ ! -d "$dir" ]; then
#            echo "Criando diretório: $dir"
#            mkdir -p "$dir"  
#        else
#            echo "Diretório já existe: $dir"
#        fi
#    done
#}
#======================================================#



#======================================================#
#=====          Download Nuttx RTOS TOOLS          ====#
#======================================================#
download_nuttx_tools(){
    cd "$NUTTXSPACE_DIR"

    # cloning repo 'tools' (if it does not exist in this folder) or update it case it already exist
    if [ ! -d "tools" ]; then
        echo "Cloning nuttx directory: 'tools'..."
        if ! git clone https://bitbucket.org/nuttx/tools.git; then
            echo "Apologize! we ran into an issue while trying to clone 'tools'."
            exit 1
        fi
    else
        echo "it seems 'tools' already exist. Let us update it so..."
        cd tools && git pull && cd ..
    fi
}
#======================================================#



#======================================================#
#=====          Download Nuttx RTOS FILES          ====#
#======================================================#
download_nuttx_rtos(){
    cd "$NUTTXSPACE_DIR"
    
    # cloning repo 'nuttx' (if it does not exist in this folder) or update it case it already exist
    if [ ! -d "nuttx" ]; then
        echo "Cloning nuttx directory: 'nuttx'..."
        if ! git clone https://github.com/apache/nuttx.git nuttx; then
            echo "Apologize! we ran into an issue while trying to clone 'nuttx'."
            exit 1
        fi
    else
        echo "it seems 'nuttx' already exist. Let us update it so..."
        cd nuttx && git pull && cd ..
    fi
}
#======================================================#



#======================================================#
#=====          Download Nuttx RTOS APPS           ====#
#======================================================#
download_nuttx_apps(){
    cd "$NUTTXSPACE_DIR"
    
    # cloning repo 'apps' (if it does not exist in this folder) or update it case it already exist
    if [ ! -d "apps" ]; then
        echo "Cloning nuttx directory: 'apps'..."
        if ! git clone https://github.com/apache/nuttx-apps.git apps; then
            echo "Apologize! we ran into an issue while trying to clone 'apps'."
            exit 1
        fi
    else
        echo "it seems 'apps' already exist. Let us update it so..."
        cd apps && git pull && cd ..
    fi
}
#======================================================#



#======================================================#
#=====          Download Kconfig-Front-End         ====#
#======================================================#
install_kconfig(){
    cd "$NUTTX_TOOLS_DIR"

    if ! ./configure --enable-mconf; then
		echo "Configuration of kconfig-frontends failed."
		exit 1
	fi

	aclocal 			# with any option needed (such as -I m4)
	autoconf
	automake --add-missing --force-missing
	sudo ln -s /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libcc1.so /usr/local/lib/libcc1.so.0
	sudo ln -s /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libexpat.so.1 /usr/local/lib/libexpat.so.1


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

install_kconfig_clean(){

    echo ">> Baixando nuttx-tools..."

    # Baixar o nuttx-tools se não existir
    # if [ ! -d "$NUTTX_TOOLS_DIR" ]; then
    #     git clone 	https://github.com/apache/nuttx-tools.git "$NUTTX_TOOLS_DIR" || {
    #         echo "Erro ao clonar nuttx-tools."
    #         exit 1
    #     }
    # fi

    cd "$NUTTX_TOOLS_DIR/kconfig-frontends" || {
        echo "Erro ao entrar na pasta kconfig-frontends."
        exit 1
    }

    echo ">> Configurando kconfig-frontends..."

    if ! ./configure --prefix=/usr --enable-mconf; then
        echo "Configuração do kconfig-frontends falhou."
        exit 1
    fi

    echo ">> Rodando autotools..."
    aclocal
    autoconf
    automake --add-missing --force-missing

    echo ">> Corrigindo dependências de bibliotecas..."
    if [ -f /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libcc1.so ]; then
        sudo ln -sf /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libcc1.so /usr/local/lib/libcc1.so.0
    fi
    if [ -f /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libexpat.so.1 ]; then
        sudo ln -sf /usr/local/riscv64-unknown-elf-gcc-8.3.0/lib/libexpat.so.1 /usr/local/lib/libexpat.so.1
    fi

    echo ">> Compilando kconfig-frontends..."
    if ! make -j$(nproc); then
        echo "Compilação do kconfig-frontends falhou."
        exit 1
    fi

    echo ">> Instalando kconfig-frontends..."
    if ! sudo make install; then
        echo "Instalação do kconfig-frontends falhou."
        exit 1
    fi

    echo ">> Atualizando cache do linker..."
    sudo ldconfig

    echo ">> Kconfig-frontends instalado com sucesso!"
}
#======================================================#




#======================================================#
#=====  Configure, compile and run NuttX simulator ====#
#======================================================#
clean_config(){
    cd "$NUTTX_DIR"
    make distclean 
}


configure_nuttx_sim(){
    cd "$NUTTX_DIR"
    ./tools/configure.sh sim:nsh
}


run_nuttx_simulator(){
    cd "$NUTTX_DIR"
    ./nuttx 
}


compile_nuttx(){
    cd "$NUTTX_DIR"
    make -j$(nproc)
}
#======================================================#



#======================================================#
#=====    Download raspberry_pi pico SDK needs     ====#
#======================================================#
Install_Pre_Requirements_PICO(){
    REQUIRED_PACKAGES_PICO="cmake python3 build-essential gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib"

    for package in $REQUIRED_PACKAGES_PICO; do
        if ! dpkg -l | grep -qw "$package"; then
            echo ""
            echo "Installing missing package: $package"
            sudo apt-get install -y "$package"
        else
            echo ""
            echo "Package $package is already installed."
        fi
    done
}
#======================================================#



#======================================================#
#=====    Download raspberry_pi pico Tool Chain    ====#
#======================================================#
download_toolchain_raspberry_pico(){
    if [ ! -d "$TOOLS_DIR" ]; then
        echo "Creating directory: $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"
    fi
    
    cd "$PROJECT_DIR"                                  # ~/embedded_sys
    mkdir -p "$RASP_TOOLS_DIR"                         # ~/embedded_sys/tools/raspberry
    cd "$RASP_TOOLS_DIR"                                                   
    
   # cloning repo 'apps' (if it does not exist in this folder) or update it case it already exist
   if [ ! -d "pico-sdk" ]; then
       echo "Cloning toolchain directory: 'pico-sdk'..."
       if ! git clone https://github.com/raspberrypi/pico-sdk.git pico-sdk; then
           echo "Apologize! we ran into an issue while trying to clone 'pico-sdk'."
           exit 1
       fi
   else
       echo "it seems 'pico-sdk' already exist. Let us update it so..."
       cd pico-sdk && git pull && cd ..
   fi

   cd "$RASP_TOOL_SDK_DIR"
   pwd
   cd "$PROJECT_DIR"
}
#======================================================#



#======================================================#
#====  Adding to path: raspberry_pi pico ToolChain  ===#
#======================================================#
add_to_path_toolchain_pico(){
    # Define a variável de ambiente na sessão atual
    export PICO_SDK_PATH="$HOME/embedded_sys/tools/raspberry/pico-sdk"

    # Remove qualquer linha existente que defina PICO_SDK_PATH
    sed -i '/export PICO_SDK_PATH=/d' ~/.bashrc

    # Adiciona a nova definição ao ~/.bashrc
    echo 'export PICO_SDK_PATH="$HOME/embedded_sys/tools/raspberry/pico-sdk"' >> ~/.bashrc
    echo "Variável PICO_SDK_PATH atualizada no ~/.bashrc"

    # Informa ao usuário para recarregar o ~/.bashrc
    echo "Abra um novo terminal ou execute 'source ~/.bashrc' para aplicar a mudança."
}
#======================================================#


#======================================================#
#=====     Configure Raspberry_PI Pico for NuttX   ====#
#======================================================#
configure_nuttx_rasp_pico(){
    cd "$NUTTX_DIR"                                     # Accessing the NuttX_RTOS folder

    clean_config                                        # clean previous configuration and binary;

    ./tools/configure.sh raspberrypi-pico:nsh           # Configure to use "raspberrypi-pico" with "nsh" profile;

    #compile_nuttx                                       # Compiling Nuttx
}
#======================================================#


#======================================================#
#=====      COMPILE Raspberry_PI Pico for NuttX    ====#
#======================================================#
compile_nuttx_rasp_pico(){
    cd "$NUTTX_DIR"                                     # Accessing the NuttX_RTOS folder
    compile_nuttx                                       # Compiling Nuttx
}
#======================================================#



#======================================================#
#=====    FLASH raspberry_pi pico over USB/SERIAL  ====#
#======================================================#
flash_pico(){
    echo "Please, disconnect RPICO"
    echo "Press RES_BOOT and hold it"
    echo "Connect RPICO again"
    echo "Release the button"
    echo "paste the nuttx.uf2 fw to rpico disk storage"
}
#======================================================#


    
#======================================================#
#=====      Install requirements for openOCD       ====#
#======================================================#
Install_Pre_Requirements_OPENOCD(){
    REQUIRED_PACKAGES_OPENOCD="automake bison build-essential flex gcc-arm-none-eabi gperf libtool libncurses5-dev libusb-dev libusb-1.0-0-dev pkg-config"

    for package in $REQUIRED_PACKAGES_OPENOCD; do
        if ! dpkg -l | grep -qw "$package"; then
            echo ""
            echo "Installing missing package: $package"
            sudo apt-get install -y "$package"
        else
            echo ""
            echo "Package $package is already installed."
        fi
    done
}
#======================================================#



#======================================================#
#=====               Download openOCD              ====#
#======================================================#
download_openOCD(){
    if [ ! -d "$TOOLS_DIR" ]; then
        echo "Criando diretório: $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"  
    else
        echo "Diretório já existe: $TOOLS_DIR"
    fi

    cd "$TOOLS_DIR"  # ~/embedded_sys

    # cloning repo 'OpenOCD' (if it does not exist in this folder) or update it if it already exists
    if [ ! -d "openOCD" ]; then
        echo "Cloning toolchain directory: 'openOCD'..."
        if ! git clone https://git.code.sf.net/p/openocd/code openOCD; then
            echo "Apologize! we ran into an issue while trying to clone 'openOCD'."
            exit 1
        fi
        # <<<=== to solve de jimtcl  submodule ===>>>
        cd openOCD
        echo "Initializing git submodules..."
        git submodule update --init --recursive
        cd ..
    else
        echo "It seems 'openOCD' already exists. Let us update it..."
        cd openOCD
        git pull
        echo "Updating submodules..."
        git submodule update --init --recursive
        cd ..
    fi

    cd "$OPENOCD_DIR"
    pwd
    cd "$PROJECT_DIR"
}
#======================================================#











#======================================================#
#=====             Compile openOCD                 ====#
#======================================================#
compile_openocd(){
    cd "$OPENOCD_DIR"


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
#======================================================#


#======================================================#
#=====       Install Serial Console Minicom        ====#
#======================================================#
install_minicom(){  
    sudo apt install -y minicom
    sudo usermod -aG dialout $USER
    newgrp dialout  # Atualiza o grupo imediatamente
}
#======================================================#










#======================================================#
#=====            Configure Python3                ====#
#======================================================#
configure_python(){  
    REQUIRED_PACKAGES_PYTHON="python3 python3-pip"

    for package in $REQUIRED_PACKAGES_PYTHON; do
        if ! dpkg -l | grep -qw "$package"; then
            echo ""
            echo "Installing missing package: $package"
            sudo apt-get install -y "$package"
        else
            echo ""
            echo "Package $package is already installed."
        fi
    done

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
#======================================================#


#======================================================#
#=====      Configure ESP32 virtual environment    ====#
#======================================================#
setup_virtualenv_esp32() {

    # Criar diretório do ambiente virtual se não existir
    if [ ! -d "$ESP32_VIRTUAL_ENV_DIR" ]; then
        echo "Criando o diretório .esp32_venv..."
        mkdir -p "$ESP32_VIRTUAL_ENV_DIR"

        echo "Configurando o ambiente virtual..."
        python3 -m venv "$ESP32_VIRTUAL_ENV_DIR"
    else
        echo "O ambiente virtual já existe."
    fi

    # Ativar o ambiente virtual
    source "$ESP32_VIRTUAL_ENV_DIR/bin/activate"

    # Verificar se o ambiente virtual foi ativado corretamente
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "Erro: o ambiente virtual não foi ativado corretamente."
        exit 1
    fi

    echo "Ambiente virtual ativado com sucesso!"
}
#======================================================#


#======================================================#
#=====      Activate ESP32 virtual environment     ====#
#======================================================#
activate_virtualenv_ESP32() {
    # Verifica se o diretório do ambiente virtual existe
    if [ -d "$ESP32_VIRTUAL_ENV_DIR" ]; then
        # Ativa o ambiente virtual
        echo "Ativando o ambiente virtual '$ESP32_VIRTUAL_ENV_DIR'..."
        source "$ESP32_VIRTUAL_ENV_DIR/bin/activate"

        # Verifica se ativação ocorreu corretamente
        if [ -z "$VIRTUAL_ENV" ]; then
            echo "Erro: O ambiente virtual não foi ativado corretamente."
            exit 1
        fi
    else
        echo "O ambiente virtual não foi encontrado. Certifique-se de que ele foi criado corretamente."
        exit 1
    fi
}
#======================================================#


#======================================================#
#=====               Install ESP_TOOL              ====#
#======================================================#
install_esptool() {
    # Ativa o ambiente virtual antes de instalar
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "Ativando ambiente virtual..."
        source "$ESP32_VIRTUAL_ENV_DIR/bin/activate"
    fi

    # Verifica se o esptool já está instalado no ambiente virtual
    if ! pip show esptool &> /dev/null; then
        echo "Instalando esptool..."
        pip install esptool
    else
        echo "esptool já está instalado no ambiente virtual."
    fi
}
#======================================================#




#======================================================#
#=====           Download Risc-V ToolChai          ====#
#======================================================#
download_riscv_tools(){
    if [ ! -d "$TOOLS_DIR" ]; then
        echo "Creating directory: $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"
    fi
    
    cd "$TOOLS_DIR"
    mkdir -p "$ESP32_TOOL_DIR"
    cd "$ESP32_TOOL_DIR"

    if [ ! -d "$ESP32_RISC_V_DIR" ]; then
        echo "Criando diretório $ESP32_RISC_V_DIR..."
        mkdir -p "$ESP32_RISC_V_DIR"
    fi 
    cd "$ESP32_RISC_V_DIR"
    wget https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz
   # Extrair a toolchain
    echo "Extraindo a toolchain..."
    tar -xvzf riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz

    # Remover o arquivo baixado para economizar espaço
    rm riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14.tar.gz

    # Definir o PATH corretamente
    TOOLCHAIN_DIR="$ESP32_RISC_V_DIR/riscv64-unknown-elf-gcc-8.3.0-2019.08.0-x86_64-linux-ubuntu14/bin"

    # Adicionar ao ~/.bashrc (sem duplicar)
    if ! grep -q "$TOOLCHAIN_DIR" ~/.bashrc; then
        echo "export PATH=\$PATH:$TOOLCHAIN_DIR" >> ~/.bashrc
        echo "Toolchain adicionada ao PATH no ~/.bashrc"
    else
        echo "Toolchain já está no PATH."
    fi

    # Aplicar a mudança no PATH imediatamente
    export PATH=$PATH:$TOOLCHAIN_DIR
    echo "Toolchain instalada e disponível no PATH."
}
#======================================================#



#======================================================#
#=====         download esp32_C3 binary            ====#
#======================================================#
download_esp32_c3_bin(){
    if [ ! -d "$TOOLS_DIR" ]; then
        echo "Creating directory: $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"
    fi
    
    if [ ! -d "$ESP32_TOOL_DIR" ]; then
        echo "Criando diretório $ESP32_TOOL_DIR..."
        mkdir -p "$ESP32_TOOL_DIR"
    fi 
    cd "$ESP32_TOOL_DIR"

    if [ ! -d "$ESP32_C3_BIN" ]; then
        echo "Criando diretório $ESP32_C3_BIN..."
        mkdir -p "$ESP32_C3_BIN"
    fi 

    # Baixar o bootloader e tabela de partições (caso não tenha sido feito antes)
    echo "Baixando bootloader e tabela de partições para ESP32-C3..."
    cd "$ESP32_C3_BIN"
    mkdir esp-bins
    wget https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/bootloader-esp32c3.bin
    wget https://github.com/espressif/esp-nuttx-bootloader/releases/download/latest/partition-table-esp32c3.bin
}
#======================================================#




#======================================================#
#=====            CONVERT ELF TO BIN               ====#
#======================================================#
convert_elf_to_bin(){
    echo '======================================================================='
	echo ' Lets converts the NuttX ELF executable (nuttx) into a mage nuttx.bin  '
	echo '======================================================================='
	   
    activate_virtualenv_ESP32
		
	cd "$NUTTX_DIR"
	esptool.py --chip esp32-c3 elf2image --flash_mode dio --flash_size 4MB -o nuttx.bin nuttx

	sleep 2
}
#======================================================#



#======================================================#
#=====     Configure ESP32-C3 [RISCV for NuttX     ====#
#======================================================#
configure_nuttx_esp32_c3(){
    activate_virtualenv_ESP32
    cd "$NUTTX_DIR"                                     # Accessing the NuttX_RTOS folder

    clean_config                                        # clean previous configuration and binary;

    cd "$NUTTX_TOOLS_DIR"
    ./configure.sh esp32c3-devkit:nsh                   # Configure to use "esp32-c3" with "nsh" profile;

    compile_nuttx                                       # Compiling Nuttx bin

    convert_elf_to_bin
    cd "$NUTTX_DIR"
    ls -la | grep -ai '.bin'
}
#======================================================#

#======================================================#
#=====      COMPILE esp32_c3_riscv for NuttX       ====#
#======================================================#
compile_nuttx_esp32_c3(){
    activate_virtualenv_ESP32
    cd "$NUTTX_DIR"                                     # Accessing the NuttX_RTOS folder

    compile_nuttx                                       # Compiling Nuttx bin

    convert_elf_to_bin
    cd "$NUTTX_DIR"
    ls -la | grep -ai '.bin'
}
#======================================================#




#======================================================#
#=====         FLASH ESP32-C3 USING ESPTOOL        ====#
#======================================================#
flash_esp32_c3(){
    activate_virtualenv_ESP32

    cd "$NUTTX_DIR"
	echo '=============================================================================================================================='
	echo ' Now, lets use the esptool.py utility to write the NuttX firmware binary image (nuttx.bin) onto the ESP32-C3 microcontroller  '
	echo '=============================================================================================================================='
	esptool.py --chip esp32-c3 -p /dev/ttyACM0 -b 921600 write_flash 0x10000 nuttx.bin
}
#======================================================#



#======================================================#
#=====                 HELP MENU                   ====#
#======================================================#
show_help() {
    echo "Usage: $0 [option]"
    echo ""
    echo "General setup:"
    echo "  -pr                  Install all required packages"
    echo "  -mf                  Create the base project folder ~/embedded_sys"
    echo ""
    echo "NuttX core:"
    echo "  -nut-tools           Clone nuttx/tools repo"
    echo "  -nut-rtos            Clone nuttx kernel repo"
    echo "  -nut-apps            Clone nuttx apps repo"
    echo "  -nut-sim             Configure NuttX for simulator (sim:nsh)"
    echo "  -nut-build           Build NuttX (must be configured first)"
    echo "  -nut-clean           Run distclean on NuttX"
    echo "  -nut-run             Run NuttX simulator binary"
    echo ""
    echo "Raspberry Pi Pico:"
    echo "  -pico-pr             Install required packages for Pico SDK"
    echo "  -pico-tc             Clone pico-sdk toolchain"
    echo "  -pico-path           Add pico-sdk path to ~/.bashrc"
    echo "  -pico-conf-nuttx     Configure NuttX for Raspberry Pi Pico"
    echo "  -pico-build-nuttx    Compile NuttX for Raspberry Pi Pico"
    echo "  -pico-flash          Flash .uf2 manually to Pico over USB"
    echo ""
    echo "ESP32-C3:"
    echo "  -esp-riscv-tc        Download and extract RISC-V toolchain"
    echo "  -esp-get-bin         Download bootloader and partition binaries"
    echo "  -esp-elf2bin         Convert NuttX ELF to .bin using esptool"
    echo "  -esp-conf-nuttx      Configure NuttX for ESP32-C3 (esp32c3-devkit)"
    echo "  -esp-build-nuttx     Build and convert NuttX for ESP32-C3"
    echo "  -esp-flash           Flash ESP32-C3 over serial with esptool"
    echo ""
    echo "Python & Virtualenv:"
    echo "  -py-conf             Configure python3 + alias + pip3"
    echo "  -venv-esp            Setup virtualenv for ESP32"
    echo "  -venv-esp-act        Activate virtualenv for ESP32"
    echo "  -venv-esptool-install Install esptool in ESP32 virtualenv"
    echo ""
    echo "External tools:"
    echo "  -tool-ocd-pr         Install OpenOCD dependencies"
    echo "  -tool-ocd-get        Clone and init OpenOCD repo"
    echo "  -tool-ocd-build      Build and install OpenOCD"
    echo "  -tool-minicom-pr     Install minicom and set user permissions"
    echo ""
    echo "Other:"
    echo "  -festival-pr         Install Festival TTS (optional)"
    echo "  -H, --help           Show this help message"
    echo ""
}
#======================================================#




# Main script logic
while [[ $# -gt 0 ]]; do
    case $1 in
        # Pré-requisitos gerais
        -pr) Install_Pre_Requirements ;;
        -mf) create_project_main_folder ;;

        # NuttX
        -nut-tools) download_nuttx_tools ;;
        -nut-rtos) download_nuttx_rtos ;;
        -nut-apps) download_nuttx_apps ;;
        -nut-sim) configure_nuttx_sim ;;
        -nut-build) compile_nuttx ;;
        -nut-clean) clean_config ;;
        -nut-run) run_nuttx_simulator ;;

        # Raspberry Pi Pico
        -pico-pr) Install_Pre_Requirements_PICO ;;
        -pico-tc) download_toolchain_raspberry_pico ;;
        -pico-path) add_to_path_toolchain_pico ;;
        -pico-conf-nuttx) configure_nuttx_rasp_pico ;;
        -pico-build-nuttx) compile_nuttx_rasp_pico ;;
        -pico-flash) flash_pico ;;

        #External Tools
        -tool-ocd-pr) Install_Pre_Requirements_OPENOCD ;;
        -tool-ocd-get) download_openOCD ;;
        -tool-ocd-build) compile_openocd ;;
        -tool-minicom-pr) install_minicom ;;

        # Python & Virtual Environments
        -py-conf) configure_python ;;
        -venv-esp) setup_virtualenv_esp32 ;;
        -venv-esp-act) activate_virtualenv_ESP32 ;;
        -venv-esptool-install) install_esptool ;;

        # ESP32
        -esp-riscv-tc) download_riscv_tools ;;
        -esp-get-bin) download_esp32_c3_bin ;;
        -esp-elf2bin) convert_elf_to_bin ;;
        -esp-conf-nuttx) configure_nuttx_esp32_c3 ;;
        -esp-build-nuttx) compile_nuttx_esp32_c3 ;;
        -esp-flash) flash_esp32_c3 ;;

	# HELP MENU
 	-H|--help) show_help ; exit 0 ;;
  
        *) echo "Invalid option. Use -H or --help for usage." ; exit 1 ;;
    esac
    shift  # Move para a próxima opção
done
