[English](README.md) · **Tiếng Việt**

# dev-pipeline

Từ spec đến ship, có bước người duyệt sau spec và vòng review luôn có điểm dừng. Cần `review-gate`: chạy
`/review-gate:init` và điền cột Coder và Reviewer trong `.claude/review-gate/routing.md` trước, nếu không
`implement` không có agent nào để gọi.

| Lệnh | Làm gì |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Viết spec ở plan mode, có tiêu chí nghiệm thu kiểm tra được qua diff và mục Non-Goals bắt buộc. |
| `/dev-pipeline:spec-validate <spec>` | Sáu điều kiện gate khách quan, ba điều kiện quyết định bằng lệnh. Lưu kết luận cạnh spec. |
| `/dev-pipeline:task-decompose <spec>` | Chia task mỗi task một tầng, có Definition of Done (DoD) kiểm tra được, làm contract trước, và tạo `execution_state.md`. |
| `/dev-pipeline:implement <spec> [--continuous]` | Coder → reviewer → kiểm tra → lọc → sửa (tối đa 2 lần) → delta review, chạy tiếp được từ `execution_state.md`. Dừng sau mỗi task, in ra `/clear` rồi đúng lệnh đó; `--continuous` chạy hết trong một session. Sau task cuối, chạy thêm một lần để audit toàn feature (Step 5). |
| `/dev-pipeline:research "<question>"` | Nghiên cứu theo mức chi phí; chỉ gọi `tech-researcher` cho câu hỏi cần đào sâu hoặc bao quát; kiểm tra trích dẫn. |

| Agent | Làm gì |
|---|---|
| `dev-pipeline:tech-researcher` | Nghiên cứu một câu hỏi kỹ thuật, có trích dẫn nguồn; do `research` gọi. |

File: spec, kết luận validate, `{feature}_tasks.md` và `execution_state.md` nằm trong `docs/features/<feature>/`
(`FEATURES_DIR` trong `config.env`), report review trong `docs/reviews/` (`review_brief.md` §B7), kết quả nghiên cứu
trong `docs/research/`.

Quy tắc hội tụ (`implement`):
- **C1** chỉ Critical/High mới chặn · **C2** Medium/Low được hoãn và phân loại một lần · **C3** từ vòng 2 chỉ là
  delta review của bản sửa · **C4** từ vòng 2 nếu có lỗi chặn mới không phải regression thì dừng và hỏi người dùng.

Dừng lại sau bước spec và review spec trước khi chia task và implement.
