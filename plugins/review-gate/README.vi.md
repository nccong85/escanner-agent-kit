[English](README.md) · **Tiếng Việt** · [日本語](README.ja.md)

# review-gate

Phần lõi của marketplace: review có gate theo rule ID và luôn có điểm dừng.

| Thành phần | Đường dẫn | Ghi chú |
|---|---|---|
| agent `finding-checker` | `agents/finding-checker.md` | Đánh giá MỘT finding (lỗi reviewer báo) dựa trên hunk của nó: `REAL` / `NOT_REAL` / `NEEDS_EVIDENCE`. Chạy trên `opus`. |
| `/review-gate:review` | `commands/review.md` | Định tuyến diff → các reviewer chạy song song → kiểm tra rule ID → lọc finding chặn → tổng hợp. |
| `/review-gate:init` | `commands/init.md` | Tạo `.claude/review-gate/` từ `templates/` mà không ghi đè, và soạn sẵn Phần A từ code của bạn. |
| Validator | `bin/validate_rule_ids.sh`, `bin/validate_findings.sh`, `bin/validate_spec_refs.sh`, `bin/validate_citations.sh` | Có trong `PATH` của Bash khi plugin bật. Thư mục gốc dự án (`bin/lib_config.sh`): `REVIEW_GATE_PROJECT_DIR`, không có thì `CLAUDE_PROJECT_DIR`, rồi git root, cuối cùng là thư mục hiện tại. |
| Hook an toàn | `hooks/hooks.json` → `bin/block_destructive_git.sh auto` | Session chính: chỉ chặn lệnh git làm mất việc đang làm. Subagent: chặn mọi lệnh git thay đổi working tree, index, ref hoặc lịch sử (commit, push, rebase, merge, switch, stash, branch, tag, …). |
| Template | `templates/` | `review_brief.md`, `review_rules.md`, `routing.md`, `common_pitfalls.md`, `config.env`. |

## Cài đặt

Cần `jq` hoặc `python3` (thiếu cả hai thì hook chặn mọi lệnh git), và `curl` cho `validate_citations.sh`.

1. `claude plugin install review-gate@escanner-agent-kit`.
2. Chạy `/review-gate:init` trong dự án. Lệnh này tạo `.claude/review-gate/` và soạn sẵn Phần A của
   `review_brief.md` từ code của bạn, đánh dấu `<VERIFY>` ở mỗi thông tin chưa kiểm chứng được.
3. Xử lý từng `<VERIFY>`, rồi điền các agent coder và reviewer vào `routing.md`.
4. Chạy `/review-gate:review` trên một diff.

Mã thoát: validator trả `0` khi mọi thứ khớp, `1` khi có chỗ không khớp, `2` khi dùng sai hoặc thiếu file. Hook trả
`2` để chặn (Claude Code hiển thị thông báo cho model), còn lại là `0`.
