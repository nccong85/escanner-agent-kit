[English](guide-new-feature.md) · **Tiếng Việt**

# Hướng dẫn: làm một tính năng mới với các agent

Bài này đưa một tính năng thật đi qua toàn bộ pipeline. Mọi output trích dẫn dưới đây đều lấy từ một lần chạy
thật trên một project thử nghiệm nhỏ (app ghi chú viết bằng Flutter, có engine C++), với tính năng **"pin/unpin
notes"** (ghim/bỏ ghim ghi chú). Hãy dùng nó như bản đồ, đừng làm theo từng bước như kịch bản: thông tin project,
agent và rule của bạn sẽ khác.

## Trước khi bắt đầu — đọc phần này

> **Bộ kit này là nền tham khảo, không phải sản phẩm hoàn chỉnh.** Nó cho thấy *cách* tổ chức agent, rule và một
> vòng review. Hãy chép lại các pattern, rồi chỉnh agent, bộ từ vựng rule và routing cho hợp với project của bạn.
> Đừng mong các agent trong `flutter-native` dùng được ngay cho codebase của bạn mà không cần sửa.

> **Chạy agent tốn rất nhiều token.** Một tính năng đi qua pipeline sẽ khởi chạy một coder, vài reviewer, một lần
> gọi bộ lọc cho mỗi finding chặn (finding là lỗi mà reviewer báo) và có thể thêm các vòng sửa — mỗi cái là một
> session model riêng trên một model mạnh. Hãy dùng với **gói Claude Max** (Claude Code với gói Max). Nếu trả tiền
> API theo token, cùng một lần chạy có thể tốn tiền rất nhanh. Với thay đổi nhỏ, hãy bỏ qua pipeline (xem phần cuối).

> **Phần lớn token nằm ở session chính kéo dài, không nằm ở agent.** Session chính gửi lại toàn bộ context ở mỗi lượt.
> Đo trong một tháng trên e-Scanner: các session có context vượt 400k token chiếm 92% tổng token; toàn bộ subagent
> cộng lại chỉ khoảng 2%. Vì vậy:
> - Chạy `/clear` khi chuyển sang việc không liên quan. Lệnh này không tốn gì; trạng thái của pipeline nằm trong
>   `execution_state.md`, không nằm trong hội thoại.
> - Đặt auto-compact thấp hơn nhiều so với cửa sổ context (ví dụ `/autocompact 200k`, hoặc
>   `"autoCompactWindow": 200000` trong `~/.claude/settings.json`), nhất là khi dùng model context 1M.
> - `implement` đã tự dừng sau mỗi task để task sau bắt đầu trong một session mới.

