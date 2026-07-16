# Pattern 2: Haiku Compression Layer for Confluence & GitLab
## Large Document → Specific Fact, Locally

This guide walks you through building an agent loop where large Confluence pages
and GitLab file/MR responses are intercepted and compressed by a cheap Haiku call
before entering the main agent context.

---

## How It Works (Architecture)

```
Your Agent (Opus/Sonnet)
    │
    ├─► MCP Tool: Confluence / GitLab → large raw response (10k–200k tokens)
    │
    ├─► [Haiku compression call]   ← this is what we're building
    │       - costs ~0.1¢ per call
    │       - shrinks payload to <500 tokens
    │       - you choose extraction mode (see Section 2)
    │
    └─► Compact result enters main context ✓
```

---

## Section 1: Prerequisites

### 1.1 Get your Anthropic API key

```bash
# Set it in your shell profile (add to ~/.zshrc or ~/.bashrc)
export ANTHROPIC_API_KEY="sk-ant-..."
```

### 1.2 Install MCP connectors

Both Confluence and GitLab are available as MCP servers you connect via Claude.ai
settings (Settings → Integrations). For local agent use, you'll call them through
the Anthropic API's `mcp_servers` parameter — no separate install needed.

Confirm you have access to:
- Atlassian/Confluence MCP: `https://mcp.atlassian.com/v1/mcp`
- GitLab MCP: you'll need to host or use a community GitLab MCP server
  (see Section 1.3)

### 1.3 GitLab MCP Options

GitLab doesn't have an official hosted MCP yet. Two practical options:

**Option A — Use the community server (recommended for local use):**
```bash
npx @modelcontextprotocol/server-gitlab
# Set GITLAB_PERSONAL_ACCESS_TOKEN in your env
export GITLAB_PERSONAL_ACCESS_TOKEN="glpat-..."
```

**Option B — Use GitLab's REST API directly as a "tool" in your agent**
(shown in the code examples below — simpler, no MCP dependency)

---

## Section 2: Extraction Modes

Choose one (or combine) based on what you need from the document:

| Mode | What you get | Best for |
|------|-------------|----------|
| **A — Structured fields** | Compact JSON with specific named fields | Jira-like metadata, page properties, MR details |
| **B — Prose summary** | 2–5 sentence narrative | Long wiki pages, changelogs, READMEs |
| **C — Q&A / specific fact** | Direct answer to your question | "What is the deployment process?" |
| **D — Key points list** | Bullet list of main points | Meeting notes, decisions, specs |
| **E — Code extraction** | Specific function/class/block from a file | GitLab file contents |

The compression prompt changes per mode. All modes are shown in the code examples.

---

## Section 3: Python Implementation

### 3.1 Install dependencies

```bash
pip install anthropic httpx
```

### 3.2 Core compression function

```python
# compressor.py
import anthropic
import json

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env

EXTRACTION_PROMPTS = {
    "fields": """Extract ONLY the specified fields from the document and return 
as a compact JSON object. Include no other text, no markdown fences, no prose.
If a field is not found, use null.""",

    "summary": """Summarize this document in 3-5 sentences maximum. 
Capture the most important information only. Return plain prose, no headers.""",

    "qa": """Answer the question using only information from the document.
Be direct and concise. If the answer is not in the document, say 'Not found.'
Return plain prose, maximum 3 sentences.""",

    "keypoints": """Extract the key points as a compact bullet list.
Maximum 8 bullets. Each bullet max 15 words. Return only the bullets, no intro.""",

    "code": """Extract only the requested code block(s) from the document.
Include the function/class signature and body. Omit all surrounding prose.
Return only the code, with a one-line comment above each block naming it.""",
}


def compress(
    raw_content: str,
    mode: str,
    *,
    fields: list[str] | None = None,
    question: str | None = None,
    code_target: str | None = None,
    max_tokens: int = 800,
) -> str:
    """
    Compress a large document using Haiku.
    
    Args:
        raw_content: The raw text/JSON from the MCP tool.
        mode: One of 'fields', 'summary', 'qa', 'keypoints', 'code'.
        fields: For mode='fields', list of field names to extract.
        question: For mode='qa', the question to answer.
        code_target: For mode='code', description of what to extract.
        max_tokens: Max tokens in the compressed output (default 800).
    
    Returns:
        Compressed string ready to inject into main agent context.
    """
    system = EXTRACTION_PROMPTS[mode]

    # Build the user message based on mode
    if mode == "fields" and fields:
        user_msg = f"Fields to extract: {', '.join(fields)}\n\nDocument:\n{raw_content}"
    elif mode == "qa" and question:
        user_msg = f"Question: {question}\n\nDocument:\n{raw_content}"
    elif mode == "code" and code_target:
        user_msg = f"Extract: {code_target}\n\nDocument:\n{raw_content}"
    else:
        user_msg = f"Document:\n{raw_content}"

    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=max_tokens,
        system=system,
        messages=[{"role": "user", "content": user_msg}],
    )

    return response.content[0].text
```

