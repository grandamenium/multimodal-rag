#!/usr/bin/env bash
# Multimodal RAG Knowledge Base - Setup Script
# One-command installer for the mmrag system

set -e

MMRAG_DIR="$HOME/.mmrag"
CONFIG_FILE="$MMRAG_DIR/config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Multimodal RAG Knowledge Base Setup ==="
echo ""

# 1. Check Python
echo "[1/5] Checking Python..."
if ! command -v python3 &>/dev/null; then
    echo "ERROR: Python 3 is required. Install it first."
    exit 1
fi
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "  Found Python $PYTHON_VERSION"

# 2. Install Python dependencies
echo "[2/5] Installing Python dependencies..."
pip3 install --quiet --upgrade chromadb google-genai python-docx python-pptx openpyxl 2>&1 | tail -1 || {
    echo "  Trying with --user flag..."
    pip3 install --quiet --upgrade --user chromadb google-genai python-docx python-pptx openpyxl 2>&1 | tail -1
}
echo "  All Python dependencies installed"

# 3. Check FFmpeg
echo "[3/5] Checking FFmpeg..."
if ! command -v ffmpeg &>/dev/null; then
    echo "  FFmpeg not found. Installing via Homebrew..."
    if command -v brew &>/dev/null; then
        brew install ffmpeg
    else
        echo "ERROR: FFmpeg is required. Install it manually:"
        echo "  macOS: brew install ffmpeg"
        echo "  Ubuntu: sudo apt install ffmpeg"
        echo "  Windows: choco install ffmpeg"
        exit 1
    fi
fi
echo "  FFmpeg found at $(which ffmpeg)"

# 4. Create data directory
echo "[4/5] Creating data directory..."
mkdir -p "$MMRAG_DIR"/{chromadb,media,logs}
echo "  Created $MMRAG_DIR/"

# 5. Configure API key
echo "[5/5] Configuring Gemini API key..."
if [ -f "$CONFIG_FILE" ]; then
    EXISTING_KEY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('gemini_api_key', ''))" 2>/dev/null || echo "")
    if [ -n "$EXISTING_KEY" ] && [ "$EXISTING_KEY" != "None" ]; then
        echo "  Existing API key found. Keep it? (y/n)"
        read -r KEEP_KEY
        if [ "$KEEP_KEY" = "y" ] || [ "$KEEP_KEY" = "Y" ]; then
            echo "  Keeping existing key."
            echo ""
            echo "=== Setup complete! ==="
            echo ""
            echo "Usage:"
            echo "  python3 $SCRIPT_DIR/mmrag.py ingest /path/to/file"
            echo "  python3 $SCRIPT_DIR/mmrag.py query \"your question\""
            echo "  python3 $SCRIPT_DIR/mmrag.py status"
            exit 0
        fi
    fi
fi

# Check env var first
if [ -n "$GEMINI_API_KEY" ]; then
    API_KEY="$GEMINI_API_KEY"
    echo "  Using GEMINI_API_KEY from environment."
else
    echo ""
    echo "  Get a free Gemini API key at: https://aistudio.google.com/apikey"
    echo "  Enter your Gemini API key: "
    read -r API_KEY
    if [ -z "$API_KEY" ]; then
        echo "ERROR: API key is required."
        exit 1
    fi
fi

# Write config
cat > "$CONFIG_FILE" << EOF
{
  "gemini_api_key": "$API_KEY",
  "default_collection": "default",
  "embedding_dimensions": 768,
  "video_chunk_seconds": 120,
  "video_overlap_seconds": 30,
  "text_chunk_size": 4000,
  "text_chunk_overlap": 200,
  "gemini_model": "gemini-2.5-flash",
  "embedding_model": "gemini-embedding-2-preview"
}
EOF
echo "  Config saved to $CONFIG_FILE"

# Verify everything works
echo ""
echo "Verifying installation..."
python3 -c "
import chromadb
from google import genai
print('  chromadb: OK')
print('  google-genai: OK')
# Test ChromaDB
client = chromadb.PersistentClient(path='$MMRAG_DIR/chromadb')
print('  ChromaDB persistent storage: OK')
print('  All checks passed!')
"

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Usage:"
echo "  python3 $SCRIPT_DIR/mmrag.py ingest /path/to/file"
echo "  python3 $SCRIPT_DIR/mmrag.py query \"your question\""
echo "  python3 $SCRIPT_DIR/mmrag.py status"
