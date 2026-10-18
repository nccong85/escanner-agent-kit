[English](README.md) · **Tiếng Việt** · [日本語](README.ja.md)

# eScanner Agent Kit

Đây là bộ công cụ gồm các agent được đúc kết và tối ưu hóa từ thực tế quá trình phát triển ứng dụng e-Scanner.

Mình tạo repo này với mục đích chia sẻ cách thức xây dựng một agent theo tư duy của mình về Software Engineering. Vì được thiết kế theo tư duy và quy trình làm việc riêng của tác giả, bộ công cụ này không phải là quy chuẩn chung, nên được sử dụng ở mức độ tham khảo để bạn tự tùy biến cho dự án của mình.

Rất hi vọng dự án nhỏ này sẽ giúp ích được cho mọi người. Nếu bạn thấy nó hữu ích, đừng quên ủng hộ repo một Star ⭐️.
Xin cảm ơn!

> **Mới bắt đầu?** [docs/guide-new-feature.vi.md](docs/guide-new-feature.vi.md).

## Về e-Scanner

Nếu bạn có hứng thú về ứng dụng thực tế đã làm nền tảng sinh ra bộ kit này, bạn có thể tải và trải nghiệm e-Scanner tại đây:

- [📱 App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8)
- [🤖 Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

## Plugin

| Plugin | Đối tượng | Bắt&nbsp;buộc | Chức năng |
|---|---|---|---|
| [`review‑gate`](plugins/review-gate/README.vi.md) | Mọi&nbsp;dự&nbsp;án,&nbsp;mọi&nbsp;ngôn&nbsp;ngữ | **Lõi** | agent `finding-checker`<br>`/review-gate:review`<br>`/review-gate:init`<br>Validator cho rule/finding/spec<br>Hook chặn lệnh git sai<br>Template dự án |
| [`flutter‑native`](plugins/flutter-native/README.vi.md) | App Flutter có engine C++ và code iOS/Android | Tùy&nbsp;chọn | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev‑pipeline`](plugins/dev-pipeline/README.vi.md) | Quy&nbsp;trình:&nbsp;spec&nbsp;→&nbsp;task&nbsp;→&nbsp;code&nbsp;→&nbsp;review | Tùy&nbsp;chọn | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, lưu checkpoint trong `execution_state.md`<br>`/dev-pipeline:research`<br>agent `tech-researcher` |
| [`device‑e2e`](plugins/device-e2e/README.vi.md) | Agent&nbsp;test&nbsp;app&nbsp;mobile&nbsp;trên&nbsp;thiết&nbsp;bị&nbsp;thật | Tùy&nbsp;chọn | Agent `device-tester`<br>`/device-e2e:init`<br>skill `device-e2e:playbook`<br>Mẫu test plan e2e và validator<br>Driver cho iPhone (WebDriverAgent) và Android (adb + uiautomator)<br>Template dự án |

`review-gate` chạy độc lập. Làm stack khác (web, backend, …) thì cài `review-gate` rồi thêm agent của riêng bạn: xem [docs/customizing.vi.md](docs/customizing.vi.md).

## Agent

Tên có dạng `<scope>-<role>`, và role cho biết agent có vai trò gì:

| Role | Vai trò |
|---|---|
| `-coder` | Viết code |
| `-expert` | Viết và review |
| `-reviewer`, `-checker` | Chỉ đọc và ghi report của chính nó |
| `-tester` | Chạy test |
| `-researcher` | Tham khảo tài liệu |

| Agent | Plugin | Làm gì |
|---|---|---|
| `finding‑checker` | `review‑gate` | Kiểm tra finding có thực sự tồn tại không |
| `tech‑researcher` | `dev‑pipeline` | Tìm phương án thực thi về kỹ thuật (dùng thư viện nào, API nào, quy định của store nói gì...) |
| `device‑tester` | `device‑e2e` | Chạy test end-to-end cho app trên iPhone và điện thoại Android thật |
| `flutter‑coder` | `flutter‑native` | Viết code feature Flutter/Dart: màn hình, state, route, lưu trữ |
| `flutter‑reviewer` | `flutter‑native` | Review thay đổi Flutter/Dart |
| `cpp‑engine‑expert` | `flutter‑native` | Viết và review xử lý C++ |
| `ios‑android‑expert` | `flutter‑native` | Viết và review code Swift và Kotlin |
| `contract‑expert` | `flutter‑native` | Đảm bảo hai phía của mỗi contract luôn khớp nhau |
| `build‑release‑expert` | `flutter‑native` | Viết và review CI, signing app và phát hành lên store |
| `security‑checker` | `flutter‑native` | Kiểm tra các thay đổi đụng tới mã hóa, khóa, log hoặc dữ liệu người dùng |
| `performance‑checker` | `flutter‑native` | Kiểm tra các thay đổi trên hot path (khởi động, pipeline xử lý ảnh, database) so với ngân sách hiệu năng của dự án |

## Cài đặt

**1. Cài plugin**

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native@escanner-agent-kit          # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

**2. Khởi tạo trong dự án của bạn**

```
/review-gate:init
```

`init` tạo `.claude/review-gate/` từ các template và soạn sẵn thông tin dự án dựa trên codebase:

| File | Nội dung |
|---|---|
| `review_brief.md` | Phần A: thông tin dự án đã được xác minh (cấu trúc thư mục, stack, lệnh, ngân sách hiệu năng, nguyên tắc bất di bất dịch). Phần B: giao thức. |
| `review_rules.md` | Bộ rule mà mọi finding sử dụng. |
| `routing.md` | Thư mục → coder/reviewer, overlay gate, quyền sở hữu. |
| `common_pitfalls.md` | Kho lỗi hay gặp (Triệu chứng → Nguyên nhân → Rule). |
| `config.env` | Các đường dẫn mà validator dùng. |

Ví dụ brief và routing đã điền sẵn nằm trong [examples/](examples).

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
   task sau … ─► sau task cuối: audit toàn feature (Step 5)
                (--per-task: dừng sau mỗi task, /clear rồi chạy lại implement)
```

[docs/architecture.vi.md](docs/architecture.vi.md) giải thích từng bước, còn
[docs/field-notes.vi.md](docs/field-notes.vi.md) ghi lại những gì đã đo được trong lúc xây dựng nó.

## Yêu cầu

**Bắt buộc**

- Claude Code (khuyến nghị gói Max)
- `bash`, `git`, và `jq` hoặc `python3`
- `curl`, cho `/dev-pipeline:research`

**Nên có**

- `serena`: tìm nơi gọi hàm và symbol
- `context7`: tài liệu thư viện bản mới nhất

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

Công cụ riêng của dự án bạn (Flutter, CMake, …) phải có trong `PATH` để agent chạy được.

## Hook an toàn

`review-gate` cài một hook `PreToolUse` cho `Bash`:
- **Session chính:** chỉ chặn những lệnh xóa mất phần việc chưa commit:
  - `git checkout` lên đường dẫn (có hoặc không có `--`, `.`, `--force`, `--patch`)
  - `git restore` (chỉ cho phép `--staged` đứng một mình)
  - `git stash` (trừ `create|list|show`)
  - `git clean` (trừ `-n`)
  - `git reset --hard|--merge|--keep`
  - các dạng `--force` của `switch`, `checkout-index`, `rm` (trừ `--cached`), `mv`, `worktree remove` và
    `submodule deinit|update`
  - `switch --discard-changes` và `read-tree -u`

  Chuyển branch, commit và push vẫn dùng bình thường.
- **Bên trong subagent** (nhận biết qua `agent_id`): chặn thêm commit, push, rebase, merge, chuyển branch, thay đổi
  branch/tag/ref, gc/hết hạn reflog, và `git apply` khi không có `--check`.
- Hook chuẩn hóa lệnh trước theo cách shell sẽ đọc nó (nối các dòng ngắt bằng `\`, bỏ `$'…'` và cặp nháy rỗng, gỡ
  escape `\x` và nháy bao quanh một từ), rồi kiểm tra riêng từng phần của lệnh nối chuỗi (`;`, `&&`, `||`, `|`, xuống
  dòng). Alias git và nội dung `eval` được mở ra và kiểm tra như lệnh thường.

Thông tin bảo mật xem [SECURITY.md](SECURITY.md).

## Đóng góp

Xem [CONTRIBUTING.md](CONTRIBUTING.md).

## Giấy phép

[MIT](LICENSE)
