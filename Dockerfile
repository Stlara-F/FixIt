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

# 克隆 starter 模板（包含主题和静态资源）
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建静态文件，baseURL 设为根路径
RUN hugo --minify --baseURL "/" --destination /public

# 修正所有 HTML 中残留的 /hugo-fixit-starter/ 子路径
RUN find /public -type f -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;

# 复制缺失的图标文件（从源 static 目录复制到 public 根目录）
RUN cp /build/static/apple-touch-icon.png /public/ 2>/dev/null || true
RUN cp /build/static/favicon-32x32.png /public/ 2>/dev/null || true
RUN cp /build/static/favicon-16x16.png /public/ 2>/dev/null || true
RUN cp /build/static/favicon.ico /public/ 2>/dev/null || true
RUN cp /build/static/safari-pinned-tab.svg /public/ 2>/dev/null || true
RUN cp /build/static/site.webmanifest /public/ 2>/dev/null || true

# 验证首页存在
RUN test -f /public/index.html

# 阶段二：Nginx 服务
FROM nginx:stable-alpine
COPY --from=builder /public /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
