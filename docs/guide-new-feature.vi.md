[English](guide-new-feature.md) · **Tiếng Việt** · [日本語](guide-new-feature.ja.md)

# Hướng dẫn: làm một tính năng mới với các agent

Phần này đưa ra 1 ví dụ, **"pin/unpin notes"** (ghim/bỏ ghim ghi chú), đi qua toàn bộ pipeline. Mọi output dưới đây lấy từ một lần chạy thật trên một project thử nghiệm nhỏ (app ghi chú viết bằng Flutter, có engine C++).
Hãy dùng nó như tham chiếu, các thông tin project, agent và rule của bạn sẽ khác.

## Trước khi bắt đầu

> **Bộ kit này ở mức độ tham khảo, không phải sản phẩm hoàn chỉnh.** Nó cho thấy cách tổ chức agent, rule và cách thức
> review. Hãy chép các pattern, rồi chỉnh agent, bộ rule và routing cho project của bạn. Các agent trong
> `flutter-native` sẽ không dùng được ngay cho codebase của bạn nếu không thay đổi.

> **Bộ agent tốn nhiều token.** Một tính năng sẽ khởi chạy coder, vài reviewer, một lần gọi bộ lọc cho mỗi
> finding và có thể thêm các vòng sửa. Khuyến nghị dùng **gói Claude Code Max**; không nên dùng bộ kit theo hình thức API trả tiền.

## 0. Cài đặt một lần cho mỗi project

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # or your own stack plugin
```
Thêm `--scope local` để plugin chỉ áp dụng cho một project. Nếu cần test trên điện thoại thật, cài thêm
`device-e2e@device-e2e` từ marketplace riêng ([github.com/nccong85/device-e2e](https://github.com/nccong85/device-e2e)) và chạy `/device-e2e:init` trong project.

**Cập nhật thêm:** chạy `claude plugin marketplace update escanner-agent-kit`, rồi
`claude plugin update <plugin>@escanner-agent-kit` (thêm `--scope local` nếu cài local).
Hãy kiểm tra `claude plugin list` trong project đó; nếu version còn cũ thì gỡ ra và cài
lại plugin ở đó.

Trong project, chạy `/review-gate:init`. Lệnh này tạo `.claude/review-gate/` và soạn sẵn thông tin project từ code
của bạn. Sau đó **xử lý các `<VERIFY>`**. Bước này quyết định chất lượng của mọi lần review về sau:

| File | Nên kiểm tra gì |
|---|---|
| `review_brief.md` Part A | Cấu trúc thư mục, các lệnh chạy được thật, ngân sách hiệu năng có đơn vị, các nguyên tắc bất di bất dịch bạn thực sự áp dụng |
| `routing.md` | Agent nào code và agent nào review từng thư mục; gate nào kích hoạt trên đường dẫn nào |
| `review_rules.md` | Các dòng ngân sách (`R-BUD-*`) và những gì lint/test của bạn đã kiểm sẵn (MECHANIZED) |
| `common_pitfalls.md` | Thay ví dụ mẫu bằng loại lỗi thật đầu tiên của bạn |

`init` tìm ra đúng cấu trúc thư mục thật và đánh dấu `<VERIFY>` những gì nó phải giả định.

## 1. Viết spec: `/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

Lệnh này chạy ở plan mode, đọc Part A và phần code có sẵn gần nhất, hỏi bạn 5–7 câu (contract, tức hợp đồng giao
tiếp giữa các phần; bảo mật; hiệu năng; phạm vi; tái sử dụng), rồi ghi ra `docs/features/<feature>/spec_<feature>.md`.

> **Về lần chạy demo:** lần chạy này không tương tác, nên lệnh tự trả lời câu hỏi của nó bằng phương án thận trọng
> nhất và ghi lại thành quyết định. Khi dùng bình thường, **bạn** trả lời các câu đó, và phần lớn giá trị của bước này nằm ở đó.

Một spec tốt trông thế nào:
- **7 mục tiêu, mỗi mục tiêu có cách chứng minh**, ví dụ *"G3 — a pinned note always sorts above every unpinned
  note … proven by the tests `pinnedFirst puts every pinned note before every unpinned note` and `… keeps relative
  order within each group`"*.
- **Một phần Non-Goals** (UI, một repository cụ thể, sắp xếp theo thời điểm ghim, optimistic update). Phần này bắt
  buộc: bước validate dùng nó để kiểm tra việc lấn phạm vi.
