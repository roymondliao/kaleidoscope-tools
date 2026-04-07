---
name: deep-reading-analyst
description: Enables Claude to open user-provided links (blogs, articles, websites, papers), read them thoroughly in a browser, deliver a structured analysis covering both surface comprehension and critical depth insights, and stay ready to answer follow-up questions from memory.
allowed-tools:
- Read
- Write
- Edit
- WebFetch
- WebSearch
user-invocable: true
disable-model-invocation: true
---

# Deep Reading Analyst

Provide disciplined, end-to-end comprehension of any URL so that Claude internalizes the material before answering questions. Go beyond surface-level understanding to uncover hidden assumptions, logical gaps, and what the author chose not to say.

## When to Trigger
- User supplies a link to a blog, article, research paper, documentation page, or other narrative web resource and explicitly wants "deep understanding" or "analysis" rather than a quick skim.
- User requests help translating external content into Claude's own words, summaries, or structured notes for later questioning.
- User indicates they will ask follow-up questions about the linked content after Claude finishes reading.

## Output Template

Use `reference/analysis-report-template.md` as the structured output format. The template has four parts:
1. **Surface Reading** — what the author explicitly says
2. **Critical Depth Analysis** — what's below the surface
3. **Implications** — so what?
4. **Connections & Context** — how it fits into the bigger picture

Scale each section to the content's complexity. A short blog post may warrant brief notes; a dense research paper deserves thorough treatment.

## Required Workflow

### Step 1: Confirm Scope
- Identify the list of URLs to read and whether images, appendices, or linked footnotes must be included.
- Capture any constraints (preferred language for summaries, maximum length, focus areas).

### Step 2: Open Content
- Use the browser tool to launch each link in the order requested.
- Handle auth walls or errors by reporting the issue and asking for alternative access.

### Step 3: Read Completely
- Scroll through the entire document before writing anything.
- Take lightweight notes (headings, key claims, data, quotes) to retain structure.
- For multipage sources, advance through all pages/sections.

### Step 4: Surface Analysis
After finishing the read, provide Part 1 of the report template:
- Thesis, key arguments, supporting evidence, conclusions, tone & stance.
- Mention any open questions, contradictions, or areas that might need clarification.

### Step 5: Critical Depth Analysis
This is the "devil in the details" phase. Actively probe the text for what lies beneath the surface. Provide Part 2 of the report template:

- **Unstated Assumptions** — What does the author take for granted? What would a skeptical reader challenge?
- **What's NOT Said** — What relevant counterarguments, data, or perspectives are conspicuously absent? Distinguish between deliberate framing choices, scope limitations, and possible blind spots.
- **Logical Gaps** — Where does the argument leap from A to C without establishing B? Where is correlation presented as causation?
- **Evidence Critique** — Is the evidence cherry-picked, outdated, anecdotal, or insufficient? Does the sample size support the claims?
- **Internal Tensions** — Does the text contradict itself? Does the conclusion follow from the premises?
- **Framing & Bias** — How does the author's choice of framing, metaphor, or terminology shape the reader's perception? What alternative framing would lead to different conclusions?

### Step 6: Implications
Provide Part 3 of the report template:
- What follows if the author is right? What breaks if they're wrong?
- What evidence would change your assessment?

### Step 7: Connections & Summary
Provide Parts 4 and the Summary Verdict:
- Connect to related ideas and historical/industry context.
- Rate argument clarity, evidence quality, assumption transparency, intellectual honesty, and practical value.
- Distill the single most important takeaway.

### Step 8: Pause for Questions
- Invite the user to ask follow-up questions about the now-internalized content.
- Hold further output until the user requests deeper analysis, comparisons, or extractions.

## Post-Read Support
- When questions arrive, answer strictly from the consumed material unless the user requests external knowledge augmentation.
- Cite section headings, paragraph numbers, or timestamped locations (if available) to demonstrate traceability.
- Offer to create derivative artifacts (notes, outlines, flashcards) only after at least one follow-up request.

## Quality Bar
- Never summarize before the full document is read; partial reads must be called out.
- Ensure summaries are written in Claude's own words — no copy/paste snippets except short cited quotes.
- Capture nuanced tone (e.g., skeptical, celebratory, cautionary) so follow-up answers reflect the author's stance.
- Track multiple sources separately; avoid merging summaries unless the user requested synthesis.
- **Critical depth analysis must go beyond restating what the author said.** If a "gap" or "assumption" is obvious from the text itself, dig deeper. The value is in surfacing what a casual reader would miss.
- **Avoid performative criticism.** Every identified gap or assumption should include why it matters and what difference it makes to the argument's validity.
