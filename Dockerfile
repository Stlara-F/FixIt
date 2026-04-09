# 阶段一：构建默认站点（使用官方示例站点 + FixIt 主题）
FROM peaceiris/hugo-extended:0.156.0 AS builder

# 安装 git（主题需要）
RUN apk add --no-cache git

WORKDIR /build

# 克隆 FixIt 主题（使用稳定版本标签，可改为具体 commit）
RUN git clone --depth 1 --branch v0.3.6 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 复制官方示例站点（不含主题，因为我们要用上面克隆的）
RUN git clone --depth 1 https://github.com/hugo-fixit/FixIt.git tmp_fixit && \
    cp -r tmp_fixit/exampleSite/* . && \
    rm -rf tmp_fixit

# 修正示例站点的主题配置（确保指向 themes/FixIt）
RUN sed -i 's|theme = .*|theme = "FixIt"|' config.toml

# 构建默认静态文件（作为后备）
RUN hugo --minify --destination /default-public

# 阶段二：运行时镜像（包含 hugo 二进制和源码，支持动态生成）
FROM nginx:stable-alpine

# 安装 bash 和 C++ 运行时（hugo 依赖）
RUN apk add --no-cache bash libstdc++

# 复制 hugo 二进制
COPY --from=builder /usr/bin/hugo /usr/local/bin/hugo

# 复制默认站点的完整源码（用于运行时重新生成）
COPY --from=builder /build /app/default-site
# 复制默认生成的静态文件（作为后备）
COPY --from=builder /default-public /usr/share/nginx/html

# 创建用户可挂载的目录
RUN mkdir -p /data/{content,static,layouts,assets,data} /config

# 复制入口脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
