# Ask Forth

**Public domain.** Local AI assistant built into EditForth (**View → Ask Forth**, ⌥⌘A). First shipped in **EditForth 2.3.0**; editor-file / Agent Enhance Reply in **2.3.1**; Library Reference, URL fetch, standard boost, and Web tabs in **2.3.2**.

## Requirements (local models)

Ask Forth talks to **[Ollama](https://ollama.com)** on this Mac (`http://127.0.0.1:11434`). Without Ollama running and a model installed, **Ask** and **Agent Enhance Reply** will report that the model is unreachable.

1. Install the **Ollama** app (or CLI) from https://ollama.com  
2. Pull a model, for example:

```bash
ollama pull gemma4:e4b
```

3. Leave Ollama running, then use EditForth.

**Default model** in the panel is **`gemma4:e4b`**. Other tags that work: **`gemma4:12b`** (heavier) and **`gemma4:31b-cloud`** (fast cloud path — not fully local).

## Basic workflow

1. Show the Ask Forth panel: trailing **sidebar** button on the tab bar, **View → Show Ask Forth**, or **⌥⌘A**. Hide the same way (or the sidebar button in the panel header) while you edit results in `AskForth-N.fth`.  
2. Type a question in **Prompt**, or select editor text and click **Capture Selected to Prompt**.  
3. Optionally leave **Include Library context** on (default folder **`~/Documents/EditForth/Library/Sample`**; **Library…** to change).  
4. Optionally leave **Fetch URLs in Prompt** on. If the Prompt contains `http://` or `https://` links, EditForth fetches those pages (plain text / HTML stripped), caps the excerpts, and adds them to the model context before Ask / Agent Enhance Reply.  
5. Optionally turn on **Include web search** (default **off**). EditForth searches the web (DuckDuckGo Lite, no API key) using the Prompt text and adds top hit titles, URLs, and snippets to the model context.  
6. Click **Ask** (below the Prompt, on the right). EditForth creates **`~/Documents/EditForth/AskForth-N.fth`**, writes a `\ Ask Forth` comment header with your prompt, and **streams the model reply into that tab**.  
7. Click **Agent Enhance Reply** to improve the answer in one step: a headless `64Forth --agent` run (Library **Autoload** always on) captures a transcript, then the model appends an **`Agent Enhanced Reply`** section to the same file.  
8. Hand-edit the file as needed (model prose/comments are often not loadable as-is), then use the status-strip **INCLUDE** button to load it into the live companion.

Typical pattern: a broad Ask (“Make me a small database”) often produces a full but flawed draft; **Agent Enhance Reply** usually yields a much better second section in the same file.

## Agent Enhance Reply (64Forth Agent)

This is the improve-answer button. It does **not** type into the live Forth console.

1. **Eval** — extract Forth from the latest Ask/Enhance segment (fenced ```forth if present) and run it in a fresh `64Forth --agent` with Autoload. Autoload output and errors go to the agent transcript.  
2. **Enhance** — send that transcript plus the prior answer back to the model; append a new section prefixed with `Agent Enhanced Reply`.

Turn on **Show Agent Transcript** (beside the button) if you want to read the eval output. For loading into your real session, edit the `AskForth-N.fth` tab and use **INCLUDE**.

## Library context

Library search does **not** send the whole tree. It scores `.fth` / `.txt` files for tokens in your prompt and includes only the top excerpts. Default folder: **`Library/Sample`**.

In addition, Ask Forth always also searches **`Library/Reference/`**, which holds plain-text chapters of the **Forth 2012 Standard** (from forth-standard.org / Forth 200x HTML). That way stack effects and standard word meanings can appear in Library context even when the main folder is Sample. Interactive standard: https://forth-standard.org/

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

## Web browser tab

**View → Open Web Page…** (⇧⌘L) opens an embedded browser tab (default [forth-standard.org](https://forth-standard.org/)). Use **Back** / **Forward** at the top left of that editor chrome, follow links in-page, and **Send to Ask Forth** to append the current URL to the Prompt (and show the Ask panel). More ideas: repo root `ASKFORTHMORE.md`.

## Streaming

Ask and Enhance stream into the editor tab as tokens arrive. Status / the **Ask** button show **Streaming…** once text starts. Body text written to `AskForth-N.fth` is **word-wrapped at 80 columns** (existing newlines are kept; overlong tokens are hard-broken).

## Related

- Headless eval details: [Agent-channel.md](Agent-channel.md)  
- Roadmap note: repo root `ROADMAP.md` §5  