## 0. Cài đặt một lần cho mỗi project

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # or your own stack plugin
```
Thêm `--scope local` để plugin chỉ áp dụng cho một project.

**Cập nhật về sau:** chạy `claude plugin marketplace update escanner-agent-kit`, rồi
`claude plugin update <plugin>@escanner-agent-kit` (thêm `--scope local` nếu cài local). Nếu bạn cài local ở nhiều
project, lệnh update có thể báo "already at the latest version" (đã là bản mới nhất) ở project thứ hai trong khi
project đó vẫn chạy bản cũ — hãy kiểm tra `claude plugin list` trong project đó, và nếu version còn cũ thì gỡ ra và
cài lại plugin ở đó. Bản cài local được ghi theo đường dẫn project, nên nếu bạn di chuyển thư mục project thì cũng
phải cài lại như vậy.

Trong project, chạy `/review-gate:init`. Lệnh này tạo `.claude/review-gate/` và soạn sẵn thông tin project từ code
của bạn. Sau đó **xử lý hết mọi `<VERIFY>` nó để lại** — đây là bước quyết định chất lượng của mọi lần review về sau:

| File | Bạn phải kiểm tra gì |
|---|---|
| `review_brief.md` Part A | Cấu trúc thư mục, các lệnh chạy được thật, ngân sách hiệu năng có đơn vị, các nguyên tắc bất di bất dịch bạn thực sự áp dụng |
| `routing.md` | Agent nào code và agent nào review từng thư mục; gate nào kích hoạt trên đường dẫn nào |
| `review_rules.md` | Các dòng ngân sách (`R-BUD-*`) và những gì lint/test của bạn đã kiểm sẵn (MECHANIZED) |
| `common_pitfalls.md` | Thay ví dụ mẫu bằng loại lỗi thật đầu tiên của bạn |

Trong lần chạy thử, `init` tìm ra đúng cấu trúc thư mục thật và soạn năm nguyên tắc bất di bất dịch từ code có sẵn,
đồng thời đánh dấu đúng `<VERIFY>` cho mọi thứ nó phải đoán (ngân sách, lệnh test, thư mục report).

**Đã có sẵn các file này** (hoặc symlink tới tài liệu của bạn)? `init` chỉ chép các file còn thiếu và chỉ soạn nội
dung vào các file nó vừa tạo; với các file còn lại nó chỉ in ra gợi ý. Để kiểm tra một lần chạy lại không đụng tới
chúng:

```bash
shasum .claude/review-gate/* > /tmp/before.sha    # before /review-gate:init
shasum .claude/review-gate/* | diff /tmp/before.sha - && echo unchanged   # after
```

## 1. Viết spec — `/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

Lệnh này chạy ở plan mode, đọc Part A và phần code có sẵn gần nhất, hỏi bạn 5–7 câu (contract — hợp đồng giao
tiếp giữa các phần, bảo mật, hiệu năng, phạm vi, tái sử dụng), rồi ghi ra `docs/features/<feature>/spec_<feature>.md`.

> **Về lần chạy demo:** lần chạy này không tương tác, nên lệnh tự trả lời câu hỏi của chính nó bằng phương án thận
> trọng nhất và ghi lại thành các quyết định. Khi dùng bình thường, **bạn** trả lời các câu hỏi đó — phần lớn giá
> trị của bước này nằm ở đó.

Một spec tốt trông thế nào — lấy từ lần chạy thử:
- **7 mục tiêu, mỗi mục tiêu có cách chứng minh**, ví dụ *"G3 — a pinned note always sorts above every unpinned
  note … proven by the tests `pinnedFirst puts every pinned note before every unpinned note` and `… keeps relative
  order within each group`"* (ghi chú đã ghim luôn xếp trên mọi ghi chú chưa ghim, được chứng minh bằng các test
  nêu tên). "Chạy đúng" không bao giờ là một tiêu chí.
- **Một phần Non-Goals** (UI, một repository cụ thể, sắp xếp theo thời điểm ghim, optimistic update). Phần này bắt
  buộc: bước validate dùng nó để kiểm tra việc lấn phạm vi.
- **Các quyết định được ghi lại** (12 quyết định, trong demo này do model tự đưa ra, ví dụ *persist first, update
  the list only after success* (lưu trước, chỉ cập nhật danh sách khi lưu thành công); *one error code `pin_failed`,
  fixed contexts `notes.pin` / `notes.unpin`* (một mã lỗi duy nhất, context cố định)).

**Dừng lại ở đây và đọc spec.** Đây là chỗ con người kiểm duyệt: trả lời câu hỏi và sửa spec rẻ hơn nhiều so với
sửa code về sau.

## 2. Kiểm duyệt spec — `/dev-pipeline:spec-validate <spec>`

Sáu điều kiện khách quan; ba điều kiện được quyết định bằng lệnh (script tham chiếu và hai lệnh grep), ba điều kiện
còn lại do model đánh giá. Kết quả lần chạy thử:

| # | Gate | Kết quả |
|---|---|---|
| 1 | `validate_spec_refs.sh` thoát với mã 0 (kiểm tra 14 đường dẫn) | ✓ |
| 2 | Có phần Non-Goals và không rỗng | ✓ |
| 3 | Mỗi mục tiêu có tiêu chí nghiệm thu kiểm tra được trên diff | ✓ |
| 4 | Open Questions rỗng | ✓ |
| 5 | Qua các kiểm tra contract, bảo mật, hiệu năng, license | ✓ |
| 6 | Không có dấu hiệu bất thường (red flag) | ✓ |

Nó cũng báo bốn lỗ hổng không chặn, đáng đọc — thiếu test cho một quyết định, race giữa `load()`/`setPinned` chưa
xử lý cần ghi lại như một giới hạn đã biết, Flutter không có trong `PATH`, và một thông tin sai trong Part A. Kết
luận được lưu cạnh spec (`validation_<feature>_<timestamp>.md`). **Not Ready nêu đúng điều kiện bị trượt** — sửa nó
rồi chạy lại.

## 3. Chia thành task — `/dev-pipeline:task-decompose <spec>`

Lệnh này ghi ra `<feature>_tasks.md` và `execution_state.md` (checkpoint mà `implement` dùng để chạy tiếp). Kiểm tra:
- **Mỗi task một layer, một agent** theo `routing.md`. Trong lần chạy thử, nó tạo một task cho
  `flutter-native:flutter-coder` và giải thích lý do: code và test đều được route tới cùng một coder và
  reviewer, và test chính là bằng chứng cho năm mục tiêu.
- **Một Definition of Done (DoD) mà reviewer chấm được**: dán output của `flutter analyze` (0 issues) và
  `flutter test test/features/notes/notes_controller_test.dart`, các test có tên cụ thể, và các rule kiểm tra được
  trên diff (guard `mounted` sau `await`, `on Object catch` → `ErrorReporter.record`, context dạng literal).
- **Làm contract trước** khi ABI, định dạng wire hoặc API thay đổi (trường hợp này thì không).
- Nó đưa các lỗ hổng phát hiện ở bước validate vào task (thêm một test bắt buộc, ghi lại giới hạn đã biết).

## 4. Làm — `/dev-pipeline:implement <spec>`

Orchestrator đọc `execution_state.md` ở mỗi lượt, nên bạn có thể dừng và chạy tiếp bất cứ lúc nào. Với mỗi task, nó
gọi coder, sau đó gọi các reviewer theo `routing.md` cùng với gate nào mà diff kích hoạt, validate mọi rule ID, gửi
từng finding chặn qua `finding-checker`, và chạy tối đa hai vòng sửa kèm review phần thay đổi (delta review).

Chuyện gì đã xảy ra trong lần chạy thử:

| Bước | Kết quả |
|---|---|
| Coder (`flutter-coder`) | Sửa đúng ba file mà spec cho phép; viết 11 test |
| Phần bàn giao của nó | Khối `SELF-CHECK`, rồi `ACTION: REVIEW_REQUIRED` kèm danh sách file |
| Reviewer (`flutter-reviewer`) | `QA_PASSED (blocking=0, deferred=1)` — vòng 1, nên không có vòng sửa và không có lần gọi bộ lọc nào |
| Orchestrator chạy lại để kiểm chứng | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| Sổ chi phí trong `execution_state.md` | 1 vòng review · 1 finding được nêu (+2 không có rule ID) · 0 vòng sửa |

Finding hoãn lại duy nhất là ví dụ tốt cho thấy review dùng để làm gì: reviewer chỉ ra rằng test "controller
disposed during save" (controller bị dispose khi đang lưu) **không thể fail** — nó xoá guard `mounted` và mọi test
vẫn pass — rồi ghi nhận là `R-DOD-3`, mức Medium, nên không chặn. Sau đó orchestrator liệt kê nó để phân loại, kèm
cách sửa trong một dòng.

Những điều cần để ý khi bạn tự chạy:
- **Đọc danh sách hoãn lại.** Finding mức Medium/Low không bao giờ chặn, nên sẽ không ai sửa chúng trừ khi bạn quyết định.
- **Reviewer có thể sửa file qua `Bash`.** Trong lần chạy này, reviewer xoá một dòng để chứng minh ý của nó rồi đặt
  lại. Orchestrator đã kiểm tra diff không đổi, và bạn cũng nên làm vậy: chạy `git diff --stat` sau mỗi lần review.
- **Finding không có rule ID sẽ bị bỏ** — đây là thiết kế có chủ ý. Nếu cùng một loại cứ lặp lại, hãy thêm một rule
  hoặc một mục pitfall.
- **Việc cài công cụ rất quan trọng.** Coder chỉ dán được output test thật vì Flutter có trong `PATH`. Nếu một lệnh
  không chạy được, dòng Definition of Done phải ghi `UNVERIFIED`, không bao giờ ghi "passed".

## 5. Đóng tính năng

- **Phân loại các finding hoãn lại một lần.** Finding mức Medium/Low không bao giờ gây ra vòng sửa; đến cuối, hãy
  quyết định cho từng cái: sửa ngay, ghi thành nợ kỹ thuật, hoặc bỏ. Ghi lại kết quả — rule nào mà finding của nó
  cứ bị bỏ là nhiễu, nên xoá khỏi `review_rules.md`.
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
| Cần chạy trên thiết bị hoặc chạy interop | Pipeline không chạy được | Tự chạy rồi dán output vào |
| Session kết thúc / mất context | — | Chạy lại `/dev-pipeline:implement <spec>`; nó đọc `execution_state.md` |

## Khi nào nên bỏ qua pipeline

- **Sửa nhỏ hoặc thay đổi trong một file:** làm trong session chính, chạy analyzer và các test liên quan, rồi chạy
  `/review-gate:review` trên diff — cùng validator và bộ lọc, nhưng không cần spec và task.
- **Khám phá hoặc làm prototype:** vòng lặp này tối ưu một thay đổi đã hoàn chỉnh, không phải để khám phá.
- **Câu hỏi nghiên cứu:** `/dev-pipeline:research "<question>"` trả lời ngay nếu được, và chỉ gọi `tech-researcher`
  khi câu hỏi cần đào sâu hoặc phủ rộng.
