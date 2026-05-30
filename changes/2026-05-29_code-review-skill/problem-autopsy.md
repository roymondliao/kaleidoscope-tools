# Problem Autopsy: Code Review Skill

## original_statement

> 現在要 create 一個 code review 的 skill + subagent 來協助處理 project 的 PR，進行 code review 的處理。
>
> 場景：User 要進行 code review，所以會給 pr 的 url，然後要透過 `gh` cmd 去 pull 該 pr review 的 branch 下來，並且切換過去。
>
> Skill 負責這個 code review skill 有幾個重點
> - 要先了解該 project(repo) 的全貌，所以了解該 project 在做些什麼、有哪些 module、folder structure ... etc
> - 閱讀 codebase，但不用去讀 tests/ 的 files
> - 了解 project 的全貌後，根據 pr description 的內容 + git commit logs 來了解這是 pr 改動的部分，跟發 pr 的原因是什麼
> - 理解 pr 的相關訊息後，開始對 pr 有修改的 files 進行 code review，將 code review 的任務給 subagent 來進行。
> - 給 subagent 的 code review task 必須要讓 subagent 先知道 project information + pr information, 然後被 assign review 的部分。
> - 每一個 PR 都可能會有多處修改，所以 main agent 要根據 project + pr information 將相關連的部分為一組，assign 給 subagent review。
>
> Subagent:
> - 必須了解 project information + pr information，先了解目的，才能知道 pr 的改動是否合理
> - 可以參考 https://github.com/obra/superpowers/blob/main/skills/requesting-code-review/code-reviewer.md 的 review 準則
> - 給出 review reslut
>
> Main agent:
> - 調用 code review skill 取得的 results，整理後，跟 User 進行討論
> - 討論後對齊 code review 結果後，使用 gh api 用 POST /repos/{owner}/{repo}/pulls/{pull_number}/comments 對 PR diff 的特定行留 review comment。需要的參數：
>   - commit_id — PR head commit SHA
>   - path — 檔案路徑
>   - line — 新檔案的行號
>   - side — RIGHT（新版）或 LEFT（舊版）
>   - body — comment 內容（支援 markdown）

## reframed_statement

Build a reusable code review skill and reviewer subagent contract for kaleidoscope-tools. The main skill owns PR intake, checkout, project reconnaissance, PR intent reconstruction, changed-file grouping, subagent dispatch, result consolidation, user alignment, and final GitHub line-comment posting. The subagent owns high-signal review of an assigned coherent slice of the PR, using project context and PR intent to judge whether the implementation is correct, maintainable, and ready.

## translation_delta

```yaml
translation_delta:
  - original: "協助處理 project 的 PR，進行 code review 的處理"
    reframed: "Reusable PR review workflow with explicit orchestration and subagent contract"
    delta: "The original frames the need as code review assistance; the implementation risk is orchestration quality, context transfer, and safe posting behavior, not only reviewing code."
  - original: "透過 `gh` cmd 去 pull 該 pr review 的 branch 下來，並且切換過去"
    reframed: "PR intake and local checkout are prerequisites with failure handling"
    delta: "Checkout is not a convenience step; all later file reads, diffs, and line mappings depend on it being correct."
  - original: "閱讀 codebase，但不用去讀 tests/ 的 files"
    reframed: "Exclude tests from broad reconnaissance, while preserving room for targeted test review if changed files or risk require it"
    delta: "A hard ban on all tests could make review blind to behavior expectations; the safer interpretation is no broad test traversal during project overview."
  - original: "根據 project + pr information 將相關連的部分為一組，assign 給 subagent review"
    reframed: "Main agent must build coherent review units from changed files and assign each unit with shared project and PR context"
    delta: "Grouping is a core quality gate. Bad grouping can cause duplicate findings, missed cross-file defects, or subagents reviewing without enough context."
  - original: "跟 User 進行討論 ... 對齊 code review 結果後"
    reframed: "User approval gate before any public GitHub comments"
    delta: "The skill should treat generated findings as drafts until the user agrees; posting is a separate, explicit action."
  - original: "POST /repos/{owner}/{repo}/pulls/{pull_number}/comments"
    reframed: "Use GitHub review comment API with validated diff-line mapping"
    delta: "Having the endpoint and fields is not enough; the skill must ensure the selected line exists in the PR diff and maps to the intended side."
```

## kill_conditions

```yaml
kill_conditions:
  - condition: "The workflow cannot reliably map approved findings back to valid PR diff lines"
    rationale: "A code review skill that posts comments on the wrong line damages trust and creates public review noise. Advisory output is acceptable; incorrect posting is not."
  - condition: "Subagents produce generic review advice that does not improve on a single main-agent review"
    rationale: "Parallel review only pays for itself when subagents find better, more focused issues. Otherwise the workflow adds coordination cost and duplicate consolidation without quality gain."
  - condition: "The required project reconnaissance makes small PR reviews slower than manual review by default"
    rationale: "Understanding the project is necessary, but if the fixed cost dominates routine PRs, users will stop invoking the skill. Reconnaissance must be bounded and proportional."
  - condition: "The skill is used to auto-post comments without human alignment"
    rationale: "The user explicitly wants discussion and alignment before public comments. Removing that gate changes the product from review assistance to automated reviewer behavior."
```

## damage_recipients

```yaml
damage_recipients:
  - who: "PR authors"
    cost: "May receive public comments that are technically wrong, low-signal, duplicated, or phrased without enough project context if the workflow fails."
  - who: "Reviewing user"
    cost: "Must validate generated findings before posting and may need to resolve conflicts between subagent outputs."
  - who: "Skill maintainer"
    cost: "Must keep GitHub API usage, diff-line mapping rules, gh workflow, and subagent prompt schema current."
  - who: "Subagent context budget"
    cost: "Each review subtask needs project information, PR information, assigned file context, and output requirements; large PRs may force summarization tradeoffs."
  - who: "Repository contributors"
    cost: "A new skill and subagent add another prescribed workflow that contributors must understand, maintain, and avoid misusing."
```

## observable_done_state

A user can give the skill a PR URL, and the skill checks out the PR branch, summarizes the project and PR intent, groups changed files into coherent review units, and dispatches each unit to reviewer subagents with project and PR context. The main agent consolidates findings into concrete, severity-calibrated review results with file and line references, then discusses them with the user. Only approved findings are posted as GitHub PR review comments with validated `commit_id`, `path`, `line`, `side`, and markdown `body`.
