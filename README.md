# hassio_install

hassio 一键安装脚本，实现以下功能。

1. 自动更改系统源为中科大源。（目前支持 Debian Ubuntu Raspbian 三款系统）
2. 自动安装 Docker，可以选择切换 Docker 源为国内源，提高容器下载速度。（注意：Ubuntu 18.10 get.docker.com 官方暂不支持安装docker）
3. 避开 Hassio 因亚马逊连接超时导致无法拉取最新版本的 Homeassistant 容器。

## 目前支持的系统

- [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) 
- [Ubuntu](https://www.ubuntu.com/download/server) 测试版本 18LTS通过，但按道理 16 以上都可以。
- [Debian](https://www.debian.org/distrib/netinst) 测试版本 >=9.5 通过。

## 使用方法

以 root 身份运行以下命令。

```bash
wget https://code.aliyun.com/neroxps/hassio_install/raw/master/install.sh
chmod a+x install.sh
./install.sh
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
- intel-nuc ：英特尔的nuc小主机
- odroid-c2 ：韩国odroid-c2
- odroid-xu ：韩国odroid-xu
- orangepi-prime ：香橙派
- qemuarm ：通用arm设备（例如斐讯N1)
- qemuarm-64 ：通用arm设备（例如斐讯N1) 64位系统
- qemux86 ：通用X86 64位系统（普通的PC机电脑）
- qemux86-64 ：通用X86（普通的PC机电脑）64位系统
- raspberrypi ：树莓派一代
- raspberrypi2 ：树莓派二代
- raspberrypi3 ：树莓派三代
- raspberrypi4 ：树莓派四代
- raspberrypi3-64 ：树莓派三代64位系统
- raspberrypi4-64 ：树莓派四代64位系统
- tinker ：华硕tinker

# Hassio 升级脚本

由于网络原因，hassio_supervisor 经常如下报告:

```bash
18-08-15 03:57:02 WARNING (MainThread) [hassio.updater] Can't fetch versions from https://s3.amazonaws.com/hassio-version/stable.json
```

无法从亚马逊刷新最新版的 json 文件，导致 hassio 升级失败，我制作了 hassio 升级脚本，可以使用脚本手动升级。

## 使用方法

请使用 root 权限运行以下命令。

```bash
wget https://code.aliyun.com/neroxps/hassio_install/raw/master/hassio_upgrade.sh
chmod u+x hassio_upgrade.sh
./hassio_upgrade.sh
```

## 操作说明

### 停止（但重启依然会自启动） 
systemctl stop hassio-supervisor.service

### 重启 
systemctl restart hassio-supervisor.service

### 禁用自启动
`systemctl disable hassio-supervisor.service`

### 启用自启动 
`systemctl enable hassio-supervisor.service`

### 查询当前启动状态 
`systemctl status hassio-supervisor.service`

### 查询当前是否自启动
`systemctl  is-enabled hassio-supervisor.service`

### 查询 hassio 日志 
`docker logs -f hassio_supervisor`

### 查询 hassio 日志最新20行信息 
`docker logs -f hassio_supervisor --tail 20`

### 查询 ha 日志 
`docker logs -f homeassistant`

### 查询 ha 日志最新20行信息 
`docker logs -f homeassistant --tail 20`

> systemctl 说明 ： [https://linux.cn/article-5926-1.html](https://linux.cn/article-5926-1.html)
> docker logs 命令用法：[https://docs.docker.com/engine/reference/commandline/logs](https://docs.docker.com/engine/reference/commandline/logs)

# Homeassistant 版本切换脚本

此脚本可在宿主中切换homeassistant版本号

## 严重警告
1. 切换版本的 home-assistant 请先备份好配置文件，虽然脚本会自动备份，但最好自己再备份一次，出现丢失配置情况恕不负责。
2. 切换旧版本启动失败的，请查看 home-assistant 的日志来修复错误配置
3. 切换过旧的版本会导致 hassio 加载 404，目前已知 0.77 以前版本都无法正常加载 hassio
4. 启动失败可以到论坛带日志发帖求助，无日志发帖我将会扣分处理

## 使用方法

使用 root 运行一下命令

```
wget https://code.aliyun.com/neroxps/hassio_install/raw/master/homeassistant_ver_switch.sh
chmod u+x homeassistant_ver_switch.sh
./homeassistant_ver_switch.sh 0.92.2
```
