[English](architecture.md) · **Tiếng Việt** · [日本語](architecture.ja.md)

# Kiến trúc

## Mục tiêu thiết kế
1. **Vòng lặp giới hạn.** Đảm bảo không phát sinh vòng lặp vô ích.
2. **Finding thật sự.** Một finding sai (finding là lỗi mà reviewer tìm ra) tốn một lần chạy coder và một lần review lại.
3. **Thông tin không trùng lặp.** Agent nào cũng tự tìm hiểu lại dự án thì lãng phí token.

## Thành phần

| Thành phần | Vai trò | Tất định? |
|---|---|---|
| `review_brief.md` Phần A | Thông tin dự án mà agent cần đọc trước tiên | — |
| `review_brief.md` Phần B | Giao thức: gate mức độ nghiêm trọng, phạm vi, review phần thay đổi, quyền sở hữu, giới hạn báo cáo, bàn giao | — |
| `review_rules.md` | Bộ rule đóng gồm các rule ID | — |
| `routing.md` | Thư mục → agent, overlay gate, quyền sở hữu | — |
| `validate_rule_ids.sh` | Loại bỏ các finding có rule ID không tồn tại | **có** |
| `validate_findings.sh` | Loại bỏ các finding mà đưa ra thông tin không có thật | **có** |
| `validate_spec_refs.sh` | Đánh fail spec/task dẫn tới file hoặc agent không tồn tại | **có** |
| `validate_citations.sh` | Đánh dấu URL chết hoặc bịa ra | **có** |
| `block_destructive_git.sh` | Chặn các lệnh git làm mất thay đổi chưa commit | **có** |
| `finding-checker` | Đánh giá một finding dựa trên một đoạn thay đổi khi diff(hunk) | model |
| Reviewer theo vùng và các gate | Review diff| model |
| `device-tester` + driver | Chạy bản build trên máy thật và đưa ra bằng chứng cho từng case | driver **có**, agent model |

## Lý do cho các nguyên tắc

- **Chỉ Critical/High mới chặn.** Medium/Low được hoãn lại và phân loại ở lần review cuối. Nếu không, vòng nào cũng sinh ra lỗi vặt mới và số lỗi không hội tụ.
- **Từ vòng 2 chỉ review phần thay đổi.** Lần review lại chỉ kiểm tra bản sửa. Lỗi vòng 1 bỏ sót thì để xử lý sau,không kéo dài vòng lặp.
- **Lỗi chặn mới mà không phải regression thì dừng lượt chạy.** Nếu bản sửa đúng mà vẫn lòi ra lỗi chặn mới thì spec sai, và sửa code thêm cũng không giải quyết được.
- **Rule ID.** Output có cấu trúc chỉ cố định *định dạng* của finding, không đảm bảo nó *đúng*. Bắt buộc dẫn một rule có sẵn sẽ ngăn reviewer tự đặt ra tiêu chuẩn.
- **Bộ lọc chỉ thấy nhận định và hunk.** Reviewer đọc lập luận của tác giả sẽ bị lập luận đó dẫn dắt, mà ý kiến thứ hai chỉ có giá trị khi độc lập. Bộ lọc không đối xứng: với mất dữ liệu, quyền riêng tư và crash thì ưu tiên không bỏ sót; với hiệu năng thì ưu tiên bằng chứng; với mọi thứ khác thì ưu tiên độ chính xác.
- **Mỗi loại lỗi một agent phụ trách.** Mỗi khía cạnh chỉ một agent được báo finding. Hai reviewer cùng báo một finding thì tốn gấp đôi và sinh ra các bản sửa mâu thuẫn.
- **Khối Handoff cố định.** Orchestrator đọc các dòng `ACTION:` thay vì đoán.
- **So với bản chụp, không so với commit.** Code thường chưa được commit giữa các task, nên `git diff <sha>..` luôn ra rỗng. Vì vậy trước khi coder sửa, pipeline chụp lại các file bằng `git stash create`.
  Sửa xong thì so với bản chụp để biết đúng phần vừa sửa. Nếu coder lỡ sửa file ngoài phạm vi task, pipeline lấy lại nội dung cũ từ bản chụp. Bản chụp không gồm file mới tạo, nên reviewer được đưa thêm danh sách các file đó.
