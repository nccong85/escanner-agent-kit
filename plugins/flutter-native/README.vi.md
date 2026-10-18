[English](README.md) · **Tiếng Việt** · [日本語](README.ja.md)

# flutter-native

Các agent mẫu cho app Flutter có engine C/C++ sau FFI và code nền tảng iOS/Android. Cần `review-gate`. Mỗi agent đọc
`.claude/review-gate/review_brief.md` trước, nên thông tin dự án của bạn ghi đè các giá trị mặc định minh họa trong
agent.

| Agent | Vai trò | Viết code? |
|---|---|---|
| `flutter-coder` | Code feature Flutter/Dart | có |
| `cpp-engine-expert` | Engine C++ sau một C ABI: viết và review | có |
| `ios-android-expert` | Code platform channel bằng Swift/Kotlin: viết và review | có |
| `contract-expert` | Header ABI, định dạng wire, cấu trúc API, thương lượng phiên bản | có (các file contract) |
| `build-release-expert` | CI, ký app, lane phát hành store, build với nhiều toolchain | có |
| `flutter-reviewer` | Độ đúng của Dart/Flutter, contract xử lý lỗi, chất lượng test | không |
| `security-checker` | Mã hóa, khóa, quyền riêng tư, rò rỉ qua telemetry, chuỗi cung ứng | không |
| `performance-checker` | Ngân sách hiệu năng, hot path, cấp phát bộ nhớ, khởi động, số liệu đo thật | không |

Tên theo dạng `<scope>-<role>`: `-coder` viết code, `-expert` viết và review một tầng, `-reviewer` và `-checker` chỉ
đọc. Reviewer chỉ dùng các tool chỉ-đọc của serena. Agent mặc định dùng `model: inherit`.

Cài bằng `claude plugin install flutter-native@escanner-agent-kit` (cài luôn `review-gate`). Sau đó ghi tên các agent
bạn dùng vào cột Coder và Reviewer của `.claude/review-gate/routing.md` dưới dạng `flutter-native:<name>`, hoặc chép
một agent vào `.claude/agents/` rồi chỉnh lại.
