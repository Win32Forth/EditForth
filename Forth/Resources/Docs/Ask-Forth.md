# Ask Forth

**Public domain.** Local AI assistant built into EditForth (**View → Ask Forth**, ⌥⌘A). First shipped in **EditForth 2.3.0**; editor-file / Agent Enhance Reply in **2.3.1**; Library Reference, URL fetch, standard boost, and Web tabs in **2.3.2**; web search, Tool agent, OpenAI-compatible provider, and Library `.md`/`.swift` / project-folder RAG in **2.3.3**; **model profiles** (Models…), per-profile Temperature, **8192** completion tokens, **Stop**, and **Library hybrid/semantic RAG** (`nomic-embed-text`, stack-effects cheat sheet, auto-rebuild) in **2.3.5**; **AskForth header** (`\\` … `{` with model / temperature / checked options), orange **setup banner**, and **nomic auto-pull / Prepare…** in **2.3.6**; Mac ANS **FALIGNED** and EditForth **Help → Show Boot Messages** in **2.3.7**; **Undock** floating panel, `info.circle` help tips, and tighter Prompt layout in **2.3.8**. Background HYPER-REINDEX in **2.3.9**. **2.5.4:** one session file until **New session**; earlier drafts are `\` line comments; **Agent Enhance Reply** replaces the live section.

## Requirements (providers)

Ask Forth talks to a pluggable **`LLMClient`** through **saved model profiles**. Use the panel **Model** picker to switch; open **Models…** to add or edit name, provider, model id, **Temperature**, Base URL, and per-profile API key. Temperature defaults to **0.3** (steadier code than typical server defaults ~0.7–0.8) and is sent on every Ask / Enhance request.

### Ollama (local)

Talks to **[Ollama](https://ollama.com)** on this Mac (`http://127.0.0.1:11434`). Without Ollama running and a model installed, **Ask** / **Agent Enhance Reply** cannot answer with a local profile.

1. Install the **Ollama** app (or CLI) from https://ollama.com and leave it running.  
2. Pull a **chat** model (EditForth does **not** auto-download multi‑GB chat models):

```bash
ollama pull gemma4:e4b
```

3. Pick an Ollama profile in Ask Forth (starter: **Ollama gemma4:e4b**).

When you open Ask Forth, an orange **setup banner** appears if Ollama is down or the selected chat model is missing (with the exact `ollama pull …` command).

**Default chat model tag:** **`gemma4:e4b`**. Also useful: **`qwen2.5-coder:7b`**, **`gemma4:12b`**, **`gemma4:31b-cloud`**. Create or pick a profile in **Models…** for the tag you pulled.

