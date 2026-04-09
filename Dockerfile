# 阶段一：构建默认站点（手动安装 Hugo extended）
FROM alpine:3.19 AS builder

# 安装依赖：git, curl, bash, 以及 hugo 需要的运行时库
RUN apk add --no-cache git curl bash libstdc++ libc6-compat

# 下载指定版本的 Hugo extended（从 GitHub releases）
ARG HUGO_VERSION=0.156.0
RUN curl -L "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz" | tar -xz -C /usr/local/bin

# 验证安装
RUN hugo version

WORKDIR /build

# 克隆 FixIt 主题（使用稳定版本标签 v0.3.6）
RUN git clone --depth 1 --branch v0.3.6 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 复制官方示例站点
RUN git clone --depth 1 https://github.com/hugo-fixit/FixIt.git tmp_fixit && \
    cp -r tmp_fixit/exampleSite/* . && \
    rm -rf tmp_fixit

# 修正主题配置
RUN sed -i 's|theme = .*|theme = "FixIt"|' config.toml

# 构建默认静态文件
RUN hugo --minify --destination /default-public

# 阶段二：运行时镜像
FROM nginx:stable-alpine

RUN apk add --no-cache bash libstdc++

# 复制 hugo 二进制（从 builder 阶段）
COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo

# 复制默认站点的完整源码
COPY --from=builder /build /app/default-site
COPY --from=builder /default-public /usr/share/nginx/html

RUN mkdir -p /data/{content,static,layouts,assets,data} /config

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
