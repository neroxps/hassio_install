#/bin/bash
version=$1
if [[ -z ${version} ]]; then
    echo '请输入需要切换的 homeassistant 版本号'
    exit 1
fi

# 检查 hassio 运行状态
if ! docker ps --format {{.Names}} | grep hassio_supervisor -q ; then
    echo "未在运行容器列表中找到 hassio_supervisor"
    docker ps
    exit 1
fi
if ! docker ps --format {{.Names}} | grep homeassistant -q ; then
    echo "未在运行容器列表中找到 homeassistant"
    docker ps
    exit 1
fi

# 获取配置文件目录
config_path=$(jq -r '.data' /etc/hassio.json || echo '未找到hassio.json 停止版本切换脚本' && exit 1)
homeassistant_config_path="${config_path}/homeassistant"
homeassistant_config_backup_path="${homeassistant_config_path}-bak"

# 获取版本号列表并进行校验
echo "正在校验输入版本号是否正确....."
images_tags="$(wget -q https://registry.hub.docker.com/v1/repositories/homeassistant/qemux86-64-homeassistant/tags -O -  | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $3}')"
if ! echo "${images_tags}" | grep -q ${version};then
    echo "输入的版本号错误，请输入正确的版本号,脚本退出."
    exit 1
else
    echo "输入的版本号正确，开始切换流程...."
fi

# 设置脚本退出时执行的函数
function exit_fun(){
    # 恢复备份配置文件夹
    if [[ -d ${homeassistant_config_backup_path} ]]; then

        # 把自动生成的配置文件夹移动到tmp由系统自动清理
        if [[ -d ${homeassistant_config_path} ]]; then
            mv "${homeassistant_config_path}" "/tmp/homeassistant-bak2"
        fi

        echo "恢复备份配置文件夹...."
        mv ${homeassistant_config_backup_path} ${homeassistant_config_path}
    fi
    # 结束 hassio 日志显示进程
    if [[ ! -z ${logger_runing_pid} ]]; then
        kill ${logger_runing_pid}
    fi
}
trap exit_fun EXIT

# 显示警告
echo "############################ 警告 ################################"
echo "由于 hassio 带有保护机制"
echo "如当前的配置文件与切换的版本不符会导致 homeassistant 启动失败"
echo "hassio 会自动安装回之前升/降级版本，从而导致版本切换失败"
echo "故此，脚本会先备份您当前的配置文件为 ${homeassistant_config_backup_path}"
echo "脚本会在退出的时候恢复目录结构"
echo "降级后出现 hassio 404 的无解，请更新到最新版本。"
echo '##################################################################'
echo ''
while true;do
    echo -e "是否清楚以上说明："
    read -p "请输入 yes 或 no (默认：no）:" selected
    case ${selected} in
        Yes|YES|yes|y|Y)
            mv "${homeassistant_config_path}" "${homeassistant_config_backup_path}"
            break;
            ;;
        ''|No|NO|no|n|N)
            echo -e "脚本退出...."
            exit 1
            ;;
        *)
            echo -e "请输入 Yes 或者 No 后按回车确认。"
            ;;
    esac
done

echo "获取 HASSIO_TOKEN"
HASSIO_TOKEN=$(docker exec -t homeassistant bash -c 'echo $HASSIO_TOKEN' | tr -d '\r')
echo "正在执行版本切换到 ${version} 请稍等片刻......"

# 显示 hassio 日志
docker logs --tail 10 -f hassio_supervisor &
logger_runing_pid=$(echo $!)

docker exec -t -e version=${version} -e HASSIO_TOKEN=${HASSIO_TOKEN} hassio_supervisor bash -c 'curl -X POST  -H "X-HASSIO-KEY:$HASSIO_TOKEN" -d "{\"version\":\"$version\"}" http://hassio/homeassistant/update'
echo ''

# 还原配置流程
echo '还原配置目录后重启 homeassistant....'
mv ${homeassistant_config_backup_path} ${homeassistant_config_path}
docker restart homeassistant
printf "等待 homeassistant 启动"
for ((i=0;i<=300;i++));do
    if netstat -napt |grep 8123 > /dev/null ;then 
        printf "done\n"
        echo "homeassistant 启动完成，版本切换成功"
        echo "查看 homeassistant 日志命令： docker logs -f homeassistant"
        echo "查看 hassio_supervisor 日志命令: docker logs -f hassio_supervisor"
        echo "重启 homeassistant 命令：docker restart homeassistant"
        echo "不看日志或者不把日志发出来的，请不要在论坛上发帖求助。"
        exit
    fi
    sleep 1
    printf "."
done
printf "fail\n"
echo "启动失败，请根据日志报错信息修改配置文件以兼容当前版本"
echo "查看 homeassistant 日志命令： docker logs -f homeassistant"
echo "查看 hassio_supervisor 日志命令: docker logs -f hassio_supervisor"
echo "重启 homeassistant 命令：docker restart homeassistant"
echo "不看日志或者不把日志发出来的，请不要在论坛上发帖求助。"
exit