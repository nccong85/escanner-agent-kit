[English](guide-new-feature.md) · **Tiếng Việt**

# Hướng dẫn: làm một tính năng mới với các agent

Bài này đưa một tính năng, **"pin/unpin notes"** (ghim/bỏ ghim ghi chú), đi qua toàn bộ pipeline. Mọi output trích
dưới đây lấy từ một lần chạy thật trên một project thử nghiệm nhỏ (app ghi chú viết bằng Flutter, có engine C++).
Hãy dùng nó như bản đồ: thông tin project, agent và rule của bạn sẽ khác.

## Trước khi bắt đầu

> **Bộ kit này là nền tham khảo, không phải sản phẩm hoàn chỉnh.** Nó cho thấy cách tổ chức agent, rule và một vòng
> review. Hãy chép các pattern, rồi chỉnh agent, bộ từ vựng rule và routing cho project của bạn. Các agent trong
> `flutter-native` sẽ không dùng được ngay cho codebase của bạn nếu không sửa.

> **Chạy agent tốn rất nhiều token.** Một tính năng sẽ khởi chạy một coder, vài reviewer, một lần gọi bộ lọc cho mỗi
> finding chặn (finding là lỗi mà reviewer báo) và có thể thêm các vòng sửa, mỗi cái là một session riêng trên một
> model mạnh. Hãy dùng **gói Claude Max** (Claude Code với gói Max); nếu trả tiền API theo token, cùng lần chạy đó
> tốn tiền rất nhanh. Với thay đổi nhỏ, hãy bỏ qua pipeline (xem phần cuối).

> **Phần lớn token nằm ở session chính kéo dài, không nằm ở agent.** Session chính gửi lại toàn bộ context ở mỗi lượt.
> Đo trong một tháng trên e-Scanner, các session có context vượt 400k token chiếm 92% tổng token; toàn bộ subagent
> cộng lại chỉ khoảng 2%. Vì vậy:
> - Chạy `/clear` khi chuyển sang việc không liên quan. Lệnh này không tốn gì: trạng thái pipeline nằm trong
>   `execution_state.md`, không nằm trong hội thoại.
> - Đặt auto-compact thấp hơn nhiều so với cửa sổ context (ví dụ `/autocompact 200k`, hoặc
>   `"autoCompactWindow": 200000` trong `~/.claude/settings.json`), nhất là với model context 1M.
> - `implement` đã tự dừng sau mỗi task để task sau bắt đầu trong session mới.

