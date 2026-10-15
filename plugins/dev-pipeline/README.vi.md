[English](README.md) · **Tiếng Việt**

# dev-pipeline

Từ spec đến lúc ship, có một bước người duyệt ngay sau spec và một vòng review luôn có điểm dừng. Cần có `review-loop`.

| Lệnh | Làm gì |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Viết spec ở plan mode, với tiêu chí nghiệm thu kiểm tra được qua diff và mục Non-Goals bắt buộc. |
| `/dev-pipeline:spec-validate <spec>` | Sáu điều kiện gate khách quan, trong đó ba điều kiện được quyết định bằng lệnh. Lưu kết luận ngay cạnh spec. |
| `/dev-pipeline:task-decompose <spec>` | Chia thành các task chỉ thuộc một tầng, mỗi task có Definition of Done (DoD) kiểm tra được, làm contract trước, và tạo `execution_state.md`. |
| `/dev-pipeline:implement <spec>` | Coder → reviewer → kiểm tra → lọc → sửa (tối đa 2 lần) → delta review, chạy tiếp được từ `execution_state.md`. |
| `/dev-pipeline:research "<question>"` | Nghiên cứu theo mức chi phí; chỉ gọi `tech-researcher` cho câu hỏi cần đào sâu hoặc bao quát rộng; kiểm tra trích dẫn. |

Quy tắc hội tụ (`implement`):
- **C1** chỉ Critical/High mới chặn · **C2** Medium/Low được hoãn lại và phân loại một lần · **C3** từ vòng 2 trở đi chỉ
  là delta review của bản sửa · **C4** nếu từ vòng 2 xuất hiện một lỗi chặn mới không phải regression thì dừng lại và
  hỏi người dùng.

Dừng lại sau bước spec: review spec trước khi chia task và implement.
