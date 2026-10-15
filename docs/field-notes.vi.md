[English](field-notes.md) · **Tiếng Việt**

# Ghi chép thực tế

Những bài học đo được khi chạy vòng lặp này trên một codebase production. Bài học nào cũng đã làm thay đổi thiết kế.

1. **Tên tool sai bị bỏ qua mà không báo gì.** Các agent ghi `serena` và `context7` trong `tools:`. Claude Code
   cần `mcp__serena` / `mcp__context7`, nên tên trơn không cấp quyền gì cả, và suốt nhiều tuần trông như thể
   subagent hoàn toàn không dùng được MCP. Một lần thử trong session mới mới tìm ra nguyên nhân thật.
2. **Trường frontmatter không được hỗ trợ thì không có tác dụng.** Các trường như `allowed_commands`, `displayName`
   và `category` chưa bao giờ giới hạn được gì.
3. **Reviewer tự bịa ra mốc tham chiếu.** Các trích dẫn như `R-PIT-8.12` trông hợp lý nhưng không hề tồn tại.
   Validator rule ID đã loại chúng mà không cần gọi model.
4. **Một model lọc nhỏ hơn trả về `NOT_REAL` cho một finding đúng**, tức là suýt bỏ mất nó. Đó là lỗi duy nhất mà
   bộ lọc không thể gỡ lại, nên
   bộ lọc chạy trên model mạnh nhất. Nó vẫn rẻ vì mỗi lần gọi chỉ xem một nhận định và một hunk.
5. **Bộ test build được chưa chắc đã chạy.** Khoảng 74 test nền tảng tích lại qua nhiều vòng review mà chưa chạy
   lần nào. Khi cuối cùng được chạy, chúng lộ ra một lỗi đọc ngoài biên và ba test bảo vệ không bao giờ có thể
   fail, vì fixture của chúng vi phạm chính quy tắc chuẩn hóa của contract.
6. **Một test helper dùng `git checkout -- <file>` để hoàn tác một mutation** và xóa sạch phần sửa chưa commit của
   một task khác trong file đó. Agent phát hiện ra và tự dựng lại file bằng tay, đó là may mắn chứ không phải cơ
   chế bảo vệ. Quy tắc trong prompt đã không ngăn được chuyện này, nên giờ hook chặn lệnh đó.
7. **Mốc delta review ghi trong tài liệu bị sai.** Workflow bảo reviewer đọc `git diff <sha>..`, lệnh này so sánh
   các commit và luôn rỗng khi team không commit giữa các task. Các orchestrator đã lách bằng một snapshot
   `git stash create`, nhưng snapshot đó bỏ sót file chưa được track — 57 file mới trong một tính năng — nên
   reviewer còn cần một danh sách rõ ràng các file mà lần sửa đã tạo ra. Giờ workflow ghi cả hai.
8. **Hook chặn một lệnh vô hại `grep "git restore"`, rồi lại cho `git "stash"` lọt qua.** Regex trên chuỗi lệnh
   shell sai theo cả hai chiều. Giờ hook đọc lệnh theo cách bash/zsh đọc, nên chữ trong dấu nháy là dữ liệu, trừ
   khi shell sẽ chạy nó (`sh -c`, `eval`, `$(…)`, một here-document đưa vào shell).
9. **Với việc nhỏ, agent chậm hơn bạn tự làm.** Chủ dự án đã thôi giao việc cho các agent coder với những lần sửa
   thường ngày. Pipeline dành cho tính năng, không phải cho thay đổi một dòng.
10. **Phần lớn agent trong một danh mục không được dùng tới.** Đếm số lần giao việc thật trong một tháng đã loại
    sáu trên mười sáu agent. Hãy đo trước khi quyết định giữ một agent.