The **chat** model answers questions. Library **Hybrid/Semantic** retrieve uses a separate **embedding** model (`nomic-embed-text`) — see [Library embeddings](#library-embeddings-nomic-embed-text) below.

### OpenAI-compatible (SpaceXAI / local mlx / others)

Uses HTTP **`/v1/chat/completions`**. In **Models…**, set **Base URL** (SpaceXAI default **`https://api.x.ai/v1`**; local mlx often **`http://127.0.0.1:1234/v1`**).

1. Create an API key when needed (for xAI: [console.x.ai](https://console.x.ai) → API Keys).  
2. In **Models…**, paste the key for that profile and click **Save** (Keychain **per profile**). Or export **`XAI_API_KEY`** before launch (SpaceXAI fallback). Local servers often use a dummy key such as **`local`**.  
3. Set **Model** (e.g. **`grok-4.7`**, or a full on-disk MLX path for `mlx_lm.server`).

First launch migrates your previous Provider / Model / Base URL / key into profiles and adds starters **Ollama gemma4:e4b**, **SpaceXAI grok-4.7**, and **Local mlx :1234** when appropriate.

Streaming and Tool agent use the same OpenAI tools message shape. Cloud use needs network access and incurs provider charges.

**Most users should prefer Ollama or SpaceXAI.** EditForth does not start a local MLX/LM Studio process; something else must already be listening on the profile’s Base URL.

### Advanced: local MLX on port 1234 (`mlx_lm.server`)

Ask Forth’s **Local mlx :1234** profile expects an OpenAI-compatible server at **`http://127.0.0.1:1234/v1`**. Opening an LM Studio **chat** alone is not enough — that UI does not serve EditForth. Either run **`mlx_lm.server`** (below) or start **LM Studio → Local Server** (Developer) on port **1234** with the model loaded.

Prefer **`python -m mlx_lm.server`** after activating your MLX venv (the bare `mlx_lm.server` command only works when that venv’s `bin` is on `PATH`):

```bash
source ~/mlx-forth-venv/bin/activate
python -m mlx_lm.server \
  --model ~/.lmstudio/models/lmstudio-community/Qwen2.5-Coder-7B-Instruct-MLX-4bit \
  --host 127.0.0.1 \
  --port 1234
```

Leave that Terminal window open. In Ask Forth, pick **Local mlx :1234** (Base URL `http://127.0.0.1:1234/v1`, API key often `local`, Model = the same on-disk path or whatever `/v1/models` lists). Adjust the `--model` path if your weights live elsewhere.

To stop a runaway generation: use Ask Forth **Stop** (cancels EditForth’s request), then stop the Terminal server with **Ctrl+C**, or quit / unload in LM Studio if that app was serving.

Ask / Agent Enhance Reply request up to **8192** completion tokens (`max_tokens` on OpenAI-compatible; `options.num_predict` on Ollama) so long Forth listings are less likely to stop mid-definition. Turn **Include web search** off for “write me a program” prompts unless you need live web hits.

To **fine-tune** a local model for 64Forth style (MLX → Ollama), see repo root **`FORTH-FINETUNE.md`** — that is separate from the xAI API.

## Basic workflow

1. Show Ask Forth: trailing **sidebar** button on the tab bar, **View → Show Ask Forth**, or **⌥⌘A**. Hide the same way (or the sidebar button in the panel header) while you edit results in `AskForth-N.fth`. Hover the **info** icon beside the title for a short how-to. Use **Undock** to float Ask Forth in its own window (**Dock** returns it to the trailing inspector).  
2. Type a question in **Prompt** (paste editor text if needed).  
2a. While **Ask** or **Agent Enhance Reply** is running, click **Stop** (or press Escape) to cancel EditForth’s in-flight request. Status shows **Stopped.** If a local server keeps generating on its own, unload the model or stop that server separately.  
3. Optionally leave **Include Library context** on (default folder **`~/Documents/EditForth/Library/Sample`**; **Library…** to change).  
4. Optionally leave **Fetch URLs in Prompt** on. If the Prompt contains `http://` or `https://` links, EditForth fetches those pages (plain text / HTML stripped), caps the excerpts, and adds them to the model context before Ask / Agent Enhance Reply.  
5. Optionally turn on **Include web search** (default **off**). EditForth searches the web (DuckDuckGo Lite, no API key) using the Prompt text and adds top hit titles, URLs, and snippets to the model context.  
6. Optionally turn on **Tool agent** (default **off**). The model may call `web_search`, `fetch_url`, or `library_search` before answering (Ollama tools; needs a tools-capable model such as `gemma4:e4b`). Slower; use **Show Agent Transcript** to see tool steps. When Tool agent is on, automatic URL fetch / web search are skipped.  
7. Click **Ask** (below the Prompt, on the right). The first Ask creates **`~/Documents/EditForth/AskForth/AskForth-N.fth`**. Later Asks keep that file until **New session**. The host writes an F-PC block-comment header (`\\` … `{`) with the active **model**, **temperature**, checked options, and a **Prompt N:** block (the prompt text and the reference path, if any). The model reply streams into the section after `\ --- live ---`. Earlier live text is kept above that marker, each line prefixed with `\ `, so INCLUDE loads only the newest section. Live Forth is not wrapped to 80 columns.  
7a. **Reference** is a menu of file tabs already open in the editor, or (none). Ask reads that buffer and does not write the file. Changing the menu does not start a new session.  
7b. **New session** keeps the old file and the next Ask creates the next `AskForth-N.fth`. Save As, rename, or a missing session file does the same: the next Ask does not follow the renamed tab.  
8. Click **Agent Enhance Reply** to test the live section in a headless `EditForth --agent` run (Library **Autoload** on). The transcript stays in the panel. The model’s corrected Forth replaces the live section. The header records the last `status=` and stack depth.  
9. Hand-edit the live section as needed, then use the status-strip **INCLUDE** button to load the session file into the live companion. INCLUDE still sends `ANEW <stem>_MODULE` for that file.

Clear the Prompt before a follow-up. The earlier prompt is already in the session file.

## Agent Enhance Reply (64Forth Agent)

This is the improve-answer button. It does **not** type into the live Forth console.

1. **Eval** — take the live section (the text after `\ --- live ---`) and run it in a fresh `EditForth --agent` with Autoload. Autoload output and errors go to the agent transcript.  
2. **Enhance** — send that transcript plus the previous live text back to the model. The host comments out the previous live section and writes the new Forth after `\ --- live ---`.

Turn on **Show Agent Transcript** (beside the button) if you want to read the eval output. The transcript is not pasted into the file. For loading into your real session, edit the live section and use **INCLUDE**.

## Library context

Library search does **not** send the whole tree. It includes only the top excerpts from `.fth` / `.txt` / `.md` / `.swift` files. Default folder: **`Library/Sample`**.

Use **Library…** to point at another folder and to choose **Retrieve mode**:

| Mode | Behavior |
|------|----------|
| **Hybrid** (default) | Blends local **nomic-embed-text** similarity with keyword scores |
| **Semantic** | Embedding search only |
| **Keyword** | Original token scoring only |

Status notes look like `· Library 8 hybrid: …`. If the embed index is missing or Ollama embeddings fail, Ask falls back to keyword and the status says so (`keyword (no embed index)`).

For EditForth app / UI / debugger questions, choose the EditForth project root (or `Editor/`) so Ask can see Swift sources and Docs. Heavy folders (`.git`, `DerivedData`, `finetune`, `Build`, `.build`, `xcuserdata`, `Pods`, `node_modules`, model weights) are skipped.

In addition, when your folder is under **Library**, Ask Forth also searches **`Library/Reference/`**, which holds plain-text chapters of the **Forth 2012 Standard** (from forth-standard.org / Forth 200x HTML). That way stack effects and standard word meanings can appear in Library context even when the main folder is Sample. Interactive standard: https://forth-standard.org/

When Library excerpts are present, Ask Forth tells the model to treat them as authoritative for word names and stack effects, cite `path:line` when helpful, and say **Not found in the provided Library context** instead of inventing APIs. If Library search returns no hits, the model is instructed to avoid fabricating stack effects.

For app-source questions, turn **Fetch URLs in Prompt** off so the model stays on local excerpts instead of inventing generic shortcuts from the web.

### Library embeddings (`nomic-embed-text`)

**Chat model ≠ embedding model.** Profiles (gemma / Qwen / SpaceXAI / mlx) write the answer. Hybrid and Semantic retrieve call local Ollama **`nomic-embed-text`** (~274 MB, 768-dimensional vectors) only to find relevant Library chunks — even when chat uses SpaceXAI or `mlx_lm.server` on port 1234.

**First-run (automatic)**

The DMG does **not** ship an embed index. When you open Ask Forth with Library on and **Hybrid/Semantic**:

1. If Ollama is running and **`nomic-embed-text`** is missing, EditForth **auto-pulls** it via Ollama’s API (~274 MB; progress in the setup banner / status).  
2. EditForth then **builds the Library index in the background** (Sample + always Reference). A full first build can take ~30+ seconds.  
3. **Ask does not wait** for that first build — it uses **keyword** Library retrieve until the index is ready, then later Asks use Hybrid/Semantic.

You can also use Library… → **Prepare…** (pull + index) or **Rebuild Index…** (full re-embed). Manual pull is still fine:

```bash
ollama pull nomic-embed-text
```

Index file:

`~/Library/Application Support/EditForth/AskForthEmbedIndex/library-embed-v1.json`

Typical Sample + Reference size is on the order of hundreds of chunks and a few–tens of MB on disk (not gigabytes).

**When the index updates**

- **Automatic background:** on Ask Forth open, after Library… Save when the folder/files drift, and when Ask notices a stale index (kicks prepare; does not block the reply).  
- **Manual:** **Prepare…** or **Rebuild Index…**.  
- Incremental updates reuse unchanged files by mtime/size.

**Stack-effects cheat sheet**

`Library/Reference/Stack-effects-cheatsheet.txt` lists stack comments and 64Forth idioms models often invent wrong (`COMPARE` vs `=`, `TYPE`, `CMOVE`/`MOVE`, file `ior`, `DO` limits, record buffers). It is indexed with the other Reference text — do not `INCLUDE` it.

**What this improves**

- Paraphrased questions (“compare two counted strings”) still surface ANS glossary stack effects (`COMPARE`, `MOVE`, `TYPE`, …) from Reference and the cheat sheet  
- Fewer invented stack diagrams when the right excerpt is in context  
- Still pair with **Agent Enhance Reply** for multi-word stack balance; embeddings find sources, they do not simulate the kernel

## Fetch URLs in Prompt

When enabled (default), Ask and Agent Enhance Reply:

1. Scan the **Prompt** for up to four `http`/`https` URLs, download each page, strip HTML to text, and include capped excerpts.  
2. **Auto-boost from forth-standard.org** when the Prompt looks like a word lookup — e.g. `` `OPEN-FILE` ``, “what does DUP do”, or a short prompt that names a standard word. EditForth resolves words via `Library/Reference/Forth-2012-word-urls.json` and fetches the live standard page (up to three words).

Status notes look like `· Web 1 page(s) · Standard DUP`. Turn the toggle off to stay fully offline aside from Ollama itself.

## Include web search

Default **off** (extra network use). When on, Ask and Agent Enhance Reply:

1. Derive a short query from the Prompt (URLs stripped, whitespace collapsed).  
2. POST to DuckDuckGo Lite, parse the top hits (title, URL, snippet), and inject a capped block into the model context.  
3. Write `\ Web search: …` comment lines into the AskForth file for auditability.

Status notes look like `· Search 5 hit(s)`. If DuckDuckGo challenges or returns nothing, Ask continues without search context (`· Search: …`). No API key. A Keychain-backed Brave/Bing backend can come later if Lite becomes unreliable.

## Tool agent

Default **off**. When on, Ask and Agent Enhance Reply run an Ollama **tool loop** (up to four rounds):

| Tool | What it does |
|------|----------------|
| `web_search` | DuckDuckGo Lite search → titles / URLs / snippets |
| `fetch_url` | Fetch one http(s) page → plain text excerpt |
| `library_search` | Library (+ Reference) excerpts via keyword / hybrid / semantic retrieve |

Status notes look like `· Tools 2 call(s)/2 round(s)`. The AskForth file gets `\ Tool agent:` audit lines. Turn on **Show Agent Transcript** to read `→ tool(…)` / `← …` steps. Automatic **Fetch URLs** / **Include web search** are disabled while Tool agent is on (the model calls those tools itself). Passive **Include Library context** still runs when enabled.

## Web browser tab

**View → Open Web Page** (⇧⌘L) opens an embedded browser tab on [forth-standard.org](https://forth-standard.org/) and focuses the address field — no URL dialog. Type a URL (`gforth.org`) or a search (`OPEN-FILE Forth`) and press Return / **Go** (searches use DuckDuckGo). Use **Back** / **Forward**, follow links in-page, and **Send to Ask Forth** to append the current URL to the Prompt. More ideas: repo root `ASKFORTHMORE.md`.

## Streaming

Ask and Enhance stream into the editor tab as tokens arrive. Status / the **Ask** button show **Streaming…** once text starts. Body text written to `AskForth-N.fth` is **word-wrapped at 80 columns** (existing newlines are kept; overlong tokens are hard-broken).

## Related

- Headless eval details: [Agent-channel.md](Agent-channel.md)  
- Roadmap note: repo root `ROADMAP.md` §5  
