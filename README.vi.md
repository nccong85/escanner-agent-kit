[English](README.md) · **Tiếng Việt**

# eScanner Agent Kit

Các agent Claude Code, bộ rule review và quy trình làm việc mà mình xây dựng trong lúc phát triển **e-Scanner**, một
app quét tài liệu cho iPhone và Android.

Chúng rút ra từ một dự án và được may đo cho dự án đó. Hãy xem chúng là tài liệu tham khảo: chép các pattern rồi chỉnh
agent, bộ từ vựng rule và routing cho dự án của bạn (các agent `flutter-native` để nguyên sẽ không khớp với codebase
khác). Bạn cứ thoải mái cải tiến, và nếu có phần nào giúp được bạn thì mình rất vui.

- **Agent ngốn nhiều token.** Một feature chạy qua pipeline gọi một coder, vài reviewer, một lần lọc cho mỗi finding
  chặn và có thể thêm vài vòng sửa, mỗi bước là một session riêng trên model mạnh. Hãy dùng **gói Claude Max**; trả
  tiền API theo token thì chi phí tăng rất nhanh. Với thay đổi nhỏ, dùng session chính kèm `/review-gate:review`.
- **Model.** Các agent dùng `model: inherit` (model của session bạn). Chỉ `finding-checker` được gắn cố định vào
  `opus`, vì từng có lần một model nhỏ hơn bác bỏ một finding đúng.