### 3.3 Confluence integration

```python
# confluence_agent.py
import anthropic
import json
from compressor import compress

client = anthropic.Anthropic()

MCP_SERVERS = [
    {
        "type": "url",
        "url": "https://mcp.atlassian.com/v1/mcp",
        "name": "atlassian",
    }
]


def fetch_confluence_page_compressed(
    page_id: str,
    mode: str,
    **compression_kwargs,
) -> str:
    """
    Fetch a Confluence page via MCP, compress it with Haiku,
    return compact result.
    """
    # Step 1: Ask the agent to fetch the page — one dedicated fetch call
    fetch_response = client.messages.create(
        model="claude-sonnet-4-6",  # main agent model
        max_tokens=4096,
        system="""You are a document fetcher. Use the available MCP tools to 
fetch the requested Confluence page. Return ONLY the raw page content 
as plain text. Do not summarize, do not add commentary.""",
        messages=[
            {
                "role": "user",
                "content": f"Fetch Confluence page with ID: {page_id}. "
                           f"Return the full page body as plain text.",
            }
        ],
        mcp_servers=MCP_SERVERS,
    )

    # Extract the raw content from the response
    raw_content = _extract_text(fetch_response)

    # Step 2: Compress with Haiku — cheap, fast, targeted
    compressed = compress(raw_content, mode, **compression_kwargs)

    return compressed


def _extract_text(response) -> str:
    """Pull plain text from an Anthropic API response."""
    return " ".join(
        block.text
        for block in response.content
        if hasattr(block, "text")
    )


# ── Main agent loop ──────────────────────────────────────────────────────────

def run_agent(user_query: str, page_id: str):
    """
    Full agent loop: fetch + compress Confluence page, then answer query.
    Main agent context only ever sees the compressed version.
    """
    print("Step 1: Fetching and compressing Confluence page...")

    # Choose your extraction mode here:
    compressed_page = fetch_confluence_page_compressed(
        page_id,
        mode="qa",               # change to 'summary', 'fields', etc.
        question=user_query,     # used in qa mode
    )

    print(f"Compressed ({len(compressed_page)} chars): {compressed_page[:200]}...")
    print("\nStep 2: Main agent reasoning with compressed context...")

    # Step 3: Main agent — only sees the compressed fact, not the raw page
    final_response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system="You are a helpful assistant. Answer based on the provided context.",
        messages=[
            {
                "role": "user",
                "content": (
                    f"Context (extracted from Confluence page {page_id}):\n"
                    f"{compressed_page}\n\n"
                    f"User question: {user_query}"
                ),
            }
        ],
    )

    return _extract_text(final_response)


if __name__ == "__main__":
    answer = run_agent(
        user_query="What is the deployment process for the payments service?",
        page_id="123456789",  # replace with your actual Confluence page ID
    )
    print("\nFinal Answer:", answer)
```

