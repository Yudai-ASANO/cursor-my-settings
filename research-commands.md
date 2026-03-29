# Research: Cursor におけるコマンド・スキル・エージェントの使い分け

## Date: 2026-03-30

## Scope

Cursorの公式ドキュメントとコミュニティのベストプラクティスを調査し、「コマンド（スラッシュコマンド）」の公式推奨実装方法を明らかにする。

---

## Key Files

| 用途 | パス | 状態 |
|------|------|------|
| グローバルスキル | `~/.cursor/skills/*/SKILL.md` | **未作成** |
| グローバルエージェント | `~/.cursor/agents/*.md` | 作成済み（5体） |
| グローバルルール | `~/.cursor/rules/*.mdc` | 作成済み（7本） |
| レガシーコマンド | `~/.cursor/commands/*.md` | **非推奨（Skillsに移行済み）** |

---

## Architecture & Patterns

### 1. Cursorの3層カスタマイズ体系（公式）

Cursor 2.4以降、カスタマイズは以下の3層に整理された:

```
Rules（静的コンテキスト・常時ロード）
  ↓ 「何を常に覚えておくべきか」
Skills（動的コンテキスト・オンデマンド）
  ↓ 「特定の状況で何をすべきか」
Subagents（独立コンテキスト・並列実行可能）
  ↓ 「複雑なマルチステップタスクの委譲」
```

### 2. Commands は Skills に統合された（重要な発見）

**Cursorの「Commands」（`~/.cursor/commands/*.md`）はレガシー機能であり、Cursor 2.4 で Skills に統合された。**

- `/migrate-to-skills` コマンドで既存コマンドをスキルに変換可能
- 変換時、`disable-model-invocation: true` が設定され、明示的な `/skill-name` 呼び出しのみで動作する（従来のスラッシュコマンドと同じ挙動）
- 公式ドキュメントはSkillsを推奨方法として記載

**出典**: https://cursor.com/docs/skills

### 3. Rules vs Skills vs Subagents の使い分け（公式推奨）

| 概念 | 格納場所 | トリガー | 用途 |
|------|---------|---------|------|
| **Rules** | `.cursor/rules/*.mdc` | Always / Intelligent / glob / Manual | 静的指示: コードスタイル、規約、プロジェクト文脈 |
| **Skills** | `.cursor/skills/*/SKILL.md` | 自動（コンテキスト判断）or 明示的 `/skill` | 動的ドメイン知識 + スクリプト + 参照資料。**ツール間ポータブル** |
| **Subagents** | `.cursor/agents/*.md` | 親エージェントが自動委譲 or `/agent-name` | 独立コンテキストでの複雑タスク。並列実行可能 |

**コミュニティの合意**:
> 「Rulesはエージェントに常に覚えておくべきことを伝える。Skillsは特定の状況で何をすべきかを教える。Commandsは人間のためのショートカット。」

### 4. Skills のファイル構造

```
~/.cursor/skills/
  skill-name/
    SKILL.md          # メイン定義（必須）
    scripts/           # ヘルパースクリプト（任意）
    references/        # 参照ドキュメント（任意）
    assets/            # アセット（任意）
```

**SKILL.md のフォーマット**:
```yaml
---
name: skill-name
description: スキルの説明（自動適用判定に使用）
disable-model-invocation: false  # true = 明示的 /skill-name のみ
---

スキルの内容（Markdown）
```

**探索パス（優先度順）**:
1. `.agents/skills/` / `.cursor/skills/` （プロジェクトレベル）
2. `~/.cursor/skills/` （ユーザーレベル・グローバル）
3. `.claude/skills/` / `.codex/skills/` （レガシー互換）

### 5. Skills vs Subagents の判断基準（公式ドキュメント）

| 特性 | Skills | Subagents |
|------|--------|-----------|
| コンテキストウィンドウ | 親と共有 | 独立（隔離） |
| 並列実行 | 不可 | 可能 |
| ツール使用 | scripts/ 経由のみ | フルツールアクセス |
| トークンコスト | 低い（共有コンテキスト） | 高い（独立コンテキスト） |
| 用途 | 単発タスク、クイックアクション、ドメイン知識 | 複雑なマルチステップ、調査、検証 |

**公式推奨の選択基準**:
- **Skill**: 「単一目的のタスク、素早い繰り返しアクション、ワンショット完了」
- **Subagent**: 「コンテキスト隔離、並列ワークストリーム、専門的なマルチステップ」

---

## Dependencies & Data Flow

### 現在の設計との関係

```
現在の設計（research.md）:
  agents/
    planner.md          # Subagent: 仕様展開（Opus 4.6）
    qa-reviewer.md      # Subagent: 品質評価（GPT-5.4）
    security-reviewer.md # Subagent: セキュリティ（GPT-5.4）
    researcher.md       # Subagent: 調査（Gemini 3.1 Pro）
    architect.md        # Subagent: 設計判断（Opus 4.6）

ユーザーが追加したいコマンド:
  plan     → 実装計画の作成
  review   → コードレビュー
  search   → コードベース検索
  + 推奨コマンド
```

### 正しい実装方法

**前回のプランの問題点**: コマンドをすべて `agents/*.md`（Subagent）として実装しようとしていた。

**修正方針**:
- **軽量なコマンド** → `skills/*/SKILL.md` として実装（`disable-model-invocation: true`）
- **重量な委譲タスク** → `agents/*.md`（Subagent）のまま維持
- 両者を組み合わせる: Skill がトリガーとなり、必要に応じて Subagent を呼び出す

