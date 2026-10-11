# Ask Forth — more ideas (web, HTML, navigation)

**Public domain.** Planning notes for EditForth **Ask Forth** beyond the shipped local Ollama + Library RAG + `AskForth-N.fth` workflow. Items marked **done** are in the working tree (may be unreleased).

Related: `Forth/Resources/Docs/Ask-Forth.md`, `ROADMAP.md` §5, `Library/Reference/` (Forth 2012 text).

---

## Current baseline (shipped)

- Local **Ollama** only; models do not browse the network by themselves.
- **Library context** scores `.fth` / `.txt` under a chosen folder (default **Sample**) and always also searches **`Library/Reference`** (Forth 2012 chapters).
- Ask streams into **`~/Documents/EditForth/AskForth-N.fth`**; **Agent Enhance Reply** appends after a headless `--agent` eval.
- Live load of edited code stays on status **INCLUDE**.

Any “web access” would mean **EditForth fetches** pages or search hits on the Mac, then **injects capped text into the LLM prompt** (same seam as Library RAG), with an explicit user opt-in where privacy matters.

---

## 1. Web context for Ask Forth

### 1.1 Opt-in “Fetch URLs in Prompt” (highest value / lowest risk) — **done (working tree)**

**Idea:** If the Prompt contains `http://` or `https://` links, EditForth fetches those URLs, strips to plain text (or lightweight Markdown), caps size, and appends excerpts to the Ask / Enhance user message.

**Implemented:** `AskForthURLFetch.swift`; panel toggle **Fetch URLs in Prompt** (default on); Ask / Agent Enhance Reply status `· Web N page(s)`.

**Why useful**

- User stays in control (only pages they named).
- No search-API keys.
- Fits local-first: works with `gemma4:e4b` and with cloud Ollama tags alike.
- Natural for forth-standard.org word pages, GitHub READMEs, and project docs.

**Design notes**

- Default **on** once implemented is reasonable if limited to URLs already in the Prompt; or a checkbox **Fetch URLs in Prompt**.
- Timeouts, max bytes per URL, max URLs per Ask, and HTTPS-only policy.
- Show fetch status in the Ask status line (`Fetched 2 URLs…` / errors).
- Do not execute scripts; strip HTML to text (same spirit as Library `.txt` Reference).

### 1.2 Opt-in web search for Ask / Agent Enhance Reply

**Idea:** Checkbox **Include web search**. Derive a search query from the Prompt (or use it verbatim), call a search provider (Brave / Bing / DuckDuckGo-style API), take the top few snippets + titles + URLs, and add them beside Library context.

**Why useful**

- Helps when offline `Library/Reference` and Sample are not enough (newer Forth-200x notes, error messages, obscure examples).
- Complements URL fetch when the user does not already know which page to open.

**Design notes**

- Default **off** (privacy + network + possible API key).
- Prefer a provider that works with a user-supplied key stored in Keychain, or a keyless scraping-free API if one stays stable.
- Cap snippets hard (same order of magnitude as Library `maxChars`).
- Optionally list the hit URLs in the AskForth file as `\ Web: …` comments for auditability.

### 1.3 Forth-standard.org helper (narrow, on-brand) — **done (working tree)**

