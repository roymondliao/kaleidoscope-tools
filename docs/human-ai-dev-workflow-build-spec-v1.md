# Human-AI Dev Workflow Build Spec v1

> 本文件定義 Human-AI 開發流程的建造規格。
>
> 它的目的不是完整規範所有治理細節，而是描述這套流程應如何透過 orchestrator、sub agents、skills、hooks 與文件 artifacts 被建立出來。

---

## 文件定位

目前 `docs/` 下三份文件的定位如下：

- `human-ai-dev-workflow-complete.md`
  - 流程總覽與 gap 定義
- `human-ai-dev-workflow-supplement-v1.1.md`
  - 補充治理、責任邊界、驗證與品質要求
- `human-ai-dev-workflow-questions-template-v1.0.md`
  - 待補充與待決策問題整理

本文件定位為：

- **Build Spec**
  - 說明這套 workflow system 要怎麼被實作出來
  - 定義最小可運作版本
  - 定義主要角色、資料流、檔案流與自動化接點

---

## 一、目標

### 主要目標

建立一套 Human-AI 協作開發流程，使 Human 提出需求後，系統能透過多個 agent 與 automation components，完成以下流程：

1. 需求澄清
2. PRD 產出
3. Task Plan 產出
4. Testing Plan 產出
5. Task Split
6. Task 實作
7. Validation
8. Review / Ship

### 核心設計原則

- **流程優先於治理細節**
  - 先讓 workflow 可運作，再逐步補治理規則
- **Orchestrator 為主控中心**
  - 所有 task 分派、狀態追蹤與恢復都由 orchestrator 控制
- **Artifacts 為流程記憶體**
  - 流程狀態不依賴單次 session，而是以文件保存
- **Sub agents 專注在局部任務**
  - 規劃、拆分、實作、驗證由不同 agent 或 skill 負責
- **Hooks 用於同步與恢復**
  - hooks 負責在流程中斷、結束、切換時同步關鍵狀態

---

## 二、非目標

本版 build spec 不處理以下內容的完整定義：

- 完整 CI/CD 治理手冊
- 完整 security policy
- 所有流程變體的最終規範
- 所有 validation failure 類型的最終分類
- metrics 與 observability 的最終標準

這些內容可於 workflow 建立完成後，再補進 supplement 或後續版本文件。

---

## 三、系統角色

### 1. Human

#### 責任

- 提供需求、背景與優先級
- 確認 PRD / Task Plan / Testing Plan
- 在高風險或不明確決策點做最終判斷
- 最終 review / ship decision

#### 不負責

- 手動維護每一步 task 狀態
- 手動執行所有 task split 與 session 恢復細節

---

### 2. Orchestrator Agent

#### 責任

- 作為整體 workflow 的主控 agent
- 讀取流程所需核心 artifacts
- 決定目前所在流程階段
- 呼叫對應的 skills / sub agents
- 更新 `index.md`、checkpoint 與整體狀態
- 在 session 中斷後恢復流程

#### 核心能力

- workflow state management
- artifact routing
- task dispatching
- recovery orchestration

#### 關鍵原則

- orchestrator 不應直接承擔所有細節實作
- orchestrator 的工作是調度，不是變成所有專家的集合

---

### 3. Planning Sub Agent / Skill

#### 責任

- 根據 Human 與主 agent 的 brainstorming 結果產出 PRD
- 根據 PRD 產出 Task Plan
- 根據 PRD 產出 Testing Plan

#### 輸出

- `prd.md`
- `task-plan.md`
- `testing-plan.md`

#### 備註

根據目前共識：

- Testing Plan 來自 PRD
- Task Plan 也來自 PRD
- Testing Plan 與 Task Plan 是平行產物，不是一前一後互相從屬

---

### 4. Task Split Sub Agent / Skill

#### 責任

- 讀取 `task-plan.md`
- 將完整 task plan 拆分為可執行的單一 task files
- 分析 task dependency
- 標記可平行執行與需線性執行的任務
- 產出 task tracking 結構

#### 輸出

- `overview.md`
- `index.md`
- `tasks/task-N.md`
- `checkpoint.md` 或等價 checkpoint artifact

---

### 5. Implementation Sub Agent

