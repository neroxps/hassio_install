#!/bin/bash

# 颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
script_version="2021.04.09.0"

function info { echo -e "\e[32m[info] $*\e[39m"; }
function warn  { echo -e "\e[33m[warn] $*\e[39m"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

# 变量
## 安装必备依赖
Ubunt_Debian_Requirements="curl socat jq avahi-daemon net-tools network-manager qrencode apparmor apparmor-utils"

## 获取系统用户用作添加至 docker 用户组
users=($(cat /etc/passwd | awk -F: '$3>=500' | cut -f 1 -d :| grep -v nobody))
users_num=${#users[*]}

title_num=1
check_massage=()
dns_ipaddress=""

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
    elif grep -Eqi "raspbian" /etc/*-release ; then
        kernel_version=$(uname -r | grep -oP '\d+\.\d+\.\d+')
        if version_lt "${kernel_version}" "5.4.79";then
            error "当前 ${kernel_version} 内核系统暂不支持 apparmor 内核模块需要更新内核(≥ 5.4.79)。"
        fi
        release="raspbian"
        systemPackage="apt"
        systemCodename=$(grep "VERSION_CODENAME" /etc/*-release | awk -F '=' '{print $2}')
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
        systemCodename=$(grep "VERSION_CODENAME" /etc/*-release | awk -F '=' '{print $2}')
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
        systemPackage="apt"
        systemCodename=$(grep "VERSION_CODENAME" /etc/*-release | awk -F '=' '{print $2}')
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
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
            curl -# -O ${url}
        else
            wget ${url}
        fi
    else
        if which curl > /dev/null 2>&1 ; then
            curl -# -o ${file_name} ${url}
        else
            wget --output-document=${file_name} ${url}
        fi
    fi
    if [[ $? -ne 0 ]];then
        error "下载 ${url} 失败，请检查网络与其连接是否正常。"
    fi
}

## 切换安装源
replace_source(){
    if [[ -z ${systemCodename} ]]; then
        error "由于无法确定系统版本，故请手动切换系统源，切换方法参考清华源使用方法：http://mirrors.ustc.edu.cn/help/"
    fi
    [[ ! -f /etc/apt/sources.list.bak ]] && warn "备份系统源文件为 /etc/apt/sources.list.bak" && mv /etc/apt/sources.list /etc/apt/sources.list.bak

    # 清华源

    case $(uname -m) in
        "x86_64" | "i686" | "i386" )
            # debian from x86_64
            if [[ ${release} == "debian" ]]; then
                {
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename} main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename}-updates main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename}-backports main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security ${systemCodename}/updates main contrib non-free"
                } > /etc/apt/sources.list
            fi

            # Ubuntu from x86_64
            if [[ ${release} == "ubuntu" ]]; then
                {
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${systemCodename} main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${systemCodename}-updates main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${systemCodename}-backports main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${systemCodename}-security main restricted universe multiverse"
                } > /etc/apt/sources.list
            fi
            ;;
        "arm" | "armv7l" | "armv6l" | "aarch64" | "armhf" | "arm64" | "ppc64el")
            if [[ -f /etc/apt/sources.list.d/armbian.list ]] ;then
                warn "发现 armbian 源，替换清华源，如需要恢复请自行到 /etc/apt/sources.list.d/ 文件夹中删除后缀名 \".bak\""
                cp /etc/apt/sources.list.d/armbian.list /etc/apt/sources.list.d/armbian.list.bak
                sed -i 's|http[s]*://apt.armbian.com|http://mirrors.tuna.tsinghua.edu.cn/armbian|g' /etc/apt/sources.list.d/armbian.list
            fi

            # debian from ARM
            if [[ ${release} == "debian" ]]; then
                {
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename} main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename}-updates main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ ${systemCodename}-backports main contrib non-free"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security ${systemCodename}/updates main contrib non-free"
                } > /etc/apt/sources.list
            fi

            # Ubuntu from ARM
            if [[ ${release} == "ubuntu" ]]; then
                {
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ ${systemCodename} main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ ${systemCodename}-updates main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ ${systemCodename}-backports main restricted universe multiverse"
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ ${systemCodename}-security main restricted universe multiverse"
                } > /etc/apt/sources.list
            fi

            if [[  ${release} == "raspbian" ]]; then
                {
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ ${systemCodename} main non-free contrib rpi"
                    echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ ${systemCodename} main non-free contrib rpi"
                } > /etc/apt/sources.list
                if [[ -f "/etc/apt/sources.list.d/raspi.list" ]]; then
                    echo "deb http://mirrors.tuna.tsinghua.edu.cn/raspberrypi/ ${systemCodename} main" > "/etc/apt/sources.list.d/raspi.list"
                fi
            fi
            ;;
        *)  error "[ERROR]: 由于无法获取系统架构，故此无法切换系统源，请跳过系统源切换。"
            ;;
    esac

    apt update
    if [[ $? -ne 0 ]]; then
        mv /etc/apt/sources.list.bak /etc/apt/sources.list
        error "[ERROR]: 系统源切换错误，请检查网络连接是否正常，脚本退出"
    fi
}

## 更新系统
update_system(){
    if [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]] || [[ ${release} == "raspbian" ]]; then
        apt upgrade -y
        if [[ $? != 0 ]]; then
            error "[ERROR]: 系统更新失败，脚本退出。"
        fi
        info "系统更新成功。"
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
    download_file 'https://get.docker.com' 'get-docker.sh'
    sed -i 's/DEFAULT_CHANNEL_VALUE="test"/DEFAULT_CHANNEL_VALUE="stable"/' get-docker.sh
    chmod u+x get-docker.sh
    ./get-docker.sh --mirror Aliyun
    if ! systemctl status docker > /dev/null 2>&1 ;then
        error "Docker 安装失败，请检查上方安装错误信息。 你也可以选择通过搜索引擎，搜索你系统安装docker的方法，安装后重新执行脚本。"
    else
        info "Docker 安装成功。"
    fi
    if [[ ! -z ${add_User_Docker} ]];then
        warn "添加用户 ${add_User_Docker} 到 Docker 用户组"
        usermod -aG docker ${add_User_Docker}
    fi
}

## apt 安装依赖方法
apt_install(){
    apt update
    apt install -y ${*}
    if [[ $? -ne 0 ]];then
        error "安装${*}失败，请将检查上方安装错误信息。"
    fi
}


## 修改 docker 源
change_docker_registry(){
    if [ ! -d /etc/docker ];then
        mkdir -p /etc/docker
    fi
cat << EOF > /etc/docker/daemon.json 
{ 
    "log-driver": "journald",
    "storage-driver": "overlay2",
    "registry-mirrors": [ 
    "https://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
    ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker > /dev/null
    info "切换国内源完成"
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
            error "获取 hassio 版本号失败，请检查你系统网络与 https://version.home-assistant.io 的连接是否正常。"
        fi
        let i--
    done
    hassio_version=$(echo ${stable_json} |jq -r '.supervisor')
    homeassistant_version=$(echo ${stable_json} |jq -r '.homeassistant.default')
    if [ -z ${hassio_version} ] || [ -z ${homeassistant_version} ];then
        error "获取 hassio 版本号失败，请检查你网络与 https://version.home-assistant.io 连接是否畅通。"
    fi
    local x=1
    while true ; do
        [[ $x -eq 10 ]] && error "获取 hassio 官方一键脚本失败，请检查你系统网络与 https://code.aliyun.com/ 的连接是否正常。"
        warn "下载 hassio_install.sh 官方脚本 第${x}次"
        download_file 'https://code.aliyun.com/neroxps/supervised-installer/raw/master/installer.sh' 'hassio_install.sh'
        grep -q '#!/usr/bin/env bash' hassio_install.sh && break
        ((x++))
    done
    chmod u+x hassio_install.sh
    sed -i "s/HASSIO_VERSION=.*/HASSIO_VERSION=${hassio_version}/g" ./hassio_install.sh
    # 替换链接到阿里云加速
    sed -i 's@https://raw.githubusercontent.com/home-assistant/supervised-installer/master/@https://code.aliyun.com/neroxps/supervised-installer/raw/master/@g' ./hassio_install.sh
    # interfaces 不替换ip设置
    sed -i 's@read answer < /dev/tty@answer=n@' ./hassio_install.sh
    # 清除警告等待
    sed -i 's/sleep 10//' ./hassio_install.sh
    # 等待 NetworkManager 重启完毕
    reset_network_line_num=$(grep -n 'systemctl restart "${SERVICE_NM}"' ./hassio_install.sh | awk -F ':' '{print $1}')
    add_shell='i=20\ninfo "Wait for networkmanages to start."\nwhile ! systemctl status ${SERVICE_NM} >/dev/null 2>&1; do\n    sleep 1\nlet i--\n    [[ i -eq 0 ]] && warn "networkmanages failed to start" && break\ndone'
    sed -i "${reset_network_line_num} a${add_shell}" ./hassio_install.sh

    warn "从 hub.docker.com 下载 homeassistant/${machine}-homeassistant:${homeassistant_version}......"
    local i=10
    while true ;do
        docker pull homeassistant/${machine}-homeassistant:${homeassistant_version}
        if [[ $? -eq 0 ]]; then
            docker tag homeassistant/${machine}-homeassistant:${homeassistant_version} homeassistant/${machine}-homeassistant:latest
            break;
        else
            warn "[WARNING]: 从 docker hub 下载 homeassistant/${machine}-homeassistant:${homeassistant_version} 失败，第 ${i} 次重试."
            if [[ ${i} -eq 0 ]]; then
               error "从 docker 下载 homeassistant/${machine}-homeassistant:${homeassistant_version} 失败，请检查上方失败信息。"
            fi
        fi
        let i--
    done
    warn "开始 hassio 安装流程。(如出现 [Warning] 请忽略，无须理会)"
    ./hassio_install.sh -m ${machine} --data-share ${data_share_path}
    
    if ! systemctl status hassio-supervisor > /dev/null ; then
        error "安装 hassio 失败，请将上方安装信息发送到论坛询问。脚本退出..."
    fi
}

ubuntu_docker_install(){
    apt install docker.io -y
}

error(){
    echo -e "${red}"
    echo "################# 发到论坛时，请把上方日志也一并粘贴发送 ################"
    echo "########################### Script Version: ${script_version}###########################"
    echo "########################### System version ###########################"
    lsb_release -a 2>/dev/null
    echo "########################### System version 2 ###########################"
    cat /proc/version
    echo "########################### System info ###########################"
    uname -a
    echo "########################### END ###########################"
    echo "${1}"
    echo -e "${plain}"
    warn " 相关问题可以访问https://bbs.iobroker.cn/t/topic/1404或者加QQ群776817275咨询"
    exit 1
}

wait_homeassistant_run(){
    info "等待 homeassistant 启动(由于 hassio 启动需要从 github pull addons 的库，所以启动速度视 pull 速度而定。)"
    while true; do
        if docker ps| grep -q hassio_supervisor; then
            docker logs -f hassio_supervisor &
            logs_pid=$!
            break;
        fi
    done
    supervisor_log_file=$(docker inspect --format='{{.LogPath}}' hassio_supervisor)
    for ((i=0;i<=3000;i++));do
        if netstat -napt |grep 8123 > /dev/null ;then 
            kill ${logs_pid}
            return 0
        fi
        sleep 1 
    done
    kill ${logs_pid}
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
    warn " [支付宝]： 如果你觉得本脚本帮到您，可以选择请我喝杯咖啡喔~😊 "
    qrencode -t UTF8 "${url}"
}

#更新 github hosts 文件到 coreDNS 的 hosts 文件里加速 addons clone 速度
## hosts 文件来自 github.com/jianboy/github-host 项目
github_set_hosts_to_coreDNS(){
    info "开始 github hosts 流程"
    local hosts_path="${data_share_path}/dns/hosts"
    local github_host_url='https://cdn.jsdelivr.net/gh/jianboy/github-host/hosts'
    local github_hosts

    # 获取最新的 github 地址
    githubHosts_get_hosts(){
        local i=0
        while [[ -z ${github_hosts} ]];do
            github_hosts=$(curl -sL ${github_host_url})
            ((i=i+1))
            if [[ i -gt 10 ]]; then
                warn "尝试 10 次依然无法从 ${github_host_url} 下载 hosts,请检查网络连通性."
                warn "跳过 github hosts 设置."
                return 1
            fi
        done
        info "github hosts 下载完成."
    }

    # 写入 hosts 文件
    write_hosts(){
        # 等待 coreDNS 的 hosts 文件生成后再写入
        info "等待 coreDNS 的 hosts 文件生成后写入 github hosts"
        while true;do
            if [[ -f ${hosts_path} ]] && [[ $(wc -l ${hosts_path} 2>/dev/null | awk '{print $1}') -gt 0  ]]; then
                info "写入 github ip 到 hosts 文件."
                sleep 3
                echo "${github_hosts}" >> ${hosts_path}
                break;
            fi
            sleep 1
        done
        info "github hosts 写入完毕."
    }
    githubHosts_get_hosts && write_hosts
}

# 修改 hassio_dns 上游 DNS 设置为本地路由服务器
setting_hassio_dns_option_dns_server(){
    info "开始设置 hassio_dns 上游 DNS 服务器"
    while true ; do
        if ha dns info > /dev/null 2>&1; then
            sleep 3
            info "hassio_dns 已启动,正应用 dns 设置"
            ha dns option --servers "dns://${dns_ipaddress}"
            ha dns restart
            break;
        fi
        sleep 1
    done
}

# 检查出国旅游连通性
check_proxy_status(){
    info "正在通过访问 www.youtube.com 检查旅游环境"
    if ! wget -q --connect-timeout 20 --tries 1 --retry-connrefused  https://www.youtube.com -O /tmp/youtube ;then
        warn "旅游失败,请检查出国旅游环境."
        return 1
    fi
    return 0
}

# Main

## 检查脚本运行环境
if ! id | grep -q 'root' 2>/dev/null ;then
    error "请输入 \"sudo -s\" 切换至 root 账户运行本脚本...脚本退出"
fi

## 检查环境变量
if ! echo $PATH | grep sbin > /dev/null 2>&1 ;then
    error "请使用 sudo -s 切换 root 账号,或者 sudo ./install.sh 运行脚本, su 环境变量不符合脚本要求."
fi

## 检查是否运行于 systemd 环境
if ! ps --no-headers -o comm 1 | grep systemd > /dev/null 2>&1 ;then
    error "你的系统不是运行在 systemd 环境下,本脚本不支持此系统!(如 android 之类的虚拟 Linux)"
fi

## 检查系统版本
check_sys

## 配置安装选项
### 1.警告信息
echo -e "(${title_num}). 你是否有“出国旅游”环境,如果没有建议停止使用 supervisor(hassio)"
echo -e "    由于 supervisor 内的 addons 全部基于 github 存储,而 addons 镜像仓库地址全部改为 ghcr.io"
echo -e "    ghcr.io 是 github 推出的容器镜像存储服务,目前国内还没有加速器,所以你安装 addons 将会很慢很慢"
while true; do
    read -p "请输入 y or n（默认 no):" selected
    case ${selected} in
        yes|y|YES|Y|Yes )
            while true; do
                read -p "请输入你“出国旅游”路由器的IP地址,作为 hassio_dns 上游 IP:" dns_ipaddress
                if check_ip "${dns_ipaddress}" && check_proxy_status ;then
                    echo -e "你输入IP地址为 ${dns_ipaddress}"
                    break;
                else
                    warn "你的出国旅游环境不正常,请检查或者更换IP地址."
                fi
            done
            break;
            ;;
        ''|no|n|NO|N|No)
            error "用户选择退出脚本."
            ;;
        *)
            echo "输入错误，请重新输入。"
            ;;
    esac
