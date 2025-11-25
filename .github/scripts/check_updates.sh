#!/bin/bash
set -e
# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 计算文件的 SHA256 哈希值
calculate_sha256() {
    local file_path=$1
    sha256sum "$file_path" | cut -d' ' -f1
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    log "下载文件: $url"
    curl -L -o "$output" "$url"
}

# 更新 linglong.yaml 文件
update_yaml_file() {
    local repo=$1
    local new_url=$2
    local new_digest=$3
    
    log "更新文件: $file_name"
    log "新 URL: $new_url"
    log "新 Digest: $new_digest"
    set -x
    # 替换url
    sed -i "s#url:.*$repo.*#url: $new_url#" linglong.yaml
    # 替换digest
    sed -i "\#url:.*$repo#{n;s/.*/    digest: $new_digest/}" linglong.yaml
}

update_yaml_version() {
    local new_version=$1
    local t=$(date +%m%d)
    log "更新版本号: $new_version"
    sed -i "s|  version:.*|  version: $new_version.$t|" linglong.yaml
}

GITHUB_OUTPUT=${GITHUB_OUTPUT:-/tmp/output.txt}
main(){
    local repo=$1
    download_url=`curl https://api.github.com/repos/$repo/releases/latest | jq -r ".assets.[].browser_download_url" | grep "AppImage$"`
    log "download url: $download_url"

    local has_changes=false
    if ! grep -q $download_url linglong.yaml; then
        has_changes=true
        # 下载文件
        tmp_dir=$(mktemp -d)
        temp_file="$tmp_dir/file"
        log "下载文件"
        download_file "$download_url" "$temp_file"
        # 计算哈希值
        local new_digest=$(calculate_sha256 "$temp_file")
        log "计算得到的 SHA256: $new_digest"
        # 使用代理下载（与 linglong.yaml 中一致）
        local proxy_url="https://gh-proxy.org/$download_url"
        log "更新linglong.yaml"
        update_yaml_file $repo $proxy_url $new_digest
        # 更新版本号
        version=`curl https://api.github.com/repos/$repo/releases/latest | jq -r '.tag_name' | grep -o '[0-9]*\.[0-9]*\.[0-9]*'`
        update_yaml_version $version
    fi
    if [ "$has_changes" = true ]; then
        log "检测到更新，文件已修改"
        echo "has_changes=true" >> "$GITHUB_OUTPUT"
    else
        log "没有检测到更新"
        echo "has_changes=false" >> "$GITHUB_OUTPUT"
    fi
}
# 运行主函数
main "$@"