# Human-AI 開發流程補充草稿 v1.1

> 本文件基於 `human-ai-dev-workflow-complete.md` 補充缺漏的治理機制、責任邊界、交付品質要求與例外處理流程。
>
> 目的不是取代原文件，而是作為下一版整合前的補充草稿，供 Human review、補充與定稿。

---

## 文件定位

- **原始文件**：`docs/human-ai-dev-workflow-complete.md`
- **本文件用途**：補齊原文件尚未明確定義的 operational details
- **適用範圍**：功能開發、bug fix、重構、驗證、review、交付
- **不涵蓋範圍**：組織流程、人員管理、正式上線審批制度

---

## 本版補充重點

本文件重點補強以下幾類缺口：

1. **Workflow Gates**
   - 定義每一步的輸入、輸出、完成條件
2. **Human-AI Responsibility Boundary**
   - 明確哪些決策由 Human 做，哪些可由 AI 自主處理
3. **Testing Strategy Layering**
   - 區分 Testing Plan、Unit Tests、Integration Tests、Validation
4. **Failure / Retry / Escalation Policy**
   - 失敗後何時重試、何時停止、何時請 Human 介入
5. **Quality / CI / Security / Infra 補充規範**
   - 將工程品質標準正式接進工作流程

---

## 一、Workflow Gates

> 建議將原始 8 個步驟都補上 Entry Criteria、Outputs、Exit Criteria、Owner。

### Step 1: Kickoff

#### Entry Criteria

- 已有初步需求、問題描述或目標
- 已知主要使用者或受影響系統
- 至少知道這次工作的基本類型：feature / bug fix / refactor / infra

#### Outputs

- 問題陳述
- 初步目標
- 初步限制條件
- 待釐清問題清單

#### Exit Criteria

- Human 與 AI 對問題定義已有共同理解
- 至少產出一版可供展開 planning 的描述
- 未知問題已被明確列出，而不是被忽略

#### Owner

- **Human**：提供背景與優先級
- **AI**：整理問題、提出澄清問題、抽出限制條件

#### 待補充

- **TODO**：Kickoff 階段是否需要固定模板？
- **TODO**：哪些情況下不允許直接跳到 planning？

---

### Step 2: PRD + Plan

#### Entry Criteria

- Kickoff 已完成
- 關鍵未知已部分澄清，或已明確標記為待研究

#### Outputs

- `plan.md` 或等價規劃文件
- 範圍界定（Scope / Non-goals）
- 風險與依賴清單
- 驗收方向草稿
- 初步 task grouping

#### Exit Criteria

- 需求範圍明確
- 重要 unknowns 已被記錄
- 後續可拆分成具體 task
- Human 已確認這份計畫可執行

#### Owner

- **Human**：確認方向、取捨、目標與非目標
- **AI**：整理規劃、識別風險、提出設計建議

#### 待補充

- **TODO**：PRD 與 Technical Plan 是否分成兩份文件？
- **TODO**：是否需要獨立 `decisions.md` 保存架構決策？

---

### Step 3: Testing Plan

#### Entry Criteria

- 功能範圍已定義
- 已知主要驗收場景

#### Outputs

- `testing-plan.md`
- Level 1 驗收標準
- Level 2 Given-When-Then 場景
- 例外情況與失敗場景

#### Exit Criteria

- 能用自然語言說清楚什麼叫做完成
- 能判斷功能是否符合預期
- 已包含至少一組正常流程與一組異常流程

#### Owner

- **Human**：確認驗收是否符合實際期待
- **AI**：整理測試計畫與場景覆蓋

#### 待補充

- **TODO**：是否要求每個 feature 都要有 edge cases？
- **TODO**：bug fix 的 testing plan 是否應包含 regression scenario？

---

### Step 4: Task 拆分

#### Entry Criteria

- plan 與 testing plan 已存在
- 已知主要技術方向與依賴

#### Outputs

- `overview.md`
- `index.md`
- `tasks/task-N.md`
- task 執行順序與依賴說明

#### Exit Criteria

- 每個 task 都可單獨執行
- task 順序符合依賴與風險優先級
- 單次 session 不需載入整份 plan

#### Owner

- **AI**：根據風險與依賴拆分 task
- **Human**：確認切分粒度與優先順序

#### 待補充

- **TODO**：task 拆分是以垂直切片、技術模組、還是驗收場景為主？
- **TODO**：task 是否需要固定欄位，例如 preconditions / touched files / risks？

