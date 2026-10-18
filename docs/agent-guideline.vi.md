[English](agent-guideline.md) · **Tiếng Việt** · [日本語](agent-guideline.ja.md)

# Hướng dẫn sử dụng và tạo agent

Đối chiếu với [tài liệu subagent của Claude Code](https://code.claude.com/docs/en/sub-agents).

## 1. Khi nào cần agent?

Chọn công cụ nhẹ nhất:

- **Session chính:** việc hằng ngày.
- **Skill:** kiến thức hoặc quy trình. Agent có thể nạp sẵn skill qua `skills:`.
- **Agent:** chỉ khi cần độc lập, giới hạn quyền, hoặc chạy
  ngầm/song song.

## 2. Đặt tên: `<mảng>-<vai trò>`

Tên cho biết agent làm gì; hậu tố cho biết nó được làm gì.

| Hậu tố | Ý nghĩa |
|---|---|
| `-coder` | Viết code, không review. |
| `-expert` | Viết và review trong mảng mình phụ trách. |
| `-reviewer` | Chỉ review; chỉ được `Write` file report của nó. |
| `-checker` | Kiểm tra chuyên sâu xuyên mảng (bảo mật, hiệu năng), quyền như reviewer. |
| `-tester` | Chạy test và báo kết quả. |
| `-researcher` | Chỉ đọc và nghiên cứu. |

## 3. Quy tắc cơ bản

- **Mỗi loại lỗi chỉ một agent được báo.** Khi nhiều agent cùng review một diff (ví dụ `flutter-reviewer`,
  `performance-checker`, `security-checker` chạy song song), phạm vi chồng nhau gây ra:
  - trùng lặp: một lỗi bị báo nhiều lần, tốn gấp đôi;
  - mâu thuẫn: hai agent đòi sửa ngược nhau trên cùng một dòng.

- **Viết frontmatter đúng tài liệu.**
  - Chỉ dùng trường có trong tài liệu; bắt buộc chỉ có `name` và `description`.
  - `description` nói *khi nào* giao việc ("Use when …"), ngắn, trong dấu nháy. Tổng description của mọi agent có
    ngân sách 15.000 token.
  - MCP: cả server là `mcp__<server>__*`; tên trần `mcp__<server>` chỉ dùng trong `disallowedTools`.
  - Màu: red, blue, green, yellow, purple, orange, pink, cyan.
  - Agent trong plugin bỏ qua `hooks`, `mcpServers` và `permissionMode`.
- **Thông tin chung của dự án (lệnh test, budget, thư mục…) chỉ viết trong một file.** Mỗi agent ghi "đọc file đó
  trước" thay vì định nghĩa riêng.

## 4. Quyền hạn

- **Chỉ cấp tool mà agent cần.**
  - Luôn ghi dòng `tools:`. Không ghi thì agent được dùng *mọi* tool, kể cả mọi MCP.
  - Reviewer chỉ đọc và viết report, nên không cấp `Edit`.
  - Muốn cấp gần hết nhưng chặn vài tool thì liệt kê tool bị chặn trong `disallowedTools`.
  - Không nên để agent này gọi agent khác thông qua chỉ định `tools:`.
- **Quy tắc quan trọng thì dùng hook hoặc script để chặn, đừng chỉ viết trong prompt.**
- **Thực hiện xác nhận** khi agent chạy trên thiết bị thật, build hoặc release.

## 5. Vòng lặp review

- **Chỉ lỗi Critical/High mới bắt coder sửa ngay.** Lỗi Medium/Low được ghi vào danh sách, xem xét một lần khi
  xong tính năng.
- **Từ lần review thứ hai, reviewer chỉ xem phần vừa sửa**, không review lại cả diff (delta review).
- **Sửa tối đa 2 vòng.** Sau 2 vòng mà vẫn còn lỗi chặn thì dừng và báo người, vì vòng thứ 3 thường sinh thêm
  lỗi mới thay vì hết lỗi.
- **Chỉ báo "xong" khi test đã chạy thật** và có kết quả, không phải chỉ build được.
- **Agent trả kết quả theo một mẫu cố định** (ví dụ dòng `ACTION: REVIEW_REQUIRED` kèm danh sách file đã sửa),
  để session chính đọc được mà không phải đoán.

## 6. Kiểm chứng

1. **Cho Claude Code nạp bản mới trước khi thử.**
2. **Giao cho agent một việc nhỏ để kiểm tra:**
   - hỏi nó đang có những tool nào, xem có đúng dòng `tools:` không;
   - bảo nó gọi một tool MCP (ví dụ serena), xem có gọi được không;
   - bảo nó chạy một lệnh mà hook phải chặn, xem có bị chặn không.
3. **Báo cáo trung thực.**

---

## Checklist

1. Cần độc lập, giới hạn quyền hay chạy song song? Không thì dùng session chính hoặc skill.
2. Trùng trách nhiệm với agent đang có? Có thì mở rộng agent đó.
3. Tên `<mảng>-<vai trò>`.
4. Frontmatter: `name`, `description` (khi nào dùng), `tools` tối thiểu, `model`, `color`, `skills` nếu cần.
5. Thân: trỏ tới file thông tin dự án, vai trò (2–3 dòng), quy tắc cứng, phương pháp, khối bàn giao.
6. Đăng ký trong bảng điều phối và các workflow giao việc cho nó.
7. Kiểm chứng như mục 6.

## Template

```markdown
---
name: <scope>-<role>
description: "<What it does> in <scope>. Use when <when to call it>."
tools: Read, Grep, Glob, Bash, Write, <Edit if it writes code>, <mcp__server__* if needed>
model: <model>
color: <allowed color>
---

## Binding context
Read <shared project facts file> first. It overrides this file on conflict.

## Role
<Two or three lines.>

## Hard rules
- <Rules specific to this area.>

## Method
1. <Steps.>

## Hand-off
<The exact block the orchestrator parses.>
```
