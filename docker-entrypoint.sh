#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 FixIt Docker Entrypoint${NC}"

if [ -d "/site" ] && [ -n "$(ls -A /site 2>/dev/null)" ]; then
    SITE_DIR="/site"
    echo -e "${YELLOW}📂 Using user-provided full site from /site${NC}"
else
    SITE_DIR="/app/default-site"
    echo -e "${YELLOW}📂 Using default site, merging custom data from /data/*${NC}"

    merge_dir() {
        local src=$1
        local dst=$2
        if [ -d "$src" ] && [ -n "$(ls -A $src 2>/dev/null)" ]; then
            echo "   Merging $src -> $dst"
            cp -rf $src/. $dst/
        fi
    }

    merge_dir /data/content    $SITE_DIR/content
    merge_dir /data/static     $SITE_DIR/static
    merge_dir /data/layouts    $SITE_DIR/layouts
    merge_dir /data/assets     $SITE_DIR/assets
    merge_dir /data/data       $SITE_DIR/data

    if [ -f /config/config.toml ]; then
        echo "   Using custom config.toml from /config"
        cp /config/config.toml $SITE_DIR/config.toml
    fi
fi

echo -e "${GREEN}⚙️  Generating static site...${NC}"
cd $SITE_DIR

if [ -n "$BASE_URL" ]; then
    hugo --minify --baseURL "$BASE_URL" --destination /usr/share/nginx/html
else
    hugo --minify --destination /usr/share/nginx/html
fi

echo -e "${GREEN}✅ Static site generated, starting Nginx...${NC}"
nginx -g "daemon off;"
