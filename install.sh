#!/bin/bash

# Author : neroxps
# Email : neroxps@gmail.com
# Version : 3.5
# Date : 2020-04-10

# 颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 变量
## 安装必备依赖
Ubunt_Debian_Requirements="curl socat jq avahi-daemon net-tools qrencode"

## 获取系统用户用作添加至 docker 用户组
users=($(cat /etc/passwd | awk -F: '$3>=500' | cut -f 1 -d :| grep -v nobody))
users_num=${#users[*]}

title_num=1
check_massage=()

## 检查系统架构以区分 machine
if [[ $(getconf LONG_BIT) == "64" ]]; then
    machine_map=(intel-nuc odroid-c2 odroid-xu orangepi-prime qemuarm-64 qemux86-64 raspberrypi3-64 raspberrypi4-64 tinker)
    machine_info=("英特尔的nuc小主机" "韩国odroid-c2" "韩国odroid-xu" "香橙派" "通用arm设备（例如斐讯N1) 64位系统" "通用X86（普通的PC机电脑）64位系统" "树莓派三代64位系统" "树莓派四代64位系统" "华硕tinker")
    default_machine="qemux86-64"
elif [[ $(getconf LONG_BIT) == "32" ]]; then
    machine_map=(intel-nuc odroid-c2 odroid-xu orangepi-prime qemuarm qemux86 raspberrypi raspberrypi2 raspberrypi3 raspberrypi4 tinker)
    machine_info=("英特尔的nuc小主机" "韩国odroid-c2" "韩国odroid-xu" "香橙派" "通用arm设备（例如斐讯N1)" "通用X86（普通的PC机电脑）" "树莓派一代" "树莓派二代" "树莓派三代" "树莓派四代" "华硕tinker")
    default_machine="qemux86"
else
    machine_map=(intel-nuc odroid-c2 odroid-xu orangepi-prime qemuarm qemuarm-64 qemux86 qemux86-64 raspberrypi raspberrypi2 raspberrypi3 raspberrypi4 raspberrypi3-64 raspberrypi4-64 tinker)
    machine_info=("英特尔的nuc小主机" "韩国odroid-c2" "韩国odroid-xu" "香橙派" "通用arm设备（例如斐讯N1)" "通用arm设备（例如斐讯N1) 64位系统" "通用X86 64位系统（普通的PC机电脑）" "通用X86（普通的PC机电脑）64位系统" "树莓派一代" "树莓派二代" "树莓派三代" "树莓派四代" "树莓派三代64位系统" "树莓派四代64位系统" "华硕tinker")
    default_machine="qemux86-64"
fi
machine_num=${#machine_map[*]}

# Function

## 这个方法抄袭自 https://github.com/teddysun/shadowsocks_install
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif lsb_release -a 2>/dev/null | grep -Eqi "raspbian"; then
        release="raspbian"
        systemPackage="apt"
        systemCodename=$(lsb_release -a 2>/dev/null | awk '/Codename/ {print $2}')
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
        systemPackage="apt"
        systemCodename=$(lsb_release -a 2>/dev/null | awk '/Codename/ {print $2}')
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
        systemCodename=$(lsb_release -a 2>/dev/null | awk '/Codename/ {print $2}')
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
        systemPackage="apt"
        systemCodename=$(lsb_release -a 2>/dev/null | awk '/Codename/ {print $2}')
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
        systemCodename=$(lsb_release -a 2>/dev/null | awk '/Codename/ {print $2}')
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
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
    if [[ $? -ne 0 ]];then
        echo -e "${red}[ERROR]: 下载 ${url} 失败，请检查网络与其连接是否正常。${plain}"
        exit 1
    fi
}

## 切换安装源
replace_source(){
    if [[ -z ${systemCodename} ]]; then
        error_exit "${yellow} [ERROR]: 由于无法确定系统版本，故请手动切换系统源，切换方法参考中科大源使用方法：http://mirrors.ustc.edu.cn/help/${plain}"
    fi
    [[ ! -f /etc/apt/sources.list.bak ]] && echo -e "${yellow}备份系统源文件为 /etc/apt/sources.list.bak${plain}" && mv /etc/apt/sources.list /etc/apt/sources.list.bak

    case $(uname -m) in
        "x86_64" | "i686" | "i386" )
            if [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
                download_file https://mirrors.ustc.edu.cn/repogen/conf/${release}-http-4-${systemCodename} /etc/apt/sources.list
            fi
            ;;
        "arm" | "armv7l" | "armv6l" | "aarch64" | "armhf" | "arm64" | "ppc64el")
            if [[ -f /etc/apt/sources.list.d/armbian.list ]] ;then
                echo -e "${yellow}发现 armbian 源，重命名armbian无法访问的源，如需要恢复请自行到 /etc/apt/sources.list.d/ 文件夹中删除后缀名 \".bak\"${plain}"
                mv /etc/apt/sources.list.d/armbian.list /etc/apt/sources.list.d/armbian.list.bak
            fi
            if [[ ${release} == "debian" ]]; then
                download_file https://mirrors.ustc.edu.cn/repogen/conf/${release}-http-4-${systemCodename} /etc/apt/sources.list
            elif [[  ${release} == "raspbian" ]]; then
                echo "deb http://mirrors.ustc.edu.cn/raspbian/raspbian/ ${systemCodename} main contrib non-free rpi" > /etc/apt/sources.list
                echo "deb http://mirrors.ustc.edu.cn/archive.raspberrypi.org/debian/ ${systemCodename} main ui" >> /etc/apt/sources.list
            elif [[ ${release} == "ubuntu" ]]; then
                echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ ${systemCodename} main restricted universe multiverse" > /etc/apt/sources.list
                echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ ${systemCodename}-updates main restricted universe multiverse" >> /etc/apt/sources.list
                echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ ${systemCodename}-backports main restricted universe multiverse" >> /etc/apt/sources.list
                echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ ${systemCodename}-security main restricted universe multiverse" >> /etc/apt/sources.list
            fi
            ;;
        *)  error_exit "[ERROR]: 由于无法获取系统架构，故此无法切换系统源，请跳过系统源切换。"
            ;;
    esac

    apt update
    if [[ $? -ne 0 ]]; then
        mv /etc/apt/sources.list.bak /etc/apt/sources.list
        error_exit "[ERROR]: 系统源切换错误，请检查网络连接是否正常，脚本退出"
    fi
}

