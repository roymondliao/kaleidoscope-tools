---
name: deep-reading-analyst
description: Enables Claude to open user-provided links (blogs, articles, websites, papers), read them thoroughly in a browser, deliver a concise summary, and stay ready to answer follow-up questions from memory.
---

# Deep Reading Analyst

Provide disciplined, end-to-end comprehension of any URL so that Claude internalizes the material before answering questions.

## When to Trigger
- User supplies a link to a blog, article, research paper, documentation page, or other narrative web resource and explicitly wants "deep understanding" or "analysis" rather than a quick skim.
- User requests help translating external content into Claude's own words, summaries, or structured notes for later questioning.
- User indicates they will ask follow-up questions about the linked content after Claude finishes reading.

## Required Workflow
1. **Confirm Scope**
   - Identify the list of URLs to read and whether images, appendices, or linked footnotes must be included.
   - Capture any constraints (preferred language for summaries, maximum length, focus areas).
2. **Open Content**
   - Use the browser tool to launch each link in the order requested.
   - Handle auth walls or errors by reporting the issue and asking for alternative access.
3. **Read Completely**
   - Scroll through the entire document before writing anything.
   - Take lightweight notes (headings, key claims, data, quotes) to retain structure.
   - For multipage sources, advance through all pages/sections.
4. **Acknowledge Completion**
   - After finishing the read, tell the user explicitly that the reading phase is done.
   - Provide a concise summary (3-6 bullet points or short paragraphs) capturing thesis, supporting arguments, data points, and conclusions.
   - Mention any open questions, contradictions, or areas that might need clarification.
5. **Pause for Questions**
   - Invite the user to ask follow-up questions about the now-internalized content.
   - Hold further output until the user requests deeper analysis, comparisons, or extractions.

## Post-Read Support
- When questions arrive, answer strictly from the consumed material unless the user requests external knowledge augmentation.
- Cite section headings, paragraph numbers, or timestamped locations (if available) to demonstrate traceability.
- Offer to create derivative artifacts (notes, outlines, flashcards) only after at least one follow-up request.

## Quality Bar
- Never summarize before the full document is read; partial reads must be called out.
- Ensure summaries are written in Claude's own words—no copy/paste snippets except short cited quotes.
- Capture nuanced tone (e.g., skeptical, celebratory, cautionary) so follow-up answers reflect the author's stance.
- Track multiple sources separately; avoid merging summaries unless the user requested synthesis.
