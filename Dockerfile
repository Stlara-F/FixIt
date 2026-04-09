# 阶段一：构建静态站点（使用 Ubuntu 确保 glibc 环境）
FROM ubuntu:22.04 AS builder

# 安装必要工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 下载并安装 Hugo extended
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

# 验证 Hugo 可执行
RUN hugo version

# 克隆官方 starter 模板（已包含主题和示例内容）
RUN git clone --depth 1 --recurse-submodules https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建静态文件
RUN hugo --minify --destination /public

# 验证 index.html 存在
RUN test -f /public/index.html || (echo "ERROR: index.html not generated" && exit 1)

# 阶段二：运行时（轻量 Nginx）
FROM nginx:stable-alpine

COPY --from=builder /build/public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
