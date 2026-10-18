[English](customizing.md) · **Tiếng Việt**

# Tùy chỉnh

Mọi chỉ định dưới đây đều không bắt buộc. Sau `/review-gate:init`, kit chạy với cấu hình mặc định.

## 1. Chỉ định đường dẫn file

**Khi nào:** brief, rule hoặc spec của bạn không nằm trong thư mục mặc định.

Kit tìm file trong `.claude/review-gate/` và tìm spec trong `docs/specs/` và `docs/features/`. Muốn đổi chỗ các script validator tìm file, đặt những key cần thiết trong `.claude/review-gate/config.env` (`init` đã chép sẵn):

```
BRIEF_FILE=$ROOT/docs/agents/review_brief.md
RULES_FILE=$ROOT/docs/agents/review_rules.md
SPECS_DIR=$ROOT/documentation/specs
```

| Key | Đường dẫn | Mặc định |
|---|---|---|
| `BRIEF_FILE` | Thông tin dự án và giao thức review | `.claude/review-gate/review_brief.md` |
| `RULES_FILE` | Danh sách rule ID | `.claude/review-gate/review_rules.md` |
| `ROUTING_FILE` | Agent nào lo thư mục nào | `.claude/review-gate/routing.md` |
| `PITFALLS_FILE` | Danh sách lỗi hay gặp của dự án | `.claude/review-gate/common_pitfalls.md` |
| `SPECS_DIR` | Spec | `docs/specs` |
| `FEATURES_DIR` | Thư mục tính năng (task, trạng thái) | `docs/features` |

Giá trị chỉ được dùng `$ROOT` (thư mục gốc dự án) và `$CONTEXT_DIR` (`.claude/review-gate`).
Chỉ các script validator đọc `config.env`; prompt của agent và command luôn đọc `.claude/review-gate/<file>`. Muốn để file ở chỗ khác thì tạo thêm symlink vào đó, ví dụ
`ln -s ../../docs/agents/review_brief.md .claude/review-gate/review_brief.md`.

Thư mục gốc dự án lấy theo thứ tự: `REVIEW_GATE_PROJECT_DIR` nếu có thiết lập, `CLAUDE_PROJECT_DIR`, git root, thư mục hiện tại.

## 2. Thêm rule cho stack của bạn

**Khi nào:** bạn muốn reviewer dẫn rule riêng cho stack của mình (web, backend, game, …).

Rule ID có dạng `R-<NAMESPACE>-<number>`. Để thêm namespace, thêm dòng vào bảng ở mục 2b của `review_rules.md`,
mỗi dòng một rule:

```
| `R-WEB-1` | Never render user input as raw HTML | High |
| `R-WEB-2` | Every API call has a timeout | Medium |
```

Có thiết lập rồi thì reviewer được dẫn `R-WEB-1` và `validate_rule_ids.sh` chấp nhận nó. ID không có dòng tương ứng sẽ bị bỏ, nên reviewer không bịa ID được.

## 3. Thêm agent của riêng bạn

**Khi nào:** bạn cần coder hoặc reviewer cho phần codebase mà kit chưa có.

1. Đặt tên dạng `<scope>-<role>`, ví dụ `web-reviewer` hoặc `backend-coder`. Các role và quyền của chúng có trong
   [agent-guideline.vi.md](agent-guideline.vi.md).
2. Đặt file ở `.claude/agents/<name>.md` (agent của dự án) hoặc trong plugin của bạn (xem mục 4).
3. Chỉ định agent đọc `.claude/review-gate/review_brief.md` trước và kết thúc câu trả lời bằng khối bàn giao ở §B7 của
   brief đó. Reviewer cần thêm `Write` trong dòng `tools:` để ghi file report (§B7), và không có `Edit`.
4. Thêm agent vào `routing.md`, cạnh các thư mục nó phụ trách. Agent trong plugin viết dạng `<plugin>:<agent>`, ví
   dụ `my-stack:web-reviewer`.

## 4. Tạo plugin cho stack của bạn

**Khi nào:** bạn muốn dùng lại một bộ agent cho nhiều dự án, như `flutter-native` làm cho Flutter.

1. Copy `plugins/flutter-native` và đổi tên. Trong `.claude-plugin/plugin.json` của nó, sửa `name`, `displayName`
   và `description`, nếu không bản copy sẽ trùng với plugin gốc.
2. Thay các agent bên trong bằng agent của bạn.
3. Giữ `"dependencies": ["review-gate"]` trong `plugin.json` đó để hook an toàn git và các validator được cài kèm.
4. Khai báo plugin trong file marketplace của bạn.

Claude Code bỏ qua `hooks`, `mcpServers` và `permissionMode` trong frontmatter của agent trong plugin. Bạn không
cần chúng: hook an toàn đã có từ `review-gate`.

## 5. Đổi tên agent

**Khi nào:** bạn đổi tên một agent đã được dùng.

Thêm tên cũ và tên mới vào mục "Legacy names" của `routing.md`, ví dụ `review-web → web-reviewer`. Các file
`execution_state.md` cũ vẫn ghi tên cũ, và pipeline dùng bảng ánh xạ này để tìm đúng agent.
