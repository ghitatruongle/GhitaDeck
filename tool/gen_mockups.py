# -*- coding: utf-8 -*-
"""Generate T17 template mockup HTML files (5 sets x 3 layouts)."""
import io
import os

B = "tool/template_mockups"
OUT = os.path.join("D:/GhitaPPT", B)

DOT = "\u25CF"


def tmpl(bg, body):
    html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; padding: 0; }
  .page { box-sizing: border-box; width: 1280px; height: 720px; padding: 56px 72px; }
</style>
</head>
<body>
<div class="page" data-bg-color="@@BG@@" style="background:@@BG@@;">@@BODY@@</div>
</body>
</html>
"""
    return html.replace("@@BG@@", bg).replace("@@BODY@@", body)


def build(body, font=True, dot=False):
    out = body.replace("@@F@@", "font-family:'Segoe UI',Arial,sans-serif;")
    if dot:
        out = out.replace("@@D@@", DOT)
    return out


sets = {}

sets["business"] = {}
sets["business"]["A"] = build("""<div style="height:100%;@@F@@">
  <div style="width:80px;height:6px;background:linear-gradient(90deg,#4248BB,#7B8CF0);border-radius:3px;margin-bottom:28px;"></div>
  <h1 style="color:#FFFFFF;font-size:44px;font-weight:700;margin:0 0 16px 0;letter-spacing:-1px;">Q3 Corporate Review</h1>
  <p style="color:#A8B3CC;font-size:20px;margin:0;">Kết quả kinh doanh và kế hoạch quý tới</p>
</div>""")
sets["business"]["B"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#E8EDF7;font-size:28px;font-weight:700;margin:0 0 28px 0;">Hiệu quả bộ phận</h2>
  <table style="border-collapse:collapse;width:100%;">
    <tr>
      <td style="background:rgba(66,72,187,0.14);border:1px solid rgba(66,72,187,0.40);border-radius:10px;padding:24px;color:#C7D2E4;font-size:17px;vertical-align:top;">
        <span style="color:#8E9BFF;font-size:32px;font-weight:700;">+18%</span><br>
        Tổng doanh thu tăng so với quý trước
      </td>
      <td style="background:rgba(66,72,187,0.14);border:1px solid rgba(66,72,187,0.40);border-radius:10px;padding:24px;color:#C7D2E4;font-size:17px;vertical-align:top;">
        <span style="color:#8E9BFF;font-size:32px;font-weight:700;">12</span><br>
        Khách hàng mới trong quý
      </td>
      <td style="background:rgba(66,72,187,0.14);border:1px solid rgba(66,72,187,0.40);border-radius:10px;padding:24px;color:#C7D2E4;font-size:17px;vertical-align:top;">
        <span style="color:#8E9BFF;font-size:32px;font-weight:700;">96%</span><br>
        Tỷ lệ gia hạn hợp đồng
      </td>
    </tr>
  </table>
</div>""")
sets["business"]["C"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#E8EDF7;font-size:26px;font-weight:700;margin:0 0 20px 0;">Lộ trình triển khai</h2>
  <div style="border-left:3px solid #4248BB;padding:0 0 4px 20px;margin:0 0 20px 0;">
    <p style="color:#8E9BFF;font-size:14px;font-weight:700;margin:0 0 4px 0;">QUÝ 1</p>
    <p style="color:#D7DEEF;font-size:18px;margin:0;">Chuẩn hóa quy trình bán hàng và đào tạo đội ngũ</p>
  </div>
  <div style="border-left:3px solid #4248BB;padding:0 0 4px 20px;margin:0 0 20px 0;">
    <p style="color:#8E9BFF;font-size:14px;font-weight:700;margin:0 0 4px 0;">QUÝ 2</p>
    <p style="color:#D7DEEF;font-size:18px;margin:0;">Ra mắt kênh đối tác và cơ chế báo cáo tự động</p>
  </div>
</div>""")

sets["creative"] = {}
sets["creative"]["A"] = build("""<div style="height:100%;@@F@@;text-align:center;">
  <div style="width:80px;height:6px;background:linear-gradient(90deg,#6A16D3,#C084FC);border-radius:3px;margin:0 auto 28px auto;"></div>
  <h1 style="color:#FFFFFF;font-size:46px;font-weight:700;margin:0 0 14px 0;letter-spacing:-1px;">Ý tưởng bứt phá 2026</h1>
  <p style="color:#CBADF5;font-size:20px;margin:0;">Workshop định hướng sáng tạo</p>
</div>""")
sets["creative"]["B"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#E9D8FF;font-size:28px;font-weight:700;margin:0 0 28px 0;">Ba trụ cột concept</h2>
  <table style="border-collapse:collapse;width:100%;font-size:17px;">
    <tr>
      <td style="background:rgba(168,85,247,0.12);border:1px solid rgba(168,85,247,0.35);border-radius:12px;padding:24px;color:#CDB7E8;vertical-align:top;">
        <span style="color:#C084FC;font-size:22px;font-weight:700;">01</span><br>Nội dung bản địa hóa theo ngữ cảnh người dùng
      </td>
      <td style="background:rgba(168,85,247,0.12);border:1px solid rgba(168,85,247,0.35);border-radius:12px;padding:24px;color:#CDB7E8;vertical-align:top;">
        <span style="color:#C084FC;font-size:22px;font-weight:700;">02</span><br>Định dạng thị giác sinh động, tương tác nhẹ
      </td>
      <td style="background:rgba(168,85,247,0.12);border:1px solid rgba(168,85,247,0.35);border-radius:12px;padding:24px;color:#CDB7E8;vertical-align:top;">
        <span style="color:#C084FC;font-size:22px;font-weight:700;">03</span><br>Đo lường quay vòng thử nghiệm hai tuần
      </td>
    </tr>
  </table>
</div>""")
sets["creative"]["C"] = build("""<div style="height:100%;@@F@@">
  <p style="color:#C084FC;font-size:64px;font-weight:700;margin:0 0 12px 0;line-height:1;">24</p>
  <p style="color:#D8BCF7;font-size:22px;font-weight:700;margin:0 0 26px 0;">giờ để chạy một thử nghiệm sản phẩm</p>
  <p style="color:#CDB7E8;font-size:18px;margin:0 0 12px 0;">&bull;  Quy trình prototype tự động hóa gần như toàn bộ</p>
  <p style="color:#CDB7E8;font-size:18px;margin:0 0 12px 0;">&bull;  Nhóm cross-functional sẵn sàng xoay hướng nhanh</p>
  <p style="color:#CDB7E8;font-size:18px;margin:0;">&bull;  Dữ liệu phản hồi gom về một nơi duy nhất</p>
</div>""")

