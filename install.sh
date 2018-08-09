#!/bin/bash

# Author : neroxps
# Email : neroxps@gmail.com
# Version : 1.1
# Date : 2018-8-4

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Function

## 这个方法抄袭自 https://github.com/teddysun/shadowsocks_install
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "raspbian" /proc/version; then
    	release="raspbian"
    	systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

## 下载文件方法
download_file(){
    local url=$1
    local file_name=$2
    if [ -z ${file_name} ];then
        if which curl > /dev/null 2>&1 ; then
            curl -sSL ${url}
        else
            wget ${url}
        fi
    else
        if which curl > /dev/null 2>&1 ; then
            curl -sSL -o ${file_name} ${url}
        else
            wget --output-document=${file_name} ${url}
        fi
    fi
}

## 切换安装源
replace_source(){
    local selected
    echo "${yellow}是否将系统源切换为中科大(USTC)源（目前支持 Debian Ubuntu Raspbian 三款系统）${plain}"
    read -p "请输入 y or n（默认 yes):" selected
    case "${selected}" in
        ''|Y|y)
            if check_sys sysRelease ubuntu ; then
                cp /etc/apt/sources.list /etc/apt/sources.list.bak
                sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
                apt update
                if [[ $? == 0 ]]; then
                    echo -e "${green}[info]: 已将系统源切换为中科大源，源文件备份至 /etc/apt/sources.list.bak。${plain}"
                else
                    mv /etc/apt/sources.list.bak /etc/apt/sources.list
                    echo -e "${red}[ERROR]: 系统源切换错误，请检查网络连接是否正常，脚本退出{plain}"
                    exit 1
                fi
            elif check_sys sysRelease debian ; then
                cp /etc/apt/sources.list /etc/apt/sources.list.bak
                sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
                apt update
                if [[ $? == 0 ]]; then
                    echo -e "${green}[info]: 已将系统源切换为中科大源，源文件备份至 /etc/apt/sources.list.bak。${plain}"
                else
                    mv /etc/apt/sources.list.bak /etc/apt/sources.list
                    echo -e "${red}[ERROR]: 系统源切换错误，请检查网络连接是否正常，脚本退出。${plain}"
                    exit 1
                fi
            elif check_sys sysRelease raspbian ; then
            	cp /etc/apt/sources.list /etc/apt/sources.list.bak
            	sed -i 's|raspbian.raspberrypi.org|mirrors.ustc.edu.cn/raspbian|g' /etc/apt/sources.list
            	sed -i 's|mirrordirector.raspbian.org|mirrors.ustc.edu.cn/raspbian|g' /etc/apt/sources.list
				sed -i 's|archive.raspbian.org|mirrors.ustc.edu.cn/raspbian|g' /etc/apt/sources.list
				apt update
				if [[ $? == 0 ]]; then
                    echo -e "${green}[info]: 已将系统源切换为中科大源，源文件备份至 /etc/apt/sources.list.bak。${plain}"
                else
                    mv /etc/apt/sources.list.bak /etc/apt/sources.list
                    echo -e "${red}[ERROR]: 系统源切换错误，请检查网络连接是否正常，脚本退出。${plain}"
                    exit 1
                fi
            fi
            ;;
        n|N) 
            echo -e "${yellow}[info]: 跳过切换系统源。${plain}"
            ;;
        *)
            replace_source
            ;;
    esac
}

## 更新系统
update_system(){
    if check_sys sysRelease ubuntu || check_sys sysRelease debian ;then
        apt upgrade -y
        if [[ $? != 0 ]]; then
            echo -e "${red}[ERROR]: 系统更新失败，脚本退出。${plain}"
            exit 1
        fi
        echo -e "${green}[info]: 系统更新成功。${plain}"
    fi
    if check_sys sysRelease ubuntu ; then
        add-apt-repository main
        add-apt-repository universe
        add-apt-repository restricted
        add-apt-repository multiverse
        apt update
    fi
}

## 安装 docker
docker_install(){
    download_file 'https://get.docker.com' 'get-docker.sh'
    chmod u+x get-docker.sh
    ./get-docker.sh
    if ! systemctl status docker > /dev/null 2>&1 ;then
        echo -e "${red}[ERROR]: Docker 安装失败，请检查上方安装错误信息。${plain}"
        exit 1
    fi
}

## apt 安装依赖方法
apt_install(){
    apt install -y ${*}
    if [[ $? -ne 0 ]];then
        echo -e "${red}[ERROR]: 安装${1}失败，请将检查上方安装错误信息。${plain}"
        exit 1
    fi
}

## 添加用户到 docker 用户组
add_user_to_docker(){
    local users=($(cat /etc/passwd | awk -F: '$3>=500' | cut -f 1 -d :| grep -v nobody))
    local users_num=${#users[*]}
    local selected
    if [[ ${users_num} -ne 1 ]];then
        echo -e "找到该系统中有以下用户名"
        echo -e "如下方列表未显示你的用户名，请切换回你用户账号后输入 usermod -aG docker '$USER' 添加用户都 docker 用户组。"
        local i = 1
        while [[ $i -le ${users_num} ]]; do
            echo -e "[${i}]: ${users[$((($i-1)))]}"
            let i++
        done
        echo -e "[s]: 跳过"
        read -p '请输入你需要使用 docker 的用户名序号，以加入 docker 用户组。' selected
        case ${selected} in
            [0-9]*)
                if [[ ${users[$(((${selected}-1)))]} != "" ]]; then
                    echo -e "${green}将${users[$(((${selected}-1)))]}用户添加至 docker 用户组。${plain}"
                    usermod -aG docker ${users[$(((${selected}-1)))]}
                else
                    echo -e "${red}输入数字错误请重新选择。${plain}"
                    add_user_to_docker
                fi
                ;;
            s|S)
                echo -e "${yellow}跳过添加用户到 docker 用户组。${plain}"
                break;
                ;;
            *)
                echo -e "${red}请输入列表中的数字后按回车。${plain}"
                add_user_to_docker
                ;;
        esac
    else
        read -p "在你系统内找到${users[0]}用户，是否将其添加至 docker 用户组( yes or no )：" selected
        case ${selected} in
            Yes|YES|yes|y|Y)
                echo -e "${green}将${users[0]}用户添加至 docker 用户组。"
                usermod -aG docker ${users[0]}
                ;;
            No|NO|no|n|N)
                echo -e "${yellow}跳过添加用户到 docker 用户组。${plain}"
                ;;
            *)
                echo -e "${red}请输入 Yes 或者 No 后按回车确认。${plain}"
                add_user_to_docker
                ;;
        esac
    fi
}

