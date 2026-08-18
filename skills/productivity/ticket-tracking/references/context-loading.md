# Context Loading

Load enough context to execute the assigned ticket without copying the entire repository into working memory.

## Required reading order

1. Read every applicable `AGENTS.md` completely.
2. Read the assigned phase overview and decision record.
3. Read the complete assigned task specification.
4. Read the directly referenced design sections in `docs/`.
5. Inspect the relevant source, tests, configuration, and migration files.
6. Inspect dependency evidence and current Git changes that affect owned files.

Follow links only when they affect an acceptance criterion, constraint, interface, or unresolved decision. Prefer precise headings and symbols over whole unrelated documents.

## Source roles

- `AGENTS.md` defines execution constraints.
- `docs/` defines accepted product, architecture, schema, and operational design.
- `changes/<phase>/` defines phase decisions, sequencing, and task contracts.
- Source and tests show the current implementation state.
- The external ticket defines live assignment, status, and coordination metadata.

The ticket points to the context; it does not replace it.

## Readiness check

Begin implementation only when you can answer:

- What observable result must change?
- Which files or modules do I own?
- Which behavior is explicitly out of scope?
- Which dependencies are present in the repository?
- How will each acceptance criterion be verified?
- Which unresolved decisions require escalation?

If one answer is missing and materially changes implementation, report it to the coordinating agent before editing the affected surface.
