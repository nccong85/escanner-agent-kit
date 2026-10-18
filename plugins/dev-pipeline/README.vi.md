[English](README.md) · **Tiếng Việt** · [日本語](README.ja.md)

# dev-pipeline

Từ spec đến ship.

| Lệnh | Vai trò |
|---|---|
| `/dev-pipeline:spec-create "<feature>"` | Viết spec ở plan mode, có tiêu chí nghiệm thu kiểm tra |
| `/dev-pipeline:spec-validate <spec>` | Sáu điều kiện gate khách quan, ba điều kiện quyết định bằng lệnh. Lưu kết luận cạnh spec. |
| `/dev-pipeline:task-decompose <spec>` | Chia task, có Definition of Done (DoD) kiểm tra được, làm contract, và tạo `execution_state.md`. |
| `/dev-pipeline:implement <spec> [--per-task]` | Coder → reviewer → kiểm tra → lọc → sửa (tối đa 2 lần) → delta review, chạy tiếp được từ `execution_state.md`. Chạy hết các task rồi audit toàn feature (Step 5) trong một session. `--per-task` dừng sau mỗi task. |
| `/dev-pipeline:research "<question>"` | Nghiên cứu cách thức implement; chỉ gọi `tech-researcher` cho câu hỏi cần đào sâu hoặc bao quát; kiểm tra trích dẫn. |

| Agent | Vai trò |
|---|---|
| `dev-pipeline:tech-researcher` | Nghiên cứu một câu hỏi kỹ thuật; do `research` gọi. |

File: spec, kết luận validate, `{feature}_tasks.md` và `execution_state.md` nằm trong `docs/features/<feature>/`
(`FEATURES_DIR` trong `config.env`), report review trong `docs/reviews/` (`review_brief.md` §B7), kết quả nghiên cứu
trong `docs/research/`.

Quy tắc hội tụ (`implement`):
- **C1** chỉ Critical/High mới chặn · **C2** Medium/Low được hoãn và phân loại một lần · **C3** từ vòng 2 chỉ là
  delta review của bản sửa · **C4** từ vòng 2 nếu có lỗi chặn mới không phải regression thì dừng và hỏi người dùng.

Dừng lại sau bước spec và review spec trước khi chia task và implement.
