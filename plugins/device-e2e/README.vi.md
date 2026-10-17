[English](README.md) · **Tiếng Việt**

# device-e2e

Test end-to-end app mobile trên máy thật từ Mac: iPhone qua WebDriverAgent và điện thoại Android qua
adb + uiautomator. Plugin được viết khi test e-Scanner trên iPhone 13 và Redmi 15C, và ghi lại các bẫy từng làm tốn
thời gian trên máy thật.

| Thành phần | Làm gì |
|---|---|
| `agents/device-tester.md` | Lên case test, điều khiển điện thoại, phân loại mọi FAIL (lỗi harness hay lỗi app), dọn dẹp, báo cáo PASS/FAIL/BLOCKED kèm bằng chứng. Chỉ sửa code app khi brief cho phép. |
| `skills/playbook/` | Quy trình: các bước, quy tắc viết case có thể fail thật, phân loại lỗi, quy tắc với thiết bị, dọn dẹp, báo cáo. Kèm `references/ios.md`, `references/android.md`, `references/traps.md`. |
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

Sau đó chỉ cần yêu cầu bằng lời, ví dụ "chạy các case import trên cả hai điện thoại", hoặc gọi `device-tester`.

## Những việc nó sẽ không làm

- Build hoặc cài lại app, trừ khi brief ghi rằng chủ dự án đã đồng ý. Gỡ app sẽ xóa sạch dữ liệu app.
- Dùng `xcodebuild test` hoặc `flutter drive` trên điện thoại có dữ liệu quan trọng.
- Báo PASS khi không có bằng chứng đọc từ thiết bị, hoặc cho case mà điều kiện tiên quyết chưa được chứng minh.
