---
name: document-skills
description: Entry-point skill for working with professional documents. Use this when Claude needs to create, edit, convert, or analyze Office/PDF files and should route to the correct format-specific workflow (docx, pdf, pptx, xlsx).
---

# Document Skills (Router)

## When to Use

Use this skill when the user is working with any of these document types:

- `.docx` (Word)
- `.pdf`
- `.pptx` (PowerPoint)
- `.xlsx` / `.xlsm` / `.csv` / `.tsv` (Excel / spreadsheets)

## Routing Rules

1. If the user provides a filename or file extension, route by extension:
   - `.docx` -> read `docx/SKILL.md`
   - `.pdf` -> read `pdf/SKILL.md`
   - `.pptx` -> read `pptx/SKILL.md`
   - `.xlsx`, `.xlsm`, `.csv`, `.tsv` -> read `xlsx/SKILL.md`
2. If the user does not provide an extension, ask which format they are working with, then route using the mapping above.
3. Prefer the format-specific workflow as the source of truth. This router skill should stay minimal and only direct to the correct sub-skill.

## Sub-Skills

- `docx/` (Word)
- `pdf/`
- `pptx/` (PowerPoint)
- `xlsx/` (Excel)
