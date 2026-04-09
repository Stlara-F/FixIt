# 阶段一：构建静态站点
FROM alpine:3.19 AS builder

# 1. 安装基础工具和 glibc 兼容层（必须放在最前面）
RUN apk add --no-cache git curl bash libc6-compat

# 2. 下载并安装 hugo
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

# 3. 验证 hugo 可执行（现在应该能运行）
RUN hugo version

# 4. 创建空白站点
RUN hugo new site /build --force
WORKDIR /build

# 5. 克隆 FixIt 主题
RUN git clone --depth 1 --branch v0.4.5 https://github.com/hugo-fixit/FixIt.git themes/FixIt

# 6. 生成配置文件
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

# 7. 创建首页
RUN cat > content/_index.md <<EOF
---
title: "Home"
---
Welcome to my FixIt site.
EOF

# 8. 创建示例文章
RUN mkdir -p content/posts && \
    printf '%s\n' '---' 'title: "Welcome to FixIt Docker"' "date: $(date +%Y-%m-%d)" 'draft: false' '---' '' 'This is a default post. You can replace it by mounting your own content.' > content/posts/welcome.md

# 9. 构建静态文件
RUN hugo --minify --destination /public

# 10. 验证 index.html 存在
RUN test -f /public/index.html || (echo "ERROR: index.html not generated" && exit 1)

# 阶段二：运行 Nginx
FROM nginx:stable-alpine

COPY --from=builder /build/public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
