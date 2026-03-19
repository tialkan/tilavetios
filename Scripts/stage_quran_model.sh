#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /absolute/path/to/whisper-turbo-quran" >&2
  exit 1
fi

SOURCE_MODEL="$1"
TARGET_DIR="$(cd "$(dirname "$0")/.." && pwd)/Tilavet App/Resources/Models"
TARGET_MODEL="$TARGET_DIR/whisper-turbo-quran"

if [[ ! -d "$SOURCE_MODEL" ]]; then
  echo "Model folder not found: $SOURCE_MODEL" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_MODEL"
cp -R "$SOURCE_MODEL" "$TARGET_MODEL"

echo "Model staged at: $TARGET_MODEL"
