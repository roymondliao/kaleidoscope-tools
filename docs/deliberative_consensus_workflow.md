下面是 Spec v2。我已經把你剛剛定下來的方向正式化：
	•	採用「subagent 直接寫自己的論點檔」
	•	先不使用 hooks
	•	先以 settings.json / settings.local.json 的 permissions 作為 MVP 的硬限制
	•	subagent 允許 Edit，但用途限定為寫 deliberation artifacts
	•	Coordinator 不代寫 subagent 的論點，避免中介改寫與觀點污染
	•	skills 用 SKILL.md 承載流程規格與輸出 schema
	•	subagents 放在 .claude/agents/，project settings 放在 .claude/settings.json，本機覆蓋放在 .claude/settings.local.json。 ￼

⸻

Deliberative Consensus Workflow for Claude Code — Spec v2

0. Purpose

本系統要把「高品質共識來自結構化衝突，而不是多數決」落地成 Claude Code 的 agent workflow。Claude Code 支援 custom subagents、project-scoped agent definitions、skills、以及 session/project/local 三層設定，因此很適合用來做一個由 Coordinator 調度、由多個 stance agents 彼此攻防、最後交給 Arbiter 裁決的 deliberation system。 ￼

⸻

1. Design Goals

1.1 Primary goal

建立一個 stance generation → cross-examination → belief revision → arbitration 的制度化衝突工作流，用於技術決策、架構評估、code review、root-cause analysis 等任務。Claude Code 的 subagents 可定義自己的描述、工具與前置行為，skills 則可把這整套流程封裝成可重用的操作規格。 ￼

1.2 Non-goals

這一版不追求：
	•	自動遞迴 spawning 的 agent tree
	•	hook-based governance
	•	自動修 code 或自動部署
	•	以單輪 vote 作為最終答案

這是因為目前 Claude Code 的 subagent 能力已足夠支撐多角色 workflow，但你現在先要驗證的是 共識形成機制，不是完整自治系統。 ￼

⸻

2. Core Principle

Consensus is not aggregation; consensus is adversarially tested survival.

也就是說，本系統不把「三個答案做投票」視為共識，而是把「各自先表態、互相指出弱點、接受攻擊後是否改變立場、最後哪個論點仍然站得住」視為共識形成過程。

因此本系統的輸出不是只有 final answer，而是包含：
	•	初始立場
	•	攻擊摘要
	•	信念修正
	•	最終裁決
	•	minority report
	•	unresolved questions

這種 artifact-oriented workflow 很適合用 Claude Code 的讀寫檔能力來落地。Claude Code 明確支持 subagents 與 skills，也保留讀寫檔案的核心能力。 ￼

⸻

3. Why subagents write their own files

本版明確採用 subagent 直接寫自己的論點檔，不由 Coordinator 代寫。

理由
	1.	避免中介改寫：如果 coordinator 幫 subagent 落檔，subagent 原始論點可能被 coordinator 摘要、重寫或弱化。
	2.	保留原始審議痕跡：每個 agent 的原文輸出可以直接作為 audit trail。
	3.	利於 replay / analytics：後續可對各輪輸出做差異分析與心證變化比較。
	4.	降低 Coordinator 權力集中：Coordinator 只控制流程，不控制內容。

Claude Code 的 agent 本身具備讀寫檔能力，而 subagent 可透過 frontmatter 的 tools 限制能力範圍，因此這個模式是符合 Claude Code 能力模型的。 ￼

⸻

4. Claude Code deployment model

4.1 Agent location

所有 project-specific subagents 放在：

.claude/agents/

Claude Code 官方支援 project-level subagents 置於 .claude/agents/，也支援 user-level agents 置於 ~/.claude/agents/。本專案使用 project scope，方便版本控管與團隊共享。 ￼

4.2 Skill location

workflow skills 放在：

.claude/skills/

skills 以 SKILL.md 定義，Claude Code 會在相關時機自動使用，或可直接以 slash command 方式調用。 ￼

4.3 Settings location
	•	Team-shared policy: .claude/settings.json
	•	Local override / experimentation: .claude/settings.local.json

Claude Code 官方明確區分 project settings 與 local settings；settings.local.json 會被 git ignore，用於未檢入的個人偏好與實驗。 ￼

⸻

5. System Roles

本 workflow 使用五個 agents。

5.1 Coordinator

責任：
	•	接收任務
	•	定義 problem statement
	•	啟動各 stage
	•	指派 subagents
	•	收集 artifact 路徑
	•	判斷是否進入下一輪
	•	組裝 final dossier

Coordinator 不應代寫 stance agents 或 arbiter 的內容，只能寫流程總結與 dossier index。這樣可以把流程控制權與內容生成權拆開。這種角色分工與 Claude Code subagents 的設計一致：由主會話調度具有不同職責的 agents。 ￼

