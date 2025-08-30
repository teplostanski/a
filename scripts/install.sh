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

echo "📥 Fetching latest release info for ${GOARCH}..."

# Получаем информацию о релизе
RELEASE_JSON=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")

# Извлекаем версию из тега
VERSION=$(echo "${RELEASE_JSON}" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')

if [ -z "${VERSION}" ]; then
    echo "❌ Could not determine latest version"
    exit 1
fi

# Формируем правильное имя файла с версией
BINARY_FILE="${APP}_${VERSION}_linux_${GOARCH}.tar.gz"
CHECKSUMS_FILE="${APP}_${VERSION}_checksums.txt"

# Находим URL для бинарника
URL=$(echo "${RELEASE_JSON}" \
    | grep "browser_download_url.*${BINARY_FILE}\"" \
    | cut -d '"' -f 4)

if [ -z "${URL}" ]; then
    echo "❌ Binary ${BINARY_FILE} not found"
    exit 1
fi

# Находим URL для чексумм
CHECKSUMS_URL=$(echo "${RELEASE_JSON}" \
    | grep "browser_download_url.*checksums\\.txt\"" \
    | cut -d '"' -f 4)

echo "⬇️ Downloading..."
if ! curl -L "${URL}" -o "${TMP_DIR}/${BINARY_FILE}"; then
    echo "❌ Download failed"
    exit 1
fi

# Скачиваем и проверяем чексуммы если доступны
if [ -n "${CHECKSUMS_URL}" ] && command -v sha256sum >/dev/null 2>&1; then
    echo "🔍 Downloading and verifying checksums..."
    
    if curl -L "${CHECKSUMS_URL}" -o "${TMP_DIR}/checksums.txt" 2>/dev/null; then
        EXPECTED_CHECKSUM=$(grep "${BINARY_FILE}" "${TMP_DIR}/checksums.txt" 2>/dev/null | cut -d' ' -f1)
        
        if [ -n "${EXPECTED_CHECKSUM}" ]; then
            ACTUAL_CHECKSUM=$(sha256sum "${TMP_DIR}/${BINARY_FILE}" | cut -d' ' -f1)
            
            if [ "${ACTUAL_CHECKSUM}" = "${EXPECTED_CHECKSUM}" ]; then
                echo "✅ Checksum verified"
                echo "   Expected: ${EXPECTED_CHECKSUM}"
                echo "   Actual:   ${ACTUAL_CHECKSUM}"
            else
                echo "❌ Checksum verification failed!"
                echo "   Expected: ${EXPECTED_CHECKSUM}"
                echo "   Actual:   ${ACTUAL_CHECKSUM}"
                exit 1
            fi
        else
            echo "⚠️ Checksum for ${BINARY_FILE} not found in checksums file"
        fi
    else
        echo "⚠️ Could not download checksums file"
    fi
elif [ -z "${CHECKSUMS_URL}" ]; then
    echo "⚠️ Checksums file not available"
elif ! command -v sha256sum >/dev/null 2>&1; then
    echo "⚠️ sha256sum not found, skipping checksum verification"
fi

echo "📦 Extracting..."
if ! tar -xzf "${TMP_DIR}/${BINARY_FILE}" -C "${TMP_DIR}"; then
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
