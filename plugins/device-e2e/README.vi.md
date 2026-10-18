[English](README.md) · **Tiếng Việt**

# device-e2e

Test end-to-end app mobile trên máy thật từ Mac: iPhone qua WebDriverAgent và điện thoại Android qua
adb + uiautomator. Plugin được viết khi test e-Scanner trên iPhone 13 và Redmi 15C, và ghi lại các bẫy từng làm tốn
thời gian trên máy thật.

| Thành phần | Làm gì |
|---|---|
| `agents/device-tester.md` | Lên case test, điều khiển điện thoại, phân loại mọi FAIL (lỗi harness hay lỗi app), dọn dẹp, báo cáo PASS/FAIL/BLOCKED kèm bằng chứng. Chỉ sửa code app khi brief cho phép. |
| `skills/playbook/` | Quy trình: các bước, phân loại lỗi, quy tắc với thiết bị, dọn dẹp, báo cáo. Kèm `references/test-design.md` (cách suy ra case từ spec để không thiếu, không trùng, cách kiểm có thể fail thật, ngân sách thời gian máy), `references/glossary.md` (mỗi thuật ngữ một nghĩa, PASS/FAIL/BLOCKED/NOT RUN), `references/ios.md`, `references/android.md`, `references/traps.md`. |
| `skills/playbook/e2e_test_plan.template.md` | Mẫu test plan: đầu vào kèm mức rủi ro, các yếu tố, bảng trạng thái × sự kiện, các bước chạy (`READY`, `DRY`, `DIAG`), case có số phút máy và thứ tự chạy, *Covered below e2e*, *Not covered*; và mẫu file kết quả: header, bảng, báo bug `BUG-n`, dòng `E2E:`. |
| `bin/validate_e2e_plan.py` | Kiểm plan không cần model: mỗi mục tiêu spec và mỗi mục đầu vào có case, có test tầng dưới được nêu tên, hoặc có lý do trong *Not covered*; không có case thừa; không ô trạng thái × sự kiện nào trống; không kết quả mong đợi nào không thể fail. Tổng thời gian máy nằm trong ngân sách. Với `--results`: header nêu build và đúng plan này, mỗi case và bước chạy trong plan có một dòng PASS/FAIL/BLOCKED/NOT RUN cho từng nền tảng, mỗi FAIL có một `BUG-n` đủ trường, và số đếm ở dòng `E2E:` khớp. |
| `skills/playbook/harness/` | `IosDriver` (HTTP của WebDriverAgent) và `AndroidDriver` (adb + uiautomator) cùng tên method, đọc biến môi trường: `WDA=http://<ip>:8100` cho iPhone, `E2E_*` cho phần còn lại. Chỉ dùng thư viện chuẩn Python 3. |
| `commands/init.md` | `/device-e2e:init`: tạo `.claude/device-e2e/project.md` từ template và liệt kê các ô chưa điền. |
| `skills/playbook/project.template.md` | Thông tin dự án agent cần: thiết bị, app id, lệnh build, đường dẫn harness, cách dọn dẹp. |

## Cài đặt

1. `claude plugin install device-e2e@escanner-agent-kit` (phụ thuộc `review-gate`, có hook ngăn agent chạy lệnh git
   phá dữ liệu).
2. Chạy `/device-e2e:init` trong dự án. Lệnh này tạo `.claude/device-e2e/project.md` từ `project.template.md`
   (không ghi đè file đã có) và liệt kê các ô còn phải điền.
3. Build WebDriverAgent một lần cho iPhone, bật Developer Mode và UI Automation trên máy, để iPhone luôn mở khoá và
   chung Wi-Fi với Mac, và làm cho adb thấy điện thoại Android (`adb devices`). Chi tiết:
   [`ios.md`](skills/playbook/references/ios.md), [`android.md`](skills/playbook/references/android.md).
4. Viết module app-flows và bộ test dựa trên hai driver. Skill có giải thích cấu trúc.

Brief của agent có các dòng cố định (`SPEC`, `PLAN`, `PLATFORMS`, `BUDGET`, …), liệt kê trong `agents/device-tester.md`.
Sau đó chỉ cần yêu cầu bằng lời, ví dụ "chạy các case import trên cả hai điện thoại", hoặc gọi `device-tester`.

## Những việc nó sẽ không làm

- Build hoặc cài lại app, trừ khi brief ghi rằng chủ dự án đã đồng ý. Gỡ app sẽ xóa sạch dữ liệu app.
- Dùng `xcodebuild test` hoặc `flutter drive` trên điện thoại có dữ liệu quan trọng.
- Báo PASS khi không có bằng chứng đọc từ thiết bị, hoặc cho case mà điều kiện tiên quyết chưa được chứng minh.
- Chạy trên thiết bị khi chủ dự án chưa duyệt test plan, hoặc bỏ một case đã lên plan khỏi kết quả.
