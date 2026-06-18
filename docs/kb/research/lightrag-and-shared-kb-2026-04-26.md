---
title: LightRAG vs. Infovore — and what it implies for a shared human/Claude KB
category: research
status: active
tags: [rag, knowledge-graph, infovore, manuals-viewer, shared-kb, retrieval, claude]
created: 2026-04-26
summary: Comparison of LightRAG (graph-augmented RAG) against the Infovore manuals
  viewer we just shipped. The viewer is a finder, LightRAG is an answer engine —
  different layers of the stack. The interesting question is whether LightRAG (or
  something like it) is a fit for a shared human/Claude knowledge base.
---

# LightRAG vs. Infovore — and what it implies for a shared human/Claude KB

## Overview

Triggered by a link to <https://lightrag.github.io> while finishing the Infovore
equipment-manuals viewer. Two questions: **(1)** should we use LightRAG instead
of what we just built? **(2)** is LightRAG (or its underlying idea) a better fit
for a *shared human/Claude knowledge base* — a thing we've been meaning to think
about?

## What LightRAG is

A retrieval-augmented-generation system that:

1. Chunks documents and uses an LLM to extract entities (nodes) and
   relationships (edges) from each chunk.
2. Builds a knowledge graph plus a vector index over keys derived from
   nodes/edges.
3. At query time, classifies a question as "specific" or "abstract", does
   dual-level retrieval (entity-local + theme-spanning), concatenates hits,
   and feeds them to an LLM for a synthesised answer.
4. Supports incremental updates — new docs merge into the existing graph.

Required infra: an LLM API (extraction *and* generation), a graph DB, and a
vector store.

## Comparison with what we just built (Infovore manuals viewer)

The two systems sit at **different layers of the stack** and don't compete:

|                       | Infovore manuals viewer            | LightRAG                          |
|-----------------------|------------------------------------|-----------------------------------|
| User goal             | open the right PDF                 | get a textual answer              |
| Granularity           | document                           | entities + relationships          |
| Retrieval             | SQL filters + LIKE search          | graph traversal + vector match    |
| Answer form           | a PDF                              | LLM-synthesised paragraphs        |
| Latency               | click                              | LLM round-trip                    |
| Infra                 | SQLite + static files              | LLM API + graph DB + vector DB    |
| Visual content        | preserved (you see the diagram)    | flattened to text in the prompt   |
| Cost per query        | free                               | per-token LLM bill                |
| Cost to ingest        | seconds (filesystem walk)          | hundreds of $ for 900 MB of PDFs  |

For the manuals problem, LightRAG is the wrong tool:

- The user wants the *PDF* (panel layouts, signal flow, modulation matrices) —
  text answers can't reproduce those.
- Eurorack manuals aren't densely interconnected the way Wikipedia articles
  are — Plaits' PDF doesn't reference Marbles' PDF. The graph would be sparse.
- Ingestion cost is prohibitive for what a click already solves.

## Ideas worth lifting from LightRAG even without adopting it

| Idea                                                           | Worth doing?                          |
|----------------------------------------------------------------|---------------------------------------|
| Full-text search over PDF content (`pdftotext` + SQLite FTS5)  | Likely yes — biggest leverage, no LLM |
| Cross-document `related_to` table for explicit references      | Cheap to add when there's a use case  |
| LLM Q&A over the manuals corpus                                | Defer — build via Claude API + simple retrieval *if* a concrete need surfaces, not by adopting LightRAG's stack |
| Graph + vector hybrid retrieval                                | Skip — solves a problem we don't have |

## The bigger question: a shared human/Claude KB

The infovore viewer is a *finder* — fine. The harder thing on the horizon is a
KB that **both Andrew and Claude read and write**, where the corpus is
heterogeneous prose: worklogs, decisions, plans, half-formed thoughts, project
context.

For *that* corpus, the shape of LightRAG's idea is a much better fit than for
manuals:

- The cross-references between docs are real and dense ("see decision in
  2026-02-12.md", "extends ARCHITECTURE.md", "blocked by project 184").
- The natural query is a question, not a filename ("what did we conclude
  about X?", "is there prior thinking on Y?").
- There's no visual content that would be lost in flattening to text.
- The corpus is tractable in size — tens of MB, not hundreds.

But LightRAG-the-package is probably still not the right answer:

1. **The hard problem isn't retrieval, it's the write-loop.** Where does Claude
   deposit notes? With what frontmatter? How do humans and agents edit the same
   file without stomping each other? How are stale entries demoted? None of
   that is what LightRAG addresses.
2. **Black-box risk.** When the KB becomes a question-answering system, the
   user loses the cheap muscle of `grep` / "open the file and skim". Active
   recall over your own notes is a feature; only a Q&A surface degrades it.
3. **Lock-in.** A KB that can only be queried via LLM is unusable when the API
   is down or expensive. Plain markdown + grep is the floor we shouldn't lose.
4. **Infrastructure for a small corpus.** Graph DB + vector DB + LLM is heavy
   for what fits in `purescript-polyglot/docs/kb/`.

### What probably *does* fit

- **Markdown stays the ground truth.** Frontmatter discipline (the existing
  `_TEMPLATE.md` pattern) gets stronger: explicit `related:`, `supersedes:`,
  `blocks:` fields. INDEX.md regenerated from frontmatter, not hand-edited.
- **Cheap deterministic search first.** ripgrep over the KB is the workhorse;
  add SQLite FTS5 only if grep stops being enough.
- **An *optional* Q&A layer**, built via Claude API with retrieval over the
  markdown files (no separate graph DB — just embeddings + the markdown
  content fed back into Claude). Wire it as a `/ask-kb` skill, not a service.
- **A documented agent-write contract.** Where Claude writes notes
  (`docs/worklog/YYYY-MM-DD.md` already exists; extend with conventions for
  decisions and "I learned X" entries).

### Adjacent existing affordances to build on

- `docs/worklog/YYYY-MM-DD.md` — already a shared write surface, lightly used.
- `docs/kb/INDEX.md` — already an index, hand-maintained.
- Marginalia — already tracks projects and their state; could host KB pointers
  the way it hosts ports.
- Claude's auto-memory (`~/.claude/projects/*/memory/`) — already accumulates
  user/feedback/project/reference snippets. Distinct from a shared KB, but a
  useful contrast: that's *Claude's* memory, single-direction; the KB would be
  the human-and-Claude shared layer.

## Status / Next Steps

- **Manuals viewer**: keep as built. Optional next pass — add `pdftotext` +
  SQLite FTS5 for in-document search.
- **Shared KB**: the hard work is conventions and the write-loop, not the
  retrieval substrate. Worth a dedicated planning session before adopting any
  retrieval system. If/when retrieval becomes the bottleneck, pick by smallest
  added complexity (SQLite FTS5 → embeddings → graph) rather than starting at
  graph.
