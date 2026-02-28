# BTS Knowledge Base Ingestion Plan

> Plan for embedding BTS conversation history into a local vector database.
> Companion to `BTS_Technical_Reference.md` — separated during v2 cleanup.

---

## Target Environment

- Mac mini M4 Pro (local development workstation)

## Ingestion Steps

1. Copy all BTS `.md` files from extraction to Mac mini knowledge base directory
2. Chunk by conversation section (≈500 token chunks with overlap)
3. Embed with OpenAI `text-embedding-3-small` or Anthropic embeddings
4. Store in local vector DB (ChromaDB or pgvector recommended)
5. Tag each chunk with metadata: `system` = BTS, `date`, `topic`, `keywords_hit`
6. Process `conversations-006.json` and merge into the same DB

## Status

- Not yet started as of 2026-02-28
- Dependent on Mac mini setup completion

---

*Moved from BTS_Technical_Reference.md v1 (section 8) during v2 restructuring — 2026-02-28*
