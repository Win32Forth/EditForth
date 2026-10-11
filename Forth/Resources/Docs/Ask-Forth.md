# Ask Forth

**Public domain.** Local AI assistant built into EditForth (**View → Ask Forth**, ⌥⌘A). Shipped with **EditForth 2.3.0**.

## Requirements (local models)

Ask Forth talks to **[Ollama](https://ollama.com)** on this Mac (`http://127.0.0.1:11434`). Without Ollama running and a model installed, **Ask** and **Fix from Agent** will report that the model is unreachable.

1. Install the **Ollama** app (or CLI) from https://ollama.com  
2. Pull a model, for example:

```bash
ollama pull gemma4:e4b
```

3. Leave Ollama running, then use EditForth.

**Default model** in the panel is **`gemma4:e4b`** (good balance of speed and quality on a 24 GB Apple Silicon Mac). Change the **Model** field to try others that Ollama knows, for example:

| Model | Notes |
|-------|--------|
| `gemma4:e4b` | Default. Fast enough for interactive Ask / Fix. |
| `gemma4:12b` | Stronger answers; much slower and heavier on memory. |
| `gemma4:31b-cloud` | Fast replies via Ollama’s cloud path — **not** fully local. |

## Basic workflow

1. Start **EditForth** (opens an untitled buffer and can start the Forth companion).  
2. **View → Ask Forth** (or ⌥⌘A).  
3. Type a question in **Prompt**, or **Capture Context** from the editor selection / caret.  
4. Optionally enable **Include Library context** and open **Library…** to choose a folder (for example `~/Documents/EditForth/Library/Sample` or `…/Classes`) and snippet limits.  
5. Click **Ask**.  
6. **Insert into Editor** to paste the reply into the untitled (or current) buffer, or **Copy Reply**.  
7. **Eval Reply** / **Eval Prompt** runs a separate headless `64Forth --agent` process and shows the transcript (does not inject into the live companion console).  
8. **Fix from Agent** sends the transcript plus the prior answer back to the model for a revised reply — then Eval again.

## Library context

Library search does **not** send the whole tree. It scores `.fth` files for tokens in your prompt and includes only the top excerpts (folder, max snippets, context lines, and max characters are set in **Library…**).

Example: point Library at `Library/Sample` (which contains `CLOCK.fth` / `GCLOCK.FTH` and related clock samples) and ask something like **“Make me a clock”** without naming the file. The model may extract pieces of those samples into a starting point. That draft often will not run as-is, but it can get surprisingly close and is a useful starting point for **Fix from Agent** / hand edits.

## Related

- Headless eval details: [Agent-channel.md](Agent-channel.md)  
- Roadmap note: repo root `ROADMAP.md` §5  
