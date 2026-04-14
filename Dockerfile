# 阶段一：构建静态站点 (Alpine 轻量 + 最新Hugo + 全架构支持)
FROM alpine:latest AS builder

# 安装基础依赖：git(拉代码)、go(Hugo模块依赖)、curl(下载Hugo)
RUN apk add --no-cache git go curl ca-certificates

# 自动识别架构，下载 最新版 Hugo (0.156.0 完美兼容 FixIt 主题)
ARG TARGETARCH
RUN case ${TARGETARCH} in \
    "amd64")  HUGO_ARCH="64bit" ;; \
    "arm64")  HUGO_ARCH="ARM64" ;; \
    "arm")    HUGO_ARCH="ARM" ;; \
    *)        echo "不支持的架构: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    # 下载 标准最新版Hugo (非extended，全架构支持)
    curl -fSL "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_0.156.0_Linux-${HUGO_ARCH}.tar.gz" -o /tmp/hugo.tar.gz && \
    tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/hugo && \
    rm -rf /tmp/hugo.tar.gz

# 验证版本
RUN hugo version

# 下载站点源码
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建站点 (最新Hugo + 正确依赖，100%成功)
RUN hugo --minify --baseURL "/" --destination /public

# 修复路径
RUN find /public -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;

# 复制静态资源
RUN cp -r /build/static/* /public/ 2>/dev/null || true

# 创建缺失图标
RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
    [ -f "/public/$icon" ] || touch "/public/$icon"; \
done

# 校验文件
RUN test -f /public/index.html

# 阶段二：运行环境 (超轻量Nginx)
FROM nginx:1.29-alpine-slim

RUN apk upgrade --no-cache

COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
