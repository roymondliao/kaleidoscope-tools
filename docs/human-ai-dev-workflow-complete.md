# Human-AI 開發流程完整方案

> 本文件整理了 Human 與 AI 協作開發的完整流程設計，包含現有 Skills 的運用以及需要自建的 Gap 解決方案。

---

## 流程總覽

| 步驟 | 內容 | Skill / 方案 | 狀態 |
|-----|------|-------------|------|
| 1 | Kickoff | Superpowers:brainstorming | ✓ 現有 |
| 2 | PRD + Plan | Superpowers:writing-plans | ✓ 現有 |
| 3 | Testing Plan | **自建 TPDD skill** | 🔨 待建 |
| 4 | Task 拆分 | **自動拆分成 tasks/** | 🔨 待建 |
| 5 | Implementation | feature-dev + TDD | ✓ 現有 |
| 6 | Validation | **Validation Agent** | 🔨 待建 |
| 7 | Code Review | gstack /review | ✓ 現有 |
| 8 | Commit & Push | gstack /ship | ✓ 現有 |

### 輔助層

| 項目 | 用途 |
|------|------|
| AGENTS.md | 撰寫統一規範（所有 agent 共享的 rules） |
| continuous-learning-v2 | 輔助 main agent 學習，跨所有階段自動學習 patterns |

---

## Gap 1: TPDD Testing Plan Skill

### 核心定義

- **Testing Plan ≠ Unit Tests**
- Testing Plan = Feature 最終 delivery 什麼結果 + 預期行為
- 一個 kickoff / feature / bug fix = **一份 testing plan**（Single Source of Truth）

### 內容層級

Testing Plan 應該達到 Level 1 和 Level 2 的標準：

**Level 1: 人類可讀的驗收標準**
```
用戶登入後應該看到 Dashboard
```

**Level 2: 結構化的測試步驟（Given-When-Then）**
```
Given: 用戶已註冊
When: 輸入帳密並點擊登入
Then: 顯示 Dashboard 頁面
```

**Level 3（不在 Testing Plan 範圍）:**
- 可直接轉換成 E2E 測試代碼
- 這部分涉及代碼的實際測試，屬於 Implementation 階段

### 產品類型對應

| 產品類型 | E2E 驗證方式 |
|---------|-------------|
| Frontend 產品 | Human 操作結果符合預期 |
| Backend 產品 | API/CLI response 正確 |

### 不在 Testing Plan 範圍

- **Unit tests** — Implementation 時 AI 自己寫
- **Integration tests** — Task plan 內定義，Implementation 時執行

---

## Gap 2: Task 拆分策略

### 選擇方案：方案 B（自動拆分）

**問題背景：**
- `Superpowers:writing-plans` 產出單一 `plan.md`（可能 500+ 行）
- 超過 40% 的 context window，AI 執行能力從 smart zone 掉到 dumb zone
- 需要解決 Context Window 問題

### 目錄結構

```
plan/
├── overview.md        # Goal, Architecture, Tech Stack（共享 context）
├── index.md           # Task 列表 + 狀態追蹤（Short-term Memory）
└── tasks/
    ├── task-1.md      # Task 1 完整內容
    ├── task-2.md      # Task 2 完整內容
    └── ...
```

### 各檔案用途

| 檔案 | 內容 | 用途 |
|------|------|------|
| `overview.md` | Goal, Architecture, Tech Stack | 共享 context，每個 session 都載入 |
| `index.md` | Task 列表 + 完成狀態 | Short-term Memory，知道進度 |
| `tasks/task-N.md` | 單一 Task 的完整內容 | 每次只載入當前執行的 task |

### 解決的問題

1. **Context Window** — 每次只載入一個 task（約 50-100 行）
2. **Session 延續性** — `index.md` 記錄進度
3. **新 Session 狀態** — 新開 session 也能知道之前處理的狀況

### 每次 Session 載入內容

```
載入順序：
1. overview.md（約 10-20 行）
2. index.md（知道目前進度）
3. 當前 task-N.md（約 50-100 行）

總計：約 100-200 行，遠低於 40% threshold
```

---

## Gap 3: Validation Agent

### 觸發時機

- **Feature-level**（整個 plan 執行完後）
- Task-level 的 unit/integration test 在 implementation 時做，不在 Validation Agent 範圍

### 驗證工具

| 產品類型 | 驗證工具 |
|---------|---------|
| Frontend | chrome-devtools-mcp / agent-browser |
| Backend | CLI / API 執行驗證 |

**參考資源：**
- https://github.com/anthropics/anthropic-quickstarts/tree/main/computer-use-demo
- https://github.com/anthropics/courses/tree/master/computer_use
- https://github.com/anthropics/anthropic-cookbook/tree/main/misc/computer_use_samples
- https://github.com/anthropics/mcp-servers
- https://github.com/anthropic-cookbook/anthropic-cookbook/tree/main/third_party/MCP_Server_Evals
- https://github.com/anthropics/courses/tree/master/claude_mcp

### 失敗處理流程

```
Implementation 完成
        ↓
Validation Agent 啟動
        ↓
讀取 testing-plan.md
        ↓
執行 plan 內定義的測試方式
        ↓
    ┌───┴───┐
    │       │
  Pass    Fail
    │       │
    ↓       ↓
Code    分析不通過原因
Review      │
            ↓
      Debug & Fix
            │
            ↓
      重新驗證
            │
      ┌─────┴─────┐
      │           │
   Pass      仍然 Fail
      │           │
      ↓           ↓
   Code      重試（最多 10 次）
   Review         │
                  ↓
            Human 介入
```

### 參考實現

- **Superpowers:verification-before-completion** — 可參考其驗證機制設計

---

## Skills 架構總覽

```
┌─────────────────────────────────────────────────────────────┐
│  Primary Framework: Superpowers                             │
│  ├── brainstorming → Kickoff                               │
│  ├── writing-plans → PRD + Tech Spec                       │
│  ├── TDD workflow → Implementation                         │
│  ├── subagent-driven-development → Parallel execution      │
│  └── code-review → PR Review                               │
├─────────────────────────────────────────────────────────────┤
│  QA & Review Enhancement: gstack                            │
│  ├── /qa → 自動分析 diff 並測試影響頁面                    │
│  ├── /browse → Browser automation                          │
│  └── /ship → 整合 Greptile 的 PR review                    │
├─────────────────────────────────────────────────────────────┤
│  AI Context Engineering: feature-dev                        │
│  └── code-explorer agent → Codebase 分析                   │
├─────────────────────────────────────────────────────────────┤
│  Meta Layer: continuous-learning-v2                         │
│  └── 跨所有階段自動學習 patterns                           │
├─────────────────────────────────────────────────────────────┤
│  待建 Skills（Gap 1, 2, 3）                                 │
│  ├── TPDD Testing Plan Skill → Step 3                      │
│  ├── Task Split Skill → Step 4                             │
│  └── Validation Agent → Step 6                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心設計原則

### TPDD（Testing Plan Driven Development）

Testing Plan 的本質與 E2E Testing 類似：

| 共同點 | 說明 |
|-------|------|
| Feature-level | 不是 code-level |
| 外部視角 | 從用戶/系統角度定義預期行為 |
| 需要執行驗證 | 不是靜態分析 |

| 差異點 | 說明 |
|-------|------|
| E2E Testing | 可執行的測試代碼（Cypress, Playwright） |
| TPDD Testing Plan | 更抽象的「驗收標準」（Level 1-2） |

### Context Window 管理

```
Smart Zone: < 40% context window
Dumb Zone: > 40% context window

解決方案：
├── 拆分 plan.md 成獨立 task files
├── 每次只載入 overview + index + 當前 task
└── 維持在 Smart Zone 內執行
```

### Session 延續性

```
Session 1 → 讀 overview + index → 執行 task-1 → 更新 index
Session 2 → 讀 overview + index → 知道 task-1 完成 → 執行 task-2
Session N → 讀 overview + index → 執行最後一個 task → 觸發 Validation
```

---

## 下一步行動

1. **Gap 1: TPDD Testing Plan Skill**
   - 設計 testing-plan.md 的具體結構
   - 定義 Level 1 和 Level 2 的模板
   - 建立 skill 的觸發條件

2. **Gap 2: Task Split Skill**
   - 設計 plan.md → tasks/ 的拆分邏輯
   - 定義 overview.md 和 index.md 的結構
   - 建立自動拆分的 prompt/script

3. **Gap 3: Validation Agent**
   - 設計 agent 的執行流程
   - 整合 chrome-devtools-mcp / agent-browser
   - 定義 debug & fix 循環的具體邏輯

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|-----|------|------|
| 1.0 | 2026-03-17 | 初版：完整流程設計 + Gap 1/2/3 方案 |
