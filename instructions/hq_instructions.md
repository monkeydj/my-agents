# Skill: Document Compression

## Rule — always apply before reasoning over large documents

When you fetch content from Confluence or GitLab that is longer than ~2,000
words, DO NOT reason over it directly. First compress it yourself:

1. Read the raw content
2. Produce a compressed version using the appropriate mode below
3. Reason only over the compressed version — discard the raw content

## Compression modes — choose based on the task

**Summary** (general understanding needed)
→ Rewrite in 3-5 sentences capturing only the most important points.

**Q&A** (specific question to answer)
→ Extract only the sentences/paragraphs relevant to the question.
   Answer directly in 2-3 sentences. Prefix with: [Extracted answer]

**Key points** (spec, decisions, requirements)
→ Bullet list, max 8 points, max 15 words each.

**Fields** (metadata needed)
→ Return a compact JSON object with only the requested fields.

**Code extraction** (GitLab source file)
→ Return only the requested function/class and its signature. No prose.

## Format your compression output as:

[Compressed — mode: <mode>, original: ~<N> words]
<compressed content here>

Then continue with the task using only this block.