sets["academic"] = {}
sets["academic"]["A"] = build("""<div style="height:100%;@@F@@;text-align:center;">
  <div style="width:80px;height:6px;background:#55F6FF;border-radius:3px;margin:0 auto 28px auto;"></div>
  <h1 style="color:#FFFFFF;font-size:44px;font-weight:700;margin:0 0 14px 0;letter-spacing:-1px;">Phương pháp nghiên cứu định lượng</h1>
  <p style="color:#9FD9DF;font-size:19px;margin:0;">Học phần: Thống kê ứng dụng trong khoa học xã hội</p>
</div>""")
sets["academic"]["B"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#BFF3F7;font-size:28px;font-weight:700;margin:0 0 24px 0;">Điểm qua trên lớp</h2>
  <p style="color:#CFECEF;font-size:19px;margin:0 0 16px 0;">Thiết kế chương trình học chia ba cấu phần liên thông:</p>
  <p style="color:#CFECEF;font-size:19px;margin:0 0 10px 0;"><span style="color:#55F6FF;font-weight:700;">@@D@@</span>  Lý thuyết khảo sát và sai số mẫu</p>
  <p style="color:#CFECEF;font-size:19px;margin:0 0 10px 0;"><span style="color:#55F6FF;font-weight:700;">@@D@@</span>  Thực hành thu thập dữ liệu theo nhóm</p>
  <p style="color:#CFECEF;font-size:19px;margin:0;"><span style="color:#55F6FF;font-weight:700;">@@D@@</span>  Báo cáo phân tích ngắn cuối học kỳ</p>
</div>""", dot=True)
sets["academic"]["C"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#BFF3F7;font-size:26px;font-weight:700;margin:0 0 22px 0;">Kết quả khảo sát mẫu</h2>
  <table style="border-collapse:collapse;width:100%;font-size:17px;">
    <tr>
      <th style="background:rgba(85,246,255,0.16);color:#DFFBFE;padding:12px 18px;border-radius:8px 0 0 0;text-align:left;font-weight:700;">Nhóm</th>
      <th style="background:rgba(85,246,255,0.16);color:#DFFBFE;padding:12px 18px;text-align:center;font-weight:700;">Cỡ mẫu</th>
      <th style="background:rgba(85,246,255,0.16);color:#DFFBFE;padding:12px 18px;border-radius:0 8px 0 0;text-align:center;font-weight:700;">Độ lệch</th>
    </tr>
    <tr>
      <td style="color:#C9E9EC;padding:12px 18px;border-bottom:1px solid rgba(85,246,255,0.20);">Nhóm thực nghiệm</td>
      <td style="color:#C9E9EC;padding:12px 18px;border-bottom:1px solid rgba(85,246,255,0.20);text-align:center;">128</td>
      <td style="color:#55F6FF;padding:12px 18px;border-bottom:1px solid rgba(85,246,255,0.20);text-align:center;font-weight:700;">0.42</td>
    </tr>
    <tr>
      <td style="color:#C9E9EC;padding:12px 18px;">Nhóm đối chứng</td>
      <td style="color:#C9E9EC;padding:12px 18px;text-align:center;">121</td>
      <td style="color:#55F6FF;padding:12px 18px;text-align:center;font-weight:700;">0.39</td>
    </tr>
  </table>
</div>""")

