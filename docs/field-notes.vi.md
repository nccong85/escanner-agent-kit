[English](field-notes.md) · **Tiếng Việt** · [日本語](field-notes.ja.md)

# Ghi chép thực tế

Dưới đây là những bài học được đúc kết từ việc chạy vòng lặp review trong dự án thực tế.

1. **Lỗi sai tên tool bị bỏ qua trong im lặng.** Khi cấu hình các tool `serena` và `context7` vào mục `tools:`,
   Claude Code thực chất yêu cầu định dạng `mcp__serena__*` / `mcp__context7__*`. Việc để bare names khiến
   agent không được cấp quyền nào, và có vẻ như các subagent hoàn toàn không thể dùng được MCP.
2. **Các trường thông tin không được hỗ trợ sẽ không có tác dụng.** Việc thêm các trường như `allowed_commands`,
   `displayName` hay `category` vào frontmatter thực tế không tạo ra bất kỳ giới hạn nào cho hệ thống.
   Muốn hạn chế thật thì phải dùng cơ chế Claude Code hỗ trợ.
3. **Reviewer (AI) hay tự bịa ra các mốc tham chiếu.** Các mã trích dẫn như `R-PIT-8.12` trông có vẻ rất hợp lý
   nhưng thực chất là không tồn tại. Dùng validator kiểm tra Rule ID, hệ thống đã tự động loại bỏ những mã ảo này
   mà không tốn thêm chi phí gọi model.
4. **Code build được chưa chắc đã chạy được.** Có trường hợp 74 testcase phần C++ báo pass cho dù chưa được chạy thực tế lần nào.
   Đến khi chạy thực tế lại phát sinh lỗi (out-of-bounds read) và các bài test bảo vệ vốn dĩ không bao giờ có thể "fail" (vì các fixture của chúng đã vi
   phạm chính quy chuẩn của hệ thống).
5. **Mất code vì lệnh Git vô tình.** Một test helper đã dùng lệnh `git checkout -- <file>` để hoàn tác một sửa đổi,
   nhưng lệnh này vô tình xóa luôn cả phần code chưa commit của một task khác trên cùng file đó.
   Vì việc viết quy tắc giới hạn vào prompt là không đủ để ngăn chặn, nên thêm "hook" để chủ động ngăn chặn việc này.
6. **Lỗi tham chiếu gốc khi review code sửa (delta review).** Tài liệu hướng dẫn trước đây yêu cầu reviewer xem
   `git diff <sha>..`, tuy nhiên lệnh này so sánh các commit nên sẽ luôn trả về kết quả rỗng nếu team có thói quen
   không commit giữa các task. Dù hệ thống (orchestrator) đã lách luật bằng cách tạo snapshot `git stash create`,
   nhưng cách này lại bỏ sót các file chưa được track (từng sót tới 57 file mới trong một tính năng). Do đó,
   reviewer cần được cung cấp thêm một danh sách liệt kê chi tiết những file mà bản fix đã tạo ra. Hiện tại,
   workflow đã cập nhật để bao gồm cả hai cơ chế này.
7. **Regex bắt lỗi shell hoạt động không chính xác.** Bộ hook từng bắt nhầm và chặn lệnh vô hại
   `grep "git restore"`, nhưng lại để lọt lệnh `git "stash"`. Việc dùng Regex để quét chuỗi
   lệnh shell thường sai cả hai chiều. Hiện tại, hook đã được sửa để đọc lệnh theo đúng cách của bash/zsh: nội dung
   trong dấu nháy sẽ được xem là dữ liệu tĩnh, trừ khi shell thực sự thực thi chúng (như `sh -c`, `eval`, `$(…)`,
   hoặc truyền thẳng vào shell).
8. **Với các task nhỏ, tự làm sẽ nhanh hơn.** Nên ngừng giao những việc sửa chữa đơn giản hàng ngày
   cho agent coder. Pipeline này được thiết kế cho việc phát triển các tính năng lớn, chứ không phù hợp để sửa những
   lỗi chỉ cần thay đổi một dòng code.
