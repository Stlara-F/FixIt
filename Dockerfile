# 阶段一：构建器（安装 Hugo 并生成默认站点）
FROM alpine:3.19 AS builder

RUN apk add --no-cache git curl bash libstdc++ libc6-compat

ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

RUN hugo version

# 创建空白站点并进入
RUN hugo new site /build --force
WORKDIR /build

# 克隆 FixIt 主题（使用 v0.4.5，该版本稳定且包含完整布局）
RUN git clone --depth 1 --branch v0.4.5 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 生成配置文件（启用主题所需的所有合并选项）
RUN cat > config.toml <<EOF
baseURL = "https://example.org/"
title = "My FixIt Site"
theme = "FixIt"
defaultContentLanguage = "zh-cn"
enableRobotsTXT = true
paginate = 10

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

# 创建一篇示例文章
RUN mkdir -p content/posts && \
    printf '%s\n' '---' 'title: "Welcome to FixIt Docker"' "date: $(date +%Y-%m-%d)" 'draft: false' '---' '' 'This is a default post from the Docker image. You can replace it by mounting your own content.' '' 'Happy blogging!' > content/posts/welcome.md

# 构建静态网站
RUN hugo --minify --destination /default-public

# 验证生成的文件是否存在（调试用）
RUN ls -la /default-public && test -f /default-public/index.html

# 阶段二：运行时（Nginx + Hugo）
FROM nginx:stable-alpine

RUN apk add --no-cache bash libstdc++ libc6-compat

COPY --from=builder /usr/local/bin/hugo /usr/local/bin/hugo
COPY --from=builder /build /app/default-site
COPY --from=builder /default-public /usr/share/nginx/html

# 再次验证运行时目录
RUN ls -la /usr/share/nginx/html && test -f /usr/share/nginx/html/index.html

RUN mkdir -p /data/{content,static,layouts,assets,data} /config

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
