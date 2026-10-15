[English](README.md) · **Tiếng Việt**

# eScanner Agent Kit

Đây là các agent Claude Code, bộ rule review và quy trình làm việc mà mình xây dựng và mài giũa trong lúc phát triển
**e-Scanner**, một app quét tài liệu cho iPhone và Android.

Đây là bài học cá nhân rút ra từ một dự án và được may đo cho dự án đó, nên bạn hãy xem chúng là tài liệu tham khảo chứ
không phải giải pháp dùng ngay: chép lại các pattern rồi chỉnh agent, bộ từ vựng rule và routing cho hợp với dự án của
bạn (các agent trong `flutter-native-agents` sẽ không khớp với một codebase khác nếu để nguyên). Bạn cứ thoải mái cải
tiến và phát triển chúng thêm. Nếu có phần nào giúp được bạn thì mình rất vui.

- **Agent ngốn rất nhiều token.** Một feature chạy qua pipeline sẽ gọi một coder, vài reviewer, một lần lọc cho mỗi
  finding chặn và có thể thêm vài vòng sửa, mỗi bước là một session riêng trên model mạnh. Hãy dùng với **gói Claude
  Max**; nếu trả tiền API theo token thì chi phí tăng rất nhanh. Với thay đổi nhỏ, hãy dùng session chính kèm
  `/review-loop:review`.
- **Model.** Các agent dùng `model: inherit` (model của session bạn đang dùng); chỉ `finding-checker` được gắn cố định
  vào `opus`, vì từng có lần một model nhỏ hơn bác bỏ một finding đúng.

