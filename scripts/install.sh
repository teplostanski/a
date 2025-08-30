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

# Проверяем аргументы
SKIP_CHECKSUM=0
for arg in "$@"; do
    case "${arg}" in
        --global)
            INSTALL_DIR="/usr/local/bin"
            ;;
        --skip-checksum)
            SKIP_CHECKSUM=1
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --global         Install to /usr/local/bin (requires root)"
            echo "  --skip-checksum  Skip checksum verification"
            echo "  --help           Show this help"
            exit 0
            ;;
    esac
done

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

# Проверяем наличие необходимых команд
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl is required but not installed"
    cleanup
    exit 1
fi

if [ "${SKIP_CHECKSUM}" = "0" ] && ! command -v sha256sum >/dev/null 2>&1; then
    echo "⚠️ sha256sum not found, skipping checksum verification"
    echo "   Use --skip-checksum to suppress this warning"
    SKIP_CHECKSUM=1
fi

echo "📥 Fetching latest release info for ${GOARCH}..."

# Получаем информацию о релизе
RELEASE_JSON=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")

# Находим URL для бинарника
BINARY_URL=$(echo "${RELEASE_JSON}" \
    | grep "browser_download_url.*linux_${GOARCH}\\.tar\\.gz\"" \
    | cut -d '"' -f 4)

if [ -z "${BINARY_URL}" ]; then
    echo "❌ Binary for linux_${GOARCH} not found"
    exit 1
fi

# Находим URL для чексумм, если проверка не пропущена
CHECKSUMS_URL=""
if [ "${SKIP_CHECKSUM}" = "0" ]; then
    CHECKSUMS_URL=$(echo "${RELEASE_JSON}" \
        | grep "browser_download_url.*checksums\\.txt\"" \
        | cut -d '"' -f 4)
    
    if [ -z "${CHECKSUMS_URL}" ]; then
        echo "⚠️ Checksums file not found, skipping verification"
        SKIP_CHECKSUM=1
    fi
fi

BINARY_FILE="${APP}_linux_${GOARCH}.tar.gz"

echo "⬇️ Downloading binary..."
if ! curl -L "${BINARY_URL}" -o "${TMP_DIR}/${BINARY_FILE}"; then
    echo "❌ Binary download failed"
    exit 1
fi

# Скачиваем и проверяем чексуммы
if [ "${SKIP_CHECKSUM}" = "0" ]; then
    echo "⬇️ Downloading checksums..."
    if ! curl -L "${CHECKSUMS_URL}" -o "${TMP_DIR}/checksums.txt"; then
        echo "⚠️ Checksums download failed, skipping verification"
        SKIP_CHECKSUM=1
    fi
fi

if [ "${SKIP_CHECKSUM}" = "0" ]; then
    echo "🔍 Verifying checksum..."
    
    # Ищем чексумму для нашего файла
    EXPECTED_CHECKSUM=$(grep "${BINARY_FILE}" "${TMP_DIR}/checksums.txt" | cut -d' ' -f1)
    
    if [ -z "${EXPECTED_CHECKSUM}" ]; then
        echo "⚠️ Checksum for ${BINARY_FILE} not found in checksums file"
        echo "   Continuing without verification..."
    else
        # Вычисляем актуальную чексумму
        ACTUAL_CHECKSUM=$(sha256sum "${TMP_DIR}/${BINARY_FILE}" | cut -d' ' -f1)
        
        if [ "${ACTUAL_CHECKSUM}" = "${EXPECTED_CHECKSUM}" ]; then
            echo "✅ Checksum verified successfully"
        else
            echo "❌ Checksum verification failed!"
            echo "   Expected: ${EXPECTED_CHECKSUM}"
            echo "   Actual:   ${ACTUAL_CHECKSUM}"
            echo ""
            echo "This could indicate a corrupted download or security issue."
            echo "Use --skip-checksum flag to bypass this check if needed."
            exit 1
        fi
    fi
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

# Показываем информацию о PATH, если установка локальная
if [ "${INSTALL_DIR}" = "${HOME}/.local/bin" ]; then
    if ! echo "${PATH}" | grep -q "${INSTALL_DIR}"; then
        echo ""
        echo "💡 Add ${INSTALL_DIR} to your PATH:"
        echo "   echo 'export PATH=\"\$PATH:${INSTALL_DIR}\"' >> ~/.bashrc"
        echo