## 0. Cài đặt một lần cho mỗi project

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # or your own stack plugin
```
Thêm `--scope local` để plugin chỉ áp dụng cho một project. Nếu cần test trên điện thoại thật, cài thêm
`device-e2e@escanner-agent-kit` và chạy `/device-e2e:init` trong project.

**Cập nhật về sau:** chạy `claude plugin marketplace update escanner-agent-kit`, rồi
`claude plugin update <plugin>@escanner-agent-kit` (thêm `--scope local` nếu cài local). Nếu cài local ở nhiều
project, lệnh update có thể báo "already at the latest version" (đã là bản mới nhất) ở project thứ hai trong khi
project đó vẫn chạy bản cũ. Hãy kiểm tra `claude plugin list` trong project đó; nếu version còn cũ thì gỡ ra và cài
lại plugin ở đó. Bản cài local được ghi theo đường dẫn project, nên di chuyển thư mục project cũng phải cài lại.

Trong project, chạy `/review-gate:init`. Lệnh này tạo `.claude/review-gate/` và soạn sẵn thông tin project từ code
của bạn. Sau đó **xử lý hết mọi `<VERIFY>` nó để lại**. Bước này quyết định chất lượng của mọi lần review về sau:

| File | Bạn phải kiểm tra gì |
|---|---|
| `review_brief.md` Part A | Cấu trúc thư mục, các lệnh chạy được thật, ngân sách hiệu năng có đơn vị, các nguyên tắc bất di bất dịch bạn thực sự áp dụng |
| `routing.md` | Agent nào code và agent nào review từng thư mục; gate nào kích hoạt trên đường dẫn nào |
| `review_rules.md` | Các dòng ngân sách (`R-BUD-*`) và những gì lint/test của bạn đã kiểm sẵn (MECHANIZED) |
| `common_pitfalls.md` | Thay ví dụ mẫu bằng loại lỗi thật đầu tiên của bạn |

Trong lần chạy thử, `init` tìm ra đúng cấu trúc thư mục thật, soạn năm nguyên tắc bất di bất dịch từ code có sẵn,
và đánh dấu `<VERIFY>` mọi thứ nó phải đoán (ngân sách, lệnh test, thư mục report).

**Đã có sẵn các file này** (hoặc symlink tới tài liệu của bạn)? `init` chỉ chép các file còn thiếu và chỉ soạn nội
dung vào các file nó vừa tạo; với các file còn lại nó chỉ in gợi ý. Để kiểm tra lần chạy lại không đụng tới chúng:

```bash
shasum .claude/review-gate/* > /tmp/before.sha    # before /review-gate:init
shasum .claude/review-gate/* | diff /tmp/before.sha - && echo unchanged   # after
```

## 1. Viết spec: `/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

Lệnh này chạy ở plan mode, đọc Part A và phần code có sẵn gần nhất, hỏi bạn 5–7 câu (contract, tức hợp đồng giao
tiếp giữa các phần; bảo mật; hiệu năng; phạm vi; tái sử dụng), rồi ghi ra `docs/features/<feature>/spec_<feature>.md`.

> **Về lần chạy demo:** lần chạy này không tương tác, nên lệnh tự trả lời câu hỏi của nó bằng phương án thận trọng
> nhất và ghi lại thành quyết định. Khi dùng bình thường, **bạn** trả lời các câu đó, và phần lớn giá trị của bước
> này nằm ở đó.

Một spec tốt trông thế nào, lấy từ lần chạy thử:
- **7 mục tiêu, mỗi mục tiêu có cách chứng minh**, ví dụ *"G3 — a pinned note always sorts above every unpinned
  note … proven by the tests `pinnedFirst puts every pinned note before every unpinned note` and `… keeps relative
  order within each group`"* (ghi chú đã ghim luôn xếp trên mọi ghi chú chưa ghim, được chứng minh bằng các test
  nêu tên). "Chạy đúng" không bao giờ là một tiêu chí.
- **Một phần Non-Goals** (UI, một repository cụ thể, sắp xếp theo thời điểm ghim, optimistic update). Phần này bắt
  buộc: bước validate dùng nó để kiểm tra việc lấn phạm vi.
- **Các quyết định được ghi lại** (12 quyết định, trong demo này do model tự đưa ra, ví dụ *persist first, update
  the list only after success* (lưu trước, chỉ cập nhật danh sách khi lưu thành công); *one error code `pin_failed`,
  fixed contexts `notes.pin` / `notes.unpin`* (một mã lỗi duy nhất, context cố định)).
- **Ngoại lệ ngân sách được ghi lại.** Câu trả lời vượt một ngân sách trong Part A được ghi vào §3 thành một dòng:
  `Exception to <rule name>: <accepted limit>, scoped to <path or operation>, approved by the owner <YYYY-MM-DD>`.

**Dừng lại ở đây và đọc spec.** Đây là chỗ con người kiểm duyệt: trả lời câu hỏi và sửa spec rẻ hơn nhiều so với
sửa code về sau.

## 2. Kiểm duyệt spec: `/dev-pipeline:spec-validate <spec>`

Sáu điều kiện khách quan. Ba điều kiện do lệnh quyết định (script tham chiếu và hai lệnh grep), ba điều kiện còn
lại do model đánh giá. Kết quả lần chạy thử:

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

## 3. Chia thành task: `/dev-pipeline:task-decompose <spec>`

Lệnh này ghi ra `<feature>_tasks.md` và `execution_state.md` (checkpoint mà `implement` dùng để chạy tiếp). Kiểm tra:
- **Mỗi task một layer, một agent** theo `routing.md`. Lần chạy thử tạo một task cho
  `flutter-native:flutter-coder` và giải thích lý do: code và test đều route tới cùng một coder và reviewer, và
  test chính là bằng chứng cho năm mục tiêu.
- **Một Definition of Done (DoD) mà reviewer chấm được**: dán output của `flutter analyze` (0 issues) và
  `flutter test test/features/notes/notes_controller_test.dart`, các test có tên cụ thể, và các rule kiểm tra được
  trên diff (guard `mounted` sau `await`, `on Object catch` → `ErrorReporter.record`, context dạng literal).
- **Làm contract trước** khi ABI, định dạng wire hoặc API thay đổi (trường hợp này thì không).
- Các lỗ hổng từ bước validate được đưa vào task (thêm một test bắt buộc, ghi lại giới hạn đã biết).
- **`**Gate:** owner approval — <what>`** cho task cần build, chạy trên thiết bị hoặc chạy benchmark mà chỉ bạn được
  duyệt. `implement` dừng trước task đó cho tới khi bạn đồng ý.
- **Task trên thiết bị** (route tới `device-e2e:device-tester`) chạy trên điện thoại thật. Report sẽ cảnh báo nếu
  `.claude/device-e2e/project.md` chưa có hoặc chưa điền; hãy chạy `/device-e2e:init` và điền nó.

## 4. Làm: `/dev-pipeline:implement <spec> [--continuous]`

Orchestrator đọc `execution_state.md` ở mỗi lượt, nên bạn có thể dừng và chạy tiếp bất cứ lúc nào. Với mỗi task, nó
gọi coder, rồi các reviewer theo `routing.md` cùng gate nào mà diff kích hoạt. Nó validate mọi rule ID, kiểm tra đoạn
trích của từng finding chặn có thật ở `file:line` của nó (Gate 1b), gửi các finding còn lại qua `finding-checker`,
và chạy tối đa hai vòng sửa kèm review phần thay đổi (delta review). Mỗi vòng sửa bắt đầu từ một snapshot
`git stash create`, và delta review diff với snapshot đó.

Mặc định lệnh **dừng sau mỗi task** và in ra `/clear  then  /dev-pipeline:implement <spec>`. Hãy chạy đúng như vậy:
task sau bắt đầu trong session mới mà không mất gì. `--continuous` chạy mọi task trong một session; dùng khi chỉ có
hai ba task ngắn.

Chuyện gì đã xảy ra trong lần chạy thử:

| Bước | Kết quả |
|---|---|
| Coder (`flutter-coder`) | Sửa đúng ba file mà spec cho phép; viết 11 test |
| Phần bàn giao của nó | Khối `SELF-CHECK`, rồi `ACTION: REVIEW_REQUIRED` kèm danh sách file |
| Reviewer (`flutter-reviewer`) | `QA_PASSED (blocking=0, deferred=1)`: vòng 1, nên không có vòng sửa và không gọi bộ lọc lần nào |
| Orchestrator chạy lại để kiểm chứng | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| Sổ chi phí trong `execution_state.md` | 1 vòng review · 1 finding được nêu (+2 không có rule ID) · 0 vòng sửa |

Finding hoãn lại duy nhất cho thấy review dùng để làm gì. Reviewer chỉ ra rằng test "controller disposed during
save" (controller bị dispose khi đang lưu) **không thể fail** (nó xoá guard `mounted` và mọi test vẫn pass), rồi ghi
nhận là `R-DOD-3`, mức Medium, nên không chặn. Sau đó orchestrator liệt kê nó để phân loại, kèm cách sửa một dòng.

Những điều cần để ý khi bạn tự chạy:
- **Đọc danh sách hoãn lại.** Finding mức Medium/Low không bao giờ chặn, nên không ai sửa chúng trừ khi bạn quyết định.
- **Reviewer có thể sửa file qua `Bash`, nhưng không được làm.** Trong lần chạy này, reviewer xoá một dòng để chứng
  minh ý của nó rồi đặt lại. Việc đó vi phạm §B2 của brief (reviewer không bao giờ sửa file, kể cả tạm thời):
  reviewer nên mô tả cách kiểm thử bằng mutation trong finding để coder tự chạy. Chạy `git diff --stat` sau mỗi lần
  review.
- **Finding không có rule ID sẽ bị bỏ**, theo thiết kế. Nếu cùng một loại cứ lặp lại, hãy thêm một rule hoặc một
  mục pitfall.
- **Việc cài công cụ rất quan trọng.** Coder chỉ dán được output test thật vì Flutter có trong `PATH`. Nếu một lệnh
  không chạy được, dòng Definition of Done phải ghi `UNVERIFIED`, không bao giờ ghi "passed".

## 5. Đóng tính năng

- **Chạy `implement` thêm một lần sau task cuối.** Lần chạy này là bước audit toàn feature (Step 5): nó chỉ review
  những gì liên quan giữa các task (file mà từ hai task trở lên cùng sửa, contract, file có finding hoãn lại), liệt
  kê các finding hoãn lại để phân loại, và cho phép một vòng sửa.
- **Phân loại các finding hoãn lại một lần.** Finding mức Medium/Low không bao giờ gây ra vòng sửa; đến cuối, hãy
  quyết định cho từng cái: sửa ngay, ghi thành nợ kỹ thuật, hoặc bỏ. Ghi lại kết quả. Rule nào mà finding của nó cứ
  bị bỏ là nhiễu; hãy xoá khỏi `review_rules.md`.
- **Biến lỗi lặp lại thành test.** Một loại finding gặp hai lần sẽ thành guard test hoặc lint, còn một loại lỗi mới
  sẽ thành một mục trong `common_pitfalls.md`.
- **Tự commit.** Pipeline không bao giờ commit.

## Nếu lần chạy bị dừng

| Điểm dừng | Ý nghĩa | Bạn làm gì |
|---|---|---|
| `Task n/N done … Continue in a fresh session` | Điểm dừng có chủ đích: mỗi task một session giúp context nhỏ, nên tốn ít token | Chạy `/clear`, rồi `/dev-pipeline:implement <spec>`. Thêm `--continuous` nếu feature nhỏ và bạn muốn chạy một mạch |
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
- **Khám phá hoặc làm prototype:** vòng lặp này tối ưu một thay đổi đã hoàn chỉnh, không dùng để khám phá.
- **Câu hỏi nghiên cứu:** `/dev-pipeline:research "<question>"` trả lời ngay nếu được, và chỉ gọi `tech-researcher`
  khi câu hỏi cần đào sâu hoặc phủ rộng.
