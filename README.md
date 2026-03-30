# Cursor Personal Harness

Cursor IDE のエージェント動作を制御するための設定一式。  
Rules（行動規約）・Agents（専門エージェント）・Skills（ユーザー起動ワークフロー）を組み合わせ、タスク種別に応じたエージェントチェーンを自動実行する。

## ディレクトリ構成

```
.
├── agents/          # サブエージェント定義（6種）
├── rules/           # 常時適用 / 条件適用のルール（7種）
├── scripts/         # デプロイスクリプト
└── skills/          # ユーザーが明示的に起動するワークフロー（10種）
```

## セットアップ

`scripts/deploy.sh` を実行して `~/.cursor/` へファイルをコピーする。

```bash
# 事前確認（変更なし）
bash scripts/deploy.sh --dry-run

# デプロイ
bash scripts/deploy.sh

# 同期状態の確認
bash scripts/deploy.sh --status

# アンインストール
bash scripts/deploy.sh --uninstall
```

デプロイは**コピー方式**（シンボリックリンクではない）。既存ファイルは `~/.cursor/.backup/<timestamp>/` に退避される。

---

## Rules（行動規約）

エージェントの振る舞いを制御するルール群。`alwaysApply: true` のルールは全セッションで自動適用される。

| ルール | 適用 | 概要 |
|--------|------|------|
| `workflow.mdc` | 常時 | タスク種別の自動判定とエージェントチェーン定義 |
| `orchestration.mdc` | 手動読込 | ゲート詳細・並列実行モード（best-of-N / タスク分割）・ハンドオフ形式 |
| `coding-standards.mdc` | 常時 | Immutability・ファイル構成・関数サイズ・エラーハンドリング |
| `quality-criteria.mdc` | 常時 | 完了前の6基準自己評価（Correctness / Completeness / Code Quality / Safety / Testing / Evidence） |
| `anti-patterns.mdc` | 常時 | ハルシネーション防止・スコープ規律・ループ防止・コンテキスト規律 |
| `security.mdc` | glob 条件付き | auth / api / env 等のファイル変更時に自動適用。プロンプトインジェクション防御含む |
| `git-workflow.mdc` | 手動読込 | Conventional Commits・PR作成ワークフロー |

---

## Agents（サブエージェント）

オーケストレーションチェーン内で自動的に呼び出される専門エージェント。

| エージェント | 役割 | 読取専用 |
|-------------|------|---------|
| `researcher` | コードベース・外部情報の調査。構造化レポートを `.research/` に出力 | Yes |
| `architect` | アーキテクチャ評価・設計トレードオフ分析 | Yes |
| `planner` | 要件を Sprint Contract（実装スコープ + 検証基準）に展開 | Yes |
| `generator` | Sprint Contract に基づくコード実装。並列起動対応 | No |
| `qa-reviewer` | 5軸の品質評価（PASS/FAIL判定）。Sprint Contract の事前検証も担当 | Yes |
| `security-reviewer` | OWASP Top 10 ベースのセキュリティレビュー（分析/検証の2フェーズ） | Yes |

### エージェントチェーン

タスク種別に応じて自動的にチェーンが組まれる:

| 種別 | チェーン |
|------|---------|
| **feature** | planner → qa-reviewer(Contract検証) → [ユーザー確認] → generator → qa-reviewer → security-reviewer |
| **bugfix** | researcher → planner → qa-reviewer(Contract検証) → [ユーザー確認] → generator → qa-reviewer |
| **refactor** | architect → planner → qa-reviewer(Contract検証) → [ユーザー確認] → generator → qa-reviewer |
| **security** | security-reviewer(分析) → planner → qa-reviewer(Contract検証) → [ユーザー確認] → generator → security-reviewer(検証) → qa-reviewer |

### 品質ゲート

全チェーン共通で以下のゲートを通過する:

- **Gate 0** — Sprint Contract 交渉（planner → qa-reviewer の検証基準レビュー）
- **Gate 1** — ユーザー確認（Contract への明示的な同意）
- **Gate 2** — lint / format / typecheck / test（省略不可）
- **Gate 3** — PASS/FAIL 判定（レビュアーごとに最大3回リトライ）

---

## Skills（ユーザー起動ワークフロー）

Skill はメッセージに `@skill名` を添付し、本文に引数を記載して起動するワークフロー定義。  
「何をしたいか」に応じて適切な Skill を選ぶことで、エージェントが最適な手順で作業を進める。

