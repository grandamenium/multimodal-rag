---
name: multimodal-rag
description: Set up and manage a fully local multimodal knowledge base using Gemini Embedding 2 and ChromaDB. Use when user wants to create a business knowledge base, ingest videos/images/audio/docs for RAG, query their knowledge base, or set up multimodal embeddings for their Claude Code agent.
---

# Multimodal RAG Knowledge Base

Fully local multimodal knowledge base. Embeds videos, images, audio, documents (PDF, DOCX, PPTX, XLSX), and text using Google's Gemini Embedding 2. Queries return text answers with source file paths so the agent can Read originals.

## Setup

```bash
bash ~/.claude/skills/multimodal-rag/scripts/setup.sh
```

Needs: Python 3.10+, FFmpeg, free Gemini API key (https://aistudio.google.com/apikey)

## Commands

```bash
MMRAG="python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py"

# Ingest
$MMRAG ingest /path/to/file                    # single file
$MMRAG ingest /path/to/folder/                 # directory (recursive)
$MMRAG ingest /path -c business                # named collection
$MMRAG ingest /path --force                    # re-ingest changed files

# Query
$MMRAG query "question" --json                 # agent-friendly JSON output
$MMRAG query "question" --json --type image    # only images
$MMRAG query "question" --json --type video    # only video chunks
$MMRAG query "question" --json --type text     # only text/code
$MMRAG query "question" --json --type pdf      # only PDF pages
$MMRAG query "question" --json --type audio    # only audio
$MMRAG query "question" -k 10 -t 0.6          # 10 results, min 0.6 similarity
$MMRAG query "question" --max-tokens 2000      # cap total output tokens
$MMRAG query "question" --full                 # show full content not truncated

# Manage
$MMRAG status -c business                      # collection stats
$MMRAG list -c business                        # list ingested files
$MMRAG collections                             # list all collections
$MMRAG delete /path/to/file -c business        # remove a file
$MMRAG reset --confirm                         # wipe everything
```

## Supported Formats

| Type | Extensions | How It's Processed |
|------|-----------|-------------------|
| Text/Code | .md .txt .py .js .ts .go .sh .json .yaml .html .css .sql + more | Chunked at 1500 chars on paragraph boundaries |
| Images | .png .jpg .jpeg .gif .webp | Gemini Flash describes + multimodal embedding |
| Video | .mp4 .mov .avi .mkv .webm | FFmpeg 60s chunks, audio extraction for large files, Gemini Flash transcribes |
| Audio | .mp3 .wav .m4a .ogg .flac | 60s chunks, Gemini Flash transcribes |
| PDF | .pdf | Gemini Flash extracts page-by-page with visual descriptions |
| Word | .docx .doc | python-docx extracts text preserving headings + tables |
| Slides | .pptx .ppt | python-pptx extracts per-slide with speaker notes |
| Spreadsheet | .xlsx .xls | openpyxl extracts per-sheet with headers and data |

## Query JSON Output

```json
{
  "query": "how does the heartbeat work?",
  "collection": "business",
  "result_count": 3,
  "source_files": ["/path/to/video.mp4", "/path/to/doc.md"],
  "results": [
    {
      "content": "transcript or text chunk...",
      "content_full_length": 2702,
      "similarity": 0.718,
      "source": "/full/path/to/original/file",
      "type": "video_chunk",
      "filename": "Workspace-and-tools.mp4",
      "chunk_index": 8,
      "total_chunks": 30,
      "time_start": 360,
      "time_end": 420,
      "chunk_path": "/path/to/60s/segment.mp4"
    }
  ]
}
```

Key fields:
- `source_files` - deduplicated list of file paths the agent can Read
- `source` - full path to original file
- `type` - text, image, video_chunk, audio, audio_chunk, pdf_page, docx, slides, spreadsheet
- `time_start`/`time_end` - video/audio timestamp in seconds
- `chunk_path` - path to the specific video/audio segment
- `page_number` - for PDFs
- `slide_number` - for presentations

## Auto-Skipped

Directories: .git, node_modules, __pycache__, .venv, dist, build, .cache, vendor, coverage
Files: .DS_Store, package-lock.json, yarn.lock, thumbs.db
Size limits: text >10MB, images >50MB, docs >100MB
Corrupted media: zero-duration audio/video gracefully skipped

## Architecture

```
Ingest: File -> [type detect] -> text chunk / Gemini Flash describe / FFmpeg split
     -> Gemini Embedding 2 (768-dim) -> ChromaDB (local, cosine similarity)

Query: Question -> Gemini Embedding 2 -> ChromaDB search -> threshold filter
     -> dedup -> token budget -> JSON with source paths
```

Media files get described by Gemini Flash BEFORE embedding so queries return text answers (not just file pointers). The text description + raw media bytes are embedded together for richer semantic matching.

## Config

`~/.mmrag/config.json`:
```json
{
  "embedding_dimensions": 768,
  "video_chunk_seconds": 60,
  "video_overlap_seconds": 15,
  "audio_chunk_seconds": 60,
  "audio_overlap_seconds": 10,
  "text_chunk_size": 1500,
  "text_chunk_overlap": 200,
  "gemini_model": "gemini-2.5-flash",
  "embedding_model": "gemini-embedding-2-preview"
}
```

## Data Location

```
~/.mmrag/
  config.json     # settings + API key
  chromadb/       # vector database
  media/          # cached video/audio chunks
```
