#!/bin/sh
set -e

APP="nosudopass"
LOCAL_DIR="${HOME}/.local/bin"
GLOBAL_DIR="/usr/local/bin"

LOCAL_BIN="${LOCAL_DIR}/${APP}"
GLOBAL_BIN="${GLOBAL_DIR}/${APP}"

local_exists=false
global_exists=false

# Проверка установок
[ -f "${LOCAL_BIN}" ] && local_exists=true
[ -f "${GLOBAL_BIN}" ] && global_exists=true

if [ "${local_exists}" = false ] && [ "${global_exists}" = false ]; then
    echo "⚠️ ${APP} is not installed locally or globally"
    exit 0
fi

remove_local() {
    echo "🗑️ Removing local version: ${LOCAL_BIN}"
    rm -f "${LOCAL_BIN}" && echo "✅ Removed local ${APP}"
}

remove_global() {
    # Используем ту же логику проверки прав, что и в скрипте установки
    if [ ! -w "${GLOBAL_DIR}" ]; then
        echo "🔑 Requires root privileges to remove from ${GLOBAL_DIR}"
        echo "💡 Running with sudo..."
        sudo rm -f "${GLOBAL_BIN}" && echo "✅ Removed global ${APP}"
    else
        echo "🗑️ Removing global version: ${GLOBAL_BIN}"
        rm -f "${GLOBAL_BIN}" && echo "✅ Removed global ${APP}"
    fi
}

if [ "${local_exists}" = true ] && [ "${global_exists}" = true ]; then
    echo "Found both local and global installations."
    echo "Select which one to remove:"
    echo "1) Local: ${LOCAL_BIN}"
    echo "2) Global: ${GLOBAL_BIN}"
    printf "Enter choice [1-2]: "
    read -r ans
    case "${ans}" in
        1) remove_local ;;
        2) remove_global ;;
        *) echo "❌ Invalid choice"; exit 1 ;;
    esac
elif [ "${local_exists}" = true ]; then
    remove_local
else
    remove_global
fi