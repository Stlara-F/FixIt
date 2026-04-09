#!/bin/bash
set -e

# 辅助函数：如果目标目录为空，则从源目录填充默认内容
populate_if_empty() {
    local src="$1"
    local dst="$2"
    if [ -d "$dst" ] && [ -z "$(ls -A "$dst" 2>/dev/null)" ]; then
        echo "  → Populating $dst with default content from $src"
        cp -r "$src"/. "$dst"/
    fi
}

# 辅助函数：合并目录内容（源覆盖目标）
merge_dir() {
    local src="$1"
    local dst="$2"
    if [ -d "$src" ] && [ -n "$(ls -A "$src" 2>/dev/null)" ]; then
        echo "  → Merging $src into $dst"
        mkdir -p "$dst"
        cp -rf "$src"/. "$dst"/
    fi
}

echo "🚀 Starting FixIt container..."

# --- 策略1：如果用户挂载了完整的站点目录到 /data/site，则直接使用它 ---
if [ -d "/data/site" ] && [ -n "$(ls -A /data/site 2>/dev/null)" ]; then
    echo "  → Using user-provided full site from /data/site"
    # 清空默认站点，复制用户完整站点
    rm -rf /app/site
    cp -r /data/site /app/site
else
    # --- 策略2：使用默认站点，并支持细分目录覆盖（向后兼容）---
    # 初始化站点目录（如果 /app/site 为空，则从默认示例站点填充）
    populate_if_empty /app/site-default /app/site

    # 应用用户挂载的配置文件（/config/config.toml）
    if [ -f /config/config.toml ]; then
        echo "  → Applying custom config.toml"
        cp /config/config.toml /app/site/config.toml
    fi

    # 合并用户提供的内容/布局/静态资源等（细分覆盖）
    merge_dir /data/content   /app/site/content
    merge_dir /data/layouts   /app/site/layouts
    merge_dir /data/static    /app/site/static
    merge_dir /data/assets    /app/site/assets
    merge_dir /data/data      /app/site/data
    merge_dir /data/i18n      /app/site/i18n
    merge_dir /data/themes    /app/themes   # 允许用户完全替换主题
fi

# 生成静态站点
echo "🔨 Generating static site with Hugo..."
cd /app/site
hugo --minify --destination /usr/share/nginx/html

# 启动 Nginx
echo "🌐 Starting Nginx..."
nginx -g "daemon off;"
