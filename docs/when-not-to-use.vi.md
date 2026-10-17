[English](when-not-to-use.md) · **Tiếng Việt**

# Khi nào không nên dùng

- **Sửa nhỏ.** Vài chỗ sửa cục bộ thì làm trong session chính nhanh hơn: tự chạy analyzer, các test trong phạm vi
  và một mutation proof. Bỏ qua pipeline; chạy `/review-gate:review` trên diff nếu muốn.
- **Khám phá và làm prototype.** Vòng lặp tối ưu cho độ đúng của thay đổi đã hoàn chỉnh, không phải tốc độ tìm tòi.
- **Task cần chung ngữ cảnh qua nhiều bước.** Subagent khởi động không có ngữ cảnh; một session dài thì giữ được.
- **Khi không đủ tiền cho token.** Chạy nhiều agent tốn gấp nhiều lần một cuộc chat đơn. Đặt `model: inherit` và
  chọn model rẻ hơn cho session nếu cần, nhưng giữ bộ lọc đủ mạnh.
- **Khi không ai bảo trì rule.** Bảng rule không bao giờ chuyển finding thành test sẽ chỉ còn là nhiễu.

Hãy dùng cho tính năng đụng tới nhiều tầng, contract phải giống hệt nhau trên mọi nền tảng, thay đổi nhạy cảm về
bảo mật, và hot path có ngân sách hiệu năng.
