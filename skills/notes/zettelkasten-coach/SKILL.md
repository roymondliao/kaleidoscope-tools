---
name: zettelkasten-coach
description: >
  Transform literature content or research ideas into Zettelkasten-compliant permanent notes.
  Use when asked to convert papers/blogs/notes into permanent notes, create atomic notes
  from research content, synthesize literature into insights, or execute Phase 4 (Synthesize)
  of the research workflow.
---

# Goal

協助使用者執行研究工作流程中最關鍵的 **Phase 4 (轉化)**：將輸入的「文獻內容」或「研究想法」，轉化為符合學術標準的永久筆記 (Permanent Notes)。

# Rules for Output

1. **原子化原則**：每張永久筆記只包含一個核心論點
2. **Metadata 完整性**：必須包含 Type, Previous, Source, Related, Tags
3. **去脈絡化寫作**：內容必須「自解釋」，用使用者的話重新闡述，而非摘要原文
4. **遵循命名規則**：永久筆記用 `YYYYMMDDHHmm-{Slug}.md` 格式

# Workflow

當使用者輸入文獻內容或想法後，依序執行：

## Step 1: 文獻分析 (Literature Analysis)

- 列出這份內容試圖解決的研究問題 (Research Gap)
- 抓出 3 個關鍵概念 (Key Concepts)

## Step 2: 永久筆記生成 (Permanent Note Generation)

生成 2-3 張永久筆記，每張使用以下格式：

```markdown
# {YYYYMMDDHHmm}-{Slug短標題}

> **Metadata**
> - **Type**: #Permanent
> - **Previous**: (留空，由使用者填寫思考源頭)
> - **Source**: [[{使用者提供的文獻來源}]]
> - **Related**:
>   - [[{建議的相關概念1}]]
>   - [[{建議的相關概念2}]]
> - **Tags**: #{領域} #{具體主題}

## 核心主張 (Core Claim)
{用學術但易懂的語言，完整論述這個觀點。約 150 字。}

## 證據與脈絡 (Evidence / Context)
- 依據：...
- 限制條件：...

## 延伸思考
{提出一個這張筆記可能引發的後續研究問題}
```

## Step 3: MOC 建議

- 建議這些筆記可以歸檔在哪個更大的研究主題 (Topic) 之下
- 如果使用者有現存的 MOC，建議如何連結

# Trigger phrases / intents

Use this skill when the user says:

- "幫我把這篇論文/文章轉成永久筆記"
- "根據這段內容產生 Zettelkasten 筆記"
- "幫我萃取這篇文獻的核心觀點"
- "把這個想法轉成原子筆記"
- "協助我做 Phase 4 轉化"
- "Transform this into permanent notes"
- "Create atomic notes from this content"

# Example interaction

**User**: 幫我把這段內容轉成永久筆記：
> Chain-of-Thought prompting enables complex reasoning by having the model generate intermediate steps...

**Assistant**:

## 文獻分析

**Research Gap**: 如何讓 LLM 進行複雜推理而非直接輸出答案

**Key Concepts**:
1. Chain-of-Thought (CoT)
2. 中間步驟生成
3. 複雜推理能力

---

## 永久筆記 1

```markdown
# 202601161430-CoT透過中間步驟實現推理

> **Metadata**
> - **Type**: #Permanent
> - **Previous**:
> - **Source**: [[使用者提供的來源]]
> - **Related**:
>   - [[Prompt工程]]
>   - [[LLM推理機制]]
> - **Tags**: #LLM #CoT #Reasoning

## 核心主張 (Core Claim)
Chain-of-Thought 的核心機制是讓模型在輸出最終答案前，先產生一系列中間推理步驟。這種方式將原本從輸入直接映射到輸出的高難度任務，分解為多個較簡單的子步驟，降低了模型的認知負擔。

## 證據與脈絡 (Evidence / Context)
- 依據：CoT prompting 論文實驗結果
- 限制條件：主要對需要多步推理的任務有效

## 延伸思考
中間步驟的「顯性化」是否意味著 token 消耗量與推理能力存在必然的權衡？
```

---

## MOC 建議

這張筆記可歸入 `MOC-LLM推理機制.md` 或 `MOC-Prompt工程技術.md`