**Tải e-Scanner:** [App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8) ·
[Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

Mới bắt đầu? **[docs/guide-new-feature.vi.md](docs/guide-new-feature.vi.md)** đưa một feature thật qua từng bước.

## Plugin

Bốn plugin, để bạn chỉ cài những gì hợp với dự án.

| Plugin | Dành cho ai | Bắt buộc? | Bạn nhận được gì |
|---|---|---|---|
| [`review-gate`](plugins/review-gate/README.vi.md) | Mọi dự án, mọi ngôn ngữ | **Lõi**, cài trước tiên | agent `finding-checker` · `/review-gate:review` · `/review-gate:init` · validator cho rule/finding/spec/trích dẫn · hook chặn lệnh git phá dữ liệu · template dự án |
| [`flutter-native`](plugins/flutter-native/README.vi.md) | App Flutter có engine C/C++ và code iOS/Android, giống e-Scanner | Tùy chọn | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev-pipeline`](plugins/dev-pipeline/README.vi.md) | Nhóm muốn chạy trọn quy trình: spec → task → code → review | Tùy chọn | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, lưu checkpoint trong `execution_state.md` · `/dev-pipeline:research` · agent `tech-researcher` |
| [`device-e2e`](plugins/device-e2e/README.vi.md) | Ai cần test app mobile trên iPhone hoặc điện thoại Android thật | Tùy chọn | agent `device-tester` · `/device-e2e:init` · skill `device-e2e:playbook` · mẫu test plan e2e và validator · driver cho iPhone (WebDriverAgent) và Android (adb + uiautomator) dùng chung một interface · template dự án |

`review-gate` chạy độc lập được. Mỗi plugin tùy chọn đều phụ thuộc vào nó và cài nó theo. Làm stack khác (web,
backend, …) thì cài `review-gate` rồi thêm agent của riêng bạn: xem [docs/customizing.vi.md](docs/customizing.vi.md).

## Agent

Tên có dạng `<scope>-<role>`, và role cho biết agent được làm gì: `-coder` viết code, `-expert` viết và review một
tầng, `-reviewer` hoặc `-checker` chỉ đọc và ghi report của chính nó, `-tester` chạy test, `-researcher` chỉ đọc nguồn
tài liệu.

| Agent | Plugin | Làm gì |
|---|---|---|
| `finding-checker` | `review-gate` | Quyết định một lỗi reviewer báo (finding) có thật không, trước khi ai đó tốn một vòng sửa cho nó |
| `tech-researcher` | `dev-pipeline` | Trả lời câu hỏi kỹ thuật (dùng thư viện nào, API nào, quy định của store nói gì) kèm nguồn trích dẫn |
| `device-tester` | `device-e2e` | Chạy test end-to-end cho app trên iPhone và điện thoại Android thật |
| `flutter-coder` | `flutter-native` | Viết code feature Flutter/Dart: màn hình, state, route, lưu trữ |
| `flutter-reviewer` | `flutter-native` | Review thay đổi Flutter/Dart |
| `cpp-engine-expert` | `flutter-native` | Viết và review engine xử lý ảnh bằng C++ |
| `ios-android-expert` | `flutter-native` | Viết và review code Swift (iOS) và Kotlin (Android) mà app gọi tới |
| `contract-expert` | `flutter-native` | Giữ hai phía của mỗi contract (hợp đồng giao tiếp giữa các phần: C ABI, định dạng file mã hóa, cấu trúc API) luôn khớp nhau |
| `build-release-expert` | `flutter-native` | Viết và review CI, ký app và việc phát hành lên store |
| `security-checker` | `flutter-native` | Kiểm tra các thay đổi đụng tới mã hóa, khóa, log hoặc dữ liệu người dùng |
| `performance-checker` | `flutter-native` | Kiểm tra các thay đổi trên hot path (khởi động, pipeline xử lý ảnh, database) so với ngân sách hiệu năng của dự án |

**Nâng cấp từ 1.x?** Bản 2.0.0 đổi tên hai plugin: `review-loop` → `review-gate` và
`flutter-native-agents` → `flutter-native`. Marketplace đã ánh xạ tên cũ, nên chỉ cần cập nhật nó và cài tên mới một
lần:

```bash
claude plugin marketplace update escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # nếu bạn đã dùng flutter-native-agents
```

Sau đó chạy `/review-gate:init` trong từng dự án. Lệnh này chuyển `.claude/review-loop/` thành `.claude/review-gate/`,
sửa tiền tố agent, và thêm cột `2.0 name` vào bảng *Legacy names* để plan viết bằng tên 1.x vẫn tìm ra agent. Trước
khi chạy init, các validator và `spec-validate` vẫn đọc thư mục cũ (kèm dòng NOTE), còn `implement`, `spec-create`,
`task-decompose`, `research` và `/review-gate:review` sẽ dừng và nhắc bạn chạy init.

**Nâng cấp từ 1.0.x?** Bản 1.1.0 đổi tên các agent (ví dụ `review-filter` → `finding-checker`,
`owner-contract` → `contract-expert`). Hãy cập nhật tên trong `.claude/review-gate/routing.md` của bạn. Bảng đối
chiếu đầy đủ tên cũ → tên mới là mục `Legacy names` trong
[template routing](plugins/review-gate/templates/routing.md); chép mục đó vào file routing của bạn để plan viết bằng 1.0.x vẫn tìm ra đúng agent.

## Cài đặt

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native@escanner-agent-kit          # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

Sau đó, trong dự án của bạn:

```
/review-gate:init
```

`init` tạo `.claude/review-gate/` từ các template và soạn sẵn thông tin dự án dựa trên code của bạn:

| File | Chứa gì |
|---|---|
| `review_brief.md` | Phần A: thông tin dự án đã được xác minh (cấu trúc thư mục, stack, lệnh, ngân sách hiệu năng, nguyên tắc bất di bất dịch). Phần B: giao thức. |
| `review_rules.md` | Bộ rule đóng mà mọi finding phải trích dẫn. |
| `routing.md` | Thư mục → coder/reviewer, overlay gate, quyền sở hữu độc quyền. |
| `common_pitfalls.md` | Kho lỗi đã gặp của bạn (Triệu chứng → Nguyên nhân → Rule). |
| `config.env` | Các đường dẫn mà validator dùng, nếu tài liệu của bạn nằm ở chỗ khác. |

Ví dụ brief và routing đã điền sẵn nằm trong [examples/](examples).

Review một diff bằng `/review-gate:review`. Chạy một feature bằng `/dev-pipeline:spec-create "<feature>"`, rồi
`spec-validate`, `task-decompose` và `implement`. `implement` dừng sau mỗi task để task sau chạy trong session mới:
chạy `/clear`, rồi chạy lại `implement` (`--continuous` chạy hết các task trong một session, hợp với feature nhỏ).
Nó cũng dừng trước task cần bạn duyệt (build hoặc chạy trên máy thật).

## Cách hoạt động

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
   xong task ── dừng: /clear, rồi chạy lại implement cho task sau
                (sau task cuối: chạy thêm một lần cho bước audit toàn feature)
```

[docs/architecture.vi.md](docs/architecture.vi.md) giải thích từng bước, còn
[docs/field-notes.vi.md](docs/field-notes.vi.md) ghi lại những gì đã đo được trong lúc xây dựng nó.

## Khi nào không nên dùng

Sửa nhỏ, thay đổi trong một file và việc mày mò thử nghiệm làm trong một session sẽ nhanh hơn. Chạy nhiều agent tốn
số token gấp nhiều lần một cuộc chat. Xem [docs/when-not-to-use.vi.md](docs/when-not-to-use.vi.md).

## Yêu cầu

Bắt buộc:
- Claude Code có hỗ trợ plugin
- `bash`, `git`, và `jq` hoặc `python3` (hook an toàn cần dùng; thiếu cả hai thì hook chặn mọi lệnh git)
- `curl`, cho `/dev-pipeline:research` (để kiểm URL được trích dẫn có tồn tại)

Nên có (không có thì agent vẫn chạy, chỉ kém chính xác hơn):
- `serena`: tìm nơi gọi hàm và symbol
- `context7`: tài liệu thư viện bản mới nhất

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

Tên phải đúng chính xác là `serena` và `context7`.

Công cụ riêng của dự án bạn (Flutter, CMake, …) phải có trong `PATH` để agent chạy được test của bạn.

## Hook an toàn

`review-gate` cài một hook `PreToolUse` cho `Bash`:
- **Session chính:** chỉ chặn những lệnh xóa mất phần việc chưa commit: `git checkout` lên đường dẫn (có hoặc không
  có `--`, `.`, `--force`, `--patch`), `git restore` (chỉ cho phép `--staged` đứng một mình), `git stash` (trừ
  `create|list|show`), `git clean` (trừ `-n`), `git reset --hard|--merge|--keep`, các dạng `--force` của `switch`,
  `checkout-index`, `rm` (trừ `--cached`), `mv`, `worktree remove` và `submodule deinit|update`, cùng
  `switch --discard-changes` và `read-tree -u`. Chuyển branch, commit và push vẫn dùng bình thường.
- **Bên trong subagent** (nhận biết qua `agent_id`): chặn thêm commit, push, rebase, merge, chuyển branch, thay đổi
  branch/tag/ref, gc/hết hạn reflog, và `git apply` khi không có `--check`.
- Hook chuẩn hóa lệnh trước theo cách shell sẽ đọc nó (nối các dòng ngắt bằng `\`, bỏ `$'…'` và cặp nháy rỗng, gỡ
  escape `\x` và nháy bao quanh một từ), rồi kiểm tra riêng từng phần của lệnh nối chuỗi (`;`, `&&`, `||`, `|`, xuống
  dòng). Alias git và nội dung `eval` được mở ra và kiểm tra như lệnh thường. Thứ gì không kiểm tra được (biến `$GIT`,
  command substitution, alias định nghĩa ngay trong lệnh) thì bị từ chối.

Hook này chắn tai nạn, không phải ranh giới bảo mật: xem [SECURITY.md](SECURITY.md).

Muốn chạy một lệnh bị chặn thì tự chạy nó bằng tiền tố `!` của Claude Code.

## Đóng góp

Xem [CONTRIBUTING.md](CONTRIBUTING.md) để biết các bước kiểm tra trước khi mở PR.

## Giấy phép

[MIT](LICENSE)