## 更新系统
update_system(){
    if [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]] || [[ ${release} == "raspbian" ]]; then
        apt upgrade -y
        if [[ $? != 0 ]]; then
            error_exit "[ERROR]: 系统更新失败，脚本退出。"
        fi
        echo -e "${green}[info]: 系统更新成功。${plain}"
    fi
    if [[ ${release} == "ubuntu" ]] ; then
        add-apt-repository main
        add-apt-repository universe
        add-apt-repository restricted
        add-apt-repository multiverse
        apt update
    fi
}

## 安装 docker
docker_install(){
    download_file 'get.docker.com' 'get-docker.sh'
    sed -i 's/DEFAULT_CHANNEL_VALUE="test"/DEFAULT_CHANNEL_VALUE="edge"/' get-docker.sh
    chmod u+x get-docker.sh
    ./get-docker.sh --mirror AzureChinaCloud
    if ! systemctl status docker > /dev/null 2>&1 ;then
        error_exit "${red}[ERROR]: Docker 安装失败，请检查上方安装错误信息。 你也可以选择通过搜索引擎，搜索你系统安装docker的方法，安装后重新执行脚本。${plain}"
    else
        echo -e "${green}[info]: Docker 安装成功。${plain}"
    fi
    if [[ ! -z ${add_User_Docker} ]];then
        echo -e "${yellow}添加用户 ${add_User_Docker} 到 Docker 用户组${plain}"
        usermod -aG docker ${add_User_Docker}
    fi
}

## apt 安装依赖方法
apt_install(){
    apt update
    apt install -y ${*}
    if [[ $? -ne 0 ]];then
        error_exit "${red}[ERROR]: 安装${1}失败，请将检查上方安装错误信息。${plain}"
    fi
}


