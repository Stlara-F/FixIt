# 阶段一：构建站点（Alpine 自动支持 amd64/arm64/armv7，无需手动下载 Hugo）
FROM alpine:latest AS builder

# 直接安装 hugo + git，自动适配所有架构
RUN apk add --no-cache hugo git

# 下载源码
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建静态文件
RUN hugo --minify --baseURL "/" --destination /public

# 修复路径
RUN find /public -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;

# 复制静态资源
RUN cp -r /build/static/* /public/ 2>/dev/null || true

# 创建缺失图标
RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
    [ -f "/public/$icon" ] || touch "/public/$icon"; \
done

# 验证
RUN test -f /public/index.html

# 阶段二：运行（超小跨架构 Nginx）
FROM nginx:1.29-alpine-slim

RUN apk upgrade --no-cache

COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