5.2 Analytical Critic

聚焦：
	•	邏輯一致性
	•	技術正確性
	•	證據是否足夠
	•	假設是否合理

5.3 Risk Critic

聚焦：
	•	failure modes
	•	安全性
	•	邊界情境
	•	rollback / incident risk

5.4 Pragmatic Critic

聚焦：
	•	成本
	•	交付現實性
	•	可維護性
	•	團隊採納成本

5.5 Arbiter

聚焦：
	•	比較 surviving arguments
	•	產出 final ruling
	•	保留 minority report
	•	標記 unresolved questions

這些 agent 會透過 .claude/agents/*.md 定義，各自使用自己的說明與工具集。 ￼

⸻

6. State Machine

Coordinator 必須依照以下流程執行，不可跳過對抗階段直接下結論。

digraph DeliberativeConsensusWorkflow {
  rankdir=LR;
  node [shape=box, style="rounded"];

  START [shape=circle, label="START"];
  END [shape=doublecircle, label="END"];

  FRAMING [label="Stage 0\nTask Framing"];
  STANCE_COLLECTION [label="Stage 1\nIndependent Stance Generation"];
  CROSS_EXAM [label="Stage 2\nCross-Examination"];
  BELIEF_REVISION [label="Stage 3\nBelief Revision"];
  EVIDENCE_GAP_CHECK [label="Evidence Gap Check"];
  ARBITRATION [label="Stage 4\nArbitration"];
  DOSSIER_COMPLETE [label="Stage 5\nDecision Dossier"];

  ABORT_INSUFFICIENT_AGENTS [label="Abort:\n< 2 valid stance agents"];
  ABORT_INSUFFICIENT_EVIDENCE [label="Fallback:\nInvestigate / Need More Evidence"];

  START -> FRAMING;
  FRAMING -> STANCE_COLLECTION [label="problem_statement + evaluation_axes ready"];

  STANCE_COLLECTION -> ABORT_INSUFFICIENT_AGENTS [label="< 2 agents succeeded"];
  STANCE_COLLECTION -> CROSS_EXAM [label=">= 2 stance outputs ready"];

  CROSS_EXAM -> BELIEF_REVISION [label="cross-attacks collected"];

  BELIEF_REVISION -> EVIDENCE_GAP_CHECK [label="revisions submitted"];

  EVIDENCE_GAP_CHECK -> CROSS_EXAM [label="new evidence requested\nand max_rounds not reached"];
  EVIDENCE_GAP_CHECK -> ARBITRATION [label="enough evidence OR max_rounds reached"];
  EVIDENCE_GAP_CHECK -> ABORT_INSUFFICIENT_EVIDENCE [label="critical evidence missing"];

  ARBITRATION -> DOSSIER_COMPLETE [label="ruling + minority report ready"];
  DOSSIER_COMPLETE -> END;

  ABORT_INSUFFICIENT_AGENTS -> END;
  ABORT_INSUFFICIENT_EVIDENCE -> END;
}

這張圖應直接放進 deliberate-consensus skill，讓 Coordinator 把它當成 execution contract。skills 在 Claude Code 中本來就是用來承載操作流程與可重用能力的。 ￼

⸻

7. Workflow Stages

Stage 0 — Task Framing

Coordinator 產出：
	•	decision_id
	•	task_type
	•	problem_statement
	•	evaluation_axes
	•	evidence_scope
	•	max_rounds

Output file

.claude/outputs/decisions/{decision_id}/stage0-framing.md


⸻

Stage 1 — Independent Stance Generation

Coordinator 分別呼叫三個 stance agents。每個 agent：
	•	不看其他 agent 的輸出
	•	先明確表態
	•	指出 assumptions
	•	附 evidence references
	•	寫自己的 stage1 artifact

Required schema

stance:
  agent: analytical-critic
  thesis: >
    核心主張
  recommendation:
    accept | reject | revise | investigate
  assumptions:
    - ...
  evidence:
    - file/path.py:123
    - command output reference
  strongest_reason:
    - ...
  risk_if_wrong:
    - ...
  confidence: 0.00-1.00


⸻

Stage 2 — Cross-Examination

Coordinator 把其他兩個 stance 文件路徑提供給每個 stance agent。每個 agent 必須：
	•	至少攻擊另外兩位各一條
	•	指出對方最弱 assumption
	•	指出 evidence gap
	•	指出 reasoning flaw
	•	標示 attack severity
	•	寫自己的 cross-exam artifact

Required schema

cross_exam:
  agent: risk-critic
  attacks:
    - target_agent: analytical-critic
      weakest_assumption: ...
      evidence_gap: ...
      reasoning_flaw: ...
      hidden_tradeoff: ...
      severity: low | medium | high
    - target_agent: pragmatic-critic
      weakest_assumption: ...
      evidence_gap: ...
      reasoning_flaw: ...
      hidden_tradeoff: ...
      severity: low | medium | high


⸻

Stage 3 — Belief Revision

Coordinator 把針對每個 agent 的攻擊回傳給該 agent。每個 agent 必須：
	•	檢查自己是否被說服
	•	明確說明有無改變立場
	•	列出 survived attacks 與 unanswered attacks
	•	重新評估 confidence
	•	寫自己的 revision artifact

Required schema

belief_revision:
  agent: pragmatic-critic
  prior_position: accept
  current_position: revise
  changed: true
  why_changed:
    - ...
  attacks_survived:
    - ...
  attacks_not_answered:
    - ...
  remaining_confidence: 0.00-1.00


⸻

Stage 4 — Arbitration

Arbiter 只看：
	•	framing artifact
	•	三個 stage1 stance files
	•	三個 stage2 cross-exam files
	•	三個 stage3 belief-revision files

Arbiter 不應重新開新論點，而應判斷：
	•	哪個 case 經攻擊後仍成立
	•	哪些風險仍未解
	•	這次是 strong / weak / provisional consensus
	•	minority report 是什麼

Required schema

decision:
  ruling: accept | reject | revise | investigate
  rationale:
    - ...
  winning_case:
    - ...
  minority_report:
    - agent: ...
      thesis: ...
      why_not_selected: ...
  unresolved_questions:
    - ...
  confidence: 0.00-1.00
  consensus_type:
    strong | weak | provisional


⸻

Stage 5 — Decision Dossier

Coordinator 組裝 final dossier，但不得重寫其他 agent 檔案內容。Coordinator 只能：
	•	index artifacts
	•	摘錄 file paths
	•	匯總 final ruling
	•	列出 next actions

Final dossier path

.claude/outputs/decisions/{decision_id}/dossier.md
.claude/outputs/decisions/{decision_id}/dossier.json


⸻

8. Artifact policy

8.1 Output root

所有 deliberation artifacts 放在：

.claude/outputs/decisions/{decision_id}/

8.2 Agent-owned files

每個 subagent 必須直接寫自己的檔案，不得讓 Coordinator 代寫。

建議命名：

stage1-analytical-critic.md
stage1-risk-critic.md
stage1-pragmatic-critic.md
stage2-analytical-critic-cross-exam.md
stage2-risk-critic-cross-exam.md
stage2-pragmatic-critic-cross-exam.md
stage3-analytical-critic-revision.md
stage3-risk-critic-revision.md
stage3-pragmatic-critic-revision.md
stage4-arbiter.md
dossier.md
dossier.json

8.3 Content ownership rule
	•	Stance file 只能由對應 stance agent 寫
	•	Arbiter file 只能由 arbiter 寫
	•	Dossier 只能由 coordinator 寫
	•	Coordinator 不得修改其他 agent 已生成的 artifact

這個規則是為了保護 deliberation provenance。

⸻

9. Permissions model

本版不用 hooks，直接依賴 Claude Code settings 與 subagent tools。

9.1 Why settings-first

Claude Code 官方支援 user/project/local 三層 settings，並可在 settings.json 或 settings.local.json 內配置 permissions 規則。這些規則作用於整個 session，適合拿來做 MVP 的硬限制。 ￼

9.2 Why Edit is needed

由於本系統要求 subagent 直接寫自己的 artifact files，因此各 stance agents 與 arbiter 都需要 Edit。若沒有 Edit，就只能把內容回傳給 Coordinator，再由 Coordinator 代寫，這會破壞內容所有權與 provenance。Claude Code 的核心能力包含讀寫檔案，因此這樣的設計是合理的。 ￼

9.3 Policy statement

在 deliberation mode 下，Edit 的用途被概念上限定為 artifact writing only。
不得修改：
	•	application source files
	•	test files
	•	build configs
	•	deployment manifests
	•	secret-bearing files
	•	credentials
	•	environment files

這個限制由 settings 與 workflow 規格共同實施。Claude Code settings 明確支援 project 與 local 範圍設定，適合做這類政策。 ￼

⸻

10. Recommended project structure

.claude/
  agents/
    coordinator.md
    analytical-critic.md
    risk-critic.md
    pragmatic-critic.md
    arbiter.md
  skills/
    deliberate-consensus/
      SKILL.md
      templates/
        stage0-framing.md
        stage1-stance.md
        stage2-cross-exam.md
        stage3-belief-revision.md
        stage4-arbitration.md
        dossier.md
  outputs/
    decisions/
  settings.json
  settings.local.json

這個結構符合 Claude Code 的 project-level agents、skills、與 settings 的使用方式。 ￼

⸻

11. Example subagent specs

下面是精簡版 frontmatter 設計。

coordinator.md

---
name: coordinator
description: Coordinates the deliberative consensus workflow and manages artifact paths without rewriting subagent outputs.
tools: Read, Glob, Grep, Edit
---

analytical-critic.md

---
name: analytical-critic
description: Evaluates technical correctness, assumptions, causal logic, and evidence sufficiency.
tools: Read, Glob, Grep, Edit
---

risk-critic.md

---
name: risk-critic
description: Evaluates safety, failure modes, operational risk, rollback risk, and long-tail edge cases.
tools: Read, Glob, Grep, Edit
---

pragmatic-critic.md

---
name: pragmatic-critic
description: Evaluates delivery realism, maintainability, cost, and team adoption burden.
tools: Read, Glob, Grep, Edit
---

arbiter.md

---
name: arbiter
description: Produces the final ruling after comparing surviving arguments, unresolved risks, and minority positions.
tools: Read, Glob, Grep, Edit
---

Claude Code 官方文件確認 subagents 可透過 agent files 定義名稱、描述與工具；這正是這裡採用的模式。 ￼

⸻

12. Skill spec

deliberate-consensus/SKILL.md 應包含：
	•	workflow purpose
	•	state machine digraph
	•	stage-by-stage protocol
	•	artifact naming rules
	•	required schemas
	•	evidence policy
	•	stop conditions
	•	dossier assembly rules

Claude Code 官方文件說明，skills 由 SKILL.md 定義，Claude 會在相關情境下使用，或用 slash command 明確調用。 ￼

Suggested frontmatter

---
name: deliberate-consensus
description: Run a structured deliberation workflow with stance generation, cross-examination, belief revision, arbitration, and dossier generation.
---


⸻

13. Evidence policy

本 workflow 不接受只有 opinion、沒有 evidence 的論點作為主勝因。

Rules
	1.	每個 critical claim 應附至少一條 evidence reference
	2.	沒有證據的內容必須標成 hypothesis
	3.	cross-exam 不能只說「我不同意」，必須指出 assumption / evidence / reasoning 的具體弱點
	4.	arbiter 對 evidence-poor claims 必須降權
	5.	若關鍵證據缺失，最終 ruling 應可退化為 investigate

這樣的規則與 Claude Code 的常見 workflow 風格一致：先掃描 codebase、查證檔案，再進入判斷，而不是純語言辯論。 ￼

⸻

14. Stop conditions

Coordinator 在以下情況可停止新一輪辯論：
	•	已完成 1 次 stance generation、1 次 cross-exam、1 次 belief revision
	•	或兩個以上 agents 收斂到同一 ruling，且沒有高嚴重度 unanswered attack
	•	或 arbiter 判定證據不足，結果降為 investigate
	•	或達到 max_rounds

這可防止 workflow 退化為無限爭辯。

⸻

15. Consensus labels

strong

多方經攻擊後仍一致，且高嚴重度攻擊多已回應。

weak

存在明確主結論，但仍有重要反方保留。

provisional

證據不足或條件未滿足，只能暫時裁決。

這些標記由 arbiter 產出，讓 final dossier 不只給 answer，也交代 answer 的穩定度。

⸻

16. MVP implementation policy

Included in v2
	•	project-level subagents
	•	one main skill: deliberate-consensus
	•	settings-based permission control
	•	artifact-writing by each subagent
	•	dossier output

Explicitly deferred
	•	hooks
	•	MCP-based orchestration
	•	automatic PR comments
	•	autonomous code modification
	•	cloud/infrastructure side effects

這樣範圍最穩，也最符合你現在的核心目標：先把 deliberation mechanism 做對。

⸻

17. Suggested settings policy text

你可以把這段直接放進 spec：

Use `.claude/settings.json` for team-shared deliberation policies and `.claude/settings.local.json` for local experimentation. During deliberation mode, subagents may use `Edit` only for writing workflow artifacts under `.claude/outputs/decisions/`. They must not modify application source files, tests, infra files, secrets, or environment-bearing files.

這段是基於 Claude Code 對 project/local settings 的正式支援，以及 permissions 規則可放在 settings 中的能力。 ￼

⸻

18. One-line summary

Spec v2 把 Claude Code 變成一個以制度化衝突為核心的 deliberation runtime：Coordinator 只控流程，不代寫內容；stance agents 與 arbiter 直接寫自己的 artifact files；settings 負責 MVP 階段的硬邊界；最終輸出是帶 provenance 的 decision dossier，而不是普通的多 agent summary。  ￼
