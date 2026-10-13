# Ask Forth

**Public domain.** Local AI assistant built into EditForth (**View → Ask Forth**, ⌥⌘A). First shipped in **EditForth 2.3.0**; editor-file / Agent Enhance Reply in **2.3.1**; Library Reference, URL fetch, standard boost, and Web tabs in **2.3.2**; web search, Tool agent, OpenAI-compatible provider, and Library `.md`/`.swift` / project-folder RAG in **2.3.3**; **model profiles** (Models…), per-profile Temperature, and **8192** completion tokens in **2.3.4**.

## Requirements (providers)

Ask Forth talks to a pluggable **`LLMClient`** through **saved model profiles**. Use the panel **Model** picker to switch; open **Models…** to add or edit name, provider, model id, **Temperature**, Base URL, and per-profile API key. Temperature defaults to **0.3** (steadier code than typical server defaults ~0.7–0.8) and is sent on every Ask / Enhance request.

### Ollama (local)

Talks to **[Ollama](https://ollama.com)** on this Mac (`http://127.0.0.1:11434`). Without Ollama running and a model installed, **Ask** / **Agent Enhance Reply** report that the model is unreachable.

1. Install the **Ollama** app (or CLI) from https://ollama.com  
2. Pull a model, for example:

```bash
ollama pull gemma4:e4b
```

3. Leave Ollama running, then pick an Ollama profile in Ask Forth (starter: **Ollama gemma4:e4b**).

**Default model tag:** **`gemma4:e4b`**. Also useful: **`gemma4:12b`**, **`gemma4:31b-cloud`**.

### OpenAI-compatible (SpaceXAI / local mlx / others)

Uses HTTP **`/v1/chat/completions`**. In **Models…**, set **Base URL** (SpaceXAI default **`https://api.x.ai/v1`**; local mlx often **`http://127.0.0.1:1234/v1`**).

1. Create an API key when needed (for xAI: [console.x.ai](https://console.x.ai) → API Keys).  
2. In **Models…**, paste the key for that profile and click **Save** (Keychain **per profile**). Or export **`XAI_API_KEY`** before launch (SpaceXAI fallback). Local servers often use a dummy key such as **`local`**.  
3. Set **Model** (e.g. **`grok-4.7`**, or a full on-disk MLX path for mlx_lm.server).

First launch migrates your previous Provider / Model / Base URL / key into profiles and adds starters **Ollama gemma4:e4b**, **SpaceXAI grok-4.7**, and **Local mlx :1234** when appropriate.

Streaming and Tool agent use the same OpenAI tools message shape. Cloud use needs network access and incurs provider charges.

Ask / Agent Enhance Reply request up to **8192** completion tokens (`max_tokens` on OpenAI-compatible; `options.num_predict` on Ollama) so long Forth listings are less likely to stop mid-definition. Turn **Include web search** off for “write me a program” prompts unless you need live web hits.

To **fine-tune** a local model for 64Forth style (MLX → Ollama), see repo root **`FORTH-FINETUNE.md`** — that is separate from the xAI API.

## Basic workflow

1. Show the Ask Forth panel: trailing **sidebar** button on the tab bar, **View → Show Ask Forth**, or **⌥⌘A**. Hide the same way (or the sidebar button in the panel header) while you edit results in `AskForth-N.fth`.  
2. Type a question in **Prompt**, or select editor text and click **Capture Selected to Prompt**.  
3. Optionally leave **Include Library context** on (default folder **`~/Documents/EditForth/Library/Sample`**; **Library…** to change).  
4. Optionally leave **Fetch URLs in Prompt** on. If the Prompt contains `http://` or `https://` links, EditForth fetches those pages (plain text / HTML stripped), caps the excerpts, and adds them to the model context before Ask / Agent Enhance Reply.  
5. Optionally turn on **Include web search** (default **off**). EditForth searches the web (DuckDuckGo Lite, no API key) using the Prompt text and adds top hit titles, URLs, and snippets to the model context.  
6. Optionally turn on **Tool agent** (default **off**). The model may call `web_search`, `fetch_url`, or `library_search` before answering (Ollama tools; needs a tools-capable model such as `gemma4:e4b`). Slower; use **Show Agent Transcript** to see tool steps. When Tool agent is on, automatic URL fetch / web search are skipped.  
7. Click **Ask** (below the Prompt, on the right). EditForth creates **`~/Documents/EditForth/AskForth/AskForth-N.fth`**, writes a `\ Ask Forth` comment header with your prompt, and **streams the model reply into that tab**.  
8. Click **Agent Enhance Reply** to improve the answer in one step: a headless `64Forth --agent` run (Library **Autoload** always on) captures a transcript, then the model appends an **`Agent Enhanced Reply`** section to the same file.  
9. Hand-edit the file as needed (model prose/comments are often not loadable as-is), then use the status-strip **INCLUDE** button to load it into the live companion.

Typical pattern: a broad Ask (“Make me a small database”) often produces a full but flawed draft; **Agent Enhance Reply** usually yields a much better second section in the same file.

## Agent Enhance Reply (64Forth Agent)

This is the improve-answer button. It does **not** type into the live Forth console.

1. **Eval** — extract Forth from the latest Ask/Enhance segment (fenced ```forth if present) and run it in a fresh `64Forth --agent` with Autoload. Autoload output and errors go to the agent transcript.  
2. **Enhance** — send that transcript plus the prior answer back to the model; append a new section prefixed with `Agent Enhanced Reply`.

Turn on **Show Agent Transcript** (beside the button) if you want to read the eval output. For loading into your real session, edit the `AskForth-N.fth` tab and use **INCLUDE**.

## Library context

Library search does **not** send the whole tree. It scores `.fth` / `.txt` / `.md` / `.swift` files for tokens in your prompt and includes only the top excerpts. Default folder: **`Library/Sample`**.

Use **Library…** to point at another folder. For EditForth app / UI / debugger questions, choose the EditForth project root (or `Editor/`) so Ask can see Swift sources and Docs. Heavy folders (`.git`, `DerivedData`, `finetune`, `Build`, `.build`, `xcuserdata`, `Pods`, `node_modules`, model weights) are skipped.

In addition, when your folder is under **Library**, Ask Forth also searches **`Library/Reference/`**, which holds plain-text chapters of the **Forth 2012 Standard** (from forth-standard.org / Forth 200x HTML). That way stack effects and standard word meanings can appear in Library context even when the main folder is Sample. Interactive standard: https://forth-standard.org/

For app-source questions, turn **Fetch URLs in Prompt** off so the model stays on local excerpts instead of inventing generic shortcuts from the web.

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
| `library_search` | Score Library (+ Reference) `.fth` / `.txt` / `.md` / `.swift` excerpts |

Status notes look like `· Tools 2 call(s)/2 round(s)`. The AskForth file gets `\ Tool agent:` audit lines. Turn on **Show Agent Transcript** to read `→ tool(…)` / `← …` steps. Automatic **Fetch URLs** / **Include web search** are disabled while Tool agent is on (the model calls those tools itself). Passive **Include Library context** still runs when enabled.

## Web browser tab

**View → Open Web Page** (⇧⌘L) opens an embedded browser tab on [forth-standard.org](https://forth-standard.org/) and focuses the address field — no URL dialog. Type a URL (`gforth.org`) or a search (`OPEN-FILE Forth`) and press Return / **Go** (searches use DuckDuckGo). Use **Back** / **Forward**, follow links in-page, and **Send to Ask Forth** to append the current URL to the Prompt. More ideas: repo root `ASKFORTHMORE.md`.

## Streaming

Ask and Enhance stream into the editor tab as tokens arrive. Status / the **Ask** button show **Streaming…** once text starts. Body text written to `AskForth-N.fth` is **word-wrapped at 80 columns** (existing newlines are kept; overlong tokens are hard-broken).

## Related

- Headless eval details: [Agent-channel.md](Agent-channel.md)  
- Roadmap note: repo root `ROADMAP.md` §5  