done
check_massage+=(" # ${title_num}. 是否有“出国旅游”环境:             ${yellow}是${plain}")
let title_num++

## 2. 配置安装源

echo -e "(${title_num}). 是否将系统源切换为清华源（目前支持 Debian Ubuntu Raspbian 三款系统）"
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
check_massage+=(" # ${title_num}. 是否将系统源切换为清华源:         ${yellow}$(if ${apt_sources};then echo "是";else echo "否";fi)${plain}")
let title_num++

### 3. 选择是否更新系统软件到最新
echo ''
echo ''
echo -e "(${title_num}).是否更新系统软件到最新？"
warn "如果系统依赖版本低于 supervisor 要求,会导致 supervisor 显示系统不健康,最终导致无法安装 addons."
while true; do
    read -p '请输入 yes 或者 no（默认：no）：' selected
    case ${selected} in
        Yes|YES|yes|y|Y)
                is_upgrade_system=true
                break;
            ;;
        ''|No|NO|no|n|N)
                is_upgrade_system=false
                break;
            ;;
        *)
                echo -e "输入错误，请重新输入。"
    esac
done
check_massage+=(" # ${title_num}. 是否更新系统软件到最新:           ${yellow}$(if ${is_upgrade_system};then echo "是，更新系统：${chack_massage_text}"; else echo "否";fi)${plain}")
let title_num++

