# hassio_install

hassio 一键安装脚本，实现以下功能。

1. 自动更改系统源为中科大源。（目前支持 Debian Ubuntu Raspbian 三款系统）
2. 自动安装 Docker，可以选择切换 Docker 源为国内源，提高容器下载速度。
3. 避开 Hassio 因亚马逊连接超时导致无法拉取最新版本的 Homeassistant 容器。

## 目前支持的系统

- [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) 
- [Ubuntu](https://www.ubuntu.com/download/server) 测试版本 18LTS通过，但按道理 16 以上都可以。
- [Debian](https://www.debian.org/distrib/netinst) 测试版本 9.5 通过。

## 使用方法

以 root 身份运行以下命令。

```bash
curl -sL -o hassio_install.sh https://raw.githubusercontent.com/neroxps/hassio_install/master/install.sh
chmod a+x hassio_install.sh
./hassio_install.sh
```

### 如果安装的是 64 位系统，脚本会自动筛选适配 64 位的设备列表

```
(1). 是否将系统源切换为中科大(USTC)源（目前支持 Debian Ubuntu Raspbian 三款系统）
请输入 y or n（默认 yes):y


(2). 在你系统内找到 nero 用户，是否将其添加至 docker 用户组。
请输入 yes 或者 no （默认 yes）：y
将nero用户添加至 docker 用户组。


(3).是否需要替换 docker 默认源？
请输入 yes 或者 no（默认：yes）：y


(4).请选择你设备类型（默认：qemux86-64）
    [1]: raspberrypi3-64
    [2]: qemuarm-64
    [3]: qemux86-64
输入数字 (1-3):
你选择了 qemux86-64
 ################################################################################
 # 1. 是否将系统源切换为中科大(USTC)源: 是
 # 2. 是否将用户添加至 Docker 用户组:   是,添加用户为 nero 
 # 3. 是否将 Docker 源切换至国内源:     是
 # 4. 您的设备类型为:                   qemux86-64
 ################################################################################
请确认以上信息，继续请按任意键，如需修改请输入 Ctrl+C 结束任务重新执行脚本。
```

### 如果安装的是 32 位系统，脚本会自动筛选适配32位的设备列表

```
(1). 是否将系统源切换为中科大(USTC)源（目前支持 Debian Ubuntu Raspbian 三款系统）
请输入 y or n（默认 yes):y


(2). 在你系统内找到 nero 用户，是否将其添加至 docker 用户组。
请输入 yes 或者 no （默认 yes）：y
将nero用户添加至 docker 用户组。


(3).是否需要替换 docker 默认源？
请输入 yes 或者 no（默认：yes）：y


(4).请选择你设备类型（默认：qemux86）
    [1]: raspberrypi
    [2]: raspberrypi2
    [3]: raspberrypi3
    [4]: qemuarm
    [5]: qemux86
    [6]: intel-nuc
输入数字 (1-6):
你选择了 qemux86
 ################################################################################
 # 1. 是否将系统源切换为中科大(USTC)源: 是
 # 2. 是否将用户添加至 Docker 用户组:   是,添加用户为 nero 
 # 3. 是否将 Docker 源切换至国内源:     是
 # 4. 您的设备类型为:                   qemux86
 ################################################################################
请确认以上信息，继续请按任意键，如需修改请输入 Ctrl+C 结束任务重新执行脚本。
```

### 设备类型选型说明

 - raspberrypi : 树莓派1代
 - raspberrypi2 : 树莓派2代
 - raspberrypi3 : 树莓派3代（或3B+）
 - raspberrypi3-64  : 树莓派3代（或3B+）
 - qemuarm : 其余未知的am设备（例如斐讯N1)
 - qemuarm-64 : 其余未知的am设备（例如斐讯N1)
 - qemux86-64 : X86-64位系统通用（普通的PC机电脑）
 - qemux86 : X86-64位系统通用（普通的PC机电脑）
 - intel-nuc : 英特尔的nuc小主机