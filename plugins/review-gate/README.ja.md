[English](README.md) · [Tiếng Việt](README.vi.md) · **日本語**

# review-gate

マーケットプレイスのコアです: ルール ID でゲートされ、必ず終了するレビュー。

| コンポーネント | パス | 備考 |
|---|---|---|
| `finding-checker` エージェント | `agents/finding-checker.md` | 1 件の指摘をその hunk に照らして判定します: `REAL` / `NOT_REAL` / `NEEDS_EVIDENCE`。`opus` で実行します。 |
| `/review-gate:review` | `commands/review.md` | diff をルーティング → レビュアーを並列実行 → ルール ID を検証 → ブロッカーをフィルタ → 集約。 |
| `/review-gate:init` | `commands/init.md` | `templates/` から `.claude/review-gate/` を作成し (上書きしません)、コードから Part A の下書きを作ります。 |
| バリデーター | `bin/validate_rule_ids.sh`, `bin/validate_findings.sh`, `bin/validate_spec_refs.sh`, `bin/validate_citations.sh` | プラグインが有効な間は Bash の `PATH` に入ります。プロジェクトルート (`bin/lib_config.sh`): `REVIEW_GATE_PROJECT_DIR`、なければ `CLAUDE_PROJECT_DIR`、なければ git ルート、なければカレントディレクトリ。 |
| 安全フック | `hooks/hooks.json` → `bin/block_destructive_git.sh auto` | メインセッション: 作業を破壊する git コマンドのみをブロックします。サブエージェント: ワーキングツリー、インデックス、ref、履歴を変更するすべての git コマンド (commit、push、rebase、merge、switch、stash、branch、tag など) をブロックします。 |
| テンプレート | `templates/` | `review_brief.md`, `review_rules.md`, `routing.md`, `common_pitfalls.md`, `config.env`。 |

## セットアップ

`jq` または `python3` が必要です (どちらもない場合、フックはすべての git コマンドをブロックします)。また `validate_citations.sh` には `curl` が必要です。

1. `claude plugin install review-gate@escanner-agent-kit`。
2. プロジェクトで `/review-gate:init` を実行します。`.claude/review-gate/` を作成し、コードから`review_brief.md` の Part A の下書きを作ります。検証できなかった事実にはそれぞれ `<VERIFY>` が付きます。
3. 各 `<VERIFY>` を解消し、`routing.md` にコーダーとレビュアーのエージェントを記入します。
4. diff に対して `/review-gate:review` を実行します。

終了コード: バリデーターはすべて解決できた場合に `0`、解決できないものがある場合に `1`、使い方の誤りやファイル不足の場合に `2` を返します。フックはブロック時に `2` を返し (Claude Code がメッセージをモデルに表示します)、それ以外は `0` を返します。
