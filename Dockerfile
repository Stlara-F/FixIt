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

# 克隆 starter 模板
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 关键：覆盖 baseURL 为根路径，避免子目录前缀
RUN hugo --minify --baseURL "/" --destination /public

# 验证首页存在
RUN test -f /public/index.html

# 阶段二：Nginx 服务
FROM nginx:stable-alpine
COPY --from=builder /build/public /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
