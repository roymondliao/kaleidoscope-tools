# Embedding-Free RAG System — Product Requirements Document

**Version:** 1.0
**Date:** 2026-03-12
**Author:** Lenny (PM)
**Status:** Draft for review

---

## Executive Summary

Embedding-free RAG addresses a fundamental cost/reliability problem in enterprise document retrieval: vector embeddings are expensive, opaque, and fragile. This system replaces the embedding layer entirely with a deterministic pipeline — template-guided lexical retrieval (ripgrep), BM25 re-ranking, RRF fusion, and LLM-as-judge — delivering high recall and high precision at a fraction of the operational cost.

The primary wedge is **knowledge-intensive enterprise search** where documents are structured (reports, filings, compliance docs), queries are fact-seeking, and the cost of a missed result is high. Our core bet is that for this segment, structured lexical signals + a targeted LLM judge outperforms dense retrieval on all dimensions that matter: cost, latency, debuggability, and accuracy.

**Top recommendation:** Ship MVP against two validated datasets (FATS doc-level, Uber 10-K chunk-level), prove recall@10 ≥ 0.80, then expand to enterprise onboarding.

---

## 1. Product Thesis

> **For enterprise knowledge workers and AI application developers who struggle with the high cost and opacity of vector-based RAG, the Embedding-Free RAG system delivers accurate, explainable document retrieval by combining structured template extraction, lexical search, and LLM judgment — unlike vector RAG systems that require expensive embedding infrastructure, yield black-box results, and degrade on domain-specific terminology.**

### Critical Assumptions

1. For knowledge-intensive, fact-seeking queries over structured enterprise documents, lexical signals (with BM25 + RRF) recover ≥ 80% of what dense retrieval finds — at 10× lower cost.
2. An LLM judge operating on compact evidence blocks is more accurate than top-K semantic similarity alone, and the cost is manageable when the candidate set is sufficiently filtered upstream.
3. Enterprise teams will pay a modest inference cost premium for **explainability** (keyword hits, evidence spans, missing constraints) that lets them debug and audit retrieval quality.

---

## 2. Problem Statement

### 2.1 The Core Pain

Retrieval-Augmented Generation (RAG) is the dominant pattern for grounding LLM responses in factual documents. The standard approach requires: (1) embedding models to encode documents and queries, (2) a vector store to index and serve those embeddings, and (3) ANN search at query time.

This creates compounding problems:

| Problem | Impact |
|---|---|
| Embedding models are expensive | Cost per ingestion, cost per query; multiplies with doc volume |
| Vector stores add infrastructure complexity | Deployment overhead, versioning, re-indexing on schema changes |
| Embedding quality is opaque | Cannot debug why a relevant doc was missed; no interpretable signal |
| Domain shift degrades quality | General-purpose embeddings fail on technical jargon, codes, regulations |
| Recall is non-deterministic | Same query on same corpus can return different results |

### 2.2 The Opportunity

A large class of enterprise queries are **fact-seeking and structured**: "Find all incidents involving Toyota between Jan–Mar 2026." These queries have discrete, grep-able signals. The answer either contains "Toyota" near a date range, or it doesn't.

For this class of query, a template-guided lexical pipeline can match or exceed embedding-based recall while being:
- **Fully deterministic** — same query, same results
- **Debuggable** — every hit traces to a keyword and field
- **Cheap** — no embedding API, no vector DB, just ripgrep + a focused LLM judge call
- **Fast to deploy** — ripgrep runs on any file system, no index pre-build required

---

## 3. User Personas

### Persona A — The AI Application Developer ("Builder")

**Profile:** Senior engineer or ML engineer building an internal RAG-powered tool (e.g., compliance search, document Q&A, research assistant).

**Current workflow:** Sets up a vector DB (Pinecone, Weaviate, pgvector), embeds documents with OpenAI or Cohere APIs, builds a retrieval layer on top. Spends significant time on chunking strategies, embedding model selection, and debugging recall failures.

**Pain:**
- "I have no idea why my vector search missed this document."
- "Embedding costs are 40% of my infra bill."
- "Every time I add a new document type, I have to re-tune the chunking and re-embed everything."

**Desired outcome:** A retrieval system they can reason about, tune with text (not math), and integrate via a clean REST API.

---

### Persona B — The Enterprise Knowledge Analyst ("Analyst")

**Profile:** A business analyst or compliance officer who works with a large corpus of domain-specific documents (financial filings, incident reports, policy documents). Uses an internal AI tool powered by this system.