- **Các quyết định được ghi lại** (12 quyết định, trong demo này do model tự đưa ra, ví dụ *persist first, update
  the list only after success* (lưu trước, chỉ cập nhật danh sách khi lưu thành công); *one error code `pin_failed`,
  fixed contexts `notes.pin` / `notes.unpin`* (một mã lỗi duy nhất, context cố định)).
- **Ngoại lệ ngân sách được ghi lại.** Câu trả lời vượt một ngân sách trong Part A được ghi vào §3 thành một dòng:
  `Exception to <rule name>: <accepted limit>, scoped to <path or operation>, approved by the owner <YYYY-MM-DD>`.

**Xác nhận spec.** Đây là chỗ con người kiểm duyệt.

## 2. Kiểm duyệt spec: `/dev-pipeline:spec-validate <spec>`

Sáu điều kiện như dưới:

| # | Gate | Kết quả |
|---|---|---|
| 1 | `validate_spec_refs.sh` thoát với mã 0 (kiểm tra 14 đường dẫn) | ✓ |
| 2 | Có phần Non-Goals và không rỗng | ✓ |
| 3 | Mỗi mục tiêu có tiêu chí nghiệm thu kiểm tra được trên diff | ✓ |
| 4 | Open Questions rỗng | ✓ |
| 5 | Qua các kiểm tra contract, bảo mật, hiệu năng, license | ✓ |
| 6 | Không có dấu hiệu bất thường (red flag) | ✓ |

Nó cũng báo bốn lỗ hổng không chặn, đáng đọc: thiếu test cho một quyết định, race giữa `load()`/`setPinned` chưa
xử lý cần ghi lại như giới hạn đã biết, Flutter không có trong `PATH`, và một thông tin sai trong Part A. Kết luận
được lưu cạnh spec (`validation_<feature>_<timestamp>.md`). **Not Ready nêu đúng điều kiện bị trượt**; sửa nó rồi
chạy lại.

## 3. Phân chia task: `/dev-pipeline:task-decompose <spec>`

Lệnh này ghi ra `<feature>_tasks.md` và `execution_state.md` (checkpoint mà `implement` dùng để chạy tiếp). Kiểm tra:
- **Mỗi task một layer, một agent** theo `routing.md`. Lần chạy thử tạo một task cho
  `flutter-native:flutter-coder` và giải thích lý do: code và test đều route tới cùng một coder và reviewer, và
  test chính là bằng chứng cho năm mục tiêu.
- **Một Definition of Done (DoD) mà reviewer xác nhận được**: dán output của `flutter analyze` và
  `flutter test test/features/notes/notes_controller_test.dart`, các test có tên cụ thể, và các rule kiểm tra được trên diff.
- **Làm contract trước** khi ABI, định dạng wire hoặc API thay đổi.
- Các lỗ hổng từ bước validate được đưa vào task.
- **`**Gate:** owner approval — <what>`** cho task cần build, chạy trên thiết bị hoặc chạy benchmark mà chỉ bạn được
  duyệt. `implement` dừng trước task đó cho tới khi bạn đồng ý.
- **Task trên thiết bị** (route tới `device-e2e:device-tester`) chạy trên điện thoại thật. Report sẽ cảnh báo nếu
  `.claude/device-e2e/project.md` chưa có hoặc chưa điền.

## 4. Làm: `/dev-pipeline:implement <spec> [--per-task]`

Orchestrator đọc `execution_state.md` ở mỗi lượt, nên bạn có thể dừng và chạy tiếp bất cứ lúc nào. Với mỗi task, sẽ gọi coder, rồi các reviewer theo `routing.md` cùng gate nào mà diff kích hoạt. Nó validate mọi rule ID và chạy tối đa hai vòng sửa kèm review phần thay đổi (delta review).

Thêm `--per-task` nếu muốn dừng sau mỗi task để task sau chạy trong session mới.

Chuyện gì đã xảy ra trong lần chạy thử:

