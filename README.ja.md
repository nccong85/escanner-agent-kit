[English](README.md) · [Tiếng Việt](README.vi.md) · **日本語**

# eScanner Agent Kit

e-Scanner アプリの実開発から抽出し、調整したエージェントのキットです。

このリポジトリは、具体的な要件に忠実に従うエージェントの作り方を共有するために作りました。これは私なりのソフトウェアエンジニアリングの理解です。作者自身の考え方とワークフローに基づいて作られているため、汎用的な標準ではありません。参考として使い、ご自身のプロジェクトに合わせて調整してください。

この小さなプロジェクトがお役に立てば幸いです。役に立ったと思ったら、リポジトリに Star ⭐️ をお願いします。ありがとうございます！

> **はじめての方へ:** [docs/guide-new-feature.ja.md](docs/guide-new-feature.ja.md)。

## e-Scanner について

このキットの元になった実際のアプリに興味があれば、こちらから e-Scanner をダウンロードしてお試しいただけます。

- [📱 App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8)
- [🤖 Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

## プラグイン

| プラグイン | 対象 | 必須 | 機能 |
|---|---|---|---|
| [`review‑gate`](plugins/review-gate/README.ja.md) | あらゆるプロジェクト、あらゆる言語 | **コア** | `finding-checker` エージェント<br>`/review-gate:review`<br>`/review-gate:init`<br>ルール/指摘/仕様 (spec) のバリデーター<br>危険な git コマンドをブロックするフック<br>プロジェクトテンプレート |
| [`flutter‑native`](plugins/flutter-native/README.ja.md) | C++ エンジンと iOS/Android コードを持つ Flutter アプリ | 任意 | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev‑pipeline`](plugins/dev-pipeline/README.ja.md) | フロー: 仕様 → タスク → コード → レビュー | 任意 | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`、`execution_state.md` にチェックポイントを記録<br>`/dev-pipeline:research`<br>`tech-researcher` エージェント |
| [`device‑e2e`](plugins/device-e2e/README.ja.md) | 実機でモバイルアプリをテストするエージェント | 任意 | `device-tester` エージェント<br>`/device-e2e:init`<br>`device-e2e:playbook` スキル<br>E2E テスト計画テンプレートとバリデーター<br>iPhone (WebDriverAgent) と Android (adb + uiautomator) のドライバー<br>プロジェクトテンプレート |

`review-gate` は単体で動作します。別のスタック (Web、バックエンドなど) では、`review-gate` をインストールして独自のエージェントを追加してください。[docs/customizing.ja.md](docs/customizing.ja.md) を参照してください。

## エージェント

名前は `<scope>-<role>` の形式で、role がエージェントの役割を表します。

| Role | 役割 |
|---|---|
| `-coder` | コードを書く |
| `-expert` | コードを書き、レビューもする |
| `-reviewer`, `-checker` | 読むだけで、自分のレポートのみ書く |
| `-tester` | テストを実行する |
| `-researcher` | ドキュメントを調べる |

| エージェント | プラグイン | 役割 |
|---|---|---|
| `finding‑checker` | `review‑gate` | 指摘が本当に存在するかを確認します |
| `tech‑researcher` | `dev‑pipeline` | 何かを実装する技術的な方法を探します (どのライブラリか、どの API か、ストアのルールが何を定めているか...) |
| `device‑tester` | `device‑e2e` | 実機の iPhone と Android スマートフォンでアプリのエンドツーエンドテストを実行します |
| `flutter‑coder` | `flutter‑native` | Flutter/Dart の機能コードを書きます: 画面、状態、ルート、ストレージ |
| `flutter‑reviewer` | `flutter‑native` | Flutter/Dart の変更をレビューします |
| `cpp‑engine‑expert` | `flutter‑native` | C++ の処理を書き、レビューします |
| `ios‑android‑expert` | `flutter‑native` | Swift と Kotlin のコードを書き、レビューします |
| `contract‑expert` | `flutter‑native` | 各コントラクトの両側を同期させます |
| `build‑release‑expert` | `flutter‑native` | CI、アプリ署名、ストアリリースを書き、レビューします |
| `security‑checker` | `flutter‑native` | 暗号化、鍵、ログ、ユーザーデータに触れる変更をチェックします |
| `performance‑checker` | `flutter‑native` | ホットパス (起動、画像パイプライン、データベース) の変更を、プロジェクトのパフォーマンス予算に照らしてチェックします |

## インストール

**1. プラグインをインストールする**

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native@escanner-agent-kit          # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

**2. プロジェクト内で初期化する**

```
/review-gate:init
```

`init` はテンプレートから `.claude/review-gate/` を作成し、コードベースからプロジェクトの事実情報の下書きを作ります。

| ファイル | 内容 |
|---|---|
| `review_brief.md` | Part A: 検証済みのプロジェクト事実 (構成、スタック、コマンド、パフォーマンス予算、譲れない条件)。Part B: プロトコル。 |
| `review_rules.md` | すべての指摘が使うルールセット。 |
| `routing.md` | ディレクトリ → コーダー/レビュアー、オーバーレイゲート、所有権。 |
| `common_pitfalls.md` | よくある欠陥 (症状 → 原因 → ルール)。 |
| `config.env` | バリデーターが使うパス。 |

brief と routing ファイルの記入例は [examples/](examples) にあります。

## 仕組み

```
spec-create ─► spec-validate ─► task-decompose ─► implement
                                                    │
        ┌───────────────────────────────────────────┘
        ▼
   coder (or main session) ── SELF-CHECK + ACTION: REVIEW_REQUIRED
        │
        ▼
   area reviewer(s) + overlay gates (parallel, diff only, one column each)
        │  ACTION: ISSUES_FOUND (blocking=n, deferred=m)
        ▼
   validate_rule_ids.sh ── drops invented rule IDs (no model call)
   validate_findings.sh ── drops findings whose file, line or quote is not there (no model call)
        │
        ▼
   finding-checker × each blocking finding ── REAL / NOT_REAL / NEEDS_EVIDENCE
        │
        ▼
   fix round (blocking only, allowed files only) ─► delta review of the fix ─► done (max 2 rounds)
        │
        ▼
   next task … ─► after the last task: feature-wide audit (Step 5)
                (--per-task: stop after each task, /clear, then run implement again)
```

[docs/architecture.ja.md](docs/architecture.ja.md) で各ステップを説明し、[docs/field-notes.ja.md](docs/field-notes.ja.md) に構築中に計測した内容を記録しています。

## 要件

**必須**

- Claude Code (Max プラン推奨)
- `bash`、`git`、および `jq` または `python3`
- `curl` (`/dev-pipeline:research` 用)

**推奨**

- `serena`: 呼び出し元とシンボルを探します
- `context7`: 最新のライブラリドキュメント

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

エージェントが実行できるよう、プロジェクト固有のツール (Flutter、CMake など) を `PATH` に通しておく必要があります。

## 安全フック

`review-gate` は `Bash` に対する `PreToolUse` フックをインストールします。

- **メインセッション:** コミットされていない作業を破壊するコマンドのみをブロックします。

  - パスに対する `git checkout` (`--`、`.`、`--force`、`--patch` の有無を問わず)
  - `git restore` (`--staged` 単独のみ許可)
  - `git stash` (`create|list|show` を除く)
  - `git clean` (`-n` を除く)
  - `git reset --hard|--merge|--keep`
  - `switch`、`checkout-index`、`rm` (`--cached` を除く)、`mv`、`worktree remove`、`submodule deinit|update` の `--force` 形式
  - `switch --discard-changes` と `read-tree -u`

  ブランチの切り替え、commit、push は引き続き使えます。
- **サブエージェント内** (`agent_id` から検出): さらに commit、push、rebase、merge、ブランチの切り替え、ブランチ/タグ/ref の変更、gc/reflog の期限切れ処理、`--check` なしの `git apply` もブロックします。
- フックはまず、シェルが解釈するのと同じ方法でコマンドを正規化し (行継続の結合、`$'…'` と空のクォートペアの除去、`\x` エスケープと単語単位のクォートの展開)、その後、連結されたコマンド(`;`、`&&`、`||`、`|`、改行) の各部分を個別にチェックします。Git エイリアスと `eval` のテキストも展開され、他のコマンドと同様にチェックされます。

セキュリティ情報については [SECURITY.md](SECURITY.md) を参照してください。

## コントリビュート

[CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT](LICENSE)
