[English](agent-guideline.md) · **Tiếng Việt**

# Hướng dẫn về agent

Cách quyết định, đặt tên, viết và kiểm chứng subagent của Claude Code.

## 1. Bạn có thật sự cần agent không?

Chọn công cụ nhẹ nhất mà vẫn làm được việc:

| Bạn cần | Dùng |
|---|---|
| Công việc bình thường | **Session chính.** Agent khởi động từ đầu, không có sẵn ngữ cảnh, nên chậm hơn. |
| Kiến thức hoặc quy trình ("làm X thế nào") | **Một skill.** Skill được nạp vào session hiện tại khi cần, và rẻ. |
| Một người làm riêng ("ai làm X") | **Một agent.** Agent có ngữ cảnh, tool và model riêng. |

Chỉ tạo agent khi bạn cần ít nhất một trong các điều sau:
- **Độc lập:** reviewer không được thấy lập luận của người viết code.
- **Giới hạn quyền:** ví dụ chỉ được đọc.
- **Việc chạy song song hoặc chạy lâu** trong khi session chính vẫn tiếp tục.

Nếu giá trị chủ yếu nằm ở kiến thức, hãy viết skill. Agent có thể nạp sẵn skill đó qua `skills:`.

## 2. Đặt tên theo phạm vi, rồi đến vai trò

Dùng dạng `<scope>-<role>`, trong đó role lấy từ một tập nhỏ, đóng, gắn với quyền hạn:

| Hậu tố vai trò | Ý nghĩa |
|---|---|
| `-coder` | Viết code trong một mảng. Không review. |
| `-expert` | Phụ trách một tầng hoặc một contract. Vừa triển khai vừa review phần đó. |
| `-reviewer` | Reviewer chỉ đọc cho một mảng. |
| `-checker` | Kiểm tra chỉ đọc, xuyên suốt nhiều mảng (bảo mật, hiệu năng, một finding duy nhất), chạy thêm bên trên các review theo mảng. |
| `-tester` | Chạy test và báo bằng chứng. |
| `-researcher` | Nghiên cứu, chỉ đọc. |

Người mới nhìn tên là biết agent làm gì, và hậu tố vẫn cho biết nó được phép làm gì. Hãy giữ tập này đóng: một
hậu tố nằm ngoài tập (`-architect`, `-helper`, `-keeper`) không nói gì về quyền hạn. Nếu đổi tên agent, hãy giữ
bảng ánh xạ tên cũ sang tên mới để các plan và log cũ vẫn tra được (mục `Legacy names` trong `routing.md`).

## 3. Mỗi agent một trách nhiệm

- Mỗi mối quan tâm có đúng một người phụ trách. Các agent khác chỉ nhắc đến nó trong một dòng và không báo finding
  (lỗi mà reviewer báo) về nó.
- Hai agent cùng báo một finding, hoặc đưa ra chỉ dẫn trái ngược nhau, là lỗi thiết kế.
- Khi bỏ một agent, hãy giao trách nhiệm **và checklist** của nó cho một agent kế nhiệm có tên cụ thể.

## 4. Theo đúng định dạng chính thức, đừng tin vào sự im lặng

Claude Code lặng lẽ bỏ qua mọi thứ nó không hiểu. Những cái bẫy hay gặp:
- Trường frontmatter không được hỗ trợ sẽ bị bỏ. Chỉ dùng các trường có trong tài liệu.
- Tên tool phải phân giải được. Tool MCP được viết là `mcp__<server>` hoặc `mcp__<server>__<tool>`; chỉ ghi tên
  server trơn thì không cấp quyền gì cả.
- Màu chỉ được chọn trong: red, blue, green, yellow, purple, orange, pink, cyan.
- Biến chỉ có trong plugin (ví dụ `${CLAUDE_PLUGIN_ROOT}`) sẽ rỗng trong file của project.
- Giữ description ngắn (một hai câu), đủ cụ thể để chọn ra đúng agent này, và đặt trong dấu nháy để YAML vẫn
  hợp lệ. Chỉ thêm "use proactively" nếu bạn thật sự muốn tự động giao việc.

## 5. Giữ thông tin dự án ở một chỗ