### 3.4 GitLab integration

```python
# gitlab_agent.py
import httpx
import os
from compressor import compress

GITLAB_TOKEN = os.environ["GITLAB_PERSONAL_ACCESS_TOKEN"]
GITLAB_BASE = "https://gitlab.com/api/v4"  # or your self-hosted URL


def fetch_gitlab_file_compressed(
    project_id: str,      # e.g. "myorg%2Fmyrepo" (URL-encoded)
    file_path: str,       # e.g. "src/payments/deploy.py"
    ref: str = "main",
    mode: str = "code",
    **compression_kwargs,
) -> str:
    """Fetch a GitLab file and compress it before returning."""
    url = f"{GITLAB_BASE}/projects/{project_id}/repository/files/{file_path.replace('/', '%2F')}/raw"
    
    resp = httpx.get(
        url,
        headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
        params={"ref": ref},
    )
    resp.raise_for_status()
    raw_content = resp.text

    print(f"Raw file: {len(raw_content)} chars → compressing...")
    return compress(raw_content, mode, **compression_kwargs)


def fetch_gitlab_mr_compressed(
    project_id: str,
    mr_iid: int,          # MR number (not global ID)
    mode: str = "summary",
    **compression_kwargs,
) -> str:
    """Fetch a GitLab MR description + thread and compress it."""
    # Fetch MR details
    mr_resp = httpx.get(
        f"{GITLAB_BASE}/projects/{project_id}/merge_requests/{mr_iid}",
        headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
    )
    mr_resp.raise_for_status()
    mr = mr_resp.json()

    # Fetch MR notes/comments
    notes_resp = httpx.get(
        f"{GITLAB_BASE}/projects/{project_id}/merge_requests/{mr_iid}/notes",
        headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
        params={"per_page": 100},
    )
    notes = notes_resp.json() if notes_resp.status_code == 200 else []

    # Combine into one document for compression
    raw_content = (
        f"MR Title: {mr['title']}\n"
        f"Author: {mr['author']['name']}\n"
        f"State: {mr['state']}\n"
        f"Description:\n{mr.get('description', '')}\n\n"
        f"Comments:\n" +
        "\n".join(
            f"- {n['author']['name']}: {n['body']}"
            for n in notes
            if not n.get("system", False)
        )
    )

    print(f"Raw MR content: {len(raw_content)} chars → compressing...")
    return compress(raw_content, mode, **compression_kwargs)


# ── Usage examples ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Example 1: Extract a specific function from a large source file
    code_result = fetch_gitlab_file_compressed(
        project_id="myorg%2Fpayments-service",
        file_path="src/payments/processor.py",
        mode="code",
        code_target="the PaymentProcessor class and its process() method",
    )
    print("Code extraction:\n", code_result)

    # Example 2: Summarize a merge request
    mr_result = fetch_gitlab_mr_compressed(
        project_id="myorg%2Fpayments-service",
        mr_iid=42,
        mode="summary",
    )
    print("MR summary:\n", mr_result)

    # Example 3: Answer a specific question from a large README
    qa_result = fetch_gitlab_file_compressed(
        project_id="myorg%2Fpayments-service",
        file_path="README.md",
        mode="qa",
        question="What environment variables are required to run this service?",
    )
    print("Q&A result:\n", qa_result)
```

---

## Section 4: TypeScript / Node.js Implementation

### 4.1 Install dependencies

```bash
mkdir haiku-compression && cd haiku-compression
npm init -y
npm install @anthropic-ai/sdk node-fetch
npm install -D typescript tsx @types/node
npx tsc --init
```

### 4.2 Core compression function

```typescript
// compressor.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic(); // reads ANTHROPIC_API_KEY from env

type ExtractionMode = "fields" | "summary" | "qa" | "keypoints" | "code";

interface CompressOptions {
  mode: ExtractionMode;
  fields?: string[];       // for mode: 'fields'
  question?: string;       // for mode: 'qa'
  codeTarget?: string;     // for mode: 'code'
  maxTokens?: number;
}

const EXTRACTION_PROMPTS: Record<ExtractionMode, string> = {
  fields: `Extract ONLY the specified fields and return as compact JSON.
