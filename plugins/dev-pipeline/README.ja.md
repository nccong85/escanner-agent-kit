[English](README.md) · [Tiếng Việt](README.vi.md) · **日本語**

# dev-pipeline

仕様 (spec) からリリースまで。

| コマンド | 役割 |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | plan モードで、確認可能な受け入れ基準付きの仕様 を書きます |
| `/dev-pipeline:spec-validate <spec>` | 6 つの客観的なゲート条件 (うち 3 つはコマンドで判定)。判定結果を仕様 の隣に保存します。 |
| `/dev-pipeline:task-decompose <spec>` | 作業を確認可能な完了の定義 (DoD) 付きのタスクに分割し、コントラクトを処理し、`execution_state.md` を作成します。 |
| `/dev-pipeline:implement <spec> [--per-task]` | コーダー → レビュアー → 検証 → フィルタ → 修正 (最大 2 回) → 差分レビュー。`execution_state.md` から再開できます。1 セッションですべてのタスクを実行し、その後に機能全体の監査 (Step 5) を行います。`--per-task` は各タスクの後で停止します。 |
| `/dev-pipeline:research "<question>"` | 何かを実装する方法を調査します。深さや幅が必要な質問の場合のみ `tech-researcher` を呼び出し、引用を確認します。 |

| エージェント | 役割 |
|---|---|
| `dev-pipeline:tech-researcher` | 1 つの技術的な質問を調査します。`research` から呼び出されます。 |

ファイル: 仕様、検証の判定結果、`{feature}_tasks.md`、`execution_state.md` は `docs/features/<feature>/` (`config.env` の `FEATURES_DIR`) に、レビューレポートは `docs/reviews/` (`review_brief.md` §B7) に、調査の回答は`docs/research/` に置かれます。

収束ルール (`implement`):

- **C1** Critical/High のみブロック · **C2** Medium/Low は保留され、1 回だけトリアージ · **C3** ラウンド 2 以降は修正の差分レビューのみ · **C4** ラウンド 2 以降、リグレッションではない新しいブロッカーが出たら実行を停止してユーザーに確認します。

仕様 のステップの後で一度止め、分解と実装の前に仕様 をレビューしてください。
