# 阶段一：构建静态站点（Alpine 全能版，自动适配 amd64/arm64/armv7）
FROM alpine:latest AS builder

# 🔥 修复：安装 hugo + git + go（解决模块依赖缺失问题）
RUN apk add --no-cache hugo git go

# 下载站点源码
RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

# 构建静态文件（Go 环境已就绪，100%成功）
RUN hugo --minify --baseURL "/" --destination /public

# 修复路径问题
RUN find /public -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;

# 复制静态资源
RUN cp -r /build/static/* /public/ 2>/dev/null || true

# 创建缺失图标，避免404
RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
    [ -f "/public/$icon" ] || touch "/public/$icon"; \
done

# 校验构建结果
RUN test -f /public/index.html

# 阶段二：生产运行（超轻量 Nginx，全架构兼容）
FROM nginx:1.29-alpine-slim

# 安全更新
RUN apk upgrade --no-cache

# 复制构建好的静态文件
COPY --from=builder /public /usr/share/nginx/html

# 暴露端口
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