No markdown fences, no prose. Use null for missing fields.`,

  summary: `Summarize in 3-5 sentences maximum. 
Most important information only. Plain prose, no headers.`,

  qa: `Answer the question using only information from the document.
Direct and concise, max 3 sentences. Say 'Not found.' if absent.`,

  keypoints: `Extract key points as a compact bullet list.
Max 8 bullets. Each bullet max 15 words. Only bullets, no intro.`,

  code: `Extract only the requested code block(s).
Include signatures and bodies. Omit surrounding prose.
One-line comment above each block naming it.`,
};

export async function compress(
  rawContent: string,
  options: CompressOptions
): Promise<string> {
  const { mode, fields, question, codeTarget, maxTokens = 800 } = options;

  const system = EXTRACTION_PROMPTS[mode];

  let userMsg: string;
  if (mode === "fields" && fields?.length) {
    userMsg = `Fields to extract: ${fields.join(", ")}\n\nDocument:\n${rawContent}`;
  } else if (mode === "qa" && question) {
    userMsg = `Question: ${question}\n\nDocument:\n${rawContent}`;
  } else if (mode === "code" && codeTarget) {
    userMsg = `Extract: ${codeTarget}\n\nDocument:\n${rawContent}`;
  } else {
    userMsg = `Document:\n${rawContent}`;
  }

  const response = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: maxTokens,
    system,
    messages: [{ role: "user", content: userMsg }],
  });

  const block = response.content[0];
  if (block.type !== "text") throw new Error("Unexpected response type");
  return block.text;
}
```

### 4.3 Confluence integration

```typescript
// confluence-agent.ts
import Anthropic from "@anthropic-ai/sdk";
import { compress } from "./compressor.js";

const client = new Anthropic();

const MCP_SERVERS = [
  {
    type: "url" as const,
    url: "https://mcp.atlassian.com/v1/mcp",
    name: "atlassian",
  },
];

function extractText(response: Anthropic.Message): string {
  return response.content
    .filter((b): b is Anthropic.TextBlock => b.type === "text")
    .map((b) => b.text)
    .join(" ");
}

async function fetchConfluencePageCompressed(
  pageId: string,
  options: Parameters<typeof compress>[1]
): Promise<string> {
  // Step 1: Dedicated fetch call — main model fetches, returns raw content
  const fetchResponse = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 4096,
    system: `You are a document fetcher. Use MCP tools to fetch the Confluence page.
Return ONLY the raw page body as plain text. No commentary, no summary.`,
    messages: [
      {
        role: "user",
        content: `Fetch Confluence page ID: ${pageId}. Return full body as plain text.`,
      },
    ],
    // @ts-ignore — mcp_servers is supported but may not be in current typedefs
    mcp_servers: MCP_SERVERS,
  });

  const rawContent = extractText(fetchResponse);

  // Step 2: Compress with Haiku
  return compress(rawContent, options);
}

export async function runAgent(userQuery: string, pageId: string): Promise<string> {
  console.log("Step 1: Fetching and compressing Confluence page...");
  
  const compressedPage = await fetchConfluencePageCompressed(pageId, {
    mode: "qa",
    question: userQuery,
  });

  console.log(`Compressed (${compressedPage.length} chars): ${compressedPage.slice(0, 200)}...`);
  console.log("\nStep 2: Main agent reasoning with compressed context...");

  // Step 3: Main agent — sees only the compressed fact
  const finalResponse = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    system: "You are a helpful assistant. Answer based on the provided context.",
    messages: [
      {
        role: "user",
        content:
          `Context (extracted from Confluence page ${pageId}):\n${compressedPage}\n\n` +
          `User question: ${userQuery}`,
      },
    ],
  });

  return extractText(finalResponse);
}

// Run
const answer = await runAgent(
  "What is the deployment process for the payments service?",
  "123456789" // replace with your Confluence page ID
);
console.log("\nFinal Answer:", answer);
```