sets["marketing"] = {}
sets["marketing"]["A"] = build("""<div style="height:100%;@@F@@">
  <div style="width:80px;height:6px;background:linear-gradient(90deg,#D45A73,#F08CA4);border-radius:3px;margin-bottom:28px;"></div>
  <h1 style="color:#FFFFFF;font-size:46px;font-weight:700;margin:0 0 16px 0;letter-spacing:-1px;">Chiến dịch khai trương</h1>
  <p style="color:#E8B3C0;font-size:20px;margin:0;">Nhắm 3 phân khúc trong 60 ngày đầu tiên</p>
</div>""")
sets["marketing"]["B"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#FBE0E8;font-size:28px;font-weight:700;margin:0 0 28px 0;">Kênh truyền thông chính</h2>
  <table style="border-collapse:collapse;width:100%;font-size:17px;">
    <tr>
      <td style="background:rgba(212,90,115,0.15);border:1px solid rgba(212,90,115,0.40);border-radius:10px;padding:24px;color:#E9C0CC;vertical-align:top;">
        <span style="color:#F08CA4;font-size:22px;font-weight:700;">Mạng xã hội</span><br>ngân sách 40% - tập trung video ngắn
      </td>
      <td style="background:rgba(212,90,115,0.15);border:1px solid rgba(212,90,115,0.40);border-radius:10px;padding:24px;color:#E9C0CC;vertical-align:top;">
        <span style="color:#F08CA4;font-size:22px;font-weight:700;">KOL địa phương</span><br>ngân sách 35% - 12 hợp đồng đã ký
      </td>
      <td style="background:rgba(212,90,115,0.15);border:1px solid rgba(212,90,115,0.40);border-radius:10px;padding:24px;color:#E9C0CC;vertical-align:top;">
        <span style="color:#F08CA4;font-size:22px;font-weight:700;">In-store</span><br>ngân sách 25% - hoạt động chạm và thử
      </td>
    </tr>
  </table>
</div>""")
sets["marketing"]["C"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#FBE0E8;font-size:26px;font-weight:700;margin:0 0 22px 0;">Thang đo mục tiêu 60 ngày</h2>
  <p style="color:#E9C0CC;font-size:18px;margin:0 0 10px 0;"><span style="color:#F08CA4;font-weight:700;">T1:</span>  Đạt 50.000 lượt chạm quảng cáo có quy đổi</p>
  <p style="color:#E9C0CC;font-size:18px;margin:0 0 10px 0;"><span style="color:#F08CA4;font-weight:700;">T2:</span>  Xếp hạng top 3 tìm kiếm thuộc khu vực</p>
  <p style="color:#E9C0CC;font-size:18px;margin:0;"><span style="color:#F08CA4;font-weight:700;">T3:</span>  Tỷ lệ quay lại cửa hàng trên 25%</p>
</div>""")