**Pain:**
- Gets incorrect or incomplete answers from AI tools and cannot tell why.
- Needs to cite exact document passages for compliance purposes.
- Corpus uses domain-specific terminology that confuses general-purpose AI.

**Desired outcome:** A retrieval tool that returns exact evidence spans they can cite, not vague paraphrases.

---

### Persona C — The Data/Infra Engineer ("Operator")

**Profile:** Responsible for maintaining the document pipeline — ingesting new documents, updating collections, monitoring quality.

**Pain:**
- Re-indexing a vector DB after a schema change is slow and costly.
- No visibility into what's happening inside the retrieval pipeline.
- Hard to test retrieval quality without running end-to-end LLM queries.

**Desired outcome:** A system they can operate without a vector DB, monitor via structured logs, and test with deterministic unit tests.

---

## 4. Use Cases & User Stories

### UC-1: Financial Report Search

> As a **financial analyst**, I want to search across quarterly SEC filings for specific events (e.g., "acquisitions involving Company X in Q3 2025") so that I can compile evidence for an investment thesis.

**Acceptance:** System returns top-3 relevant passages with exact quotes and source offsets within 10 seconds.

---

### UC-2: Incident / Threat Intelligence Lookup

> As a **security analyst**, I want to query an incident database for "credential stuffing attacks targeting retail companies in 2026" so that I can assess threat exposure.

**Acceptance:** Template fill correctly extracts `Event: credential stuffing`, `Sector: retail`, `Date: 2026`; lexical retrieval returns candidate nodes; judge returns relevant hits with missing constraints flagged.

---

### UC-3: Compliance Policy Lookup

> As a **compliance officer**, I want to ask "What is our policy on vendor data retention?" and get the exact clause from our internal policy corpus, with the document name and section.

**Acceptance:** Result includes the exact text span, document ID, and offset — not a paraphrase.

---

### UC-4: Developer Integration

> As an **AI app developer**, I want to create a collection, ingest a set of documents, auto-generate an information template schema, and query via REST API so that I can build a domain-specific search feature in my application.

**Acceptance:** Full workflow (create → ingest → schema_gen → query) completable in < 30 minutes using documented API.

---

### UC-5: Collection Management & Schema Iteration

> As an **operator**, I want to update the information template schema for a collection without re-ingesting documents so that I can improve retrieval quality without downtime.

**Acceptance:** PATCH schema endpoint updates schema; next query uses new schema without re-indexing.

---

## 5. System Architecture Overview

The pipeline has two phases:

### Offline (Data Preparation)

| Step | Description |
|---|---|
| A1. Collection Definition | Define a named corpus with domain metadata (id, name, description, domain tags, language) |
| A2. Chunking & Ingestion | Ingest documents as Nodes (doc-level or chunk-level); store as text files with metadata |
| A3. Template Schema Generation | LLM samples N docs from collection, generates collection-specific field schema (e.g., Date, Vendor, Event) |

### Online (Query Pipeline)

| Step | Description |
|---|---|
| B0. Query Transform | Optional LLM rewrite of raw query before template fill; off by default (`enable_query_transform=false`) |
| B1. Template Fill | LLM maps user query → structured field values using collection schema |
| B2. Keyword Derivation | Deterministic expansion: 1–3 gram, wildcards, variants |
| B3. Lexical Retrieval | ripgrep scans collection files per keyword; returns `hits[keyword → node_ids]` |
| B4. Keyword Ranking | Score by field coverage + IDF-weighted keyword sum |
| B5. BM25 Re-Rank | Re-rank candidate set using BM25 (small-corpus, not global index) |
| B6. RRF Fusion | Combine B4 + B5 rankings: `RRF = w_kw/(k+rank_kw) + w_bm25/(k+rank_bm25)` |
| B7. Top-K Selection | Take top-K candidates (default: 100–300) with optional coverage threshold |
| B8. Interval Merge | Merge adjacent/overlapping text spans per document → Evidence Blocks |
| B8.5. Cascade Filter | Pre-judge field-overlap filter: rejects evidence blocks with insufficient matched-field overlap vs. query fields (default `min_overlap=0.3`); avoids unnecessary judge calls |
| B9. LLM Judge | Parallel judge calls per evidence block: outputs `relevant`, `confidence`, `evidence spans`, `missing_constraints` |
| B10. Final Output | Top-N results with full provenance (RRF rank, judge score, evidence spans) |