### 4.4 GitLab integration

```typescript
// gitlab-agent.ts
import { compress } from "./compressor.js";

const GITLAB_TOKEN = process.env.GITLAB_PERSONAL_ACCESS_TOKEN!;
const GITLAB_BASE = process.env.GITLAB_BASE_URL ?? "https://gitlab.com/api/v4";

async function gitlabGet(path: string, params?: Record<string, string>) {
  const url = new URL(`${GITLAB_BASE}${path}`);
  if (params) Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
  const resp = await fetch(url.toString(), {
    headers: { "PRIVATE-TOKEN": GITLAB_TOKEN },
  });
  if (!resp.ok) throw new Error(`GitLab API error: ${resp.status} ${path}`);
  return resp;
}

export async function fetchGitlabFileCompressed(
  projectId: string,          // URL-encoded: "myorg%2Fmyrepo"
  filePath: string,            // "src/payments/processor.py"
  ref: string = "main",
  options: Parameters<typeof compress>[1]
): Promise<string> {
  const encodedPath = filePath.replaceAll("/", "%2F");
  const resp = await gitlabGet(
    `/projects/${projectId}/repository/files/${encodedPath}/raw`,
    { ref }
  );
  const rawContent = await resp.text();
  console.log(`Raw file: ${rawContent.length} chars → compressing...`);
  return compress(rawContent, options);
}

export async function fetchGitlabMrCompressed(
  projectId: string,
  mrIid: number,
  options: Parameters<typeof compress>[1]
): Promise<string> {
  const [mrResp, notesResp] = await Promise.all([
    gitlabGet(`/projects/${projectId}/merge_requests/${mrIid}`),
    gitlabGet(`/projects/${projectId}/merge_requests/${mrIid}/notes`, {
      per_page: "100",
    }),
  ]);

  const mr = await mrResp.json() as any;
  const notes = await notesResp.json() as any[];

  const rawContent = [
    `MR Title: ${mr.title}`,
    `Author: ${mr.author.name}`,
    `State: ${mr.state}`,
    `Description:\n${mr.description ?? ""}`,
    `Comments:\n` +
      notes
        .filter((n) => !n.system)
        .map((n) => `- ${n.author.name}: ${n.body}`)
        .join("\n"),
  ].join("\n\n");

  console.log(`Raw MR content: ${rawContent.length} chars → compressing...`);
  return compress(rawContent, options);
}

// ── Usage examples ────────────────────────────────────────────────────────────

// Example 1: Extract a specific function from a large file
const codeResult = await fetchGitlabFileCompressed(
  "myorg%2Fpayments-service",
  "src/payments/processor.py",
  "main",
  { mode: "code", codeTarget: "the PaymentProcessor class and process() method" }
);
console.log("Code extraction:\n", codeResult);

// Example 2: Summarize a merge request
const mrResult = await fetchGitlabMrCompressed(
  "myorg%2Fpayments-service",
  42,
  { mode: "summary" }
);
console.log("MR summary:\n", mrResult);

// Example 3: Q&A from a large README
const qaResult = await fetchGitlabFileCompressed(
  "myorg%2Fpayments-service",
  "README.md",
  "main",
  {
    mode: "qa",
    question: "What environment variables are required to run this service?",
  }
);
console.log("Q&A result:\n", qaResult);
```

---

## Section 5: Wiring Into a Multi-Step Agent Loop

This is the full pattern where the compression layer sits between every MCP call
and the main agent context in a real agentic loop:

```python
# full_loop.py (Python version — same pattern applies in TypeScript)
import anthropic
from compressor import compress

client = anthropic.Anthropic()

def agent_loop(user_goal: str, max_steps: int = 10):
    """
    Multi-step agent that auto-compresses all document fetches.
    The main model never sees raw Confluence/GitLab responses.
    """
    messages = [{"role": "user", "content": user_goal}]
    
    for step in range(max_steps):
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            system="""You are a helpful agent with access to Confluence and GitLab.
When you need to read a document, fetch it and I will compress it for you.
Plan your approach, then act step by step.""",
            messages=messages,
            mcp_servers=[
                {"type": "url", "url": "https://mcp.atlassian.com/v1/mcp", "name": "atlassian"},
            ],
        )
        
        # Check if the model used any MCP tools
        tool_results = []
        for block in response.content:
            if block.type == "mcp_tool_result":
                raw = block.content[0].text if block.content else ""
                
                # ← COMPRESSION HAPPENS HERE, before re-entering context
                compressed = compress(
                    raw,
                    mode="summary",      # or pick mode based on tool name
                    max_tokens=500,
                )
                tool_results.append({
                    "original_length": len(raw),
                    "compressed_length": len(compressed),
                    "compressed": compressed,
                })
        
        # Add the model turn to history
        messages.append({"role": "assistant", "content": response.content})
        
        # If tool results exist, inject compressed versions (not raw)
        if tool_results:
            compressed_injection = "\n\n".join(
                f"[Tool result {i+1}, compressed from {r['original_length']} → "
                f"{r['compressed_length']} chars]:\n{r['compressed']}"
                for i, r in enumerate(tool_results)
            )
            messages.append({
                "role": "user",
                "content": f"Tool results (compressed):\n{compressed_injection}",
            })
        
        # Stop if no more tool calls
        if response.stop_reason == "end_turn":
            final_text = next(
                (b.text for b in response.content if hasattr(b, "text")), ""
            )
            return final_text
    
    return "Max steps reached."
```

---

## Section 6: Cost & Token Estimates

For reference, Haiku pricing (as of early 2026):
- Input: ~$0.80 / 1M tokens
- Output: ~$4.00 / 1M tokens

| Scenario | Raw response | After Haiku compression | Compression call cost |
|----------|-------------|------------------------|----------------------|
| Confluence page (long spec) | ~8,000 tokens | ~400 tokens | ~$0.007 |
| GitLab file (large module) | ~15,000 tokens | ~600 tokens | ~$0.013 |
| GitLab MR + 50 comments | ~6,000 tokens | ~300 tokens | ~$0.005 |

On a main Sonnet context, each 1,000 tokens saved in the conversation history
saves ~$0.003 per subsequent turn. If your agent runs 10 turns, a single
compression that saves 8,000 tokens saves ~$0.24 in downstream costs — vs
a one-time Haiku call costing $0.007. **~34× ROI on a single document.**

---

## Section 7: Quick Reference — Extraction Mode Prompts

Modify `EXTRACTION_PROMPTS` in `compressor.py` / `compressor.ts` to tune per use case:

```
Mode: fields   → use when you need structured data (metadata, configs, tables)
Mode: summary  → use for narrative content (specs, READMEs, MR descriptions)
Mode: qa       → use when the agent has a specific question to answer
Mode: keypoints→ use for meeting notes, decisions, lists of requirements
Mode: code     → use when fetching source files and you need specific functions
```

You can also **combine modes** in a single compression call by chaining prompts:
```python
# Hybrid: fields + summary
system = """First, extract these fields as JSON: title, owner, status.
Then, on a new line, add a one-sentence prose summary of the document's purpose.
Return: JSON object on line 1, summary sentence on line 2. Nothing else."""
```

---

## Next Steps

- Add **caching** to skip re-compressing the same page ID within a session
- Add **mode auto-selection** based on the tool name (Confluence → summary, GitLab file → code)
- Connect the compressed results to a **vector store** for multi-document retrieval
- Use the **MCP server** (`@ccusage/mcp` pattern) to expose compressed results to Claude Desktop
