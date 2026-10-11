# Ask Forth

**Public domain.** Local AI assistant built into EditForth (**View → Ask Forth**, ⌥⌘A). First shipped in **EditForth 2.3.0**; editor-file / Agent Enhance Reply workflow polished in **2.3.1**.

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

1. Open **View → Ask Forth** (⌥⌘A).  
2. Type a question in **Prompt**, or select editor text and click **Capture Selected to Prompt**.  
3. Optionally leave **Include Library context** on (default folder **`~/Documents/EditForth/Library/Sample`**; **Library…** to change).  
4. Click **Ask** (below the Prompt, on the right). EditForth creates **`~/Documents/EditForth/AskForth-N.fth`**, writes a `\ Ask Forth` comment header with your prompt, and **streams the model reply into that tab**.  
5. Click **Agent Enhance Reply** to improve the answer in one step: a headless `64Forth --agent` run (Library **Autoload** always on) captures a transcript, then the model appends an **`Agent Enhanced Reply`** section to the same file.  
6. Hand-edit the file as needed (model prose/comments are often not loadable as-is), then use the status-strip **INCLUDE** button to load it into the live companion.

Typical pattern: a broad Ask (“Make me a small database”) often produces a full but flawed draft; **Agent Enhance Reply** usually yields a much better second section in the same file.

## Agent Enhance Reply (64Forth Agent)

This is the improve-answer button. It does **not** type into the live Forth console.

1. **Eval** — extract Forth from the latest Ask/Enhance segment (fenced ```forth if present) and run it in a fresh `64Forth --agent` with Autoload. Autoload output and errors go to the agent transcript.  
2. **Enhance** — send that transcript plus the prior answer back to the model; append a new section prefixed with `Agent Enhanced Reply`.

Turn on **Show Agent Transcript** (beside the button) if you want to read the eval output. For loading into your real session, edit the `AskForth-N.fth` tab and use **INCLUDE**.

## Library context

Library search does **not** send the whole tree. It scores `.fth` files for tokens in your prompt and includes only the top excerpts. Default folder: **`Library/Sample`**.

## Streaming

Ask and Enhance stream into the editor tab as tokens arrive. Status / the **Ask** button show **Streaming…** once text starts. Body text written to `AskForth-N.fth` is **word-wrapped at 80 columns** (existing newlines are kept; overlong tokens are hard-broken).

## Related

- Headless eval details: [Agent-channel.md](Agent-channel.md)  
- Roadmap note: repo root `ROADMAP.md` §5  
