# Human-AI 開發流程問題統整 Template v1.0

> 本文件整合以下來源的待補充問題，作為後續補強 workflow 的工作底稿：
>
> - `docs/human-ai-dev-workflow-complete.md`
> - `docs/human-ai-dev-workflow-supplement-v1.1.md`
> - Reference 1 / Reference 2

---

## 使用方式

- 每一題都包含可直接填寫的欄位。
- 已定案的內容可移回正式文件。
- 未定案的內容可保留在此持續追蹤。

### 建議填寫欄位

- **Decision**：最後決策
- **Reason**：決策理由
- **Owner**：誰負責確認
- **Impact**：會影響哪些文件 / skill / 流程
- **Open Questions**：尚未解答的細節

---

## 一、流程銜接與總體結構

### 1. Step 2 → Step 3 → Step 4 的關係

#### 問題

- Testing Plan 根據什麼產生？`plan.md`、PRD，還是兩者？
- 應先寫 Testing Plan 再做 Task Split，還是相反？
- `testing-plan.md` 是整個 feature 一份，還是每個 task 都有局部驗收條件？

#### Template

- **Decision**：
* Testing Plan 會根據 PRD 產生，Plan 的內容是規劃 tasks 的細節(Task plan)。
* 如 Reason 所述，有的 Tasks Plan 後要進行 tasks split。Testing Plan 跟 Tasks Plan 是並行的。
* `testing-plan.md` 是整個 feature 一份，
  - 預期這個 kickoff 要達到什麼期望
  - 這個 feature 的預期行為是什麼
  - Bug fix 修正的後的行為應該是什麼

- **Reason**：
1. Testing Plan 是基於 PRD 來規劃的，而 PRD 是在 Step 2 產生的。
2. 與 Agent brainstorming 之後，確定方向跟內容，就會產生 PRD，根據 PRD 的內容會產生：
   - Tasks Plan(這也就是 Superpowers:writing-plans 在做的事情)
   - Testing Plan
3. 有的 Tasks Plan 後要進行 tasks split，因為 `Superpowers:writing-plans` 產生的 Task plan 是一份完整且詳細的 task plan，需要將每個 task split 出來，這樣才不會一次輸入過多的 task 給 Agent

- **Owner**：
- Task Plan: human
- Testing Plan: human

- **Impact**：
- **Open Questions**：

---

### 2. Workflow Gates 是否強制化

#### 問題

- 8 個步驟是否都要有 `Entry Criteria / Outputs / Exit Criteria / Owner`？
- 哪些步驟可簡化？哪些不可跳過？

#### Template

- **Required Gates**：
- **Skippable Steps**：
- **Non-skippable Steps**：
- **Owner**：
- **Open Questions**：
這個問題的意思是 1 or 2?
1: 是指 8 個步驟都要像是 checklist 的方式來確認目前的 step ?
2: 是指每一個步驟都要有明確的 input 是什麼，output 是什麼?

---

### 3. Validation 觸發條件

#### 問題

- 怎麼判定「所有 task 都完成了」？
- Validation 是 `index.md` 全完成後自動觸發，還是手動觸發？
- 可否先做 partial validation？

#### Template

- **Trigger Rule**：
1. 當所有 tasks 的實作都通過 unit test 後，自動觸發 validation
- **Manual or Automatic**：
1. 自動觸發
- **Partial Validation Policy**：
- **Owner**：
- **Open Questions**：
1. Partial Validation 是指什麼？

---

## 二、流程變體

### 4. Bug Fix 流程

#### 問題

- Bug fix 是否需要完整 8 步驟？
- Bug fix 的 Testing Plan 應該長什麼樣子？
- 是否必須包含 regression scenario？

#### Template

- **Bug Fix Workflow Variant**：
Bug fix 的 Testing Plan 應該就是會在 user 與 AI 明確分析完 bug 的 root cause 後，AI 根據分析的內容來編寫 testing plan，並讓 user 來 review。
Bug fix 本質上也是一個 feature 開發，只是是在解決既有的 codebase 問題，而不是 add new feature，所以是需要完整的 eight steps.