**Idea:** When the Prompt looks like a word lookup (“What does `OPEN-FILE` do?”, “stack effect of `INCLUDE-FILE`”), also fetch the matching live page on [forth-standard.org](https://forth-standard.org/) and include a capped excerpt.

**Implemented:** `AskForthStandardBoost.swift` + `Library/Reference/Forth-2012-word-urls.json` (~430 words). Tied to **Fetch URLs in Prompt**. Status `· Standard WORD`.

**Why useful**

- Offline Reference chapters are strong; the live site often has extra navigation, cross-links, and discussion affordances.
- Small scope; no general search required.

**Design notes**

- Heuristic: Forth-ish token in quotes/backticks, or “what does WORD”, or Core-looking names.
- Map word → standard URL carefully (word sets: core, file, float, …).
- Fail soft if the page 404s; Library Reference remains the fallback.
- Can share the same HTML→text pipeline as §1.1.

### 1.4 Full tool-calling agent (later)

**Idea:** Ollama tool loop where the model may call `search`, `fetch_url`, or `library_search`, see results, then answer.

**Why useful**

- Most flexible; model decides when browsing helps.

**Why later**

- Slower, harder to debug, easier to wander and burn tokens.
- Needs clear UI for “tools used” (transcript of fetches).
- Build after §1.1–1.3 prove the fetch/search plumbing.

### Suggested build order

1. **URL fetch** (§1.1)  
2. **forth-standard.org boost** (§1.3) reusing that fetcher  
3. **Opt-in web search** (§1.2)  
4. **Tool-calling** (§1.4) only if 1–3 still feel limited  

Cloud tags such as `gemma4:31b-cloud` may *feel* better informed; that is **not** the same as EditForth-controlled, visible web context.

---

## 2. HTML viewing in the editor (and link clicking)

### Possibility — **done (working tree)**

Yes. EditForth already hosts multiple tab kinds (source, compare-with-disk, etc.). A **Web / HTML tab** (WKWebView) is a normal macOS pattern: open a URL or local HTML file in a tab beside `.fth` buffers.

**Implemented:** `WebSession` / `WebBrowserView`; **View → Open Web Page…** (⇧⌘L); Back / Forward / URL / Reload / **Send to Ask Forth**; link clicks navigate in-tab (`http`/`https`/`file`/`about`).

### What would be useful

- Open fetched Ask URLs or search hits **in a tab** (“Open in Editor”) instead of only stuffing text into the model.
- Browse [forth-standard.org](https://forth-standard.org/) or local `file:` docs without leaving EditForth.
- Click a link in that page and navigate **inside the same tab** (normal web behavior).
- From a Web tab, **Send page to Ask Forth** (current URL + optional selection → Prompt / URL-fetch context).

### How it might work

- New tab type: `EditorTab` / view mode **web** with `WKWebView`, URL field or fixed URL from Open Link.
- Link clicks: allow navigation within http(s) and maybe `file:` under Documents/EditForth; block dangerous schemes.
- Optional: intercept clicks on `.fth` / project links and open them as code tabs instead of downloading.
- Security: no mixing WebKit arbitrary JS with the Forth kernel; Web tabs are view-only relative to the dictionary. Sandbox / ATS as for any Mac app that loads remote HTML.

### Limits and cautions

- A full browser chrome (bookmarks, many tabs, extensions) is out of scope; keep it a **doc browser**, not Safari.
- Heavy SPAs may work poorly; plain HTML (standard site, READMEs) is the target.
- Offline Library Reference `.txt` remains better for RAG than scraping live HTML every Ask.

### Relation to Ask Forth

HTML viewing is **orthogonal but complementary** to §1:

| Path | Role |
|------|------|
| Fetch → text → LLM | Model answers with citations |
| Open URL in Web tab | Human reads the real page |
| “Send to Ask Forth” | Bridge from reading to asking |

Implementing §1 without a Web tab is still valuable. A Web tab without fetch-to-LLM is still valuable for reading the standard. Together they feel like a small Forth IDE browser.

---

## 3. Forward / Back at the top left of the editor

### Possibility — **done for Web tabs (working tree)**

Yes. Two common meanings:

**A. Web navigation (Back / Forward)** — **done**  
Enabled on the Web tab chrome (top left of the editor area); drive `WKWebView.goBack()` / `goForward()`. Not shown on plain `.fth` tabs.

**B. Editor tab / location history**  
A global history stack of (tab identity, URL or file URL, scroll/caret). Back/Forward moves through places you visited—including code tabs and Web tabs. Closer to an IDE “Navigate Back” than to browser buttons.

### Most useful for EditForth

- If Web tabs ship: put **Back / Forward** at the **top left of the editor chrome**, active for Web tabs (meaning **A**), with optional later upgrade to **B** so Back also returns from a Web tab to the `.fth` you came from.
- Tooltips: “Back” / “Forward” when web; later “Previous location” if history is unified.
- Keyboard: ⌘[ / ⌘] or ⌃⌘← / ⌃⌘→ (match platform norms; avoid stealing Forth-critical shortcuts).

### Without Web tabs

Back/Forward for **code-only** history (recent tabs + caret positions) is still useful after Search in Folders, Hyper jumps, or AskForth file switches—but it is a different feature from “browser buttons.” Prefer implementing them together with §2 so the top-left controls have an obvious meaning.

### Layout sketch

```text
[ ← ] [ → ]   path or URL ……………………………  (tab bar / traffic lights as today)
```

Keep the controls small; do not displace Run / INCLUDE status strip behavior.

---

## 4. Privacy and product rules (for any of the above)

- Network features **opt-in** except perhaps fetching URLs the user already pasted.
- Never send Library paths or AskForth file contents to a search provider unless the user asked for web search with that context.
- Prefer showing **what was fetched** (status line, optional `\ Web:` comments in `AskForth-N.fth`, or an Agent-style “Web transcript” disclosure).
- Document keys and providers in `Ask-Forth.md` when implemented.
- Keep **Ollama local-first**; web context is optional seasoning, not a requirement to use Ask Forth.

---

## 5. Rough priority summary

| Priority | Item | Depends on |
|----------|------|------------|
| 1 | Fetch URLs in Prompt → LLM context | HTML→text helper |
| 2 | forth-standard.org word boost | Same fetcher |
| 3 | Web / HTML tab + link clicking | WKWebView tab type |
| 4 | Back / Forward (web, top-left) | Web tab |
| 5 | Opt-in web search | Search provider + UI |
| 6 | Unified location history Back/Forward | Tab + web history |
| 7 | Tool-calling browse agent | Stable fetch + search + UI |

---

## 6. Out of scope (for now)

- Replacing Ollama with a cloud-only chat that “has browsing” with no local control.
- Turning EditForth into a general-purpose web browser.
- Auto-INCLUDE of downloaded HTML or arbitrary remote Forth without review.
- Indexing PDF standards inside RAG without a text extraction path (Reference already uses `.txt`).
