# 調査レポート: ハーネス設計準拠とオーケストレーション実現性

## 発見事項

### 1. ハーネス設計への準拠度

Anthropic が 2026年3月に公開した [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) では、3エージェントアーキテクチャ（**Planner → Generator → Evaluator**）を推奨している。本構成との対応を以下に整理する。

#### コアコンポーネントの対応


| ハーネス設計の概念                                       | 本構成の対応                                                  | 準拠  | 備考                                                                                                                                  |
| ----------------------------------------------- | ------------------------------------------------------- | --- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Planner** — 1-4行の要件を詳細仕様に展開                   | `agents/planner.md` + `skills/plan/SKILL.md`            | ✅   | Anthropic の planner と同じ設計思想。技術詳細を指定しない点も一致                                                                                          |
| **Generator** — 仕様に従い実装を実行                      | **明示的な定義なし**                                            | ⚠️  | メインセッションが直接担当。`research.md` でも「implementer が未定義」と指摘済み                                                                               |
| **Evaluator** — 成果物を基準で PASS/FAIL 判定            | `agents/qa-reviewer.md` + `agents/security-reviewer.md` | ✅   | Anthropic の evaluator と同等。自己評価問題の回避（生成と評価の分離）も実現                                                                                    |
| **Sprint Contract** — 実装前の合意文書                  | `planner.md` の出力テンプレートに定義                               | ✅   | Anthropic: "generator と evaluator が sprint contract を交渉" → 本構成では planner が単独生成                                                      |
| **Grading Criteria** — 評価基準の明文化                 | `rules/quality-criteria.mdc` + `qa-reviewer.md` の5基準    | ✅   | Anthropic は design quality, originality, craft, functionality の4軸。本構成は Correctness, Completeness, Code Quality, Safety, Testing の5軸 |
| **Feedback Loop** — FAIL 時の修正→再評価               | `rules/orchestrate.mdc` Gate 3（最大3回リトライ）                | ✅   | Anthropic のパターンと同一構造                                                                                                                |
| **File-based Communication** — エージェント間のファイル受け渡し | **明示的な定義なし**                                            | ❌   | Anthropic: "Communication was handled via files" → 本構成にはハンドオフ artifact の仕様がない                                                       |
| **Context Reset** — コンテキスト枯渇対策                  | **明示的な定義なし**                                            | —   | Anthropic: Opus 4.6 ではコンテキスト不安が解消されたため sprint 構造を撤廃。本構成が Opus 4.6 前提であれば省略は合理的                                                      |


#### 準拠度の総合評価

**7項目中 5項目準拠、1項目部分的、1項目未対応**。コア構造（Planner-Generator-Evaluator + Sprint Contract + Feedback Loop）は概ね準拠している。主要ギャップは Generator の明示的定義とファイルベースのハンドオフ仕様。

---

### 2. オーケストレーション構成の分析

#### 二重定義の問題

オーケストレーションロジックが **3箇所** に分散しており、整合性リスクがある:


| ファイル                          | 種別    | alwaysApply | 内容                                           |
| ----------------------------- | ----- | ----------- | -------------------------------------------- |
| `rules/workflow.mdc`          | Rule  | **true**    | タスク種別判定 + 除外条件。「orchestrate ワークフローに従って実行」と指示 |
| `rules/orchestrate.mdc`       | Rule  | **false**   | エージェントチェーンの詳細定義。4ワークフローの全ステップを記述             |
| `skills/orchestrate/SKILL.md` | Skill | —           | ほぼ `orchestrate.mdc` と同内容のチェーン定義 + ゲート定義     |


**問題点**:

- `workflow.mdc`（alwaysApply: true）が「orchestrate ワークフローに従え」と指示するが、参照先の `orchestrate.mdc`（alwaysApply: false）は **自動ロードされない**。エージェントが `orchestrate.mdc` を能動的に読みに行く保証がない。
- `orchestrate.mdc` と `skills/orchestrate/SKILL.md` が同じチェーン定義を持つため、片方を更新してもう片方を更新し忘れるドリフトリスクがある。
- Cursor の仕様上、Rule（alwaysApply: false）は「Agent が関連性を判断して自動ロード」（Apply Intelligently）か「glob パターンでファイルマッチ」の挙動。`orchestrate.mdc` には glob 指定がないため Apply Intelligently 扱いとなり、確実にロードされるかはモデル依存。

#### エージェントチェーンの駆動メカニズム


| 要素      | 実装状況                             | 懸念                        |
| ------- | -------------------------------- | ------------------------- |
| チェーン定義  | 4タスク種別×ステップ定義あり                  | ✅                         |
| 自動トリガー  | `workflow.mdc`（alwaysApply）で判定   | ✅                         |
| ゲートシステム | 3ゲート（ユーザー確認、lint/test、PASS/FAIL） | ✅                         |
| 停止条件    | 3回 FAIL で停止 + ブロッカー報告            | ✅                         |
| ハンドオフ形式 | **未定義**                          | ⚠️ エージェント間のコンテキスト伝達方法が暗黙的 |