#### 責任

- 根據 orchestrator 指派實作單一 task
- 讀取必要 context 與對應 source files
- 實作程式碼
- 撰寫 unit tests
- 回報 task 完成狀態給 orchestrator

#### 完成條件

目前暫定為：

- code 完成
- 對應 unit test 通過
- handoff / 任務結果已回傳 orchestrator

---

### 6. Validation Agent

#### 責任

- 在所有 task implementation 完成且 unit tests 通過後被觸發
- 根據 `testing-plan.md` 執行 feature-level validation
- 回報 validation 結果
- 若失敗，將結果回交 orchestrator 做下一步決策

#### 觸發條件

目前暫定為：

- 所有 tasks 完成實作
- 所有 tasks 對應 unit tests 通過
- orchestrator 判定可進入 validation stage

---

### 7. Hooks

#### 責任

- 在流程中負責輕量同步與恢復資訊更新
- 在 session 開始或結束時維持必要上下文
- 可用於 checkpoint 寫入或狀態檢查

#### 不建議承擔的責任

- 不應由 hooks 承擔複雜決策邏輯
- 不應由 hooks 取代 orchestrator 的流程管理

---

## 四、核心 Artifacts

### 最小必要文件

```text
plans/<feature-slug>/
├── prd.md
├── task-plan.md
├── testing-plan.md
├── overview.md
├── index.md
├── checkpoint.md
└── tasks/
    ├── task-1.md
    ├── task-2.md
    └── ...
```

### 文件用途

#### `prd.md`

- 定義需求目標
- 定義 feature / bug fix 的預期成果
- 作為 Task Plan 與 Testing Plan 的共同來源

#### `task-plan.md`

- 記錄完整任務規劃
- 作為 task split 的輸入

#### `testing-plan.md`

- 定義整個 feature 的驗收標準
- 定義預期行為
- 若是 bug fix，定義修正後應恢復的行為

#### `overview.md`

- 記錄共享背景
- 記錄技術方向與共同上下文
- 作為 orchestrator 與 sub agents 的共享入口

#### `index.md`

- 作為 task checklist
- 記錄 task 狀態
- 讓 orchestrator 知道目前進度

#### `checkpoint.md`

- 記錄 orchestrator 執行到哪裡
- 記錄 session 中斷時的恢復點
- 記錄下一步應該做什麼

#### `tasks/task-N.md`

- 單一 task 的執行內容
- 單一 task 的 context
- 任務 dependency / notes / result

---

## 五、Artifact Flow

### Phase 1: Discovery / Kickoff

#### 輸入

- Human 需求
- 背景說明
- brainstorming 結果

#### 輸出

- `prd.md`

---

### Phase 2: Planning

#### 輸入

- `prd.md`

#### 輸出

- `task-plan.md`
- `testing-plan.md`

#### 說明

- `task-plan.md` 與 `testing-plan.md` 平行產出
- 二者都以 `prd.md` 為來源

---

### Phase 3: Task Split

#### 輸入

- `task-plan.md`
- `testing-plan.md`

#### 輸出

- `overview.md`
- `index.md`
- `tasks/task-N.md`
- `checkpoint.md`

#### 說明

- task split 主要依據 `task-plan.md`
- `testing-plan.md` 作為 feature-level 驗收背景，不要求與每個 task 一對一映射

---

### Phase 4: Implementation

#### 輸入

- `overview.md`
- `index.md`
- 當前 `task-N.md`
- 相關 source files

#### 輸出

- 程式碼變更
- unit tests
- task result 回報
- `index.md` 更新
- `checkpoint.md` 更新

#### 說明

- sub agent 完成 task 後回報 orchestrator
- orchestrator 更新整體狀態，而不是由 Human 手動同步

---

### Phase 5: Validation

#### 輸入

- `testing-plan.md`
- 已完成的 implementation
- `index.md`

#### 輸出

- validation result
- validation notes / report
- 若失敗，回傳 orchestrator 進入修正流程

---

### Phase 6: Review / Ship

#### 輸入

- validation result
- code changes
- task completion summary

#### 輸出

- review 結果
- ship decision

---

## 六、流程控制模型

### 高層流程