## 修改 docker 源
change_docker_registry(){
    local selected
    echo -e "${yellow}是否需要替换 docker 默认源？${plain}"
    while true; do
        read -p '请输入( yes or no )：' selected
        case ${selected} in
            Yes|YES|yes|y|Y)
                    selected="yes"
                    break;
                ;;
            No|NO|no|n|N)
                    selected="no"
                    break;
                ;;
            *)
                    echo -e "${red}输入错误，请重新输入。${plain}"
                    change_docker_registry
        esac
    done
    if [[ ${selected} == "yes" ]]; then
        if [ ! -d /etc/docker ];then
            mkdir -p /etc/docker
        fi
    cat << EOF > /etc/docker/daemon.json 
{ 
  "registry-mirrors": [ 
    "https://registry.docker-cn.com" 
  ] 
} 
EOF
        systemctl daemon-reload
        systemctl restart docker > /dev/null
        echo -e "${green}切换国内源完成${plain}"
    fi
}

## hassio 安装
hassio_install(){
    download_file 'https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/hassio_install' 'hassio_install.sh'
    chmod u+x hassio_install.sh
    local hassio_version=$(curl -Ls https://registry.hub.docker.com/v1/repositories/homeassistant/amd64-hassio-supervisor/tags | jq -r 'length as $num |.[$num - 1].name')
    if [ -z ${hassio_version} ];then
        echo -e "${red} 获取 hassio 版本号失败，请检查你网络与 registry.hub.docker.com 连接是否畅通。${plain}"
        echo -e "${red}脚本退出...${plain}"
        exit 1
    fi
    sed -i "s/HASSIO_VERSION=.*/HASSIO_VERSION=${hassio_version}/g" ./hassio_install.sh
    local machine_map=(raspberrypi raspberrypi2 raspberrypi3 raspberrypi3-64 qemuarm qemuarm-64 qemux86-64 qemux86 intel-nuc)
    local machine
    local name
    local selected
    while true;do
        local i=1
        echo -e "${yellow}请选择你设备类型:（默认 qemux86-64）${plain}"
        for name in ${machine_map[@]}; do
            echo -e "    [${i}]: ${name}"
            let i++
        done
        read -p "输入数字 (0-9)" selected
        case ${selected} in
            [1-9])
                machine="${machine_map[((${selected}-1))]}"
                break;
                ;;
            '')
                machine='qemux86-64'
                break;
                ;;
            *)
                echo -e "${red}输入错误，请重新输入${plain}"
        esac
    done
    local homeassistant_version=$(curl -Ls https://registry.hub.docker.com/v1/repositories/homeassistant/qemux86-64-homeassistant/tags | jq -r 'length as $num |.[$num - 2].name')
    echo -e "${yellow}从 hub.docker.com 下载 homeassistant/${machine}-homeassistant:${homeassistant_version}......${plain}"
    docker pull homeassistant/${machine}-homeassistant:${homeassistant_version}
    mkdir -p /usr/share/hassio/
cat << EOF > /usr/share/hassio/updater.json
{
  "channel": "stable",
  "hassio": "${hassio_version}",
  "homeassistant": "${homeassistant_version}"
}
EOF
    ./hassio_install.sh -m ${machine}
    if ! systemctl status hassio-supervisor > /dev/null ; then
        echo -e "${red}安装 hassio 失败，请将上方安装信息发送到论坛询问。${plain}"
        echo -e "${red}脚本退出...${plain}"
        exit 1
    fi
}

# Main

## 检查脚本运行环境
if [[ $USER != "root" ]];then
    echo -e "${red}[ERROR]: 请输入 \"sudo -s\" 切换至 root 账户运行本脚本...脚本退出${plain}"
    exit 1
fi

## 切换安装源
echo -e "${yellow}[info]: 切换系统网络源.....${plain}"
replace_source

## 更新系统至最新
echo -e "${yellow}[info]: 更新系统至最新.....${plain}"
update_system

## 定义 Ubuntu 和 Debian 依赖
echo -e "${yellow}[info]: 安装 hassio 必要依赖.....${plain}"
Ubunt_Debian_Requirements="socat jq avahi-daemon"
apt_install ${Ubunt_Debian_Requirements}

## 安装 Docker 引擎
if ! command -v docker;then
    echo -e "${yellow}[info]: 安装 Docker 引擎.....${plain}"
    docker_install
else
    echo -e "${yellow}[info]: 发现系统已安装 docker，跳过 docker 安装${plain}"
fi

## 添加用户到 docker 用户组
echo -e "${yellow}[info]: 添加用户到 docker 用户组.....${plain}"
add_user_to_docker

## 切换 Docker 源为国内源
change_docker_registry

## 安装 hassio
echo -e "${yellow}[info]: 安装 hassio......${plain}"
hassio_install

