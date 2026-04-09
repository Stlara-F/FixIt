# 阶段一：构建默认站点（手动安装 Hugo extended，支持多架构）
FROM alpine:3.19 AS builder

# 安装必要工具
RUN apk add --no-cache git curl bash libstdc++ libc6-compat

# 根据目标架构下载 Hugo extended 二进制
ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

# 验证 Hugo 版本
RUN hugo version

WORKDIR /build

# 克隆完整的 FixIt 仓库（包含主题源码和 apps/demo）
RUN git clone --depth 1 --branch v0.3.6 https://github.com/hugo-fixit/FixIt.git repo

# 复制示例站点到当前工作目录
RUN cp -r repo/apps/demo/* .

# 将主题源码复制到 themes/FixIt 目录（覆盖可能存在的空目录）
RUN mkdir -p themes/FixIt && \
    cp -r repo/layouts repo/assets repo/i18n repo/data repo/archetypes repo/static repo/theme.toml themes/FixIt/

# 修正 demo 站点配置：确保主题名称正确，并设置 baseURL
RUN sed -i 's|^theme = .*|theme = "FixIt"|' hugo.toml && \
    sed -i 's|^baseURL = .*|baseURL = "https://example.org/"|' hugo.toml

# 可选：为 demo 添加一篇额外的欢迎文章（如果 content 为空）
RUN if [ ! -d content/posts ] || [ -z "$(ls -A content/posts 2>/dev/null)" ]; then \
        mkdir -p content/posts && \
        cat > content/posts/welcome.md <<EOF
---
title: "Welcome to FixIt Docker"
date: $(date +%Y-%m-%d)
draft: false
---

This is a default post from the Docker image. You can replace it by mounting your own content.

Happy blogging!
EOF \
    ; fi

# 构建静态文件（作为容器启动时的后备内容）
RUN hugo --minify --destination /default-public

# ========== 阶段二：运行时镜像 ==========
FROM nginx:stable-alpine

RUN apk add --no-cache bash libstdc++

# 复制 Hugo 二进制
COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo

# 复制站点的完整源码（用于运行时动态重建）
COPY --from=builder /build /app/default-site
# 复制预构建的静态文件（作为 Nginx 默认内容）
COPY --from=builder /default-public /usr/share/nginx/html

# 创建可挂载的数据目录
RUN mkdir -p /data/{content,static,layouts,assets,data} /config

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
