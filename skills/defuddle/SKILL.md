---
name: defuddle
description: Extract clean markdown content from web pages using Defuddle CLI (via npx), removing clutter and navigation to save tokens. Use instead of WebFetch when the user provides a URL to read or analyze, for online documentation, articles, blog posts, or any standard web page.
---

# Defuddle

Use the Defuddle CLI via `npx` to extract clean readable content from web pages. Prefer over WebFetch for standard web pages — it removes navigation, ads, and clutter, reducing token usage.

No global install required. Run with `npx -y defuddle` (the older `defuddle-cli` package is deprecated and merged into `defuddle`).

## Usage

Always use `--md` for markdown output:

```bash
npx -y defuddle parse <url> --md
```

Save to file:

```bash
npx -y defuddle parse <url> --md -o content.md
```

Extract specific metadata:

```bash
npx -y defuddle parse <url> -p title
npx -y defuddle parse <url> -p description
npx -y defuddle parse <url> -p domain
```

Pipe HTML over stdin (e.g. when `curl` handles redirects/auth better):

```bash
curl -L <url> | npx -y defuddle parse --md
```

## Output formats

| Flag | Format |
|------|--------|
| `--md` | Markdown (default choice) |
| `-f` / `--frontmatter` | Markdown with YAML frontmatter (title, author, source) prepended |
| `--json` / `-j` | JSON with both HTML and markdown |
| (none) | HTML |
| `-p <name>` | Specific metadata property |

## Capabilities

- **Sources**: URL, local HTML file path, or stdin (`parse -`)
- **Markdown conversion**: `--md` / `-m` strips ads, nav, and boilerplate into readable markdown
- **YAML frontmatter**: `-f` / `--frontmatter` prepends metadata (title, author, source) to output
- **Metadata extraction**: `-p <name>` pulls a single property (`title`, `description`, `domain`, author, etc.)
- **JSON output**: `-j` / `--json` returns structured metadata + content in one response
- **File output**: `-o <file>` writes to file instead of stdout
- **Language hint**: `-l <code>` sets preferred content language (BCP 47, e.g. `en`, `ja`)
- **Custom User-Agent**: `-u "<string>"` helps bypass 403/FORBIDDEN responses on sites that block default agents
- **Debug mode**: `--debug` for troubleshooting failed extractions
- **Extractable properties** (usable with `-p <name>`): `title`, `author`, `description`, `domain`, `site`, `favicon`, `image`, `language`, `published`, `wordCount`, plus raw `schemaOrgData` and `metaTags` via JSON output
