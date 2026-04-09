# 阶段一：构建静态站点
FROM alpine:3.19 AS builder

RUN apk add --no-cache git curl bash

ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

RUN hugo version

# 创建空白站点
RUN hugo new site /build --force
WORKDIR /build

# 克隆 FixIt 主题（使用 v0.4.5）
RUN git clone --depth 1 --branch v0.4.5 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 复制预先准备好的配置文件
COPY config.toml .

# 创建首页（必须）
RUN cat > content/_index.md <<EOF
---
title: "Home"
---
Welcome to my FixIt site.
EOF

# 创建一篇示例文章
RUN mkdir -p content/posts && \
    printf '%s\n' '---' 'title: "Welcome to FixIt Docker"' "date: $(date +%Y-%m-%d)" 'draft: false' '---' '' 'This is a default post. You can replace it by mounting your own content.' > content/posts/welcome.md

# 构建静态文件
RUN hugo --minify --destination /public

# 验证 index.html 存在（关键）
RUN test -f /public/index.html || (echo "index.html not generated" && exit 1)

# 阶段二：提供静态文件的 Nginx
FROM nginx:stable-alpine

COPY --from=builder /build/public /usr/share/nginx/html

# 可选：复制一个简单的启动脚本，用于支持未来可能的动态合并（暂不需要复杂逻辑）
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