## 修改 docker 源
change_docker_registry(){
    if [ ! -d /etc/docker ];then
        mkdir -p /etc/docker
    fi
cat << EOF > /etc/docker/daemon.json 
{ 
    "registry-mirrors": [ 
    "https://rw21enj1.mirror.aliyuncs.com",
    "https://dockerhub.azk8s.cn",
    "https://reg-mirror.qiniu.com",
    "https://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
    ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker > /dev/null
    echo -e "${green}[info]: 切换国内源完成${plain}"
}

## hassio 安装
hassio_install(){
    local i=10
    while true;do
        stable_json=$(curl -Ls https://version.home-assistant.io/stable.json)
        if [[ ! -z ${stable_json} ]]; then
            break;
        fi
        if [[ $i -eq 0 ]]; then
            error_exit "${red}[ERROR]: 获取 hassio 版本号失败，请检查你系统网络与 https://version.home-assistant.io 的连接是否正常。${plain}"
        fi
        let i--
    done
    hassio_version=$(echo ${stable_json} |jq -r '.supervisor')
    homeassistant_version=$(echo ${stable_json} |jq -r '.homeassistant.default')
    if [ -z ${hassio_version} ] || [ -z ${homeassistant_version} ];then
        error_exit "${red}[ERROR]: 获取 hassio 版本号失败，请检查你网络与 https://version.home-assistant.io 连接是否畅通。${plain}"
    fi
    download_file 'https://code.aliyun.com/neroxps/hassio-installer/raw/master/installer.sh' 'hassio_install.sh'
    chmod u+x hassio_install.sh
    sed -i "s/HASSIO_VERSION=.*/HASSIO_VERSION=${hassio_version}/g" ./hassio_install.sh
    sed -i "s@https://raw.githubusercontent.com/home-assistant/supervised-installer@https://code.aliyun.com/neroxps/hassio-installer/raw@g" ./hassio_install.sh
    echo -e "${yellow}从 hub.docker.com 下载 homeassistant/${machine}-homeassistant:${homeassistant_version}......${plain}"
    local i=10
    while true ;do
        docker pull homeassistant/${machine}-homeassistant:${homeassistant_version}
        if [[ $? -eq 0 ]]; then
            docker tag homeassistant/${machine}-homeassistant:${homeassistant_version} homeassistant/${machine}-homeassistant:latest
            break;
        else
            echo -e "${yellow}[WARNING]: 从 docker hub 下载 homeassistant/${machine}-homeassistant:${homeassistant_version} 失败，第 ${i} 次重试.${plain}"
            if [[ ${i} -eq 0 ]]; then
                echo -e "${red}[ERROR]: 从 docker 下载 homeassistant/${machine}-homeassistant:${homeassistant_version} 失败，请检查上方失败信息。${plain}"
                exit 1
            fi
        fi
        let i--
    done
    echo -e "${yellow}开始 hassio 安装流程。(如出现 [Warning] 请忽略，无须理会)${plain}"
    ./hassio_install.sh -m ${machine} --data-share ${data_share_path}
    
    if ! systemctl status hassio-supervisor > /dev/null ; then
        error_exit "安装 hassio 失败，请将上方安装信息发送到论坛询问。脚本退出..."
    fi
}

ubuntu_18_10_docker_install(){
    apt install docker.io -y
}

error_exit(){
    echo -e "${red}"
    echo "################# 发到论坛时，请把上方日志也一并粘贴发送 ################"
    echo "########################### System version ###########################"
    lsb_release -a 2>/dev/null
    echo "########################### System version 2 ###########################"
    cat /proc/version
    echo "########################### System info ###########################"
    uname -a
    echo "########################### END ###########################"
    echo "${1}"
    echo -e "${plain}"
    echo -e "${yellow} 相关问题可以访问https://bbs.iobroker.cn或者加QQ群776817275咨询${plain}"
    exit 1
}

wait_homeassistant_run(){
    printf "等待 homeassistant 启动(树莓派的话启动可能会慢一点请耐心等待)"
    for ((i=0;i<=600;i++));do
        if netstat -napt |grep 8123 > /dev/null ;then 
            printf "done\n"
            return 0
        fi
        sleep 1 
        printf "."
    done
    printf "fail\n"
    return 1
}

#检查 IP 合法性
check_ip()
{   
    IP=$1   
    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then   
        FIELD1=$(echo $IP|cut -d. -f1)   
        FIELD2=$(echo $IP|cut -d. -f2)   
        FIELD3=$(echo $IP|cut -d. -f3)   
        FIELD4=$(echo $IP|cut -d. -f4)   
        if [ $FIELD1 -le 255 -a $FIELD2 -le 255 -a $FIELD3 -le 255 -a $FIELD4 -le 255 ]; then   
            return 0 
        else   
            return 1
        fi   
    else   
        return 1 
    fi
}

#通过默认网关的网卡接口获取本机有效的IP地址
get_ipaddress(){
    local device_name=$(netstat -rn | grep -e '^0\.0\.0\.0' | awk '{print $8}' | head -n1)
    ipaddress=$(ifconfig ${device_name} | grep "inet"| grep -v "inet6" | awk '{ print $2}')
    if ! check_ip ${ipaddress} ;then
        ipaddress='你的服务器的IP地址'
    fi
}

# 打印赞赏二维码
print_sponsor(){
    local url='https://qr.alipay.com/fkx16030bqmbsoauc8ezmce'
    echo ''
    echo -e "${yellow} [支付宝]： 如果你觉得本脚本帮到您，可以选择请我喝杯咖啡喔~😊 ${plain}"
    qrencode -t UTF8 "${url}"
}

# Main

## 检查脚本运行环境
if ! id | grep -q 'root' 2>/dev/null ;then
    echo -e "${red}[ERROR]: 请输入 \"sudo -s\" 切换至 root 账户运行本脚本...脚本退出${plain}"
    exit 1
fi

## 检查系统版本
check_sys

## 配置安装选项
### 1. 配置安装源

echo -e "(${title_num}). 是否将系统源切换为中科大(USTC)源（目前支持 Debian Ubuntu Raspbian 三款系统）"
while true; do
    read -p "请输入 y or n（默认 yes):" selected
    case ${selected} in
        ''|yes|y|YES|Y|Yes )
            apt_sources=true
            break;
            ;;
        no|n|NO|N|No)
            apt_sources=false
            break;
            ;;
        *)
            echo "输入错误，请重新输入。"
            ;;
    esac
