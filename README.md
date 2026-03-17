# Multimodal RAG Knowledge Base

A fully local multimodal knowledge base for AI agents. Ingest videos, images, audio, documents (PDF, DOCX, PPTX, XLSX), and code into a local vector database using Google's Gemini Embedding 2 model. Query it from Claude Code, OpenClaw, or any script.

## Quick Start

```bash
# 1. Clone into your skills directory
git clone https://github.com/grandamenium/multimodal-rag.git ~/.claude/skills/multimodal-rag

# 2. Run setup (installs deps, prompts for free Gemini API key)
bash ~/.claude/skills/multimodal-rag/scripts/setup.sh

# 3. Ingest and query
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest ~/Documents/my-business/
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "What's our pricing strategy?" --json
```

## What It Does

Most RAG systems only handle text. This one handles everything - videos, images, audio, PDFs, Office docs, and code - all in one local database.

The key insight: you can't just embed a video and expect useful answers. This system runs every non-text file through Gemini Flash first to generate a detailed text description (transcript, visual description, key topics), then embeds that description alongside the raw media. So when you query "how does the heartbeat work?", you get back an actual text answer with the source file path - not just a video clip.

**For videos**: FFmpeg splits into 60-second chunks with overlap. Large files (1GB+) automatically extract the audio track for processing. Each chunk gets a full transcript + topic summary.

**For images**: Gemini Flash describes everything visible - text, diagrams, layout, concepts. The description + raw image are embedded together.

**For Office docs**: .docx, .pptx, .xlsx are extracted locally using python-docx/pptx/openpyxl. No API calls needed.

## How It Works

```
Ingest: File -> type detection -> Gemini Flash describes (media) or chunk (text)
     -> Gemini Embedding 2 (768-dim vectors) -> ChromaDB (local)

Query: Question -> embed -> cosine similarity search -> threshold filter
     -> dedup -> JSON with text answers + source file paths
```

## Requirements

- Python 3.10+
- FFmpeg (`brew install ffmpeg`)
- Free Gemini API key ([get one here](https://aistudio.google.com/apikey))

## Supported Formats

| Type | Extensions | Processing |
|------|-----------|-----------|
| Text/Code | .md .txt .py .js .ts .go .sh .json .yaml .html .css + more | Chunked at 1500 chars |
| Images | .png .jpg .jpeg .gif .webp | Gemini Flash description + multimodal embedding |
| Video | .mp4 .mov .avi .mkv .webm | 60s chunks, audio extraction for large files |
| Audio | .mp3 .wav .m4a .ogg .flac | 60s chunks, Gemini Flash transcription |
| PDF | .pdf | Page-by-page extraction with visual descriptions |
| Word | .docx .doc | Local text extraction with heading structure |
| Slides | .pptx .ppt | Per-slide extraction with speaker notes |
| Spreadsheet | .xlsx .xls | Per-sheet extraction with headers and data |

## Usage

```bash
MMRAG="python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py"

# Ingest files
$MMRAG ingest /path/to/file                    # single file
$MMRAG ingest /path/to/folder/                 # recursive directory
$MMRAG ingest /path -c business                # named collection
$MMRAG ingest /path --force                    # re-ingest changed files

# Query
$MMRAG query "your question" --json            # JSON output for agents
$MMRAG query "find the diagram" --type image   # filter by modality
$MMRAG query "what was discussed" --type video  # video chunks only
$MMRAG query "question" -k 10 -t 0.6          # 10 results, min similarity 0.6
$MMRAG query "question" --max-tokens 2000      # cap output size
$MMRAG query "question" --full                 # full content, not truncated

# Manage
$MMRAG status                                  # collection stats
$MMRAG list                                    # list ingested files
$MMRAG collections                             # list all collections
$MMRAG delete /path/to/file                    # remove a file's chunks
$MMRAG reset --confirm                         # wipe everything
```

## Query Output

```json
{
  "query": "how does the heartbeat work?",
  "source_files": ["/path/to/video.mp4", "/path/to/doc.md"],
  "results": [
    {
      "content": "The heartbeat mechanism wakes up OpenClaw at configured intervals...",
      "similarity": 0.718,
      "source": "/path/to/original/file.mp4",
      "type": "video_chunk",
      "time_start": 360,
      "time_end": 420,
      "chunk_path": "/path/to/60s/segment.mp4"
    }
  ]
}
```

The agent gets text it can reason about, plus source file paths it can Read for more context.

## Agent Integration

This is the tool layer. For automatic agent integration (proactive querying, bootstrap file injection, collection routing), see the companion skill: `knowledgebase-agent`.

## Data Storage

Everything stays local:
```
~/.mmrag/
  config.json     # settings + API key
  chromadb/       # vector database
  media/          # cached video/audio chunks
```

## License

MIT