### 一覧と使いどころ

#### `/orchestrate` — ワークフロー駆動

**使うとき**: 機能追加・バグ修正・リファクタリング・セキュリティ修正など、複数ステップを要する開発タスクを依頼するとき。

エージェントチェーンを自動で駆動し、計画 → レビュー → 実装 → 品質検証の一連のプロセスを実行する。タスク種別（feature / bugfix / refactor / security）を自動判定し、最適なチェーンを選択する。

```
/orchestrate feature ユーザー認証の追加
/orchestrate bugfix ログイン時に500エラーが発生する
```

---

#### `/plan` — 実装計画

**使うとき**: コードを書く前に、要件を整理して実装の見通しを立てたいとき。

planner サブエージェントに要件を展開させ、Sprint Contract（実装スコープ + 検証基準）を生成する。ユーザーの同意を得てから次のステップに進むため、方向性のすり合わせに最適。

```
/plan APIレスポンスにページネーションを追加
```

---

#### `/research` — 深層調査

**使うとき**: 既存コードの構造を理解したい、外部APIの仕様を調べたいなど、コード変更の前に情報収集が必要なとき。

researcher サブエージェントがコードベースを探索し、構造化されたレポートを `.research/` に保存する。調査結果をもとに `/plan` への移行を提案する。

```
/research 認証フローの仕組み
/research GraphQL スキーマの依存関係
```

---

#### `/review` — コードレビュー

**使うとき**: 実装が終わった後、コミット前にコード品質をチェックしたいとき。

qa-reviewer サブエージェントが5軸（Correctness / Completeness / Code Quality / Safety / Testing）で評価し、PASS/FAIL を判定する。FAIL の場合は具体的な修正箇所が提示される。

```
/review
/review src/handlers/user.ts
```

---

#### `/verify` — 完了前検証

**使うとき**: 「実装が完了した」と宣言する前に、漏れがないか最終確認したいとき。

ビルド・テスト・lint・型チェック・フォーマット・要件照合・差分確認を実際に実行し、結果を証拠付きで報告する。「おそらく通るはず」ではなく、コマンド出力を根拠にする。

```
/verify
```

---

#### `/debug` — 体系的デバッグ

**使うとき**: バグやテスト失敗の原因がわからず、闇雲に修正を試みる前に根本原因を特定したいとき。

4フェーズ（症状の記録 → 仮説の構築 → 仮説の検証 → 修正と防御）で体系的にデバッグする。ランダムな print 文や場当たり的な修正を防ぐ。

```
/debug ログイン後にリダイレクトされない
/debug テスト user.test.ts の3件が失敗する
```

---

#### `/build-fix` — ビルドエラー修正

**使うとき**: ビルドやコンパイルが通らないとき。最小限の変更でエラーを解消したいとき。

エラーをシンプルなものから順に修正し、1つ修正するごとにビルドを再実行して進捗を確認する。アーキテクチャ変更は行わない。

```
/build-fix
/build-fix TypeScript の型エラー TS2322
```

---

#### `/tdd` — テスト駆動開発

**使うとき**: 新機能やバグ修正をテストファーストで進めたいとき。

RED（失敗するテスト）→ GREEN（最小限の実装）→ REFACTOR（改善）のサイクルを厳格に実行する。テストを書く前にプロダクションコードを書くことを禁止する。

```
/tdd ユーザー登録のバリデーション
/tdd CSV エクスポート機能
```

---

#### `/refactor` — リファクタリング

**使うとき**: コードの振る舞いは変えずに、構造・可読性・保守性を改善したいとき。

architect サブエージェントが現状分析と改善方針を提案し、ユーザーの同意後に実行する。テストがパスする状態を常に維持する。

```
/refactor src/services/payment.ts の責務分離
/refactor デッドコードの削除
```

---

#### `/explain` — コード説明

**使うとき**: コードやアーキテクチャの仕組みを理解したいとき。コードの変更は不要で、説明だけが欲しいとき。

「何をしているか」「どう動いているか」「なぜこう設計されているか」「依存関係」の4観点で説明する。読み取り専用で、改善提案は求められない限り行わない。

```
/explain src/middleware/auth.ts
/explain このプロジェクトの認証フロー
```

---

## ライセンス

個人利用の設定リポジトリ。