> **Determinism scope:** Steps B2–B8.5 are fully deterministic — same query, same corpus, same results every time. Steps B0, B1, and B9 involve LLM calls and are subject to model variance and provider drift. "Deterministic retrieval" is the accurate claim; end-to-end pipeline determinism depends on LLM consistency.

---

## 6. API Surface

All endpoints are RESTful JSON. Base path: `/api`.

### Collections

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/collections` | Create a new collection |
| `GET` | `/collections` | List all collections |
| `GET` | `/collections/{id}` | Get collection details |
| `DELETE` | `/collections/{id}` | Delete a collection |

### Ingestion

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/collections/{id}/ingest` | Ingest documents (text, chunked or doc-level) |
| `GET` | `/collections/{id}/nodes` | List ingested nodes |
| `DELETE` | `/collections/{id}/nodes/{node_id}` | Remove a node |

### Schema Generation

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/collections/{id}/schema` | Auto-generate template schema from sampled docs |
| `GET` | `/collections/{id}/schema` | Get current schema |
| `PATCH` | `/collections/{id}/schema/fields/{field_name}` | Update a single schema field (rename, change constraints) |

### Query

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/query` | Execute full retrieval pipeline (`collection_id` in request body) |
| `POST` | `/query?debug=true` | Query with full debug bundle (template fill, keyword hits, interval merge, judge reasoning) |

### Query Request/Response

```json
// Request
{
  "collection_id": "security-incidents",
  "query": "Toyota credential stuffing attack 2026",
  "top_k": 100,
  "top_n": 5,
  "debug": false
}

// Response
{
  "results": [
    {
      "doc_id": "D123",
      "text": "Toyota confirmed a credential stuffing attack...",
      "start_offset": 1042,
      "end_offset": 1088,
      "matched_fields": ["Vendor", "Event"],
      "matched_keywords": ["Toyota", "credential stuffing"],
      "source_node_ids": ["node-abc"],
      "judge": {
        "relevant": true,
        "confidence": 0.86,
        "missing_constraints": []
      },
      "cascade_filtered": false
    }
  ],
  "degradation_level": 0,
  "debug": null
}
```

---

## 7. Success Metrics

### Retrieval Quality (Primary)

| Metric | MVP Target | Description |
|---|---|---|
| `recall@10` | ≥ 0.80 | Fraction of relevant docs in top-10; measured on FATS + Uber datasets |
| `precision@5` | ≥ 0.70 | Fraction of top-5 results that are relevant |
| `judge_accuracy` | ≥ 0.85 | Judge `relevant` decision vs. ground truth label |
| `template_fill_hit_rate` | ≥ 0.75 | Fraction of queries where template fill produces ≥ 1 keyword hit |

### Operational (Secondary)

| Metric | MVP Target | Description |
|---|---|---|
| `p95 query latency` | ≤ 10s | End-to-end query latency (B1–B10) at p95 |
| `cost per query` | ≤ $0.05 | LLM API cost (template fill + judge) per query, mid-size corpus |
| `ingestion throughput` | ≥ 100 docs/min | Sustained ingestion rate |

### Activation (Product)

| Metric | Target | Description |
|---|---|---|
| Time-to-first-query | ≤ 30 min | From account creation to first successful query result |
| Schema gen accuracy | ≥ 4/5 useful fields | Human-rated usefulness of auto-generated schema fields |

---

## 8. Competitive Positioning

| Dimension | Embedding-Free RAG (This) | Vector RAG (Pinecone / pgvector) | Hybrid (BM25 + Dense) | Pure Lexical (Elasticsearch) |
|---|---|---|---|---|
| **Infrastructure** | ripgrep + LLM API only | Embedding model + vector DB | Both | Elasticsearch cluster |
| **Cost** | Low (LLM judge only) | High (embed + vector ops) | High | Medium (indexing + ops) |
| **Debuggability** | Full trace (keywords, fields, evidence) | Black box | Partial | Good (term hits) |
| **Domain adaptation** | Schema editing (no re-index) | Full re-embed required | Partial re-embed | Index rebuild |
| **Determinism** | Fully deterministic | Non-deterministic | Non-deterministic | Deterministic |
| **Recall on exact-match queries** | Very high | Medium–High | High | High |
| **Recall on semantic queries** | Medium | High | High | Low |
| **Best for** | Structured fact-seeking | Semantic/conceptual search | General purpose | Keyword-heavy, exact match |

**Positioning summary:** We are the best choice when queries are fact-seeking and structured, documents have domain-specific terminology, and debuggability + cost control matter more than semantic recall.