---

### Step 5: Implementation

#### Entry Criteria

- 當前 task 已明確
- 已知相關 code context
- 已知對應驗收標準

#### Outputs

- 程式碼修改
- 單元測試 / 整合測試
- 必要的文件更新
- handoff 記錄

#### Exit Criteria

- 當前 task 的程式碼完成
- 對應測試已補齊並可執行
- 變更符合 coding standards
- task 狀態與 handoff 已更新

#### Owner

- **AI**：實作、補測試、驗證局部結果
- **Human**：針對高風險設計調整進行確認

#### 待補充

- **TODO**：是否要求每個 task 完成都更新 `index.md`？
- **TODO**：哪些類型的修改屬於高風險，需要先詢問 Human？

---

### Step 6: Validation

#### Entry Criteria

- feature 或可驗證切片已完成
- testing plan 已存在
- validation 環境可用

#### Outputs

- `validation-report.md`
- 驗證結果
- 失敗原因分類
- 修復建議或重新驗證記錄

#### Exit Criteria

- 驗證結果明確為 pass / fail / blocked
- 若 fail，已分類原因並決定後續動作
- 若 blocked，已記錄阻塞點與所需協助

#### Owner

- **Validation Agent**：執行 feature-level 驗證
- **Human**：對 blocked / high-risk fail 做決策

#### 待補充

- **TODO**：validation report 是否要標準化？
- **TODO**：是否要求附上 screenshot / logs / API response evidence？

---

### Step 7: Code Review

#### Entry Criteria

- 實作完成
- validation 已有結果
- 變更範圍清楚

#### Outputs

- review comments
- review 結論
- 待修清單

#### Exit Criteria

- 阻擋性 review comment 已處理
- 重要設計疑慮已被回應
- merge / ship 條件達成

#### Owner

- **AI / Tooling**：初步 review
- **Human**：最終風險判斷與接受與否

#### 待補充

- **TODO**：哪些 review comment 屬於 blocking？
- **TODO**：AI review 與 Human review 的權重如何區分？

---

### Step 8: Commit & Push / Ship

#### Entry Criteria

- review 已完成
- 必要檢查已通過

#### Outputs

- commit
- PR / stack 更新
- ship 記錄

#### Exit Criteria

- 變更已被正確保存與提交
- 可追蹤本次交付內容
- 若需要部署，已有對應的 deployment gate

#### Owner

- **AI**：整理 commit scope、準備交付資訊
- **Human**：確認最終 ship 動作

#### 待補充

- **TODO**：commit message 是否有固定格式？
- **TODO**：push / merge / deploy 的權限邊界為何？

---

## 二、Discovery / Clarification Gate

> 在 Kickoff 與 PRD + Plan 之間，建議增加明確的需求澄清關卡。

### 建議最少回答以下問題

- **Problem**：這次要解決什麼問題？
- **Desired Outcome**：完成後應該達成什麼效果？
- **Non-goals**：這次刻意不做什麼？
- **Constraints**：有哪些限制？
- **Unknowns**：有哪些尚未確認的事？
- **Risks**：最可能出問題的是什麼？

### 補充模板

```md
## Discovery Notes

### Problem
- 待補充

### Desired Outcome
- 待補充

### Non-goals
- 待補充

### Constraints
- 待補充

### Unknowns
- 待補充

### Risks
- 待補充
```

### 待補充

- **TODO**：這一段要併入 `plan.md`，還是獨立成 `discovery.md`？

---

## 三、Artifact 結構建議

### 建議目錄結構

```text
plans/<feature-slug>/
├── overview.md
├── discovery.md
├── testing-plan.md
├── index.md
├── decisions.md
├── validation-report.md
└── tasks/
    ├── task-1.md
    ├── task-2.md
    └── ...
```

### 各文件建議用途

#### `overview.md`

- Goal
- Architecture
- Tech Stack
- Shared Context
- Authoritative references

#### `discovery.md`

- Problem
- Constraints
- Unknowns
- Risks
- Assumptions

#### `testing-plan.md`

- Level 1 acceptance criteria
- Given-When-Then scenarios
- edge cases
- regression scenarios

#### `index.md`

- 任務列表
- 進度狀態
- blocked items
- 下一步建議
- session handoff 摘要

#### `decisions.md`