---

### 3. Cursor プラットフォームとの整合性

#### agents/ の活用パターン


| エージェント            | model           | readonly | is_background | 役割     |
| ----------------- | --------------- | -------- | ------------- | ------ |
| architect         | claude-opus-4-6 | true     | false         | 設計評価   |
| planner           | claude-opus-4-6 | true     | false         | 仕様展開   |
| qa-reviewer       | gpt-5.4-high    | true     | false         | 品質評価   |
| researcher        | gemini-3.1-pro  | true     | **true**      | 調査     |
| security-reviewer | gpt-5.4-high    | true     | false         | セキュリティ |


**事実**: 全エージェントが `readonly: true`。実装（コード変更）を行うエージェントは定義されていない。

**Cursor の推奨構成との比較**:

- Cursor は `.cursor/agents/` に YAML frontmatter 付き Markdown でロール定義を推奨 → **準拠** ✅
- Cursor は Skills と Rules の使い分け（Rules = 常時適用の規約、Skills = 動的ロードのワークフロー）を推奨 → **概ね準拠** ✅
- Cursor は Plan Mode → Agent Mode のフローを推奨 → `/plan` skill が Plan Mode 的役割を担い **整合** ✅

#### skills/ の設計パターン


| Skill       | disable-model-invocation | サブエージェント委譲          |
| ----------- | ------------------------ | ------------------- |
| plan        | true                     | → planner agent     |
| research    | true                     | → researcher agent  |
| orchestrate | true                     | (自身がチェーン駆動)         |
| review      | true                     | → qa-reviewer agent |
| refactor    | true                     | → architect agent   |
| verify      | true                     | (自身が検証実行)           |
| debug       | true                     | (自身がデバッグ実行)         |
| tdd         | true                     | (自身がTDDサイクル実行)      |
| build-fix   | true                     | (自身がビルド修正実行)        |
| explain     | true                     | (自身が説明実行)           |


**発見**: `disable-model-invocation: true` が全 Skill に設定されている。これは Skill 自体がモデルを呼ばず、メインセッションのコンテキスト内で実行される設計を意味する。「Skill がサブエージェントを呼ぶ」パターン（plan → planner, research → researcher 等）は Cursor の委譲モデルに合致するが、`disable-model-invocation: true` の状態でサブエージェントを呼べるかは **Cursor のランタイム実装に依存** する（推測）。

---

### 4. 業界のハーネス設計パターンとの比較

Anthropic 推奨の5パターンとの対応:


| パターン                    | 説明               | 本構成の対応                                          |
| ----------------------- | ---------------- | ----------------------------------------------- |
| **Single Agent**        | 1エージェントで完結       | 除外条件（1ファイル修正等）に該当                               |
| **Prompt Chaining**     | 順序付きステップの連結      | feature/bugfix/refactor/security の各チェーン         |
| **Router**              | 条件分岐でルーティング      | `workflow.mdc` のタスク種別判定                         |
| **Orchestrator-Worker** | 階層的なエージェント協調     | orchestrate skill + 各専門エージェント                   |
| **Evaluator-Optimizer** | 生成→評価→フィードバックループ | 実装 → qa-reviewer/security-reviewer → FAIL 時リトライ |


**本構成は5パターンのうち4つを組み合わせた複合設計** であり、設計の網羅性は高い。

---

## 関連ファイル


| ファイル                          | 役割                                    |
| ----------------------------- | ------------------------------------- |
| `rules/workflow.mdc`          | オーケストレーション自動トリガー（alwaysApply: true）   |
| `rules/orchestrate.mdc`       | エージェントチェーン詳細定義（alwaysApply: false）    |
| `skills/orchestrate/SKILL.md` | オーケストレーション Skill（orchestrate.mdc と重複） |
| `agents/planner.md`           | Planner エージェント定義                      |
| `agents/qa-reviewer.md`       | Evaluator エージェント定義                    |
| `agents/security-reviewer.md` | セキュリティ Evaluator 定義                   |
| `agents/architect.md`         | アーキテクチャ評価エージェント定義                     |
| `agents/researcher.md`        | 調査エージェント定義                            |
| `rules/quality-criteria.mdc`  | 品質基準サマリー（alwaysApply: true）           |
| `rules/anti-patterns.mdc`     | アンチパターン防止（alwaysApply: true）          |
| `scripts/deploy.sh`           | ハーネスデプロイスクリプト                         |


## パターン・規約

### 本構成が従っているパターン

