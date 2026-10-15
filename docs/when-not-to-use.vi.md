[English](when-not-to-use.md) · **Tiếng Việt**

# Khi nào không nên dùng

- **Sửa nhỏ.** Vài chỗ sửa cục bộ thì làm trong session chính nhanh hơn: tự chạy analyzer, các test trong phạm vi
  và một mutation proof. Bỏ qua delta review.
- **Khám phá và làm prototype.** Vòng lặp này tối ưu cho độ đúng của một thay đổi đã hoàn chỉnh, không phải cho
  tốc độ tìm tòi.
- **Task cần chia sẻ ngữ cảnh qua nhiều bước.** Subagent khởi động từ đầu, không có ngữ cảnh; một session dài thì
  giữ được ngữ cảnh.
- **Khi bạn không đủ tiền cho token.** Chạy nhiều agent tốn gấp nhiều lần một cuộc chat đơn. Đặt `model: inherit`
  và chọn model rẻ hơn cho session nếu cần, nhưng vẫn giữ bộ lọc đủ mạnh.
- **Khi không ai bảo trì các rule.** Một bảng rule không bao giờ chuyển finding thành test sẽ chỉ còn là nhiễu.

Hãy dùng nó cho các tính năng đụng tới nhiều tầng, các contract phải giữ y hệt nhau trên mọi nền tảng, các thay
đổi nhạy cảm về bảo mật, và các hot path có ngân sách hiệu năng.
