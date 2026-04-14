# 阶段一：构建静态站点（amd64 / arm64 / armv7 全支持）
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates golang-go && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64")  HUGO_ARCH="64bit" ;; \
        "arm64")  HUGO_ARCH="ARM64" ;; \
        "arm")    HUGO_ARCH="ARM" ;; \
        *)        echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_Linux-${HUGO_ARCH}.tar.gz" -o /tmp/hugo.tar.gz && \
    tar -xzf /tmp/hugo.tar.gz -C /tmp && \
    mv /tmp/hugo /usr/local/bin/hugo && \
    chmod +x /usr/local/bin/hugo

RUN hugo version

RUN git clone --depth 1 https://github.com/hugo-fixit/hugo-fixit-starter.git /build
WORKDIR /build

RUN hugo --minify --baseURL "/" --destination /public

RUN find /public -type f -name "*.html" -exec sed -i 's|/hugo-fixit-starter/|/|g' {} \;
RUN cp -r /build/static/* /public/ 2>/dev/null || true

RUN for icon in apple-touch-icon.png favicon-32x32.png favicon-16x16.png; do \
    [ -f "/public/$icon" ] || touch "/public/$icon"; \
done

RUN test -f /public/index.html

# 阶段二：运行（跨架构）
FROM nginx:1.29-alpine-slim

RUN apk upgrade --no-cache && \
    apk add --upgrade musl --no-cache

COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
