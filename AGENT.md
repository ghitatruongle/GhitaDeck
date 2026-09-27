# AGENT.md — Quy tắc bắt buộc cho mọi agent AI làm việc trong repo này

Ba quy tắc cốt lõi dưới đây có độ ưu tiên cao nhất trong toàn bộ repo. Mọi agent (AI hoặc người cộng tác) phải đọc file này TRƯỚC khi thực hiện bất kỳ thao tác nào. Vi phạm bất kỳ quy tắc nào là lỗi nghiêm trọng, kể cả khi được yêu cầu gián tiếp.

---

## Quy tắc 1 — KHÔNG BAO GIỜ tự ý commit hay push

Không tự ý thực hiện bất kỳ thao tác ghi nào lên git mà chưa có sự cho phép rõ ràng của chủ repo trong phiên làm việc đó. Bao gồm nhưng không giới hạn ở:

- `git commit` (tạo commit mới ở local)
- `git push` (lên GitHub hoặc bất kỳ remote nào)
- `git push --force` / `--force-with-lease`
- `git tag` + push tag
- `git commit --amend`, `git rebase`, `git reset --hard`, `git filter-branch`, `git filter-repo` — mọi thao tác đổi lịch sử
- Tạo branch, tạo Pull Request, tạo Release trên GitHub

"Cho phép" nghĩa là người dùng nói rõ trong hội thoại (ví dụ: "commit đi", "push lên github", "đặt tag"). Sự im lặng, trả lời chung chung ("ok", "ừ") cho một câu hỏi KHÁC không cấu thành cho phép. Khi nghi ngờ: hỏi lại, đừng làm.

Ngoại lệ duy nhất: thao tác git chỉ đọc (`status`, `log`, `diff`, `fetch`…) được tự do thực hiện.

## Quy tắc 2 — CODE KHÔNG ĐƯỢC CÓ GHI CHÚ (comment)

Mọi mã nguồn viết mới hoặc sửa trong repo này KHÔNG được chứa bất kỳ chú thích nào, ở bất kỳ ngôn ngữ nào:

- Dart: không `//`, không `///`, không `/* */`
- Rust: không `//`, không `///`, không `//!`
- C++ / CMake / PowerShell / YAML / script: không `#`, không `//`, không `/* */`
- HTML / XML: không `<!-- -->`

Code phải tự giải thích bằng tên biến, tên hàm, cấu trúc. Nếu một đoạn code cần comment để hiểu được thì cách viết đó sai — viết lại code, đừng thêm ghi chú.

Lưu ý hiện trạng: codebase hiện có sẵn hàng nghìn dòng comment từ trước. Việc dọn comment cũ là một bước riêng, chỉ làm khi chủ repo duyệt; không tự ý xoá hàng loạt khi chỉ sửa một phần nhỏ.

## Quy tắc 3 — Tài liệu nội bộ / riêng tư KHÔNG lên git

Mọi file thuộc loại sau PHẢI nằm trong `.gitignore` (mục 11) và KHÔNG BAO GIỜ được commit hay push:

- Kế hoạch phát hành, roadmap, bản nháp kế hoạch (`RELEASE_PLAN_*.md`, `ROADMAP_*.md`)
- Kết quả đo, benchmark, profiling nội bộ (`tool/benchmark_results_*.md`, `tool/ram_results_*.md`)
- Checklist QA nội bộ, mockup ghi chú (`installer/demo_manual_checklist.md`, `tool/template_mockups/*.md`)
- Ghi chú phiên làm việc của agent (`.zcode/`, `.agents/`, scratch)
- Bất kỳ tài liệu "rác, nháp, riêng tư, bí mật, không thể công khai" nào khác

Nếu lỡ commit hoặc phát hiện file như vậy TỒN TẠI TRONG LỊCH SỬ git (kể cả đã bị xoá ở commit sau): phải xoá VĨNH VIỄN khỏi toàn bộ lịch sử — không chỉ thêm commit xoá mới — rồi mới push:

```
git filter-branch --index-filter "git rm -r --cached --ignore-unmatch <đường-dẫn>" --tag-name-filter cat -- --all
git push --force origin main --tags
```

Vì lịch sử đã bị đổi, force-push là bắt buộc. Cả hai bước này đều thuộc Quy tắc 1: phải có sự cho phép rõ ràng trước khi chạy.

Tài liệu nội bộ vẫn sống bình thường trên máy (gitignore chỉ ẩn khỏi git, không xoá file ở thư mục làm việc).
