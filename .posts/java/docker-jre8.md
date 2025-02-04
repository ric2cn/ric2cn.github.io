# 功能

1. 基于 openjdk 编辑一个可运行 jre8 的镜像。（保证镜像体积最小）
2. 容器启动时，自动启动 jar 包。约定容器内 /usr/java/workpath/ 路径作为 jar 的路径，并且支持多个 jar 的情况。 jar 可以直接放在 /usr/java/workpath/ 也可以在 /usr/java/workpath/\*/ 。*更新* ：这种方式不够灵活，改为使用脚本指定 jar 路径进行启动操作。
3. 支持带参数的启动 jar。约定在 jar 统计路径下放置一个 jvm.args 文件，读取里面第一行作为启动参数。如果没有这个 jvm.args 文件，则使用一个默认值，不要报错。

# 操作步骤

## 准备文件

### 安装 docker。
(略，win10、linux、mac 都可)
### 创建一个工作路径
    mkdir ~/jre8Docker/
### 编辑一个启动脚本
  ~/jre8Docker/boot.sh

```bash
#!/bin/sh

echo "start up."
date

# 执行jar
#  如果路径下有 jvm.args 文件，则读取里面的参数
#  如果没有 jvm.args 文件，则使用默认参数： -server
runjar()
{
    run_file=$1
    run_path=$(dirname $run_file)
    jvmArgs="-server"
    if [ -f "$run_path/jvm.args" ]; then
        jvmArgs=$(head -n 1 $run_path/jvm.args)
    fi
    echo "run: $1, args: $jvmArgs"
	# 这里必须先 cd 到路径，不然 springboot 读取配置文件有问题
    cd "$run_path"
    java $jvmArgs -jar $run_file >> $run_path/vmlog 2>&1 &
}

# 遍历 /usr/workpath/ 下的 jar
count1=`ls /usr/java/workpath/*.jar 2>/dev/null| wc -w`
if [ $count1 -eq 1 ]
then
    for jarfile1 in `ls /usr/java/workpath/*.jar`
        do
            runjar $jarfile1
    done
fi

# 遍历 /usr/java/workpath/*/ 下的 jar
count2=`ls ls /usr/java/workpath/*/*.jar 2>/dev/null| wc -w`
if [ $count2 -gt 0 ]
then
    for jarfile2 in `ls /usr/java/workpath/*/*.jar`
        do
            runjar $jarfile2
    done
fi

echo "start up done."
```

*更新*
有时候不需要启动全部 jar，而且有的 jar （比如 nacos）自带启动脚本，因此上面这个脚本就不合适了。
改成调用 /usr/java/workpath/startup.sh，且文件不存在时自动生成一个。

```bash
#!/bin/bash

echo "================================================================================="
echo "boot start."
date

startup_file="/usr/java/workpath/on_boot.sh"
if [ ! -f $startup_file ]; then
  echo "$startup_file not exists. do initial."
  echo "#!/bin/bash"                                                     > $startup_file
  echo "set -e"                                                         >> $startup_file
  echo ""                                                               >> $startup_file
  echo "# 执行jar"                                                      >> $startup_file
  echo "#  如果路径下有 jvm.args 文件，则读取里面的参数"                >> $startup_file
  echo "#  如果没有 jvm.args 文件，则使用默认参数： -server"            >> $startup_file
  echo "runjar()"                                                       >> $startup_file
  echo "{"                                                              >> $startup_file
  echo "    run_file=\$1"                                               >> $startup_file
  echo "    run_path=\$(dirname \$run_file)"                            >> $startup_file
  echo "    jvmArgs=\"-server\""                                        >> $startup_file
  echo "    if [ -f \"\$run_path/jvm.args\" ]; then"                    >> $startup_file
  echo "        jvmArgs=\$(head -n 1 \$run_path/jvm.args)"              >> $startup_file
  echo "    fi"                                                         >> $startup_file
  echo "    echo \"run: \$1, args: \$jvmArgs\""                         >> $startup_file
  echo "	# 这里必须先 cd 到路径，不然 springboot 读取配置文件有问题" >> $startup_file
  echo "    cd /usr/java/workpath/"                                     >> $startup_file
  echo "    cd \$run_path"                                              >> $startup_file
  echo "    java \$jvmArgs -jar \$run_file >> \$run_path/vmlog 2>&1 &"  >> $startup_file
  echo "}"                                                              >> $startup_file
  echo ""                                                               >> $startup_file
  echo "cd /usr/java/workpath/"                                         >> $startup_file
  echo ""                                                               >> $startup_file
  echo "# 示例"                                                         >> $startup_file
  echo "# runjar \"/usr/java/workpath/sample.jar\""                     >> $startup_file
  echo ""                                                               >> $startup_file
  echo "# 保持容器不退出（放到最后一行）"                               >> $startup_file
  echo "tail -n 0 -f \$0"                                               >> $startup_file
  echo "empty command, exit"
  exit 0
fi

# 授予执行权限
if [ ! -x $startup_file ]; then
  echo "give +x to $startup_file"
  chmod +x $startup_file
fi

sh $startup_file
```


### 创建 Dockerfile
  ~/jre8Docker/Dockerfile

```
# FROM 表示基于这个镜像进行创建，下面这个镜像是适用于 jar 的最小镜像
FROM openjdk:8-jre-slim

# 指定工作路径
WORKDIR /tmp

# 把启动脚本放进容器
COPY ./boot.sh /usr/boot.sh

# 构建镜像时运行以下脚本，授予权限
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
 chmod +x /usr/boot.sh

# 声明守护端口
EXPOSE 8080
 
# docker 容器启动时运行的命令，这个脚本会将指定路径（含子路径）的 jar 包全部启动
# 遇到一个问题，docker 的机制 0 号进程退出会导致整个容器终端，因此加一个 tail -f 防止退出
CMD bash /usr/boot.sh

# 打标签
LABEL org.opencontainers.image.authors="lalinking"
```

### Build 创建镜像

```bash
cd ~/jre8Docker/
# -f : 指定 Dockerfile 路径
# -t ：指定 name:tag
docker build -f ./Dockerfile -t jar_runner:open-jre8 .
```

### 使用镜像创建并运行容器

```bash
# -m : 限制内存不超过256m （测试过低于 256m jar 可能起不来）
# -p : 映射端口 宿主端口:容器端口
# -v : 映射路径 宿主路径:容器路径
# --name : 容器名字
# 参数一个横杠 表示用的缩写，两个横杠 表示不是缩写
docker run -p 2001:80 -m 256m -v ~/docker/volume/eureka:/usr/java/workpath --name eureka_01 -d jar_runner:open-jre8
```