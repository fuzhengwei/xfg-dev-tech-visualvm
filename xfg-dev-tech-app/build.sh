# 普通镜像构建，随系统版本构建 amd/arm
docker build -t fuzhengwei/xfg-dev-tech-visuallvm-app:2.0 -f ./Dockerfile .

# 兼容 amd、arm 构建镜像
# docker buildx build --load --platform linux/amd64,linux/arm64 -t fuzhengwei/xfg-dev-tech-visuallvm-app:1.2 -f ./Dockerfile .