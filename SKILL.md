---
name: multimodal-rag
description: Set up and manage a fully local multimodal knowledge base using Gemini Embedding 2 and ChromaDB. Use when user wants to create a business knowledge base, ingest videos/images/audio/docs for RAG, query their knowledge base, or set up multimodal embeddings for their Claude Code agent.
---

# Multimodal RAG Knowledge Base

Fully local multimodal knowledge base. Embeds videos, images, audio, documents (PDF, DOCX, PPTX, XLSX), and text using Google's Gemini Embedding 2. Queries return text answers with source file paths so the agent can Read originals.

---

## Onboarding (Run This First Time)

Walk the user through these steps in order. Ask questions, don't assume.

### Step 1: Install Dependencies

```bash
bash ~/.claude/skills/multimodal-rag/scripts/setup.sh
```

This will:
1. Check Python 3.10+ is installed
2. Install chromadb, google-genai, python-docx, python-pptx, openpyxl
3. Check for FFmpeg (installs via brew if missing)
4. Prompt for Gemini API key (free at https://aistudio.google.com/apikey) or use GEMINI_API_KEY env var
5. Create ~/.mmrag/ data directory
6. Verify everything works

If the user already has GEMINI_API_KEY set, setup will use it automatically.

### Step 2: Choose a Collection Name

Ask the user: **"What should we call this knowledge base?"**

Suggest names based on context:
- Working in a project directory? Use the project name (e.g., `my-saas`, `openclaw`)
- General business docs? Use `business`
- Course materials? Use `courses`
- Mixed personal stuff? Use `default`

The collection name is used in every command: `--collection NAME`

### Step 3: Initial Ingestion

Ask: **"What files or folders do you want to make searchable?"**

Common patterns:
- `~/Documents/business/` - business docs
- `~/Projects/my-app/` - a codebase
- A specific folder of videos, PDFs, images
- Individual important files

Run the ingest:
```bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest /path/to/their/content --collection COLLECTION_NAME
```

Report results: how many chunks, which file types were found, any errors or skips.

### Step 4: Verify It Works

Run three test queries to confirm retrieval is working. Pick questions based on what was just ingested:

**Test 1 - General concept query:**
```bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "a topic you know is in the ingested files" --collection COLLECTION_NAME --json -k 3 --threshold 0.5
```
Check: Did it return relevant results? Is similarity > 0.5?

**Test 2 - Type-filtered query (if multiple modalities were ingested):**
```bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "something from a video or image" --collection COLLECTION_NAME --json --type video -k 2
```
Check: Did it return the right file type?

**Test 3 - File finding query:**
```bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "description of a specific file" --collection COLLECTION_NAME --json -k 1
```
Check: Does the `source` field point to the right file?

Show the user the results of all three tests. If any fail, troubleshoot before proceeding:
- Low similarity scores -> content may not have ingested properly, try `status` and `list`
- Zero results -> check collection name matches, check `collections` command
- Wrong file types -> verify the files were actually in the ingested folder

### Step 5: Configure Agent Integration

Ask the user three questions:

**Question 1: "Where should the KB instructions live?"**

- **A) In my CLAUDE.md** (recommended for most users)
  - Instructions are always in your agent's context
  - Agent will know about the KB every session
  - Uses some context window space (~500 tokens)
  - Best for: frequent KB usage, business knowledge, project context

- **B) As a skill only** (what you have now)
  - Agent only uses KB when you explicitly ask
  - Zero context cost when not in use
  - Best for: occasional lookups, large reference libraries you rarely query

- **C) Both** (light reference in CLAUDE.md + full instructions in skill)
  - CLAUDE.md has a one-liner reminding the agent the KB exists
  - Detailed query/ingest instructions stay in this skill file
  - Best for: balanced usage without burning context

**Question 2: "How autonomous should the agent be with the KB?"**

- **Manual** - Only query/ingest when I explicitly ask
  - "search the knowledge base for X"
  - "add this file to the KB"
  - "what's in the knowledge base?"

- **Suggested** - Query automatically for business/project questions, but don't ingest without asking
  - Agent queries KB before answering questions about the project, business, or topics likely in the KB
  - Agent suggests ingesting new important documents but waits for approval
  - Agent ignores KB for general coding, conversation, or topics clearly outside the KB scope

- **Proactive** - Query and ingest automatically
  - Agent queries KB before answering any project/business question
  - Agent auto-ingests important new files (meeting notes, docs it creates, files user shares)
  - Agent offers to ingest when it notices relevant content not in the KB

**Question 3: "What's the default collection for this project?"**

Use the collection name from Step 2. This gets baked into the CLAUDE.md instructions so the agent doesn't have to guess.

### Step 6: Inject Configuration

Based on their answers, add the appropriate section to their CLAUDE.md (or global ~/.claude/CLAUDE.md if they chose global).

**If they chose A or C, add to CLAUDE.md:**

For **Manual** mode:
```markdown
## Knowledge Base (mmrag)

You have a local multimodal knowledge base at ~/.mmrag/ with collection "COLLECTION_NAME".

Query it ONLY when the user explicitly asks you to search, recall, or check the knowledge base:
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "question" --collection COLLECTION_NAME --json -k 5 --threshold 0.6
\`\`\`

Ingest new files ONLY when the user explicitly asks:
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest /path --collection COLLECTION_NAME
\`\`\`

Use --type image/video/text/pdf/audio to filter by modality when looking for specific file types.
Results include source file paths you can Read for full context.
```

