[English](README.md) · **Tiếng Việt**

# review-gate

Phần lõi của marketplace: review có gate theo rule ID và luôn có điểm dừng.

| Thành phần | Đường dẫn | Ghi chú |
|---|---|---|
| agent `finding-checker` | `agents/finding-checker.md` | Đánh giá MỘT finding (lỗi mà reviewer báo) dựa trên hunk của nó: `REAL` / `NOT_REAL` / `NEEDS_EVIDENCE`. Chạy trên `opus`. |
| `/review-gate:review` | `commands/review.md` | Định tuyến diff → các reviewer chạy song song → kiểm tra rule ID → lọc finding chặn → tổng hợp. |
| `/review-gate:init` | `commands/init.md` | Tạo `.claude/review-gate/` từ `templates/` mà không ghi đè, và soạn sẵn Phần A dựa trên code của bạn. |
| Validator | `bin/validate_rule_ids.sh`, `bin/validate_findings.sh`, `bin/validate_spec_refs.sh`, `bin/validate_citations.sh` | Có trong `PATH` của Bash khi plugin đang bật. |
| Hook an toàn | `hooks/hooks.json` → `bin/block_destructive_git.sh auto` | Session chính: chỉ chặn các lệnh git làm mất phần việc đang làm. Subagent: chặn thêm commit/push/rebase/merge/switch. |
| Template | `templates/` | `review_brief.md`, `review_rules.md`, `routing.md`, `common_pitfalls.md`, `config.env`. |

Mã thoát: validator trả về `0` khi mọi thứ đều khớp, `1` khi có gì đó không khớp, `2` khi dùng sai cách hoặc thiếu
file. Hook trả về `2` để chặn (Claude Code hiển thị thông báo cho model) và `0` trong các trường hợp còn lại.