- 關鍵設計決策
- 替代方案
- 選擇理由
- 後續影響

#### `validation-report.md`

- 驗證日期
- 驗證工具
- 驗證結果
- 失敗分類
- 修復建議
- evidence links

### 待補充

- **TODO**：這些文件是否全部必選？還是依專案類型裁切？
- **TODO**：是否需要版本編號與更新紀錄？

---

## 四、Human-AI Responsibility Matrix

> 建議將責任邊界明文化，避免 AI 在高風險情況下做出未授權決策。

### Human 必須決定的事項

- scope 變更
- 需求優先級取捨
- 架構方向重大調整
- 新增外部依賴或外部服務
- 資料模型破壞性變更
- Terraform apply / deployment 類高風險操作
- 涉及 secrets / credentials / production data 的動作

### AI 可自主處理的事項

- 已明確 task 內的小型實作
- 局部重構
- 補 unit tests / integration tests
- 依既有規範更新檔案
- 撰寫 validation / review 所需報告草稿

### AI 必須停下來詢問的情況

- 需求互相矛盾
- 找不到 authoritative logic
- validation 結果與預期不一致
- 修復某問題可能影響核心模組
- 需要引入新依賴或修改公共介面
- 發現安全、權限、資料隱私風險

### 待補充

- **TODO**：是否要依 task 類型設定不同授權等級？
- **TODO**：對 ask mode / code mode 是否要有不同邊界？

---

## 五、Testing Strategy Layering

### 1. Testing Plan

用途：定義 feature-level 驗收標準，不直接等於測試代碼。

#### 必備內容

- 正常流程
- 異常流程
- 邊界情況
- bug fix 的 regression scenario

### 2. Unit Tests

用途：驗證函式、類別、模組級邏輯。

#### 建議規則

- 新增功能要補對應單元測試
- bug fix 要補 regression test
- 測試應聚焦單一責任

### 3. Integration Tests

用途：驗證多模組或外部系統之間的整合。

#### 建議規則

- 資料流跨模組時應有整合驗證
- 涉及 DB / API / queue / CLI interaction 時優先考慮

### 4. Validation / E2E

用途：驗證對使用者可見的功能是否成立。

#### 建議規則

- 以 `testing-plan.md` 為依據
- 產出 evidence
- pass / fail / blocked 要明確分類

### 待補充

- **TODO**：是否要規定最小測試覆蓋標準？
- **TODO**：哪些小型修正可以免 integration tests？

---

## 六、Failure / Retry / Escalation Policy

### 驗證失敗分類建議

#### Spec Mismatch

- 功能結果與 testing plan 不一致

#### Environment Issue

- 環境設定、依賴、port、credential、fixture 問題

#### Flaky Validation

- 驗證不穩定、重跑結果不一致

#### Architectural Mismatch

- 問題不是小修可解，需要重新調整設計

#### Unsafe Change Risk

- 修復方式可能影響核心模組、資料結構或外部介面

### 建議處理原則

- **可重試**：環境暫時問題、已知 flaky case、明確低風險修正
- **不可無限重試**：同類錯誤重複出現、架構不匹配、高風險副作用
- **需 Human 介入**：需求不清、風險過高、修復方向涉及重大決策

### 建議停止條件

- 同類錯誤連續多次出現
- 修復範圍持續擴大
- 新問題數量超過已解決問題
- 驗證 evidence 顯示問題來自原始設計而非實作細節

### 待補充

- **TODO**：最多 10 次重試是否合理？是否應依錯誤類型調整？
- **TODO**：是否需要 failure report 模板？

---

## 七、Context Loading Policy

### 建議載入優先順序

1. 實際 codebase
2. 已確認的 plan / decisions
3. 當前 task 文件
4. 補充說明與歷史討論

### 基本原則

- code 是最終真相來源
- 文件是執行指引，不可凌駕於實際程式碼之上
- 若 plan 與 code 衝突，需要先查明原因，再決定修正哪一方
- 未查證的 function、API、file path 不可直接假設存在

### 建議 session 最小載入集

- `AGENTS.md`
- `overview.md`
- `index.md`
- 當前 `task-N.md`
- 相關模組的 authoritative source files

### 待補充

- **TODO**：是否要定義「重新探索 codebase」的觸發條件？

---

## 八、Session Handoff 建議

### 建議每次 task 更新至少包含以下欄位