---

## 9. MVP Scope

### Must Have (MVP)

- [ ] Collection CRUD API
- [ ] Document ingestion (doc-level and chunk-level Node model)
- [ ] Template schema auto-generation (LLM-based, A3)
- [ ] Full query pipeline B1–B10 with configurable weights
- [ ] REST API with debug mode
- [ ] FATS dataset validation (doc-level retrieval)
- [ ] Uber 10-K validation (chunk-level retrieval)
- [ ] deepeval synthetic evaluation (recall@K, judge accuracy)
- [ ] Structured observability (query trace logs with template fill, keyword hits, interval merge, judge output)

### Should Have (Post-MVP)

- [ ] Web UI for collection management and query debugging
- [ ] Schema versioning and rollback
- [ ] Batch ingestion with progress tracking
- [ ] Per-collection RRF weight tuning via API
- [ ] Multi-collection query (fan-out + merge)

### Not Now

- [ ] Vector embedding fallback mode
- [ ] Real-time document streaming / push ingestion
- [ ] User authentication / multi-tenant access control
- [ ] Managed cloud hosting
- [ ] Fine-tuned judge model

---

## 10. Phased Execution Plan

### Phase 1 — Validate (Now)

**Goal:** Prove core retrieval quality against real datasets.

- [x] Implement full pipeline (A1–A3, B1–B10) in Python clean architecture
- [x] FastAPI HTTP routes for all core endpoints
- [ ] Run deepeval evaluation on FATS + Uber datasets; hit recall@10 ≥ 0.80
- [ ] Fix any pipeline gaps (keyword derivation, RRF weights, judge prompt)
- [ ] Write integration test suite covering both dataset types
- **Exit criterion:** recall@10 ≥ 0.80 on both datasets

### Phase 2 — Productize (Next)

**Goal:** Make it usable by an external developer in < 30 minutes.

- [ ] API documentation (OpenAPI spec)
- [ ] SDK / client example (Python)
- [ ] Docker Compose deployment
- [ ] Schema gen quality improvements (field coverage tuning)
- [ ] Latency profiling + optimization (target p95 ≤ 10s)
- **Exit criterion:** Time-to-first-query ≤ 30 minutes for a new developer

### Phase 3 — Scale (Later)

**Goal:** Handle production-scale corpora and enterprise onboarding.

- [ ] Multi-collection query
- [ ] FTS engine option (as alternative to ripgrep)
- [ ] Web debug UI
- [ ] Schema versioning
- **Exit criterion:** Successful onboarding of first external team with > 10K documents

---

## 11. Non-Functional Requirements

### Performance

- Query p95 latency ≤ 10 seconds for corpora up to 10,000 nodes
- LLM judge calls must be parallelized (async, not sequential)
- BM25 re-ranking must complete in < 500ms on candidate sets ≤ 500 nodes

### Scalability

- ripgrep-based lexical retrieval scales to ~100K files without pre-indexing
- For > 100K nodes, FTS (e.g., Tantivy/Meilisearch) should be supported as a drop-in alternative to ripgrep

### Observability

- Every query must produce a structured trace log (template fill → keyword hits → RRF scores → judge decisions)
- `debug=true` query mode must expose full intermediate state for operator diagnostics
- LLM API cost per query must be tracked and surfaced in debug output

### Reliability

- ripgrep must be present on system PATH; startup must fail fast with a clear error if not found
- LLM API errors must be handled gracefully: judge failures degrade to RRF-only ranking with a warning
- Schema must be versioned; a missing schema falls back to raw query keywords

### Security

- No user data stored beyond the document collection; no PII in logs
- LLM API keys must be injected via environment variables, never hardcoded

---

## 12. Technical Constraints

- **Runtime:** Python 3.14+, managed with `uv`
- **Lexical engine:** ripgrep (`rg`) required on system PATH
- **LLM abstraction:** litellm (supports OpenAI, Anthropic, local models)
- **BM25:** bm25s library
- **Architecture:** Clean architecture — domain / application / infrastructure / presentation layers
- **No vector DB dependency** — this is a hard constraint, not a trade-off

---

## 13. Risks & Mitigations

