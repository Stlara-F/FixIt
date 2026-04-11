# 阶段一：构建静态站点
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates golang-go && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" -o /tmp/hugo.tar.gz && \
    tar -xzf /tmp/hugo.tar.gz -C /tmp && \
    mv /tmp/hugo /usr/local/bin/hugo && \
    chmod +x /usr/local/bin/hugo

RUN hugo version

RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

RUN hugo --minify --baseURL "/" --destination /public

# 修复 HTML 中的子路径残留
RUN find /public -type f -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;

# 复制所有静态资源（包括缺失的图标）
RUN cp -r /build/static/* /public/ 2>/dev/null || true

# 如果仍缺少特定图标，创建简单占位（避免 404）
RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
        if [ ! -f "/public/$icon" ]; then \
            echo "Creating placeholder $icon"; \
            convert -size 32x32 xc:transparent /public/$icon 2>/dev/null || \
            touch /public/$icon; \
        fi; \
    done

# 验证首页存在
RUN test -f /public/index.html

FROM nginx:1.28-alpine-slim
RUN /bin/sh -c apk upgrade --no-cache # buildkit
COPY /public /usr/share/nginx/html # buildkit
EXPOSE [80/tcp]
CMD ["nginx" "-g" "daemon off;"]
