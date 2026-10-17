[English](README.md) · **Tiếng Việt**

# flutter-native

Các agent mẫu cho app Flutter có engine C/C++ đứng sau FFI và code nền tảng iOS/Android. Cần có `review-gate`. Agent nào
cũng đọc `.claude/review-gate/review_brief.md` trước tiên, nên thông tin dự án của bạn sẽ ghi đè các giá trị mặc định
minh họa bên trong từng agent.

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

Cách đặt tên: `<scope>-<role>` — `-coder` viết code, `-expert` viết và review một tầng, `-reviewer` và `-checker` chỉ
đọc. Reviewer chỉ được dùng các tool chỉ-đọc của serena; mặc định agent dùng `model: inherit`.

Bạn có thể dùng chúng như agent của plugin (`flutter-native:<name>`) hoặc chép một agent vào `.claude/agents/`
rồi chỉnh lại.