done
check_massage+=(" # ${title_num}. 是否将系统源切换为中科大(USTC)源: ${yellow}$(if ${apt_sources};then echo "是";else echo "否";fi)${plain}")
let title_num++

### 2. 是否将用户添加至 docker 用户组
echo ''
echo ''
while true;do
    if [[ ${users_num} -ne 1 ]];then
        echo -e "($title_num). 找到该系统中有以下用户名"
        echo -e "如下方列表未显示你的用户名，请切换回你用户账号后输入 sudo usermod -aG docker \$USER 添加用户到 docker 用户组。"
        i=1
        while [[ $i -le ${users_num} ]]; do
            echo -e "    [${i}]: ${users[$((($i-1)))]}"
            let i++
        done
        echo -e "    [s]: 跳过"
        read -p '请输入你需要使用 docker 的用户名序号，以加入 docker 用户组:' selected
        case ${selected} in
            [0-9]*)
                if [[ ${users[$(((${selected}-1)))]} != "" ]]; then
                    echo -e "将${users[$(((${selected}-1)))]}用户添加至 docker 用户组。"
                    add_User_Docker=${users[$(((${selected}-1)))]}
                    break;
                else
                    echo -e "输入数字错误请重新选择。"
                fi
                ;;
            s|S)
                echo -e "跳过添加用户到 docker 用户组。"
                break;
                ;;
            *)
                echo -e "请输入列表中的数字后按回车，如无数字请输入 s 跳过。"
                ;;
        esac
    else
        echo -e "(${title_num}). 在你系统内找到 ${users[0]} 用户，是否将其添加至 docker 用户组。"
        read -p "请输入 yes 或者 no （默认 yes）：" selected
        case ${selected} in
            ''|Yes|YES|yes|y|Y)
                echo -e "将${users[0]}用户添加至 docker 用户组。"
                add_User_Docker=${users[0]}
                break;
                ;;
            No|NO|no|n|N)
                echo -e "跳过添加用户到 docker 用户组。"
                break;
                ;;
            *)
                echo -e "请输入 Yes 或者 No 后按回车确认。"
                ;;
        esac
    fi
done
check_massage+=(" # ${title_num}. 是否将用户添加至 Docker 用户组:   ${yellow}$(if [ -z ${add_User_Docker} ];then echo "否";else echo "是,添加用户为 ${add_User_Docker}";fi) ${plain}")
let title_num++
### 3. 选择是否切换 Docker 国内源
echo ''
echo ''
echo -e "(${title_num}).是否需要替换 docker 默认源？"
while true; do
    read -p '请输入 yes 或者 no（默认：yes）：' selected
    case ${selected} in
        ''|Yes|YES|yes|y|Y)
                CDR=true
                break;
            ;;
        No|NO|no|n|N)
                CDR=false
                break;
            ;;
        *)
                echo -e "输入错误，请重新输入。"
    esac
done
check_massage+=(" # ${title_num}. 是否将 Docker 源切换至国内源:     ${yellow}$(if ${CDR};then echo "是，切换源选择：${chack_massage_text}"; else echo "否";fi)${plain}")
let title_num++

### 4. 选择设备类型，用于选择 hassio 拉取 homeassistant 容器之用。
echo ''
echo ''
while true;do
    echo -e "(${title_num}).请选择你设备类型（默认：${default_machine}）"
    for (( i = 0; i < ${machine_num}; i++ )); do
        echo -e "    [$[${i}+1]]: ${machine_map[$i]}: ${machine_info[$i]}"
    done
    read -p "输入数字 (1-${machine_num}):" selected
    case ${selected} in
        *[0-9]*)
            if [[ ${selected} -le ${machine_num} && ${selected} -gt 0 ]]; then
                machine="${machine_map[((${selected}-1))]}"
                echo -e "你选择了 ${machine}"
                break;
            else
                echo -e "输入错误，请重新输入"
            fi
            ;;
        '')
            machine=${default_machine}
            echo -e "你选择了 ${machine}"
            break;
            ;;
        *)
            echo -e "输入错误，请重新输入"
            ;;
    esac
