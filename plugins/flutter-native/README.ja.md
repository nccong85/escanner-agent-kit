[English](README.md) · [Tiếng Việt](README.vi.md) · **日本語**

# flutter-native

FFI の背後に C/C++ エンジンを持ち、iOS/Android のプラットフォームコードを持つ Flutter アプリ向けのリファレンスエージェントです。`review-gate` が必要です。各エージェントは最初に `.claude/review-gate/review_brief.md` を読むため、プロジェクトの事実情報が例示用のデフォルトより優先されます。

| エージェント | 役割 | コードを書くか |
|---|---|---|
| `flutter-coder` | Flutter/Dart の機能コード | はい |
| `cpp-engine-expert` | C ABI の背後の C++ エンジン: 実装とレビュー | はい |
| `ios-android-expert` | Swift/Kotlin のプラットフォームチャネルコード: 実装とレビュー | はい |
| `contract-expert` | ABI ヘッダー、ワイヤーフォーマット、API の形、バージョンネゴシエーション | はい (コントラクトファイル) |
| `build-release-expert` | CI、署名、ストアレーン、複数ツールチェーンのビルド | はい |
| `flutter-reviewer` | Dart/Flutter の正しさ、エラーコントラクト、テスト品質 | いいえ |
| `security-checker` | 暗号、鍵、プライバシー、テレメトリーからの漏洩、サプライチェーン | いいえ |
| `performance-checker` | 予算、ホットパス、アロケーション、起動、計測値 | いいえ |

名前は `<scope>-<role>` に従います: `-coder` は書く、`-expert` は 1 つのレイヤーを書いてレビューする、`-reviewer` と `-checker`は読み取り専用です。レビュアーには読み取り専用の serena ツールのみが与えられます。エージェントのデフォルトは `model: inherit` です。

`claude plugin install flutter-native@escanner-agent-kit` でインストールします (`review-gate` もインストールされます)。その後、使うエージェント名を `.claude/review-gate/routing.md` の Coder 列と Reviewer 列に `flutter-native:<name>` として記入するか、エージェントを `.claude/agents/` にコピーして調整してください。