| Risk | Type | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| Recall degrades on semantic queries (e.g., "What were the risks mentioned?") | Value | High | High | Be explicit in positioning: system targets structured, fact-seeking queries. Add semantic fallback to roadmap. |
| LLM template fill hallucinates field values | Value | High | Medium | Strict non-invent prompt rules; unit tests for template fill; confidence threshold on empty fields |
| ripgrep missing from deployment environment | Feasibility | High | Low | Fast-fail startup check; clear install documentation; Docker image with rg pre-installed |
| Judge LLM API costs exceed budget | Business | Medium | Medium | Configurable Top-K cap; max evidence block length; cost-per-query monitoring |
| BM25 candidate set size explodes on broad queries | Feasibility | Medium | Medium | Coverage threshold filter (field_coverage ≥ 1); per-doc chunk cap |
| Schema gen produces low-quality fields | Value | Medium | Medium | Human review workflow; schema edit API; evaluation against sample queries |
| litellm rate limits on parallel judge calls | Feasibility | Medium | Medium | Configurable parallelism ceiling; retry with backoff; degrade to sequential on rate limit |

### Pre-Mortem

> "It's March 2027 and the project was abandoned. Why? The pipeline worked on the two test datasets, but when the first enterprise team tried it on their corpus, recall was 0.55. The queries were more semantic ('What is our company's position on X?') — not the structured fact-seeking queries we designed for. We had positioned broadly as a 'RAG replacement' instead of a 'structured search upgrade,' and the gap between expectation and reality killed adoption. We should have nailed our ICP positioning and validated with a third, real-world enterprise corpus before calling it production-ready."

---

## 14. Acceptance Criteria

These criteria align with the engineering validation defined in `CLAUDE.md`:

| Criteria | How Verified |
|---|---|
| Ingestion correctness | Unit tests: node model, chunking, collection YAML storage |
| Template schema generation | Unit tests: schema fields non-empty, versioned, parseable |
| Full pipeline execution | Integration tests on FATS (doc-level) and Uber 10-K (chunk-level) datasets |
| Retrieval quality | deepeval synthetic evaluation: recall@10 ≥ 0.80, precision@5 ≥ 0.70 |
| Judge accuracy | deepeval judge eval: ≥ 0.85 agreement with ground truth |
| API surface completeness | All REST endpoints return correct status codes and response shapes |
| Debug mode | `debug=true` query returns template fill, keyword hits, interval merge output, judge reasoning |
| Error handling | LLM API failure → graceful degradation to RRF-only; missing rg → startup error |

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found | 18 findings (determinism claim, PDF ingestion, eval leakage, concurrency) |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | issues_open | 8 issues, 2 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |

- **CODEX:** Flagged determinism claim (LLM steps break it), synthetic eval leakage, missing PDF parsing, ripgrep concurrency risks
- **CROSS-MODEL:** Both reviewers agree on determinism scope, PDF gap, and concurrency unknowns
- **UNRESOLVED:** 0 unresolved decisions (all 12 issues answered)
- **VERDICT:** ENG REVIEW has 2 critical gaps — resolve B1.5 silent failure + startup model validator before shipping

---

## Closing Blocks

### What We Believe

1. For structured, fact-seeking enterprise queries, lexical + BM25 + RRF achieves recall parity with dense retrieval at significantly lower cost.
2. The LLM judge operating on compact evidence blocks (not full documents) is the right trade-off point: high accuracy, bounded cost, and fully explainable output.
3. Debuggability and operator control are undervalued in current RAG tooling — this is our durable competitive differentiator.

### What We Still Need to Learn

1. **Recall floor on semantic queries:** At what query complexity does the lexical pipeline break down? We need a third dataset (customer-provided, not hand-picked) to test this boundary.
2. **Template fill quality at scale:** Does the LLM reliably extract the right field values for diverse query types? We need red-team prompts.
3. **Operator adoption friction:** Is the schema generation + tuning loop intuitive enough, or will operators hit a wall after 30 minutes?

### What NOT to Build Yet

- Vector embedding fallback (blurs positioning, adds complexity)
- Multi-tenant authentication (not needed for MVP validation phase)
- Managed cloud hosting (validate on-premise first)
- Real-time streaming ingestion (batch is sufficient for Phase 1–2 validation)
- Fine-tuned judge model (general-purpose LLM is good enough to start)

### Next 3 Moves

1. **Run deepeval evaluation** on both FATS and Uber datasets; if recall@10 < 0.80, diagnose which pipeline stage is the bottleneck (template fill miss? keyword derivation? BM25 re-rank?).
2. **Write OpenAPI spec** for all REST endpoints — this unblocks developer onboarding and will expose any API design inconsistencies early.
3. **Recruit one external team** to attempt the time-to-first-query flow with their own small corpus (< 500 docs) — qualitative feedback on schema gen + debug experience.