- Đặt thông tin dự án (cấu trúc thư mục, lệnh, ngân sách hiệu năng, quy tắc cứng) trong một file dùng chung duy
  nhất, và điều phối agent bằng một bảng duy nhất. Agent trỏ tới các file này chứ không chép lại, vì bản chép sẽ
  lệch dần.
- Trước khi ghi một thông tin vào agent, hãy đối chiếu với code và lịch sử, không phải với tài liệu cũ.
- Code mẫu trong agent phải chép từ một file thật trong repository, và phải ghi tên file đó.
- Kiểm tra agent và skill của bên thứ ba theo quy ước của bạn trước khi dùng.

## 6. Dùng máy để ép các quy tắc quan trọng

Một quy tắc nằm trong prompt mỗi lần được áp dụng một kiểu; quy tắc nằm trong hook, script hay test thì lần nào
cũng chạy giống nhau.
- Chặn các lệnh nguy hiểm bằng hook `PreToolUse`, ví dụ các lệnh git xóa mất phần việc chưa commit.
- Bắt reviewer trích rule ID từ một danh sách đóng, và loại bỏ ID không hợp lệ bằng script.
- Một finding cứ lặp lại thì nên biến thành test hoặc lint, hoặc bỏ đi.

## 7. Quyền tối thiểu

- Reviewer không có tool sửa file, và chỉ được dùng phần chỉ đọc của bất kỳ MCP server nào có khả năng sửa file.
- Agent đụng tới thiết bị, build hoặc release chỉ được hành động khi có sự đồng ý rõ ràng.
- Agent nào có shell cũng phải mang hook an toàn.

## 8. Vòng lặp phải kết thúc, và bước nào cũng cần bằng chứng

- Chỉ finding Critical và High mới chặn. Finding Medium và Low được hoãn lại và phân loại một lần ở cuối.
- Từ vòng review thứ hai trở đi, chỉ review phần sửa (delta review). Giới hạn số vòng sửa (hai là đủ).
- Agent nào cũng kết thúc bằng một khối bàn giao cố định, máy đọc được, để orchestrator không phải đoán.
- "Xong" đòi hỏi kết quả thật, đã chạy thật. "Build được" không có nghĩa là "test pass".
- Đảm bảo mốc so sánh phù hợp với cách team làm việc. Nếu team không commit giữa các task, `git diff <sha>..`
  luôn rỗng; khi đó hãy diff với một snapshot (`git stash create`).

## 9. Kiểm chứng bằng cách chạy

- Định nghĩa agent được nạp lúc bắt đầu session, nên hãy thử thay đổi trong một session mới (ví dụ `claude -p`).
- Yêu cầu agent liệt kê tool của nó, gọi một tool MCP, và thử một lệnh mà hook đáng lẽ phải chặn.
- Chạy một script kiểm tra frontmatter, tên tool, màu, hook, skill được nạp sẵn, và mọi tên agent mà workflow
  của bạn nhắc tới.
- Nói rõ những gì chưa được chạy.

---

## Checklist

1. Việc này có cần độc lập, giới hạn quyền, hay chạy song song không? Nếu không, dùng session chính hoặc một skill.
2. Nó có trùng trách nhiệm với agent nào đang có không? Nếu có, mở rộng agent đó.
3. Chọn tên: `<scope>-<role>`.
4. Frontmatter: `name`, một `description` ngắn trong dấu nháy, `tools` tối thiểu, `model`, `color`, `skills` nếu
   cần, và `hooks` nếu agent có shell.
5. Phần thân: trỏ tới file thông tin dự án dùng chung, nêu vai trò trong hai ba dòng, liệt kê quy tắc cứng của
   mảng, phương pháp, và khối bàn giao.
6. Đăng ký agent trong bảng điều phối và trong mọi workflow có giao việc cho nó.
7. Thử nó trong một session mới và báo những gì đã và chưa được kiểm chứng.

## Template

```markdown
---
name: <scope>-<role>
description: "<What it does> in <scope>. Use for <when to call it>."
tools: Read, Grep, Glob, Bash, <Edit, Write if it writes code>, <mcp__server__tool if needed>
model: <model>
color: <allowed color>
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "\"$CLAUDE_PROJECT_DIR\"/<path to your safety hook>"
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
