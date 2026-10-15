[English](README.md) · **Tiếng Việt**

# device-e2e

Test end-to-end app mobile trên máy thật từ một máy Mac: iPhone thật qua WebDriverAgent và điện thoại Android qua
adb + uiautomator. Plugin này được viết trong lúc test e-Scanner trên iPhone 13 và Redmi 15C, và ghi lại những cái bẫy
từng làm tốn thời gian trên máy thật.

| Thành phần | Làm gì |
|---|---|
| `agents/device-tester.md` | Lên kịch bản test, điều khiển điện thoại, phân loại mọi FAIL (lỗi của harness hay lỗi của app), dọn dẹp, báo cáo PASS/FAIL/BLOCKED kèm bằng chứng. Không bao giờ sửa code app. |
| `skills/playbook/` | Quy trình: các bước làm, quy tắc để viết case có thể fail thật, cách phân loại lỗi, quy tắc với thiết bị, dọn dẹp, báo cáo — kèm `references/ios.md`, `references/android.md`, `references/traps.md`. |
| `skills/playbook/harness/` | `IosDriver` (HTTP của WebDriverAgent) và `AndroidDriver` (adb + uiautomator) có cùng tên method, cấu hình bằng các biến môi trường `E2E_*`. Chỉ dùng thư viện chuẩn của Python 3. |
| `skills/playbook/project.template.md` | Thông tin dự án mà agent cần: thiết bị, app id, lệnh build, đường dẫn harness, cách dọn dẹp. |

## Cài đặt

1. `claude plugin install device-e2e@escanner-agent-kit` (plugin này phụ thuộc `review-loop`, có hook ngăn agent chạy
   các lệnh git phá dữ liệu).
2. Chép `project.template.md` vào `.claude/device-e2e/project.md` trong dự án của bạn rồi điền thông tin.
3. Build WebDriverAgent một lần cho iPhone của bạn, bật Developer Mode và UI Automation trên máy, và làm sao cho adb
   thấy được điện thoại Android (`adb devices`).
4. Viết module app-flows và bộ test của bạn dựa trên hai driver — skill có giải thích cấu trúc cần có.

Sau đó chỉ cần yêu cầu bằng lời thường, ví dụ "chạy các case import trên cả hai điện thoại", hoặc gọi `device-tester`.

## Những việc nó sẽ không làm

- Build hoặc cài lại app, trừ khi brief ghi rằng chủ dự án đã đồng ý — gỡ app sẽ xóa sạch dữ liệu app.
- Dùng `xcodebuild test` hoặc `flutter drive` trên điện thoại có dữ liệu quan trọng.
- Báo PASS khi không có bằng chứng đọc từ thiết bị, hoặc báo PASS cho case mà điều kiện tiên quyết chưa được chứng minh.