```md
## Handoff

### Done
- 待補充

### In Progress
- 待補充

### Blocked By
- 待補充

### Next Recommended Action
- 待補充

### Open Questions
- 待補充

### Touched Files
- 待補充
```

### 目的

- 降低 session 切換成本
- 避免重複探索已知資訊
- 讓 Human 快速理解目前狀態

### 待補充

- **TODO**：handoff 放在 `index.md` 還是每個 `task-N.md`？

---

## 九、Quality Gates

### Python 專案建議最低要求

- 依賴使用 `uv` 管理
- 以 `pyproject.toml` 作為依賴與專案配置中心
- 測試使用 `pytest`
- 新增 public API 時補 type hints
- 公開 API 補 Google-style docstrings
- 關鍵流程補 logging
- 避免模糊或裸 `except`
- 外部輸入需驗證

### 實作完成前建議檢查項

- 功能是否符合 task 與 testing plan
- 是否補齊最小必要測試
- 是否影響現有 public interface
- 是否引入額外依賴
- 是否需要補文件
- 是否需要更新 handoff

### 待補充

- **TODO**：是否需要專案級 lint / type check / formatting 的標準指令？

---

## 十、CI / Review / Merge Gate

### 建議 minimum checks

- lint
- type check
- unit tests
- integration tests（若適用）
- feature-level validation result
- security scan（若適用）

### PR / Review 建議關注點

- 是否符合原始需求
- 是否引入不必要複雜度
- 是否破壞既有抽象邊界
- 是否具備可測試性
- 是否具備可觀測性
- 是否存在安全風險

### 待補充

- **TODO**：目前專案實際 CI 工具鏈是什麼？
- **TODO**：哪些 check 是 blocking，哪些是 advisory？

---

## 十一、Infrastructure Change Variant

> 若 task 涉及 Terraform 或基礎設施變更，建議走獨立檢查流程。

### 建議流程

1. 撰寫或調整 Terraform 配置
2. 執行格式與語法檢查
3. 執行 validate
4. 產出 plan
5. Human review plan 結果
6. 確認後再決定是否 apply

### 建議檢查指令

```bash
terraform fmt -check -recursive
terraform validate
terraform plan --var-file="<var_file>" -out="tfplan.binary"
```

### 建議原則

- AI 不應自行執行高風險 infra 變更
- plan 必須由 Human 檢閱
- 若涉及 production，需額外 deployment gate

### 待補充

- **TODO**：是否要區分 dev / staging / prod 的 apply 權限？

---

## 十二、Security / Secrets / Observability

### Security 最低要求

- 不得將 secrets 寫入程式碼或版本控制
- 新增外部服務時需定義 key 管理方式
- 涉及 auth / permission / user input 時要明確檢查
- 採用 least privilege 原則

### Observability 最低要求

- 關鍵流程需有可讀的 logging
- 錯誤應具備可定位資訊
- validation fail 應可追蹤到 evidence
- backend / CLI 功能需保留足夠輸出供除錯

### 待補充

- **TODO**：目前專案是否已有統一 logging / monitoring 方案？

---

## 十三、建議整合回原文件的方式

### 方案 A：原文件維持簡潔，本文件作補充規範

適合情境：
- 原文件想保持高層設計視角
- operational details 另存為 playbook

### 方案 B：將本文件精簡後整合回原文件，形成單一權威文件

適合情境：
- 希望降低查找成本
- 團隊偏好單一來源文件

### 建議

- 先用本文件進行 review 與補充
- 待欄位成熟後，再決定是否整併到原始文件

---

## 十四、待 Human 補充的問題清單

### 流程層

- Kickoff 是否需要固定模板？
- Discovery 是獨立文件還是併入 plan？
- 每一步是否都要有明確 owner？

### 交付層

- `validation-report.md` 是否必備？
- handoff 應放在 `index.md` 還是各 task 檔案？
- `decisions.md` 是否需要獨立保存？

### 治理層

- 哪些動作 AI 必須停下來請示？
- 哪些 review comment 算 blocking？
- retry 上限是否應按錯誤類型區分？

### 工程層

- Python 專案的 quality gate 要到什麼嚴格程度？
- CI minimum checks 的實際命令是什麼？
- Terraform 流程是否要獨立成一份 infra workflow？

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|-----|------|------|
| 1.1-draft | 2026-03-20 | 基於原始 Human-AI workflow 文件補充 operational gaps 的 review 草稿 |