```
ユーザー → /plan（Skill）→ planner（Subagent）に委譲
ユーザー → /review（Skill）→ qa-reviewer（Subagent）に委譲
ユーザー → /search（Skill）→ 軽量ならSkill内で完結 / 重いなら researcher（Subagent）に委譲
ユーザー → /commit（Skill）→ Skill内で完結（git操作のみ）
```

### Claude Code との対応関係（更新）

| 概念 | Claude Code | Cursor（公式推奨） |
|------|------------|-------------------|
| スラッシュコマンド | `~/.claude/commands/*.md` | `~/.cursor/skills/*/SKILL.md`（`disable-model-invocation: true`） |
| サブエージェント | `~/.claude/agents/*.md` | `~/.cursor/agents/*.md` |
| 静的ルール | `CLAUDE.md` + `~/.claude/rules/*.md` | `.cursor/rules/*.mdc` + `AGENTS.md` |
| 自動適用スキル | superpowers skills（自動判定） | Skills（`disable-model-invocation: false`） |

---

## Constraints & Invariants

### 技術的制約

1. Skills は Cursor 2.4 以降で利用可能
2. `disable-model-invocation: true` で明示的スラッシュコマンド化
3. Skills のスクリプトはシェルスクリプトとして実行される
4. Subagent はネスト不可（1階層のみ）
5. Skills と Subagents は異なるコンテキストモデル — Skills は親と共有、Subagents は独立

### 設計上の制約

1. Skills はプロジェクト間でポータブル（`.agents/skills/` 標準）
2. 1つの Skill = 1つの SKILL.md + 任意のサブディレクトリ
3. Skills 名はディレクトリ名で決定される

---

## Risks & Considerations

### 1. Skills と Agents の二重管理

Skills からエージェントを呼び出すパターンでは、Skill 内のプロンプトとエージェント定義の整合性を保つ必要がある。

### 2. deploy.sh の更新

現在の deploy.sh は `agents/` と `rules/` のみ配置。`skills/` ディレクトリの配置ロジックを追加する必要がある。

### 3. コンテキスト予算

Skills は親コンテキストを共有するため、大きな Skill 定義はコンテキストウィンドウを圧迫する。Skill は簡潔に、重い処理は Subagent に委譲するのが望ましい。

### 4. レガシー commands/ との互換性

一部のCursorバージョンでは `commands/` もまだ動作する可能性があるが、公式は Skills への移行を推奨。新規作成は Skills で行うべき。

---

## Recommendations for Planning Phase

### 推奨アーキテクチャ

```
my-settings/
  agents/           # Subagents（重量タスク委譲）— 既存維持
    planner.md
    qa-reviewer.md
    security-reviewer.md
    researcher.md
    architect.md
  skills/            # Skills（スラッシュコマンド）— 新規作成
    plan/
      SKILL.md       # /plan → planner subagent に委譲
    review/
      SKILL.md       # /review → 軽量レビュー or qa-reviewer に委譲
    search/
      SKILL.md       # /search → 軽量検索 or researcher に委譲
    commit/
      SKILL.md       # /commit → Conventional Commits（Skill内完結）
    explain/
      SKILL.md       # /explain → コード説明（Skill内完結）
    debug/
      SKILL.md       # /debug → 体系的デバッグ（Skill内完結）
    test/
      SKILL.md       # /test → TDDワークフロー（Skill内完結）
    orchestrate/
      SKILL.md       # /orchestrate → ワークフロー駆動
  rules/             # Rules（静的コンテキスト）— 既存維持
    ...7本
  scripts/
    deploy.sh        # 更新必要: skills/ の配置を追加
```

### Skill 設計方針

1. **明示呼び出し型**: 全 Skill に `disable-model-invocation: true` を設定（コマンドとして使うため）
2. **軽量設計**: Skill 本体は 50-100 行以内。重い処理は Subagent に委譲
3. **委譲パターン**: Skill が指示を定義し、Subagent が実行する（Skill = what, Subagent = how）

### コマンド一覧（推奨）

| # | コマンド | 実装 | 完結/委譲 |
|---|---------|------|----------|
| 1 | `/plan` | Skill → planner Subagent | 委譲 |
| 2 | `/review` | Skill → qa-reviewer Subagent | 委譲 |
| 3 | `/search` | Skill（軽量は内部完結、重いなら researcher） | 条件付き |
| 4 | `/commit` | Skill 内完結 | 完結 |
| 5 | `/explain` | Skill 内完結 | 完結 |
| 6 | `/debug` | Skill 内完結 | 完結 |
| 7 | `/test` | Skill 内完結 | 完結 |
| 8 | `/orchestrate` | Skill → 複数 Subagent チェーン | 委譲 |

---

## 参考リソース

| リソース | URL |
|---------|-----|
| Cursor Skills 公式ドキュメント | https://cursor.com/docs/skills |
| Cursor Rules 公式ドキュメント | https://cursor.com/docs/context/rules |
| Cursor Subagents 公式ドキュメント | https://cursor.com/docs/subagents |
| Cursor 2.4 Changelog | https://cursor.com/changelog/2-4 |
| Agent Best Practices (Cursor Blog) | https://cursor.com/blog/agent-best-practices |
| awesome-cursorrules (38.8k stars) | https://github.com/PatrickJS/awesome-cursorrules |
| bmadcode/cursor-custom-agents-rules-generator | https://github.com/bmadcode/cursor-custom-agents-rules-generator |
| chrisboden/cursor-skills | https://github.com/chrisboden/cursor-skills |
| gotalab/skillport | https://github.com/gotalab/skillport |
| SkillsAuth Skills Hub | https://skillsauth.com/skills/hub/for-cursor |
