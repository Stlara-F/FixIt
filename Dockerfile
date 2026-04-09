# 阶段一：构建默认站点（手动安装 Hugo extended，支持多架构）
FROM alpine:3.19 AS builder

# 安装必要工具
RUN apk add --no-cache git curl bash libstdc++ libc6-compat

# 根据目标架构下载 Hugo extended 二进制
ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

# 验证 Hugo 版本
RUN hugo version

# 创建空白站点
RUN hugo new site /build --force

WORKDIR /build

# 克隆 FixIt 主题（整个仓库作为主题目录）
RUN git clone --depth 1 --branch v0.3.6 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 生成基础配置文件（符合 FixIt 主题要求）
RUN cat > config.toml <<EOF
baseURL = "https://example.org/"
title = "My FixIt Site"
theme = "FixIt"
defaultContentLanguage = "zh-cn"
enableRobotsTXT = true
paginate = 10
summaryLength = 70

[markup]
  _merge = "shallow"

[outputs]
  _merge = "shallow"

[taxonomies]
  _merge = "shallow"

[params]
  version = "4.x"
  description = "A site built with Hugo FixIt theme"
  keywords = ["Hugo", "FixIt", "Blog"]
  defaultTheme = "auto"
EOF

# 创建一篇默认示例文章
RUN mkdir -p content/posts && \
    printf '%s\n' '---' 'title: "Welcome to FixIt Docker"' "date: $(date +%Y-%m-%d)" 'draft: false' '---' '' 'This is a default post from the Docker image. You can replace it by mounting your own content.' '' 'Happy blogging!' > content/posts/welcome.md

# 构建静态文件（作为容器启动时的后备内容）
RUN hugo --minify --destination /default-public

# 阶段二：运行时镜像
FROM nginx:stable-alpine

RUN apk add --no-cache bash libstdc++ libc6-compat   # 添加这行

COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo
COPY --from=builder /build /app/default-site
COPY --from=builder /default-public /usr/share/nginx/html

RUN mkdir -p /data/{content,static,layouts,assets,data} /config

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