- **Required Artifacts**：
- **Regression Requirement**：
1. 必須包含 regression testing，但是一般的 regression testing 通常包含哪些？因為這會根據 project 有什麼內容來決定。
- **Owner**：

---

### 5. Hotfix / Fast Track 流程

#### 問題

- 是否需要緊急修復的簡化流程？
- 哪些步驟可縮短？
- 事後是否必須補完整文件與驗證紀錄？

#### Template

- **Decision**：
基本上 hotfix 也就是走 bugfix 的流程，在 Agent 的時代，開發已經是"秒"級地前進，所以不用區分所謂的 bugfix or hotfix，因為開發週期都是差不多的。
- **Fast Track Criteria**：
- **Minimum Required Steps**：
- **Post-fix Follow-up**：
- **Owner**：

---

### 6. 小改動 / 低風險變更

#### 問題

- 一行 config、文件修正、小型 refactor 是否需要完整流程？
- 哪些項目可簡化？哪些不可省略？

#### Template

- **Decision**：
基本上小改動也就是走 feature development 的流程，在 Agent 的時代，開發已經是"秒"級地前進，所以不用區分所謂的 feature development or low-risk change，因為開發週期都是差不多的。
- **Low-risk Change Definition**：
- **Simplified Flow**：
- **Non-skippable Checks**：
- **Owner**：

---

## 三、Artifact 與檔案結構

### 7. Plan Folder 的標準結構

#### 問題

- `testing-plan.md` 放在 `plan/` 裡還是根目錄？
- `discovery.md`、`decisions.md`、`validation-report.md` 是否必備？
- 是否需要版本欄位與更新紀錄？

#### Template

- **Decision**：
1. 基本上是會根據 Superpowers 的設計來做改動，所以應該是在 `testing-plan` folder 下面的檔案結構會比較清楚。
- **Required Files**：
- **Optional Files**：
- **File Locations**：
- **Versioning Rule**：
- **Owner**：

---

### 8. `index.md` 更新機制

#### 問題

- 誰負責更新 task 狀態？AI、Human，還是 script/hook？
- 何時更新？
- `blocked / in_progress / completed` 的標準是什麼？

#### Template

- **Decision**：
1. 要由 orchestrator agent 來更新 task 狀態，sub agent 必須要回到完成狀況。
2. agent or sub agent 完成 task 更新狀態。
- **Updater**：
- **Update Timing**：
- **Status Definitions**：
- **Conflict Resolution**：
- **Owner**：

---

### 9. Session Handoff / Checkpoint

#### 問題

- handoff 放在 `index.md` 還是 `task-N.md`？
- Session 中途中斷時如何恢復？
- 是否需要 checkpoint 機制？

#### Template

- **Decision**：
1. 為什麼會需要 handoff? 是什麼情況需要 handoff?
2. Session 如果中斷，orchestrator agent 透過讀取 checkpoint 來恢復，根據 index.md 來了解目前的 task 進度。
3. index.md 就像是 check list 一樣，紀錄目前所有 task 的狀態。
4. checkpoint 就像是紀錄目前執行到哪個 task 的細項，斷掉的時間點，會從這個地方開始恢復。
- **Handoff Location**：
- **Checkpoint Policy**：
- **Recovery Procedure**：
當 orchestrator agent 需要恢復時，會讀取 checkpoint 來恢復，然後再去讀取 `overview.md` and `index.md` 來了解 project 的規範跟目前的 task 進度，在指派給 sub agent。
- **Owner**：

---

## 四、Task 拆分與執行協調

### 10. Task 拆分原則

#### 問題

- task 應以垂直切片、技術模組、驗收場景，還是依賴關係來拆？
- task 與 testing plan 是否一對一映射？

