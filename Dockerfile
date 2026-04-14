# 阶段一：仅在 amd64 构建静态文件（使用 Hugo Extended，完美兼容 FixIt）
FROM --platform=linux/amd64 ubuntu:22.04 AS builder

# 安装依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates golang-go && \
    rm -rf /var/lib/apt/lists/*

# 下载官方 Hugo Extended (amd64 专用，FixIt 强制要求)
RUN curl -fSL "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-64bit.tar.gz" -o /tmp/hugo.tar.gz && \
    tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/hugo

# 下载站点源码
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建静态站点（Extended 版，无任何模板报错）
RUN hugo --minify --baseURL "/" --destination /public

# 修复路径
RUN find /public -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;
RUN cp -r /build/static/* /public/ 2>/dev/null || true

# 创建图标占位
RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
    [ -f "/public/$icon" ] || touch "/public/$icon"; \
done

# 阶段二：全架构 Nginx（静态文件无架构限制，直接运行）
FROM nginx:1.29-alpine-slim

# 安全升级
RUN apk upgrade --no-cache

# 复制构建好的静态文件（全架构通用）
COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
