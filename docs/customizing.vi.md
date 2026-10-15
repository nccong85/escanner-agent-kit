[English](customizing.md) · **Tiếng Việt**

# Tùy chỉnh

Mọi thứ dưới đây đều không bắt buộc. Sau `/review-loop:init`, kit chạy được với cấu hình mặc định.

## 1. Để file của bạn ở chỗ khác

**Khi nào:** brief, rule hoặc spec của bạn không nằm trong các thư mục mặc định.

Mặc định kit tìm file của nó trong `.claude/review-loop/`, và tìm spec trong `docs/specs/` và `docs/features/`.
Muốn đổi, bạn tạo file `.claude/review-loop/config.env` và chỉ đặt những key cần thiết:

```
BRIEF_FILE=$ROOT/docs/agents/review_brief.md
RULES_FILE=$ROOT/docs/agents/review_rules.md
SPECS_DIR=$ROOT/documentation/specs
```

| Key | Trỏ tới gì | Mặc định |
|---|---|---|
| `BRIEF_FILE` | Thông tin dự án và giao thức review | `.claude/review-loop/review_brief.md` |
| `RULES_FILE` | Danh sách rule ID | `.claude/review-loop/review_rules.md` |
| `ROUTING_FILE` | Agent nào lo thư mục nào | `.claude/review-loop/routing.md` |
| `PITFALLS_FILE` | Danh sách lỗi hay gặp của dự án | `.claude/review-loop/common_pitfalls.md` |
| `SPECS_DIR` | Spec | `docs/specs` |
| `FEATURES_DIR` | Thư mục tính năng (task, trạng thái) | `docs/features` |

Giá trị chỉ được dùng `$ROOT` (thư mục gốc dự án) và `$CONTEXT_DIR` (`.claude/review-loop`). File được đọc như dữ
liệu thuần và không bao giờ bị thực thi.

Thư mục gốc dự án được xác định theo thứ tự: `REVIEW_LOOP_PROJECT_DIR` nếu bạn đặt, rồi `CLAUDE_PROJECT_DIR`, rồi
git root.

## 2. Thêm rule cho stack của bạn

**Khi nào:** bạn muốn reviewer dẫn các rule riêng cho stack của mình (web, backend, game, …).

Rule ID có dạng `R-<NAMESPACE>-<number>`. Để thêm một namespace, bạn thêm dòng vào bảng ở mục 2b của
`review_rules.md`, mỗi dòng một rule:

```
| `R-WEB-1` | Never render user input as raw HTML | High |
| `R-WEB-2` | Every API call has a timeout | Medium |
```

Vậy là xong. Ngay khi dòng đó có mặt, reviewer được phép dẫn `R-WEB-1` và `validate_rule_ids.sh` chấp nhận nó. ID
nào không có dòng tương ứng sẽ bị bỏ, nên reviewer không thể tự bịa ra ID.

## 3. Thêm agent của riêng bạn

**Khi nào:** bạn cần một coder hoặc reviewer cho phần codebase mà kit chưa có.

1. Đặt tên theo dạng `<scope>-<role>`, ví dụ `web-reviewer` hoặc `backend-coder`. Các role và quyền của từng role có
   trong [agent-guideline.vi.md](agent-guideline.vi.md).
2. Đặt file ở `.claude/agents/<name>.md` (agent của dự án) hoặc trong plugin của bạn (xem mục 4).
3. Trong hướng dẫn của agent, bảo nó đọc `.claude/review-loop/review_brief.md` trước, và kết thúc câu trả lời bằng
   khối bàn giao ở §B7 của brief đó.
4. Thêm agent vào `routing.md`, cạnh các thư mục nó phụ trách. Agent trong plugin thì viết dạng
   `<plugin>:<agent>`, ví dụ `my-stack:web-reviewer`.

## 4. Tạo plugin cho stack của bạn

**Khi nào:** bạn muốn dùng lại một bộ agent cho nhiều dự án, giống như `flutter-native-agents` làm cho Flutter.

1. Copy thư mục `plugins/flutter-native-agents` và đổi tên.
2. Thay các agent bên trong bằng agent của bạn.
3. Trong `.claude-plugin/plugin.json` của nó, giữ `"dependencies": ["review-loop"]` để hook an toàn git và các
   validator được cài kèm.
4. Khai báo plugin trong file marketplace của bạn.

Lưu ý: Claude Code bỏ qua `hooks`, `mcpServers` và `permissionMode` trong frontmatter của agent **trong plugin**.
Bạn không cần chúng: hook an toàn đã có từ `review-loop`.

## 5. Đổi tên agent

**Khi nào:** bạn đổi tên một agent sau khi nó đã được dùng.

Thêm tên cũ và tên mới vào mục "Legacy names" của `routing.md`, ví dụ `review-web → web-reviewer`. Các file
`execution_state.md` cũ vẫn ghi tên cũ, và pipeline dùng bảng ánh xạ này để tìm đúng agent.
