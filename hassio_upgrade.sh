#!/bin/bash

# Author : neroxps
# Email : neroxps@gmail.com
# Version : 1.0
# Date : 2018-08-15
echo '检查 hassio_supervisor 最新版本....'
arg=$1
local_hassio_version=$(docker inspect hassio_supervisor | jq -r '.[0].Config.Labels["io.hass.version"]')
remote_hassio_version=$(curl -Ls https://raw.githubusercontent.com/neroxps/qemux86-64-homeassistant/master/stable.json | jq -r '.supervisor')
image_name=$(docker inspect hassio_supervisor | jq -r '.[0].Config.Image')

whit_ha(){
	printf '等待 homeassistant 启动'
	local whit_num=10
	while [[ ${whit_num} -gt 0 ]] ; do
		printf '.'
		docker ps -f name=homeassistant | grep homeassistant > /dev/null
		if [[ $? -eq 0 ]]; then
			printf 'done.'
			return 0
		fi
		let whit_num--
		sleep 5
	done
	return 1
}

if [[ -f /etc/hassio.json ]]; then
	date_path=$(cat /etc/hassio.json | jq --raw-output '.data // "/usr/share/hassio"')
else
	date_path="/usr/share/hassio"
fi

if [[ ${remote_hassio_version} -gt ${local_hassio_version} ]]; then
	echo "发现新版本 hassio-supervisor ${remote_hassio_version}，执行升级操作。"
	if [[ ${arg} != "-q" ]]; then
		read -p '按任意键执行升级:'
	fi
	systemctl stop hassio-supervisor.service
	docker stop homeassistant
	docker rm -f homeassistant
	docker rm -f hassio_supervisor
	docker pull ${image_name}:${remote_hassio_version}
	docker tag ${image_name}:${remote_hassio_version} ${image_name}:latest
	docker rmi ${image_name}:${local_hassio_version}
	cat ${date_path}/updater.json | jq --arg version ${remote_hassio_version} '.hassio=$version' > ${date_path}/updater.json
	systemctl start hassio-supervisor.service
	sleep 5
	restart_num=0
	while [[ ${reset_num} -le 5 ]] ; do
		let restart_num++
		echo "第${restart_num}次尝试启动 homeassistant。"
		docker restart hassio_supervisor
		if whit_ha;then
			break;
		fi
	done
	if [[ ${restart_num} -eq 5 ]]; then
		docker logs hassio_supervisor
		echo "homeassistant 启动失败，请将上方日志发送至论坛询问。"
		exit 1
	fi
	echo "hassio_supervisor 升级完毕，如出现 addons 异常，最好重启服务器以刷新 HASSIO_TOKEN."
else
	echo '你的 hassio_supervisor 是最新的。'
fi
