#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CRYPTO_TOOLS_REPO="$ROOT/deps/libOTe/cryptoTools"
TARGET_FILE="$CRYPTO_TOOLS_REPO/cryptoTools/Network/IOService.cpp"
PATCH_FILE="$ROOT/patches/libote-cryptotools-asio-post.patch"

if [ ! -e "$CRYPTO_TOOLS_REPO/.git" ]; then
    echo "Skipping libOTe patch: $CRYPTO_TOOLS_REPO is missing."
    exit 0
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "Skipping libOTe patch: $TARGET_FILE is missing."
    exit 0
fi

if grep -Fq "boost::asio::post(ios->mIoService.get_executor()" "$TARGET_FILE"; then
    echo "libOTe patch already applied."
    exit 0
fi

if git -C "$CRYPTO_TOOLS_REPO" apply --check "$PATCH_FILE" >/dev/null 2>&1; then
    git -C "$CRYPTO_TOOLS_REPO" apply "$PATCH_FILE"
else
    perl -0777 -i -pe 's@    void post\(IOService\* ios, std::function<void\(\)>&& fn\)\r?\n    \{\r?\n        boost::asio::post\(std::move\(fn\)\);\r?\n    \}@    void post(IOService* ios, std::function<void()>&& fn)\r\n    {\r\n        if (ios)\r\n            boost::asio::post(ios->mIoService.get_executor(), std::move(fn));\r\n        else\r\n            fn();\r\n    }@s' "$TARGET_FILE"
fi

if ! grep -Fq "boost::asio::post(ios->mIoService.get_executor()" "$TARGET_FILE"; then
    echo "Failed to apply libOTe Boost.Asio compatibility patch." >&2
    exit 1
fi

echo "Applied libOTe Boost.Asio compatibility patch."