done
check_massage+=(" # ${title_num}. 您的设备类型为:                   ${yellow}${machine}${plain}")
let title_num++

### 5. 选择 hassio 数据保存路径。
echo ''
echo ''
while true;do
    echo -e "(${title_num}).是否需要设置 hassio 数据保存路径（默认：/usr/share/hassio）"
    read -p "请输入 yes 或 no (默认：no）:" selected
    case ${selected} in
        Yes|YES|yes|y|Y)
            while true; do
                read -p "请输入路径:" data_share_path
                if [[ ! -d ${data_share_path} ]]; then
                    mkdir -p ${data_share_path}
                    if [[ $? -ne 0 ]];then 
                        echo -e "[ERROR] 无法设置改目录为 hassio 数据目录，权限不够。"
                    else
                        echo -e "[INFO] 设置路径 ${data_share_path} 成功。"
                        break;
                    fi
                else
                    break;
                fi
            done
            break;
            ;;
        ''|No|NO|no|n|N)
            echo -e "hassio 数据路径为默认路径: /usr/share/hassio"
            data_share_path="/usr/share/hassio"
            break;
            ;;
        *)
            echo -e "请输入 Yes 或者 No 后按回车确认。"
            ;;
    esac
done
check_massage+=(" # ${title_num}. 您的 hassio 数据路径为:           ${yellow}${data_share_path}${plain}")

echo " ################################################################################"
for (( i = 0; i < ${#check_massage[@]}; i++ )); do echo -e "${check_massage[$i]}"; done 
echo " ################################################################################"
echo "请确认以上信息，继续请按任意键，如需修改请输入 Ctrl+C 结束任务重新执行脚本。"

read selected

## 切换安装源
if  [[ ${apt_sources} == true ]]; then
    echo -e "${yellow}[info]: 切换系统网络源.....${plain}"
    replace_source
else
    echo -e "${yellow}[info]: 跳过切换系统源。${plain}"
fi

## 更新系统至最新
 # echo -e "${yellow}[info]: 更新系统至最新.....${plain}"
 # update_system

## 定义 Ubuntu 和 Debian 依赖
echo -e "${yellow}[info]: 安装 hassio 必要依赖.....${plain}"
apt_install ${Ubunt_Debian_Requirements}

## 安装 Docker 引擎
if ! command -v docker;then
    echo -e "${yellow}[info]: 安装 Docker 引擎.....${plain}"
    if [[ ${systemCodename} == "cosmic" ]]; then
        echo -e "${yellow}[info]: 发现你系统为 Ubuntu 18.10(cosmic) 该系统 docker 官方并不推荐使用，建议安装 Ubuntu 18.04.....${plain}"
        echo -e "${yellow}[info]: 您可以输入任意键继续从源安装兼容 Ubuntu 18.16 的 docker，或选择 Ctrl+C 结束安装。${plain}"
        read 
        ubuntu_18_10_docker_install
    else
        docker_install
    fi
else
    echo -e "${yellow}[info]: 发现系统已安装 docker，跳过 docker 安装${plain}"
fi

## 切换 Docker 源为国内源
if [[ ${CDR} == true ]]; then
    echo -e "${yellow}[info]: 切换 Docker 源为国内源....${plain}"
    change_docker_registry
else
    echo -e "${yellow}[info]: 跳过切换 Docker 源....${plain}"
fi

## 安装 hassio
echo -e "${yellow}[info]: 安装 hassio......${plain}"
hassio_install
get_ipaddress
if wait_homeassistant_run ;then
    echo -e "${green} hassio 安装完成，请输入 http://${ipaddress}:8123 访问你的 HomeAssistant${plain}"
    echo -e "${yellow} 相关问题可以访问https://bbs.iobroker.cn或者加QQ群776817275咨询${plain}"
    print_sponsor
else
    echo "########################### Docker images ###########################"
    docker images
    echo "########################### Docker ps ###########################"
    docker ps -a
    echo "########################### hassio log ###########################"
    docker logs hassio_supervisor
    echo "########################### homeassistant log ###########################"
    docker logs homeassistant
    echo "########################### END ###########################"
    echo -e "${red} homeassistant 启动超时，请检查上方日志....或者重启操作系统${plain}"
    echo -e "${yellow} 相关问题可以访问https://bbs.iobroker.cn或者加QQ群776817275咨询${plain}"
fi
