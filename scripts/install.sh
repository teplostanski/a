#!/bin/sh
set -e

REPO="teplostanski/nosudopass"
APP="nosudopass"
INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="/tmp/nosudopass_install_$$"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM

# Создаем временную директорию
mkdir -p "${TMP_DIR}"

if [ "${1}" = "--global" ]; then
    INSTALL_DIR="/usr/local/bin"
fi

ARCH=$(uname -m)
case "${ARCH}" in
    x86_64)   GOARCH="amd64" ;;
    aarch64)  GOARCH="arm64" ;;
    arm64)    GOARCH="arm64" ;;
    *)
        echo "❌ Unsupported architecture: ${ARCH}"
        cleanup
        exit 1
        ;;
esac

# Проверяем наличие curl
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl is required but not installed"
    cleanup
    exit 1
fi

echo "📥 Fetching latest release URL for ${GOARCH}..."
URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep "browser_download_url.*linux_${GOARCH}\\.tar\\.gz" \
    | cut -d '"' -f 4)

if [ -z "${URL}" ]; then
    echo "❌ Binary for linux_${GOARCH} not found"
    exit 1
fi

echo "⬇️ Downloading..."
if ! curl -L "${URL}" -o "${TMP_DIR}/${APP}_linux_${GOARCH}.tar.gz"; then
    echo "❌ Download failed"
    exit 1
fi

echo "📦 Extracting..."
if ! tar -xzf "${TMP_DIR}/${APP}_linux_${GOARCH}.tar.gz" -C "${TMP_DIR}"; then
    echo "❌ Extraction failed"
    exit 1
fi

echo "🚚 Installing to ${INSTALL_DIR}"
chmod +x "${TMP_DIR}/${APP}"

# Если глобальная установка — используем sudo, если нужно
if [ "${INSTALL_DIR}" = "/usr/local/bin" ]; then
    if [ ! -w "${INSTALL_DIR}" ]; then
        echo "🔑 Requires root privileges to write to ${INSTALL_DIR}"
        sudo mv "${TMP_DIR}/${APP}" "${INSTALL_DIR}/${APP}"
    else
        mv "${TMP_DIR}/${APP}" "${INSTALL_DIR}/${APP}"
    fi
else
    mkdir -p "${INSTALL_DIR}"
    mv "${TMP_DIR}/${APP}" "${INSTALL_DIR}/${APP}"
fi

echo "✅ Installed to ${INSTALL_DIR}/${APP}"