| Bước | Kết quả |
|---|---|
| Coder (`flutter-coder`) | Sửa đúng ba file mà spec cho phép; viết 11 test |
| Phần bàn giao của nó | Khối `SELF-CHECK`, rồi `ACTION: REVIEW_REQUIRED` kèm danh sách file |
| Reviewer (`flutter-reviewer`) | `QA_PASSED (blocking=0, deferred=1)`: vòng 1, nên không có vòng sửa và không gọi bộ lọc lần nào |
| Orchestrator chạy lại để kiểm chứng | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| Sổ chi phí trong `execution_state.md` | 1 vòng review · 1 finding được nêu (+2 không có rule ID) · 0 vòng sửa |

Những điều cần để ý khi bạn tự chạy:
- **Đọc danh sách hoãn lại.** Finding mức Medium/Low không bị chặn, không ai sửa chúng trừ khi bạn quyết định.
- **Finding không có rule ID sẽ bị bỏ.** Nếu cùng một loại lặp lại, hãy thêm một rule hoặc một
  mục pitfall.

## 5. Hoàn tất tính năng

- **Step 5 là bước audit toàn feature** (với `--per-task` thì chạy `implement` thêm một lần sau task cuối): nó chỉ review
  những gì liên quan giữa các task (file mà từ hai task trở lên cùng sửa, contract, file có finding hoãn lại), liệt
  kê các finding hoãn lại để phân loại, và cho phép một vòng sửa.
- **Phân loại các finding chưa được sửa.** Finding mức Medium/Low không được sửa; đến cuối, hãy
  quyết định cho từng cái: sửa ngay, ghi thành nợ kỹ thuật, hoặc bỏ. Ghi lại kết quả. Rule nào mà finding của nó gây nhiễu hãy bỏ trong `review_rules.md`.
- **Xử lý lỗi lặp lại.**
  - Nếu một lỗi lặp đi lặp lại thì ghi vào `common_pitfalls.md`.
  - Nếu lỗi đã có trong `common_pitfalls.md` vẫn phát sinh thì tạo test (hoặc bật lint) để `flutter test`/`analyze`
    tự báo lỗi.
- **Tự commit.** Pipeline không bao giờ commit.

## Nếu lần chạy bị dừng

| Điểm dừng | Ý nghĩa | Bạn làm gì |
|---|---|---|
| `Task n/N done … Continue in a fresh session` | Chỉ khi dùng `--per-task`: mỗi task một session giúp context nhỏ, nên tốn ít token | Chạy `/clear`, rồi `/dev-pipeline:implement <spec> --per-task` |
| `SPEC-DOUBT` (rule C4) | Một finding chặn mới ở vòng ≥ 2 mà không phải do lần sửa gây ra | Spec sai hoặc thiếu. Sửa spec rồi chạy tiếp |
| `FINAL_QA_PARTIAL` | Đã qua hai vòng sửa mà vẫn còn finding chặn | Đọc các finding còn mở; sửa tay hoặc đổi spec |
| Reviewer mâu thuẫn nhau | Hai reviewer muốn sửa ngược nhau trên cùng một dòng | Quyết định cột nào chịu trách nhiệm (`routing.md`) |
| Đang chờ chủ dự án duyệt | Task tiếp theo có `**Gate:** owner approval` mà chưa có lần duyệt nào được ghi | Trả lời đồng ý (hoặc không); lần duyệt được ghi vào Pipeline State và chỉ áp dụng cho task đó |
| Một agent báo `BLOCKED` | Agent chủ động dừng (chưa được duyệt, điện thoại đang bận, thiếu file của project) | Xử lý đúng lý do nó nêu rồi chạy tiếp |
| `FATAL` (validator thoát với mã 2) | Thiếu một file review hoặc symlink bị hỏng | Sửa file hoặc link (hoặc chạy lại `/review-gate:init`) rồi chạy tiếp |
| Cần chạy trên thiết bị hoặc chạy interop | Pipeline không chạy được | Tự chạy rồi dán output vào, hoặc với lần chạy trên thiết bị thì route task tới `device-e2e:device-tester` (`/device-e2e:init`) |
| Session kết thúc / mất context | — | Chạy lại `/dev-pipeline:implement <spec>`; nó đọc `execution_state.md` |

## Khi nào nên bỏ qua pipeline

- **Sửa nhỏ hoặc thay đổi trong một file:** làm trong session chính, chạy analyzer và các test liên quan, rồi chạy
  `/review-gate:review` trên diff. Cách này có cùng validator và bộ lọc mà không cần spec và task.
- **Research hoặc làm prototype:** vòng lặp này tối ưu một thay đổi đã hoàn chỉnh, không dùng để khám phá.