For **Suggested** mode:
```markdown
## Knowledge Base (mmrag)

You have a local multimodal knowledge base at ~/.mmrag/ with collection "COLLECTION_NAME".
It contains [DESCRIPTION OF WHAT WAS INGESTED - e.g., "business docs, course videos, and project files"].

### When to query
- When the user asks about the project, business, or any topic that might be documented
- When you're unsure about project-specific details (pricing, architecture, processes)
- When the user says "find", "where is", or references a file/image/video they can't locate
- When the user asks you to recall or remember something
- Do NOT query for general coding questions, conversation, or topics clearly outside the KB

### How to query
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "question" --collection COLLECTION_NAME --json -k 5 --threshold 0.6
\`\`\`

For finding specific files by type:
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "description" --collection COLLECTION_NAME --json --type image -k 3
\`\`\`

### How to use results
- Read the `content` field for the answer
- Use `source` paths to Read original files for more context
- For video results, `time_start`/`time_end` tell you where in the video
- If similarity < 0.5, the result is probably not relevant - use your judgment

### Ingestion
- Suggest ingesting new important documents but ask the user first
- When user says "add this to the KB" or "remember this": ingest it
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest /path --collection COLLECTION_NAME
\`\`\`
```

For **Proactive** mode:
```markdown
## Knowledge Base (mmrag)

You have a local multimodal knowledge base at ~/.mmrag/ with collection "COLLECTION_NAME".
It contains [DESCRIPTION OF WHAT WAS INGESTED].

### When to query
- Before answering any question about the project, business, architecture, processes, or team
- When the user references something that might be documented (files, decisions, meeting notes)
- When you're about to make assumptions about project-specific details - check the KB first
- When the user asks to find, locate, or recall anything
- Skip for: pure coding tasks on files in front of you, general conversation, external topics

### How to query
\`\`\`bash
python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py query "question" --collection COLLECTION_NAME --json -k 5 --threshold 0.6
\`\`\`
Use --type image/video/text/pdf/audio to narrow by modality.

### How to use results
- Read the `content` field for context, weave it into your answer naturally
- Use `source` paths with Read tool to get full files when the chunk isn't enough
- For video: `time_start`/`time_end` are timestamps in seconds
- If similarity < 0.5, ignore the results - they're not relevant
- If zero results, answer from your own knowledge and move on

### Auto-ingestion
- When you create important documents (meeting notes, specs, plans), ingest them:
  \`\`\`bash
  python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest /path/to/new/file --collection COLLECTION_NAME
  \`\`\`
- When the user shares a file and says "remember this" or "add to KB", ingest immediately
- When you notice important files that aren't in the KB, suggest ingesting them
- Do NOT ingest temporary files, scratch work, or ephemeral content
```

**If they chose B (skill only), don't add anything to CLAUDE.md.** The skill file itself contains all the instructions and will be read when invoked.

**If they chose C (both), add this minimal reference to CLAUDE.md:**
```markdown
## Knowledge Base

You have a multimodal knowledge base. When you need to search it or add to it, read the multimodal-rag skill for instructions.
Collection: "COLLECTION_NAME"
```

### Step 7: Confirm Setup

Tell the user:
1. What was installed
2. How many files/chunks are in the KB
3. Which mode they chose (manual/suggested/proactive)
4. Where the instructions were added (CLAUDE.md / skill only / both)
5. How to add more content later: `mmrag.py ingest /path --collection NAME`
6. How to check what's indexed: `mmrag.py status --collection NAME`

---

## Reference: All Commands

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

## Reference: Supported Formats

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

## Reference: Query JSON Output

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
- `source_files` - deduplicated file paths the agent can Read
- `source` - full path to original file
- `type` - text, image, video_chunk, audio, audio_chunk, pdf_page, docx, slides, spreadsheet
- `time_start`/`time_end` - video/audio timestamps in seconds
- `chunk_path` - path to the specific video/audio segment
- `page_number` - for PDFs
- `slide_number` - for presentations

## Reference: Auto-Skipped Content

Directories: .git, node_modules, __pycache__, .venv, dist, build, .cache, vendor, coverage
Files: .DS_Store, package-lock.json, yarn.lock, thumbs.db
Size limits: text >10MB, images >50MB, docs >100MB
Corrupted media: zero-duration audio/video gracefully skipped

## Reference: Architecture

```
Ingest: File -> [type detect] -> text chunk / Gemini Flash describe / FFmpeg split
     -> Gemini Embedding 2 (768-dim) -> ChromaDB (local, cosine similarity)

Query: Question -> Gemini Embedding 2 -> ChromaDB search -> threshold filter
     -> dedup -> token budget -> JSON with source paths
```

Media files get described by Gemini Flash BEFORE embedding so queries return text answers (not just file pointers). The text description + raw media bytes are embedded together for richer semantic matching.

## Reference: Config

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

## Reference: Data Location

```
~/.mmrag/
  config.json     # settings + API key
  chromadb/       # vector database
  media/          # cached video/audio chunks
```
