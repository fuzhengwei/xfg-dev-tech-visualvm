# 基础镜像 openjdk:8-jre-slim openjdk:8-jdk-alpine 8-jdk-alpine
FROM openjdk:8-jdk

# 作者
MAINTAINER xiaofuge

# 配置
ENV PARAMS=""

# 时区
ENV TZ=PRC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 添加应用
ADD target/xfg-dev-tech-visuallvm-app.jar /xfg-dev-tech-visuallvm-app.jar

## 在镜像运行为容器后执行的命令
ENTRYPOINT ["sh","-c","java -jar $JAVA_OPTS /xfg-dev-tech-visuallvm-app.jar $PARAMS"]