### 4. 是否将用户添加至 docker 用户组
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
### 5. 选择是否切换 Docker 国内源
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

### 6. 选择设备类型，用于选择 hassio 拉取 homeassistant 容器之用。
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

### 7. 选择 hassio 数据保存路径。
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
let title_num++

### 8. 选择是否加入 github hosts 到 coreDNS。
echo ''
echo ''
while true;do
    echo -e "(${title_num}).是否将 github hosts 写入 coreDNS"
    echo -e "或许有效加快 hassio 第一次启动时 clone addons 速度"
    echo -e "hosts 文件来自 https://github.com/jianboy/github-host 项目"
    read -p "请输入 yes 或 no (默认：yes）:" selected
    case ${selected} in
        ''|Yes|YES|yes|y|Y)
            set_github_hosts_to_coreDNS=true
            break;
            ;;
        No|NO|no|n|N)
            set_github_hosts_to_coreDNS=false
            break;
            ;;
        *)
            echo -e "请输入 Yes 或者 No 后按回车确认。"
            ;;
    esac
done
check_massage+=(" # ${title_num}. 是否将 github hosts 写入 coreDNS: ${yellow}$(if ${set_github_hosts_to_coreDNS};then echo "是"; else echo "否";fi)${plain}")

echo " ################################################################################"
for (( i = 0; i < ${#check_massage[@]}; i++ )); do echo -e "${check_massage[$i]}"; done 
echo " ################################################################################"
echo "请确认以上信息，继续请按任意键，如需修改请输入 Ctrl+C 结束任务重新执行脚本。"

read selected

## 切换安装源
if  [[ ${apt_sources} == true ]]; then
    info "切换系统网络源....."
    replace_source
else
    info "跳过切换系统源。"
fi

## 更新系统至最新
if [[ ${is_upgrade_system} == true ]]; then
    info "更新系统至最新....."
    update_system
fi

## 定义 Ubuntu 和 Debian 依赖
info "安装 hassio 必要依赖....."
apt_install ${Ubunt_Debian_Requirements}

## 安装 Docker 引擎
if ! command -v docker;then
    info "安装 Docker 引擎....."
    if [[ ${release} == "ubuntu" ]]; then
        ubuntu_docker_install
    else
        docker_install
    fi
else
    info "发现系统已安装 docker，跳过 docker 安装"
fi

## 切换 Docker 源为国内源
if [[ ${CDR} == true ]]; then
    info "切换 Docker 源为国内源...."
    change_docker_registry
else
    info "跳过切换 Docker 源...."
fi
get_ipaddress
## 安装 hassio
info "安装 hassio......"
hassio_install
if [[ ${set_github_hosts_to_coreDNS} == true ]]; then
    github_set_hosts_to_coreDNS &
fi

if wait_homeassistant_run ;then
    setting_hassio_dns_option_dns_server
    info "hassio 安装完成，请输入 http://${ipaddress}:8123 访问你的 HomeAssistant"
    warn " 相关问题可以访问https://bbs.iobroker.cn或者加QQ群776817275咨询"
    print_sponsor
else
    error "等待 hassio 启动超时!"
fi