#### Template

- **Split Strategy**：
1. 會根據 `Superpowers:write-plan` 的內容來拆分 task。
2. Task plan 與 testing plan 不是一對一映射關係。
- **Mapping to Testing Plan**：
- **Owner**：
- **Open Questions**：

---

### 11. Task 依賴與平行執行

#### 問題

- 若 Task B 依賴 Task A，要如何表達？
- 哪些 task 可以平行？
- 平行 task 如何協調 context 與 merge？

#### Template
- 在拆分 Task 的時候，需要分析 task 之間的依賴關係，以及哪些 task 可以平行執行。

- **Dependency Representation**：
- **Parallel Execution Rule**：
- **Coordination Mechanism**：
- **Owner**：

---

### 12. Task 完成標準

#### 問題

- Task 完成是 code 寫完、測試通過、handoff 更新，還是 commit 完成？
- 是否需要 Human 確認？
- 如何表示部分完成？

#### Template

- **Definition of Done**：
1. Task 完成是 code 寫完、測試 unit test 通過，handoff 更新
2. Orchestrator agent 會在 Task 完成後，更新 index.md 來記錄 task 的狀態
- **Partial Completion Status**：
- **Human Approval Requirement**：
- **Owner**：

---

## 五、Testing Plan 與驗收策略

### 13. Testing Plan 的內容邊界

#### 問題

- 除了 happy path，是否要強制包含：
  - 錯誤輸入
  - 權限 / 邊界條件
  - 向後相容性
  - bug fix regression

#### Template

- **Required Scenarios**：
- **Optional Scenarios**：
- **Bug Fix Additions**：
- **Owner**：
- **Open Questions**：
這問題的內容請在詳細說明。

---

### 14. Testing Plan 的版本控制與 SSOT

#### 問題

- 需求變更時，誰更新 Testing Plan？
- 誰維護 single source of truth？
- 舊版本如何保留或追蹤？

#### Template

- **Source of Truth**：
- **Update Owner**：
- **Change Management Rule**：
- **Version Tracking**：
- **Open Questions**：
1. 什麼是 SSOT?
2. Testing Plan 會是文檔紀錄，為什麼會需要版控？跟 `Superpowers:write-plan` 一樣在產生 file 都會有明確的 date 在檔名中，且 file name 會根據該下的任務來命名。

---

### 15. Validation 對應哪份 Testing Plan

#### 問題

- Validation Agent 如何知道要讀取哪個 `testing-plan.md`？
- 多 feature 並行時如何區分？

#### Template

- **Binding Rule**：
- **Multi-feature Handling**：
- **Owner**：

---

## 六、Validation 與失敗處理

### 16. 部分通過 / 部分失敗

#### 問題

- 若 3/5 測試通過，狀態應是 fail、partial pass，還是 blocked？
- 部分失敗時，是否能繼續後續步驟？

#### Template

- **Allowed Statuses**：
- **Partial Pass Policy**：
- **Next-step Rule**：
- **Owner**：

---

### 17. Debug & Fix 對應範圍

#### 問題

- Validation 失敗後，Debug & Fix 改的是哪個 task？
- 若需要跨多個 task 修正怎麼處理？
- 是否需要 checkpoint 或版本回溯？

#### Template

- **Fix Scope Rule**：
- **Cross-task Fix Policy**：
- **Rollback / Checkpoint Rule**：
- **Owner**：

---

### 18. Human 介入後的流程

#### 問題

- 10 次重試後 Human 介入，之後如何把決策回傳給 AI？
- 是否需要 `Human Decision Log`？

#### Template

- **Escalation Trigger**：
- **Human Decision Recording**：
- **Feedback-to-AI Mechanism**：
- **Owner**：

---

## 七、Human-AI 責任邊界

### 19. Human 介入點

#### 問題

除了 validation fail 以外，還有哪些節點必須 Human review？