sets["minimal"] = {}
sets["minimal"]["A"] = build("""<div style="height:100%;@@F@@">
  <div style="width:72px;height:4px;background:#90A54F;border-radius:2px;margin-bottom:30px;"></div>
  <h1 style="color:#1C2421;font-size:46px;font-weight:700;margin:0 0 14px 0;letter-spacing:-1px;">Báo cáo tuần số 14</h1>
  <p style="color:#5B665C;font-size:20px;margin:0;">Thống kê tổng hợp - ghi chú nội bộ</p>
</div>""")
sets["minimal"]["B"] = build("""<div style="height:100%;@@F@@">
  <h2 style="color:#26302A;font-size:28px;font-weight:700;margin:0 0 26px 0;">Việc đã xong trong tuần</h2>
  <p style="color:#4C5A50;font-size:19px;margin:0 0 12px 0;"><span style="color:#90A54F;font-weight:700;">@@D@@</span>  Xuất bản dòng mới của trang chủ</p>
  <p style="color:#4C5A50;font-size:19px;margin:0 0 12px 0;"><span style="color:#90A54F;font-weight:700;">@@D@@</span>  Đóng 8 luồng tối ưu theo dữ liệu A/B</p>
  <p style="color:#4C5A50;font-size:19px;margin:0;"><span style="color:#90A54F;font-weight:700;">@@D@@</span>  Việc kế tiếp: phát hành bản lưu trữ câu hỏi</p>
</div>""", dot=True)
sets["minimal"]["C"] = build("""<div style="height:100%;@@F@@">
  <table style="border-collapse:collapse;width:100%;font-size:17px;">
    <tr>
      <th style="background:#EDF2E6;color:#333D36;padding:12px 18px;border-radius:6px 0 0 0;text-align:left;font-weight:700;">Chỉ số</th>
      <th style="background:#EDF2E6;color:#333D36;padding:12px 18px;border-radius:0 6px 0 0;text-align:center;font-weight:700;">Tuần này</th>
    </tr>
    <tr>
      <td style="color:#55605A;padding:12px 18px;border-bottom:1px solid #E3E9DA;">Lượt truy cập hợp lệ</td>
      <td style="color:#6B7C3C;padding:12px 18px;border-bottom:1px solid #E3E9DA;text-align:center;font-weight:700;">12,480</td>
    </tr>
    <tr>
      <td style="color:#55605A;padding:12px 18px;border-bottom:1px solid #E3E9DA;">Tỷ lệ chuyển đổi</td>
      <td style="color:#6B7C3C;padding:12px 18px;border-bottom:1px solid #E3E9DA;text-align:center;font-weight:700;">3.8%</td>
    </tr>
    <tr>
      <td style="color:#55605A;padding:12px 18px;">Thời gian ở lại</td>
      <td style="color:#6B7C3C;padding:12px 18px;text-align:center;font-weight:700;">04:32</td>
    </tr>
  </table>
</div>""")

BGS = {
    "business": {"A": "#0F1F33", "B": "#0F1F33", "C": "#0F1F33"},
    "creative": {"A": "#170A26", "B": "#170A26", "C": "#170A26"},
    "academic": {"A": "#0E2A2E", "B": "#0E2A2E", "C": "#0E2A2E"},
    "marketing": {"A": "#26121A", "B": "#26121A", "C": "#26121A"},
    "minimal": {"A": "#FFFFFF", "B": "#F7F9F4", "C": "#FFFFFF"},
}

if not os.path.isdir(OUT):
    os.makedirs(OUT)

total = 0
for sid, layouts in sets.items():
    for lid, body in layouts.items():
        html = tmpl(BGS[sid][lid], body)
        fn = os.path.join(OUT, "%s_%s.html" % (sid, lid))
        with io.open(fn, "w", encoding="utf-8") as f:
            f.write(html)
        total += 1
        print("written", fn)
print("TOTAL files:", total)