```text
Human Request
    ↓
Orchestrator 啟動
    ↓
Planning Skill 產生 prd / task-plan / testing-plan
    ↓
Task Split Skill 產生 overview / index / tasks / checkpoint
    ↓
Orchestrator 讀取 index 與 checkpoint
    ↓
指派單一 task 給 Implementation Sub Agent
    ↓
Sub Agent 回報結果
    ↓
Orchestrator 更新 index / checkpoint
    ↓
若仍有未完成 task，繼續分派
    ↓
所有 task 完成後觸發 Validation Agent
    ↓
Validation Pass → Review / Ship
Validation Fail → 回交 Orchestrator 處理
```

### 狀態控制原則

- orchestrator 是唯一 workflow state owner
- sub agents 是工作執行者，不是全局狀態管理者
- Human 提供決策，不負責維護機器狀態同步

---

## 七、Context Loading Model

### Orchestrator 最小載入集

- `prd.md`
- `task-plan.md`
- `testing-plan.md`
- `overview.md`
- `index.md`
- `checkpoint.md`

### Implementation Sub Agent 最小載入集

- `overview.md`
- 當前 `task-N.md`
- 相關 source files
- 必要時參考 `testing-plan.md`

### Validation Agent 最小載入集

- `testing-plan.md`
- validation 目標環境
- 相關實作結果

---

## 八、Recovery Model

### 目標

當 session 中斷時，流程不應依賴對話記憶恢復，而應依賴 artifacts 恢復。

### 恢復步驟

1. orchestrator 讀取 `checkpoint.md`
2. orchestrator 讀取 `overview.md`
3. orchestrator 讀取 `index.md`
4. 判斷目前停在哪個 task / phase
5. 決定是否重新指派 sub agent 或進入 validation

### 恢復原則

- `checkpoint.md` 記錄恢復起點
- `index.md` 記錄任務全局狀態
- `overview.md` 記錄共享背景與規範

---

## 九、MVP 範圍

### 第一版必須具備

- 1 個 orchestrator agent
- 1 個 planning skill 或 planning sub agent
- 1 個 task split skill 或 task split sub agent
- 1 個 implementation sub agent 流程
- 1 個 validation agent
- `plans/<feature-slug>/` artifact 結構
- `index.md` 狀態更新機制
- `checkpoint.md` 恢復機制

### 第一版可以先不處理

- metrics dashboard
- 完整 rollback policy
- 完整 CI integration
- 所有流程變體的細分規範
- advanced learning feedback loop

---

## 十、後續擴充方向

### 可在 v2 補充

- bug fix / feature / infra 的正式流程變體
- validation failure taxonomy
- review gate / CI gate
- metrics 與 observability
- continuous-learning-v2 的安全採納機制
- security / secrets / infra governance

---

## 十一、目前已採納的關鍵共識

以下內容來自目前文件與已填入的問題模板，並在本 build spec 採納：

- Testing Plan 與 Task Plan 都由 PRD 產生
- Testing Plan 與 Task Plan 是平行產物
- `testing-plan.md` 是 feature-level 文件
- bug fix 仍視為完整開發流程的一部分
- 不特別區分 hotfix 與 low-risk change 的獨立流程
- orchestrator 負責更新 `index.md` 與 checkpoint
- task split 需要考慮 task dependency 與可能的平行執行
- task 完成的最小標準為 code 完成、unit test 通過、結果回報 orchestrator

---

## 十二、尚未阻塞實作的開放問題

以下問題重要，但不應阻塞 v1 build：

- partial validation 如何定義
- regression scenario 的最終模板
- testing-plan 的版本管理細節
- handoff 是否要獨立成單獨文件
- metrics 如何蒐集
- validation evidence 的標準化格式

---

## 十三、建議的下一步

1. 定義 `plans/<feature-slug>/` 各文件的最小模板
2. 定義 orchestrator 的 state transition 規則
3. 定義 planning / task split / implementation / validation 的 skill interfaces
4. 實作 checkpoint 寫入與恢復機制
5. 以一個真實 feature 試跑整套流程

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|-----|------|------|
| 1.0 | 2026-03-20 | 基於 docs 現有 workflow 文件整理出的 build spec 初版 |
