[English](architecture.md) · **Tiếng Việt**

# Kiến trúc

## Mục tiêu thiết kế
1. **Vòng lặp phải dừng được.** Chu trình review → sửa → review mà cứ tìm ra cái mới là kiểu thất bại mặc định của
   review nhiều agent.
2. **Finding phải là thật.** Một finding chặn sai (finding là lỗi mà reviewer báo) tốn một lần chạy coder cộng
   thêm một lần review lại.
3. **Thông tin chỉ viết một lần.** Agent nào cũng tự tìm hiểu lại dự án từ đầu thì vừa chậm vừa dễ lệch nhau.

## Thành phần

| Thành phần | Vai trò | Tất định? |
|---|---|---|
| `review_brief.md` Phần A | Thông tin dự án mà mọi agent đọc trước tiên | — |
| `review_brief.md` Phần B | Giao thức: gate mức độ nghiêm trọng, phạm vi, review phần thay đổi, quyền sở hữu, giới hạn báo cáo, bàn giao | — |
| `review_rules.md` | Bộ rule đóng gồm các rule ID | — |
| `routing.md` | Thư mục → agent, overlay gate, quyền sở hữu | — |
| `validate_rule_ids.sh` | Bỏ các finding có rule ID không tra ra được | **có** |
| `validate_findings.sh` | Bỏ các finding mà file, dòng hoặc đoạn trích nguyên văn được dẫn không có thật | **có** |
| `validate_spec_refs.sh` | Đánh fail spec/task dẫn tới file không tồn tại hoặc agent không có | **có** |
| `validate_citations.sh` | Đánh dấu URL nghiên cứu chết hoặc bịa ra | **có** |
| `block_destructive_git.sh` | Chặn các lệnh git làm mất thay đổi chưa commit | **có** |
| `finding-checker` | Đánh giá một finding dựa trên một hunk | model |
| Reviewer theo vùng và các gate | Review diff, mỗi bên một cột | model |
| `device-tester` + driver | Chạy bản release trên máy thật và báo bằng chứng cho từng case | driver **có**, agent model |

## Vì sao có từng quy tắc

- **Chỉ Critical/High mới chặn.** Medium/Low được hoãn lại và phân loại một lần ở cuối. Nếu không, vòng nào cũng
  sinh ra lỗi vặt mới và vòng lặp không bao giờ hội tụ.
- **Từ vòng 2 chỉ review phần thay đổi.** Lần review lại kiểm tra bản sửa, không kiểm tra lại cả tính năng. Lỗi
  mà vòng 1 bỏ sót thì để xử lý sau; nó không kéo dài vòng lặp.
- **Lỗi chặn mới mà không phải regression thì dừng lượt chạy.** Nếu bản sửa đúng mà vẫn lòi ra lỗi chặn mới, thì
  spec sai, và sửa code mãi cũng không giải quyết được.
- **Rule ID.** Output có cấu trúc chỉ cố định *định dạng* của finding, không đảm bảo nó *đúng*. Bắt buộc dẫn một
  rule có sẵn sẽ ngăn reviewer tự đặt ra tiêu chuẩn, và một script có thể kiểm tra việc đó mà không tốn gì.
- **Bộ lọc chỉ thấy nhận định và hunk.** Reviewer đọc lập luận của tác giả thì sẽ bị lập luận đó dẫn dắt; giá trị
  của ý kiến thứ hai nằm ở chỗ độc lập. Bộ lọc không đối xứng: với mất dữ liệu, quyền riêng tư và crash thì ưu tiên
  không bỏ sót; với hiệu năng thì ưu tiên bằng chứng; với mọi thứ khác thì ưu tiên độ chính xác.
- **Quyền sở hữu độc quyền.** Mỗi khía cạnh chỉ một agent được báo finding. Hai reviewer cùng báo một finding thì
  tốn gấp đôi và sinh ra các bản sửa mâu thuẫn nhau.
- **Khối bàn giao cố định.** Orchestrator đọc các dòng `ACTION:` thay vì đoán từ văn xuôi.
- **Snapshot, không dùng SHA.** Team không commit giữa các task sẽ nhận được `git diff <sha>..` rỗng. Pipeline
  diff với một snapshot tạo bằng `git stash create` và khôi phục các thay đổi ngoài phạm vi từ snapshot đó.

## Liên hệ với các hướng dẫn đã công bố

- [Hệ thống nghiên cứu nhiều agent](https://www.anthropic.com/engineering/multi-agent-research-system) của Anthropic:
  làm việc nhiều agent tốn khoảng 15 lần một cuộc chat và chỉ đáng khi công việc song song, trải rộng. Ở đây coder
  chạy lần lượt theo từng task; chỉ reviewer chỉ-đọc mới chạy song song.
- [Don't build multi-agents](https://cognition.com/blog/dont-build-multi-agents) của Cognition: các agent song song
  cùng viết code sẽ đưa ra quyết định mâu thuẫn nhau. Ở đây không có hai agent nào viết cùng một tầng cùng lúc, và
  subagent chỉ trả lời các câu hỏi hẹp.
- Tài liệu tham khảo về [subagent](https://code.claude.com/docs/en/sub-agents) và
  [plugin](https://code.claude.com/docs/en/plugins-reference) của Claude Code định nghĩa các định dạng dùng ở đây.