1. **Generator-Evaluator 分離**: 実装（メインセッション）と評価（qa-reviewer, security-reviewer）を別モデルで実行し、自己評価バイアスを軽減
2. **Sprint Contract**: planner が検証可能な合意文書を生成してから実装に入る
3. **Gate-based Workflow**: ユーザー確認ゲート → lint/test ゲート → PASS/FAIL ゲートの3段階品質保証
4. **Retry with Ceiling**: 3回 FAIL で停止（Anthropic の anti-patterns.mdc の Loop Prevention と一致）
5. **Scope Discipline**: 除外条件の明示（1ファイル修正、設定編集、ドキュメント等はオーケストレーション不要）
6. **Multi-model Strategy**: Claude Opus 4.6（設計・計画）、GPT-5.4-high（評価）、Gemini 3.1 Pro（調査）のマルチモデル構成

### ハーネス設計で一般的だが本構成にないパターン

1. **Explicit Handoff Artifacts**: Anthropic はエージェント間のコンテキスト伝達にファイルベースの artifact を使用。本構成にはハンドオフの形式仕様がない
2. **Sprint Decomposition**: 大規模タスクをスプリント単位に分解する仕組み（ただし Opus 4.6 では不要とする根拠あり）
3. **Evaluator Calibration**: Anthropic は few-shot 例でEvaluator を校正。本構成の qa-reviewer にはキャリブレーション用の例がない
4. **Cost/Duration Tracking**: Anthropic はエージェント毎のコスト・所要時間を計測。本構成にモニタリング機構がない

## 依存関係

- **Cursor 2.x** の agents/skills/rules ランタイム仕様
- エージェントの `model` フィールド（claude-opus-4-6, gpt-5.4-high, gemini-3.1-pro）が Cursor で利用可能であること
- `deploy.sh` によるシンボリックリンクデプロイ（`~/.cursor/` への配置）

## 制約・不変条件

1. **全エージェントが readonly** — 実装はメインセッションが直接担当する設計。サブエージェントに実装を委譲する構造ではない
2. **orchestrate.mdc が alwaysApply: false** — 自動ロードが保証されない。workflow.mdc が参照しても、orchestrate.mdc が確実にコンテキストに入るかはモデルの判断依存
3. **Skill と Rule の二重定義** — orchestrate の内容が2箇所に存在し、ドリフトリスクを内包
4. **disable-model-invocation: true** — 全 Skill がモデル呼び出し不可。Skill 内でのサブエージェント委譲がプラットフォームのランタイム制約に依存

## 推奨事項

### 優先度: 高

1. **orchestrate の定義を一本化する** — `rules/orchestrate.mdc` と `skills/orchestrate/SKILL.md` のどちらかを正とし、もう一方は参照のみにする。推奨は **Rule をマスター、Skill は Rule を参照する薄いラッパー** にする構成（Rule が「何をするか」、Skill が「いつ・どう起動するか」の責務分担）
2. **orchestrate.mdc の alwaysApply を再検討する** — workflow.mdc（alwaysApply: true）がオーケストレーションを指示するなら、参照先の orchestrate.mdc も確実にロードされる必要がある。選択肢:
  - (A) orchestrate.mdc を alwaysApply: true にする（コンテキスト消費増）
  - (B) workflow.mdc にチェーン定義を統合して1ファイル化する
  - (C) orchestrate.mdc に description を充実させ Apply Intelligently での検出率を上げる

### 優先度: 中

1. **ハンドオフ artifact の形式を定義する** — Anthropic のハーネス設計に倣い、エージェント間の引き継ぎドキュメント形式を標準化する（例: `Goal / Changes Made / Open Questions / Next Owner` 形式）
2. **qa-reviewer の Evaluator Calibration を追加する** — few-shot の PASS/FAIL 例を qa-reviewer.md に含め、判定基準のブレを減らす
3. **Sprint Contract の交渉プロセスを明確化する** — 現在は planner が一方的に Contract を生成するが、Anthropic の設計では generator と evaluator が交渉する。qa-reviewer が事前に Contract をレビューするステップの追加を検討

### 優先度: 低

1. **Generator（implementer）の明示的定義** — 現状の「メインセッション＝実装者」は Opus 4.6 の能力を考慮すると合理的。ただし、将来的に実装を並列サブエージェントに委譲する場合は agents/implementer.md の定義が必要になる
2. **コスト・所要時間のモニタリング** — オーケストレーション実行時にエージェント毎のトークン消費と所要時間を記録する仕組み（ロギング用の hook や post-run レポート）

---

## 参考ソース

- [Harness design for long-running application development — Anthropic Engineering](https://www.anthropic.com/engineering/harness-design-long-running-apps) (2026-03-24)
- [The Complete Guide to AI Harness Design Patterns in Claude Code — Claude Lab](https://claudelab.net/en/articles/claude-code/claude-code-ai-harness-design-patterns)
- [Agent Skills — Cursor Docs](https://www.cursor.com/docs/context/skills)
- [Rules — Cursor Docs](https://www.cursor.com/docs/context/rules)
- [Best practices for coding with agents — Cursor Blog](https://www.cursor.com/blog/agent-best-practices)

