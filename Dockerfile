# 阶段一：构建默认站点（手动安装 Hugo extended，支持多架构）
FROM alpine:3.19 AS builder

# 安装依赖：git, curl, bash, 以及 hugo 需要的运行时库
RUN apk add --no-cache git curl bash libstdc++ libc6-compat

# 根据目标架构下载对应的 Hugo extended 二进制
ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

# 验证安装
RUN hugo version

WORKDIR /build

# 下载 FixIt 主题的 Release 压缩包
ADD https://github.com/hugo-fixit/FixIt/archive/refs/tags/v0.3.6.tar.gz /tmp/

# 解压到 themes/FixIt（自动剥离顶层目录），并复制 exampleSite 内容
RUN mkdir -p /build/themes/FixIt && \
    tar -xzf /tmp/v0.3.6.tar.gz -C /build/themes/FixIt --strip-components=1 && \
    cp -r /build/themes/FixIt/exampleSite/. /build/

# 修正主题配置：确保主题名称正确
RUN sed -i 's|theme = .*|theme = "FixIt"|' config.toml

# 构建默认静态文件
RUN hugo --minify --destination /default-public

# 阶段二：运行时镜像
FROM nginx:stable-alpine

RUN apk add --no-cache bash libstdc++

# 复制 hugo 二进制
COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo

# 复制默认站点的完整源码
COPY --from=builder /build /app/default-site
COPY --from=builder /default-public /usr/share/nginx/html

# 创建用户可挂载的目录
RUN mkdir -p /data/{content,static,layouts,assets,data} /config

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