**Tải e-Scanner:** [App Store (iOS)](https://apps.apple.com/app/id6790476934?pt=129164581&ct=github_agent_kit&mt=8) ·
[Google Play (Android)](https://play.google.com/store/apps/details?id=io.pbsolutions.escanner&referrer=utm_source%3Dgithub%26utm_medium%3Dreadme%26utm_campaign%3Dagent_kit)

Mới bắt đầu? Hãy làm theo **[docs/guide-new-feature.vi.md](docs/guide-new-feature.vi.md)** — một feature thật được đi
qua từng bước.

## Plugin

Kit được chia thành bốn plugin để bạn chỉ cài những gì hợp với dự án.

| Plugin | Dành cho ai | Bắt buộc? | Bạn nhận được gì |
|---|---|---|---|
| [`review-loop`](plugins/review-loop/README.vi.md) | Mọi dự án, mọi ngôn ngữ | **Lõi**, cài trước tiên | agent `finding-checker` · `/review-loop:review` · `/review-loop:init` · validator cho rule/finding/spec/trích dẫn · hook chặn lệnh git phá dữ liệu · template dự án |
| [`flutter-native-agents`](plugins/flutter-native-agents/README.vi.md) | App Flutter có engine C/C++ và code iOS/Android, giống e-Scanner | Tùy chọn | `flutter-coder`, `flutter-reviewer`, `cpp-engine-expert`, `ios-android-expert`, `contract-expert`, `build-release-expert`, `security-checker`, `performance-checker` |
| [`dev-pipeline`](plugins/dev-pipeline/README.vi.md) | Nhóm muốn chạy trọn quy trình: spec → task → code → review | Tùy chọn | `/dev-pipeline:spec-create` → `spec-validate` → `task-decompose` → `implement`, lưu checkpoint trong `execution_state.md` · `/dev-pipeline:research` · agent `tech-researcher` |
| [`device-e2e`](plugins/device-e2e/README.vi.md) | Ai cần test app mobile trên iPhone hoặc điện thoại Android thật | Tùy chọn | agent `device-tester` · skill `device-e2e:playbook` · driver cho iPhone (WebDriverAgent) và Android (adb + uiautomator) dùng chung một interface · template dự án |

`review-loop` chạy độc lập được. Mỗi plugin tùy chọn đều phụ thuộc vào nó, và khi cài một plugin tùy chọn thì
`review-loop` cũng được cài theo. Bạn làm stack khác (web, backend, …)? Hãy cài `review-loop` rồi thêm agent của riêng
bạn — xem [docs/customizing.vi.md](docs/customizing.vi.md).

## Agent

Mỗi tên có dạng `<scope>-<role>`, và phần role cho biết agent được phép làm gì: `-coder` viết code, `-expert` viết và
review một tầng, `-reviewer` hoặc `-checker` chỉ đọc, `-tester` chạy test, `-researcher` chỉ đọc nguồn tài liệu.

| Agent | Plugin | Làm gì |
|---|---|---|
| `finding-checker` | `review-loop` | Nhận một lỗi mà reviewer báo (finding) và quyết định nó có thật không, trước khi ai đó tốn một vòng sửa cho nó |
| `tech-researcher` | `dev-pipeline` | Trả lời câu hỏi kỹ thuật (dùng thư viện nào, API nào, quy định của store nói gì) kèm nguồn trích dẫn |
| `device-tester` | `device-e2e` | Chạy test end-to-end cho app trên iPhone và điện thoại Android thật |
| `flutter-coder` | `flutter-native-agents` | Viết code feature Flutter/Dart: màn hình, state, route, lưu trữ |
| `flutter-reviewer` | `flutter-native-agents` | Review thay đổi Flutter/Dart |
| `cpp-engine-expert` | `flutter-native-agents` | Viết và review engine xử lý ảnh bằng C++ |
| `ios-android-expert` | `flutter-native-agents` | Viết và review code Swift (iOS) và Kotlin (Android) mà app gọi tới |
| `contract-expert` | `flutter-native-agents` | Giữ các contract (hợp đồng giao tiếp giữa các phần) — C ABI, định dạng file mã hóa, cấu trúc API — để hai phía luôn khớp nhau |
| `build-release-expert` | `flutter-native-agents` | Viết và review CI, ký app và việc phát hành lên store |
| `security-checker` | `flutter-native-agents` | Kiểm tra các thay đổi đụng tới mã hóa, khóa, log hoặc dữ liệu người dùng |
| `performance-checker` | `flutter-native-agents` | Kiểm tra các thay đổi trên hot path (khởi động, pipeline xử lý ảnh, database) so với ngân sách hiệu năng của dự án |

**Nâng cấp từ 1.0.x?** Các agent đã được đổi tên ở bản 1.1.0 (ví dụ `review-filter` → `finding-checker`,
`owner-contract` → `contract-expert`). Hãy cập nhật tên trong `.claude/review-loop/routing.md` của bạn; bảng đối chiếu
đầy đủ tên cũ → tên mới nằm ở mục `Legacy names` trong [template routing](plugins/review-loop/templates/routing.md).
Chép mục đó vào file routing của bạn để các plan viết bằng 1.0.x vẫn tìm ra đúng agent.

## Cài đặt

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-loop@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit            # optional
claude plugin install flutter-native-agents@escanner-agent-kit   # optional, Flutter + native stacks
claude plugin install device-e2e@escanner-agent-kit              # optional, real-device e2e on iPhone + Android
```

Sau đó, trong dự án của bạn:

```
/review-loop:init
```

`init` tạo `.claude/review-loop/` từ các template và soạn sẵn thông tin dự án dựa trên code của bạn:

| File | Chứa gì |
|---|---|
| `review_brief.md` | Phần A: thông tin dự án đã được xác minh (cấu trúc thư mục, stack, lệnh, ngân sách hiệu năng, nguyên tắc bất di bất dịch). Phần B: giao thức. |
| `review_rules.md` | Bộ rule đóng mà mọi finding phải trích dẫn. |
| `routing.md` | Thư mục → coder/reviewer, overlay gate, quyền sở hữu độc quyền. |
| `common_pitfalls.md` | Kho lỗi đã gặp của bạn (Triệu chứng → Nguyên nhân → Rule). |
| `config.env` | Các đường dẫn mà validator dùng, nếu tài liệu của bạn nằm ở chỗ khác. |

Review một diff bằng `/review-loop:review`. Chạy một feature từ đầu đến cuối bằng
`/dev-pipeline:spec-create "<feature>"`.

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
```

Xem [docs/architecture.vi.md](docs/architecture.vi.md) để hiểu lý do đằng sau từng bước, và
[docs/field-notes.vi.md](docs/field-notes.vi.md) để biết những gì đã đo được trong lúc xây dựng nó.

## Khi nào không nên dùng

Sửa nhỏ, thay đổi trong một file và việc mày mò thử nghiệm thì làm trong một session duy nhất sẽ nhanh hơn. Chạy nhiều
agent tốn số token gấp nhiều lần một cuộc chat. Xem [docs/when-not-to-use.vi.md](docs/when-not-to-use.vi.md).

## Yêu cầu

**Bắt buộc**
- Claude Code có hỗ trợ plugin
- `bash`, `git`, và `jq` hoặc `python3` (hook an toàn cần dùng)

**Nên có** — không có thì agent vẫn chạy, chỉ kém chính xác hơn
- `serena`: tìm nơi gọi hàm và symbol
- `context7`: tài liệu thư viện bản mới nhất

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

Tên phải đúng chính xác là `serena` và `context7`.

**Công cụ riêng của dự án bạn** (Flutter, CMake, …) phải có trong `PATH` để agent chạy được test của bạn.

## Hook an toàn

`review-loop` cài một hook `PreToolUse` cho `Bash`:
- **Session chính:** chỉ chặn những lệnh xóa mất phần việc chưa commit — `git checkout` lên đường dẫn (có hoặc không
  có `--`, `.`, `--force`, `--patch`), `git restore` (chỉ cho phép `--staged` đứng một mình), `git stash` (trừ
  `create|list|show`), `git clean` (trừ `-n`), `git reset --hard|--merge|--keep`, `git worktree remove --force`.
  Chuyển branch, commit và push vẫn dùng bình thường.
- **Bên trong subagent** (nhận biết qua `agent_id`): chặn thêm commit, push, rebase, merge, chuyển branch, thay đổi
  branch/tag/ref, gc/hết hạn reflog, và `git apply` khi không có `--check`.
- Lệnh được chuẩn hóa trước theo cách shell sẽ đọc nó (nối các dòng ngắt bằng `\`, bỏ `$'…'` và cặp nháy rỗng, gỡ escape
  `\x` và nháy bao quanh một từ), rồi từng phần của lệnh nối chuỗi (`;`, `&&`, `||`, `|`, xuống dòng) được kiểm tra
  riêng. Lệnh git được dựng qua alias, biến `$GIT`, `eval` hoặc command substitution đều bị từ chối.

Đây là lớp chắn tai nạn, không phải ranh giới bảo mật — xem [SECURITY.md](SECURITY.md).

Nếu bạn thật sự muốn chạy một lệnh bị chặn, hãy tự chạy nó bằng tiền tố `!` của Claude Code.

## Đóng góp

Xem [CONTRIBUTING.md](CONTRIBUTING.md). Chạy `bash tests/run.sh` và `claude plugin validate --strict .` trước khi
mở PR.

## Giấy phép

[MIT](LICENSE)