- Step 2 後 plan review？
- Step 3 後 testing plan review？
- Step 7 review 要檢查哪些項目？

#### Template

- **Mandatory Human Review Points**：
- **Review Scope per Step**：
- **Owner**：

---

### 20. AI 可自主更新哪些內容

#### 問題

- AI 是否可自動更新 `index.md`、`testing-plan.md`、`validation-report.md`？
- 哪些文件只能由 Human 定案？

#### Template

- **AI-editable Files**：
- **Human-owned Files**：
- **Approval-required Files**：
- **Owner**：

---

## 八、Skills 協調與 Orchestration

### 21. Skill 之間的介面定義

#### 問題

- `writing-plans` 產出 `plan.md` 後，Task Split Skill 如何接手？
- Skills 間如何傳遞 context？
- 是否需要標準輸入 / 輸出格式？

#### Template

- **Producer Skill**：
- **Consumer Skill**：
- **Interface Contract**：
- **Owner**：

---

### 22. 是否需要 Orchestrator

#### 問題

- 多個 skill 如何協調工作？
- 是否需要一個 orchestrator 控制流程狀態與 context 傳遞？

#### Template

- **Need Orchestrator**：
- **Why / Why not**：
- **Minimal Orchestration Requirement**：
- **Owner**：

---

### 23. `continuous-learning-v2` 的學習邊界

#### 問題

- 如何避免學到錯誤 patterns？
- 學習結果如何回饋到 `AGENTS.md` 或其他規範？

#### Template

- **Learning Scope**：
- **Validation Before Adoption**：
- **Feedback Destination**：
- **Owner**：

---

## 九、Quality / Metrics / Logging

### 24. Quality Gates

#### 問題

- Python 專案的 quality gate 要嚴格到什麼程度？
- 哪些檢查是 blocking，哪些是 advisory？

#### Template

- **Required Checks**：
- **Blocking Checks**：
- **Advisory Checks**：
- **Owner**：

---

### 25. Metrics 與流程成效追蹤

#### 問題

- 是否需要記錄每個步驟耗時、重試次數、成功率？
- 如何評估這套 workflow 是否有效？

#### Template

- **Metrics to Track**：
- **Collection Method**：
- **Review Cadence**：
- **Owner**：

---

### 26. Logging / Observability

#### 問題

- 是否需要標準化 validation evidence？
- 是否要統一 logging / monitoring 實踐？

#### Template

- **Evidence Standard**：
- **Logging Standard**：
- **Monitoring Standard**：
- **Owner**：

---

## 十、Infra / Security 補充

### 27. Infrastructure 變更流程

#### 問題

- Terraform 類型變更是否應走獨立 workflow？
- `plan` 是否必須 Human review？
- dev / staging / prod 權限是否分層？

#### Template

- **Infra Workflow Rule**：
- **Human Review Requirement**：
- **Environment Policy**：
- **Owner**：

---

### 28. Security / Secrets 邊界

#### 問題

- 哪些動作涉及 secrets / credentials / production data？
- 哪些操作 AI 必須停下來詢問？

#### Template

- **Sensitive Actions**：
- **AI Stop Conditions**：
- **Secret Handling Rule**：
- **Owner**：

---

## 十一、優先級整理

### P0

- 流程銜接關係
- 檔案結構定義
- `index.md` 更新機制
- Task 完成標準
- Validation 觸發條件

### P1

- Bug fix / hotfix / low-risk 變體
- Human 介入點
- 失敗處理與 rollback/checkpoint
- Skill 介面與 orchestration

### P2

- continuous-learning-v2 邊界
- metrics
- logging / observability
- infra / security 細化

---

## 十二、總結決策區

### 已定案

- 待補充

### 待定案

- 待補充

### 需先實驗後決定

- 待補充

### 建議先處理的前三項

- 待補充

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|-----|------|------|
| 1.0-draft | 2026-03-20 | 整合 complete / supplement / reference 分析後的問題統整 template |
