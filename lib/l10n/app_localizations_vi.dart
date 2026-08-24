// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Ghita PPT Converter';

  @override
  String get homeTitle => 'Trang Chủ';

  @override
  String get editorTitle => 'Trình Soạn Thảo';

  @override
  String get projectsTitle => 'Dự Án';

  @override
  String get templatesTitle => 'Mẫu Slide';

  @override
  String get aiChatTitle => 'Chat AI';

  @override
  String get settingsTitle => 'Cài Đặt';

  @override
  String get newSlide => 'Slide Mới';

  @override
  String get duplicate => 'Nhân Bản';

  @override
  String get delete => 'Xóa';

  @override
  String get save => 'Lưu';

  @override
  String get export => 'Xuất';

  @override
  String get import => 'Nhập';

  @override
  String get undo => 'Hoàn Tác';

  @override
  String get redo => 'Làm Lại';

  @override
  String get present => 'Trình chiếu';

  @override
  String get presentFromCurrent => 'Từ Slide Hiện Tại';

  @override
  String get presentation => 'Bài Thuyết Trình';

  @override
  String get slides => 'Slides';

  @override
  String slideCount(int count) {
    return 'Slides ($count)';
  }

  @override
  String get noSlidesYet => 'Chưa có slide nào';

  @override
  String get clickToAddSlide => 'Bấm + để thêm slide mới';

  @override
  String get title => 'Tiêu Đề';

  @override
  String get content => 'Nội Dung';

  @override
  String get notes => 'Ghi Chú';

  @override
  String get addSlideTooltip => 'Thêm slide mới';

  @override
  String get deleteSlideTooltip => 'Xóa slide';

  @override
  String get duplicateSlideTooltip => 'Nhân bản slide';

  @override
  String get previewTooltip => 'Xem trước slide';

  @override
  String get editSlide => 'Sửa Slide';

  @override
  String get preview => 'Xem Trước';

  @override
  String get cancel => 'Hủy';

  @override
  String get ok => 'OK';

  @override
  String get apply => 'Áp Dụng';

  @override
  String get close => 'Đóng';

  @override
  String get yes => 'Có';

  @override
  String get no => 'Không';

  @override
  String get loading => 'Đang tải...';

  @override
  String get error => 'Lỗi';

  @override
  String get success => 'Thành Công';

  @override
  String get warning => 'Cảnh Báo';

  @override
  String get info => 'Thông Tin';

  @override
  String get connectionError => 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';

  @override
  String get timeoutError => 'Yêu cầu hết thời gian. Vui lòng thử lại.';

  @override
  String get invalidFile => 'Định dạng file không hợp lệ.';

  @override
  String get fileNotFound => 'Không tìm thấy file.';

  @override
  String get permissionDenied => 'Bị từ chối quyền truy cập.';

  @override
  String get unknownError => 'Lỗi không xác định';

  @override
  String get saveSuccess => 'Đã lưu thành công';

  @override
  String get exportSuccess => 'Đã xuất thành công';

  @override
  String get importSuccess => 'Đã nhập thành công';

  @override
  String get deleteSuccess => 'Đã xóa thành công';

  @override
  String get duplicateSuccess => 'Đã nhân bản thành công';

  @override
  String deletedWithUndo(String title) {
    return 'Đã xóa \"$title\"';
  }

  @override
  String get undoAction => 'Hoàn Tác';

  @override
  String get addNewProvider => 'Thêm Mới';

  @override
  String get details => 'Chi Tiết';

  @override
  String apiKeySaved(String name) {
    return 'Đã lưu API Key cho $name';
  }

  @override
  String get apiKeyHint => 'API Key...';

  @override
  String get saveApiKeyTooltip => 'Lưu API Key';

  @override
  String get exportBackup => 'Xuất Cấu Hình (JSON)';

  @override
  String get importBackup => 'Nhập Cấu Hình (JSON)';

  @override
  String get saveBackup => 'Lưu backup';

  @override
  String get restoreSettings => 'Khôi phục cài đặt?';

  @override
  String restoreSettingsMessage(String date, int count) {
    return 'File backup từ $date.\nSố providers: $count\n\nCài đặt hiện tại sẽ bị ghi đè. Tiếp tục?';
  }

  @override
  String get restore => 'Khôi Phục';

  @override
  String backupExported(String filename) {
    return 'Đã xuất backup thành công: $filename';
  }

  @override
  String get settingsRestored => 'Đã khôi phục cài đặt thành công!';

  @override
  String get about => 'Thông Tin';

  @override
  String get appearance => 'Giao Diện';

  @override
  String get interfaceMode => 'Chế Độ Giao Diện';

  @override
  String currentMode(String mode) {
    return 'Hiện tại: $mode';
  }

  @override
  String get lightMode => 'Sáng';

  @override
  String get darkMode => 'Tối';

  @override
  String get autoMode => 'Auto';

  @override
  String get lightModeFull => 'Sáng (Light)';

  @override
  String get darkModeFull => 'Tối (Dark)';

  @override
  String get systemMode => 'Hệ Thống (Auto)';

  @override
  String get themeSettings => 'Cài Đặt Theme';

  @override
  String get customTheme => 'Tùy Chỉnh Theme';

  @override
  String get customThemeSubtitle => 'Màu sắc, font chữ, preset themes';

  @override
  String get presetThemes => 'Preset Themes';

  @override
  String get customColors => 'Màu Tùy Chỉnh';

  @override
  String get primaryColor => 'Màu Chính';

  @override
  String get accentColor => 'Màu Phụ';

  @override
  String get typography => 'Phông Chữ';

  @override
  String get fontFamily => 'Font Chữ';

  @override
  String get exportTheme => 'Xuất theme';

  @override
  String get importTheme => 'Nhập theme';

  @override
  String get resetToDefault => 'Khôi phục mặc định';

  @override
  String get themeResetMessage => 'Đã khôi phục theme về Office Blue';

  @override
  String themeAppliedMessage(String name) {
    return 'Đã áp dụng preset $name';
  }

  @override
  String get themeCopied => 'Đã sao chép theme vào clipboard!';

  @override
  String get themeImported => 'Đã nhập theme thành công!';

  @override
  String get themeImportFailed =>
      'Không thể nhập theme. Định dạng không hợp lệ.';

  @override
  String get clipboardEmpty => 'Clipboard trống';

  @override
  String get pickColor => 'Chọn màu';

  @override
  String get pickColorTooltip => 'Chọn màu';

  @override
  String get officeBlue => 'Office Blue';

  @override
  String get officeBlueDesc => 'Microsoft Office cổ điển';

  @override
  String get darkProfessional => 'Dark Professional';

  @override
  String get darkProfessionalDesc => 'Theme tối thanh lịch';

  @override
  String get lightMinimal => 'Light Minimal';

  @override
  String get lightMinimalDesc => 'Sạch sẽ và tối giản';

  @override
  String get custom => 'Tùy Chỉnh';

  @override
  String get customDesc => 'Theme của bạn';

  @override
  String get version => 'Phiên Bản';

  @override
  String versionInfo(String version, String year) {
    return '$version • Build $year';
  }

  @override
  String get language => 'Ngôn Ngữ';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get aiProvider => 'API Key & AI Provider';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get infoSection => 'Thông Tin';

  @override
  String get addNew => 'Thêm mới';

  @override
  String get recentProjects => 'Dự Án Gần Đây';

  @override
  String get noRecentProjects => 'Chưa có dự án nào';

  @override
  String get openProject => 'Mở Dự Án';

  @override
  String get removeFromList => 'Xóa khỏi danh sách';

  @override
  String get removeAll => 'Xóa Tất Cả';

  @override
  String get confirmRemoveAll => 'Xóa tất cả dự án gần đây?';

  @override
  String get search => 'Tìm Kiếm';

  @override
  String get templates => 'Mẫu Slide';

  @override
  String get noTemplates => 'Chưa có mẫu slide';

  @override
  String get useTemplate => 'Dùng Mẫu Này';

  @override
  String get aiChat => 'Chat AI';

  @override
  String get typeMessage => 'Nhập tin nhắn của bạn...';

  @override
  String get send => 'Gửi';

  @override
  String get regenerate => 'Tạo Lại';

  @override
  String get stop => 'Dừng';

  @override
  String get clearChat => 'Xóa Chat';

  @override
  String get clearChatConfirm => 'Xóa lịch sử chat?';

  @override
  String get selectProvider => 'Chọn AI Provider';

  @override
  String get noProviders => 'Chưa cấu hình AI provider nào';

  @override
  String get addProviderFirst => 'Thêm provider trong Cài đặt trước';

  @override
  String get copy => 'Sao Chép';

  @override
  String get paste => 'Dán';

  @override
  String get cut => 'Cắt';

  @override
  String get selectAll => 'Chọn Tất Cả';

  @override
  String get bold => 'In Đậm';

  @override
  String get italic => 'In Nghiêng';

  @override
  String get underline => 'Gạch Chân';

  @override
  String get strikethrough => 'Gạch Ngang';

  @override
  String get alignLeft => 'Căn Trái';

  @override
  String get alignCenter => 'Căn Giữa';

  @override
  String get alignRight => 'Căn Phải';

  @override
  String get alignJustify => 'Căn Đều';

  @override
  String get bulletList => 'Danh Sách Dấu Đầu Dòng';

  @override
  String get numberedList => 'Danh Sách Đánh Số';

  @override
  String get indent => 'Thụt Lề Vào';

  @override
  String get outdent => 'Thụt Lề Ra';

  @override
  String get link => 'Liên Kết';

  @override
  String get image => 'Hình Ảnh';

  @override
  String get table => 'Bảng';

  @override
  String get code => 'Code';

  @override
  String get format => 'Định Dạng';

  @override
  String get help => 'Trợ Giúp';

  @override
  String get shortcuts => 'Phím Tắt';

  @override
  String get exitPresentation => 'Thoát Trình Chiếu';

  @override
  String get nextSlide => 'Slide Tiếp Theo';

  @override
  String get previousSlide => 'Slide Trước';

  @override
  String get firstSlide => 'Slide Đầu Tiên';

  @override
  String get lastSlide => 'Slide Cuối Cùng';

  @override
  String get aiTools => 'Công Cụ AI';

  @override
  String get improveWriting => 'Cải Thiện Văn Phong';

  @override
  String get fixGrammar => 'Sửa Ngữ Pháp';

  @override
  String get makeShorter => 'Rút Gọn';

  @override
  String get makeLonger => 'Mở Rộng';

  @override
  String translateTo(String language) {
    return 'Dịch sang $language';
  }

  @override
  String get summary => 'Tóm Tắt';

  @override
  String get generateSlides => 'Tạo Slides';

  @override
  String get fromText => 'Từ Văn Bản';

  @override
  String get fromTopic => 'Từ Chủ Đề';

  @override
  String get topic => 'Chủ Đề';

  @override
  String get slideCountQuestion => 'Bao nhiêu slide?';

  @override
  String get style => 'Phong Cách';

  @override
  String get professional => 'Chuyên Nghiệp';

  @override
  String get casual => 'Thân Mật';

  @override
  String get academic => 'Học Thuật';

  @override
  String get creative => 'Sáng Tạo';

  @override
  String get files => 'Tệp';

  @override
  String get addFiles => 'Thêm Tệp';

  @override
  String get noFiles => 'Chưa có tệp nào';

  @override
  String get fileName => 'Tên Tệp';

  @override
  String get fileSize => 'Kích Thước';

  @override
  String get fileType => 'Loại';

  @override
  String get uploadedAt => 'Đã Tải Lên';

  @override
  String get collaboration => 'Cộng Tác';

  @override
  String get startSession => 'Bắt Đầu Phiên';

  @override
  String get joinSession => 'Tham Gia Phiên';

  @override
  String get sessionCode => 'Mã Phiên';

  @override
  String get host => 'Máy Chủ';

  @override
  String get join => 'Tham Gia';

  @override
  String get leave => 'Rời Khỏi';

  @override
  String get audio => 'Âm Thanh';

  @override
  String get startRecording => 'Bắt Đầu Ghi';

  @override
  String get stopRecording => 'Dừng Ghi';

  @override
  String get playRecording => 'Phát Bản Ghi';

  @override
  String get deleteRecording => 'Xóa Bản Ghi';

  @override
  String get audioRecorded => 'Đã ghi âm';

  @override
  String get recordings => 'Bản Ghi';

  @override
  String get noRecordings => 'Chưa có bản ghi nào';

  @override
  String get advancedExport => 'Xuất nâng cao';

  @override
  String get exportFormat => 'Định dạng xuất';

  @override
  String get aspectRatio => 'Tỷ lệ khung hình';

  @override
  String get quality => 'Chất lượng';

  @override
  String get exportOptions => 'Tùy chọn';

  @override
  String get includeSpeakerNotes => 'Kèm ghi chú người thuyết trình';

  @override
  String get includeBackgrounds => 'Kèm nền slide';

  @override
  String get slidesToExport => 'Slide cần xuất';

  @override
  String get allSlides => 'Tất cả slide';

  @override
  String selectedSlides(int count) {
    return 'Đã chọn ($count)';
  }

  @override
  String get exporting => 'Đang xuất...';

  @override
  String exportSuccessful(String summary) {
    return 'Xuất thành công: $summary';
  }

  @override
  String exportFailed(String error) {
    return 'Xuất thất bại: $error';
  }

  @override
  String get chooseAtLeastOneSlide =>
      'Hãy chọn ít nhất một slide hoặc chọn \"Tất cả slide\".';

  @override
  String get chooseTemplate => 'Chọn mẫu';

  @override
  String get htmlPreview => 'Xem trước HTML:';

  @override
  String get useThisTemplate => 'Dùng mẫu này';

  @override
  String get clearAllSlides => 'Xóa toàn bộ slide';

  @override
  String clearAllSlidesMessage(int count) {
    return 'Bạn có chắc muốn xóa toàn bộ $count slide? Thao tác này không thể hoàn tác.';
  }

  @override
  String get deletedAllSlides => 'Đã xóa toàn bộ slide';

  @override
  String get untitledPresentation => 'Bài thuyết trình chưa có tên';

  @override
  String get hideSidebar => 'Ẩn thanh bên';

  @override
  String get showSidebar => 'Hiện thanh bên';

  @override
  String get toggleTheme => 'Đổi giao diện';

  @override
  String get slideEditor => 'Trình soạn slide';

  @override
  String get navigation => 'Điều hướng';

  @override
  String get system => 'Hệ thống';

  @override
  String get noSlides => 'Chưa có slide để trình chiếu.';

  @override
  String get startCollaboration => 'Bắt đầu cộng tác';

  @override
  String get stopCollaboration => 'Dừng cộng tác';

  @override
  String get leaveCollaboration => 'Rời phiên';

  @override
  String get hostCollaboration => 'Tạo phiên cộng tác';

  @override
  String get hostCollaborationDescription =>
      'Chia sẻ bài thuyết trình hiện tại với người tin cậy trong cùng mạng nội bộ.';

  @override
  String get joinCollaboration => 'Tham gia phiên';

  @override
  String get hostOrShareLink => 'IP máy chủ hoặc liên kết chia sẻ';

  @override
  String get port => 'Cổng';

  @override
  String get displayName => 'Tên hiển thị';

  @override
  String get sessionToken => 'Mã bảo mật phiên';

  @override
  String get connect => 'Kết nối';

  @override
  String get collaborationHosting => 'Đang mở phiên được bảo vệ';

  @override
  String get collaborationConnected => 'Đã kết nối và đang đồng bộ';

  @override
  String collaborationRevision(int revision) {
    return 'Bản sửa đổi $revision';
  }

  @override
  String collaborationParticipants(int count) {
    return 'Người tham gia: $count';
  }

  @override
  String get collaborationSecurityNotice =>
      'Chỉ chia sẻ liên kết hoặc mã phiên với người tin cậy trong mạng nội bộ.';

  @override
  String get collaborationStartFailed =>
      'Không thể mở máy chủ nội bộ được bảo vệ. Hãy kiểm tra cổng và tường lửa.';

  @override
  String get collaborationJoinFields =>
      'Hãy nhập máy chủ/liên kết chia sẻ và mã bảo mật phiên.';

  @override
  String get collaborationJoinFailed =>
      'Không thể xác thực hoặc kết nối với phiên này.';

  @override
  String get collaborationJoined => 'Đã kết nối. Các slide đang được đồng bộ.';

  @override
  String get collaborationLinkCopied =>
      'Đã sao chép liên kết chia sẻ được bảo vệ.';

  @override
  String get collaborationConflict =>
      'Phát hiện bản mới hơn. Đã khôi phục phiên bản chính thức từ máy chủ.';

  @override
  String get collaborationAuthFailed => 'Mã cộng tác không còn hợp lệ.';

  @override
  String slideListSemantics(int count) {
    return 'Danh sách slide, $count slide';
  }

  @override
  String slideSemanticLabel(int number, String title) {
    return 'Slide $number: $title';
  }

  @override
  String get slideSemanticHint =>
      'Kích hoạt để chỉnh sửa. Nhấn giữ để xem thêm thao tác.';

  @override
  String get workspaceSemantics =>
      'Không gian làm việc bài thuyết trình GhitaPPT';

  @override
  String exportProgress(int done, int total) {
    return 'Đang xuất… $done/$total';
  }

  @override
  String get exportCancel => 'Hủy xuất';

  @override
  String get exportCancelDescription =>
      'Dừng quá trình xuất đang chạy và bỏ kết quả của nó.';

  @override
  String get fitContent => 'Vừa khít với slide';

  @override
  String get fitContentDescription =>
      'Thu nhỏ chữ khi tràn để nội dung vừa với slide.';

  @override
  String get loadingRemoteImages => 'Đang tải ảnh từ web…';

  @override
  String remoteImageLoadFailed(String name) {
    return 'Không tải được ảnh $name';
  }

  @override
  String get exportThemePreview => 'File xuất sẽ dùng theme này';

  @override
  String get exportThemePreviewDescription =>
      'Hiển thị clrScheme và font sẽ được ghi vào file PPTX xuất ra.';

  @override
  String get layout => 'Bố cục';

  @override
  String get layoutBlank => 'Trống';

  @override
  String get layoutTitleSlide => 'Slide tiêu đề';

  @override
  String get layoutTitleAndContent => 'Tiêu đề và Nội dung';

  @override
  String get layoutSectionHeader => 'Đầu mục';

  @override
  String get layoutTwoContent => 'Hai cột nội dung';

  @override
  String get layoutComparison => 'So sánh';

  @override
  String get layoutTitleOnly => 'Chỉ tiêu đề';

  @override
  String get layoutContentAndCaption => 'Nội dung và Chú thích';

  @override
  String get layoutPictureAndCaption => 'Ảnh và Chú thích';

  @override
  String layoutApplied(String name) {
    return 'Đã áp dụng bố cục: $name';
  }

  @override
  String get pdfPaperSize => 'Khổ giấy PDF';

  @override
  String get pdfPaperMatchSlide => 'Khớp slide';

  @override
  String get pdfPaperA4 => 'A4';

  @override
  String get pdfPaperLetter => 'Letter';

  @override
  String get pdfMargins => 'Lề trang';

  @override
  String get pdfMarginCompact => 'Nhỏ';

  @override
  String get pdfMarginStandard => 'Tiêu chuẩn';

  @override
  String get pdfMarginWide => 'Rộng';

  @override
  String get pdfScaleToFit => 'Vừa khít trang';

  @override
  String get includeHiddenSlides => 'In cả slide ẩn';

  @override
  String get insertChart => 'Chèn biểu đồ';

  @override
  String get editChart => 'Chỉnh sửa biểu đồ';

  @override
  String get chartTitle => 'Tiêu đề biểu đồ';

  @override
  String get chartCategories => 'Nhãn (phân cách dấu phẩy)';

  @override
  String get chartSeriesName => 'Tên chuỗi';

  @override
  String get chartSeriesValues => 'Giá trị (phân cách dấu phẩy)';

  @override
  String get chartLegend => 'Chú giải';

  @override
  String get chartDataLabels => 'Nhãn dữ liệu';

  @override
  String get chartStacked => 'Chồng cột';

  @override
  String get chartExisting => 'Biểu đồ trong slide này';

  @override
  String get chartPreview => 'Xem trước';

  @override
  String get chartInserted => 'Đã chèn biểu đồ';

  @override
  String get chartUpdated => 'Đã cập nhật biểu đồ';

  @override
  String get chartAddSeries => 'Thêm chuỗi';

  @override
  String get chartUpdate => 'Cập nhật biểu đồ';

  @override
  String get chartColumn => 'Cột';

  @override
  String get chartBar => 'Thanh ngang';

  @override
  String get chartLine => 'Đường';

  @override
  String get chartPie => 'Tròn';

  @override
  String get chartArea => 'Vùng';

  @override
  String get chartDonut => 'Vành khuyên';

  @override
  String get chartCombo => 'Kết hợp';

  @override
  String get chartTreemap => 'Bản đồ cây';

  @override
  String get chartSunburst => 'Mặt trời';

  @override
  String get chartHistogram => 'Tần suất';

  @override
  String get chartBoxWhisker => 'Hộp & Râu';

  @override
  String get chartWaterfall => 'Thác nước';

  @override
  String get chartFunnel => 'Phễu';

  @override
  String get chartMap => 'Bản đồ';

  @override
  String get chartData => 'Dữ liệu biểu đồ';

  @override
  String get gridAddRow => 'Thêm dòng';

  @override
  String get gridRemoveRow => 'Xóa dòng';

  @override
  String get gridAddSeries => 'Thêm chuỗi';

  @override
  String get gridRemoveSeries => 'Xóa chuỗi';

  @override
  String get gridQuickFill => 'Điền nhanh';

  @override
  String get gridPasteCsv => 'Dán CSV';

  @override
  String get insertSmartArt => 'Chèn SmartArt';

  @override
  String get editSmartArt => 'Chỉnh sửa SmartArt';

  @override
  String get smartartTitle => 'Tiêu đề sơ đồ';

  @override
  String get smartartLayouts => 'Bố cục';

  @override
  String get smartartNodes => 'Ngăn văn bản';

  @override
  String get smartartNode => 'Mục';

  @override
  String get smartartAddNode => 'Thêm mục';

  @override
  String get smartartRemoveNode => 'Xóa mục';

  @override
  String get smartartColorTheme => 'Chủ đề màu';

  @override
  String get smartartExisting => 'SmartArt trong slide này';

  @override
  String get smartartInserted => 'Đã chèn SmartArt';

  @override
  String get smartartUpdated => 'Đã cập nhật SmartArt';

  @override
  String get smartartGroupList => 'Danh sách';

  @override
  String get smartartGroupProcess => 'Quy trình';

  @override
  String get smartartGroupCycle => 'Vòng lặp';

  @override
  String get smartartGroupHierarchy => 'Phân cấp';

  @override
  String get smartartGroupRelationship => 'Quan hệ';

  @override
  String get smartartGroupMatrix => 'Ma trận';

  @override
  String get smartartGroupPyramid => 'Kim tự tháp';

  @override
  String get smartartGroupPicture => 'Hình ảnh';

  @override
  String get insertVideo => 'Chèn video';

  @override
  String get editVideo => 'Sửa video';

  @override
  String get videoInserted => 'Đã chèn video';

  @override
  String get videoUpdated => 'Đã cập nhật video';

  @override
  String get videoExisting => 'Video trong slide';

  @override
  String get videoFromFile => 'Tệp MP4';

  @override
  String get videoFromYoutube => 'Link YouTube';

  @override
  String get videoPickFile => 'Chọn tệp MP4…';

  @override
  String get videoYoutubeUrl => 'URL YouTube';

  @override
  String get videoInvalidUrl => 'Đây không phải link YouTube hợp lệ';

  @override
  String get videoTrimStart => 'Bắt đầu (p:giây)';

  @override
  String get videoTrimEnd => 'Kết thúc (p:giây)';

  @override
  String get videoNoFfmpeg =>
      'Không tìm thấy FFmpeg — mốc cắt chỉ áp dụng cho trình phát HTML';

  @override
  String get videoAutoplay => 'Tự phát khi chiếu';

  @override
  String get videoLoop => 'Lặp lại';

  @override
  String get videoPoster => 'Ảnh poster';

  @override
  String get videoChoosePoster => 'Chọn ảnh poster…';

  @override
  String get videoChangePoster => 'Đổi ảnh poster…';

  @override
  String get videoRemovePoster => 'Bỏ poster';

  @override
  String get videoBookmarks => 'Đánh dấu';

  @override
  String get videoAddBookmark => 'Thêm đánh dấu';

  @override
  String get videoRemoveBookmark => 'Xóa đánh dấu';

  @override
  String get videoBookmarkLabel => 'Nhãn';

  @override
  String get videoBookmarkTime => 'Thời điểm (p:giây)';

  @override
  String get recordScreen => 'Quay màn hình';

  @override
  String get recordInserted => 'Đã chèn bản quay';

  @override
  String get recordModeFullscreen => 'Toàn màn hình';

  @override
  String get recordModeWindow => 'Cửa sổ';

  @override
  String get recordModeRegion => 'Vùng tùy chỉnh';

  @override
  String get recordWindowSelect => 'Cửa sổ';

  @override
  String get recordWindowEmpty =>
      'Không thấy cửa sổ nào — hãy mở/khôi phục một cửa sổ rồi thử lại.';

  @override
  String get recordWindowRequired => 'Hãy chọn cửa sổ cần quay.';

  @override
  String get recordRegionX => 'X';

  @override
  String get recordRegionY => 'Y';

  @override
  String get recordRegionW => 'Rộng';

  @override
  String get recordRegionH => 'Cao';

  @override
  String get recordRegionRequired =>
      'Nhập chiều rộng và chiều cao vùng lớn hơn 0.';

  @override
  String get recordRegionHint =>
      'Tọa độ tính bằng pixel màn hình (gốc trên-trái).';

  @override
  String get recordStart => 'Bắt đầu quay';

  @override
  String get recordCountdown => 'Bắt đầu quay sau…';

  @override
  String get recordRecording => 'đang quay';

  @override
  String get recordPaused => 'tạm dừng';

  @override
  String get recordPause => 'Tạm dừng';

  @override
  String get recordResume => 'Tiếp tục';

  @override
  String get recordStop => 'Dừng';

  @override
  String get recordDuration => 'Thời lượng';

  @override
  String get recordSize => 'Dung lượng';

  @override
  String get recordLimit => 'Giới hạn';

  @override
  String get recordMinutes => 'phút';

  @override
  String get recordPreviewHint =>
      'Xem trước khung hình poster — chèn bản quay này vào slide.';

  @override
  String get recordInsert => 'Chèn vào slide';

  @override
  String get recordDiscard => 'Hủy bỏ';

  @override
  String get recordNoFfmpeg =>
      'Quay màn hình cần FFmpeg trên máy. Hãy cài FFmpeg (ffmpeg.org) và thêm vào PATH, sau đó khởi động lại ứng dụng.';

  @override
  String get recordFailed => 'Quay thất bại — vui lòng thử lại.';

  @override
  String get recordDiskLowTitle => 'Đĩa sắp đầy';

  @override
  String get recordDiskLowBody =>
      'Ổ đĩa còn dưới 500 MB trống. Quá trình quay có thể dừng bất ngờ.';

  @override
  String get recordContinue => 'Vẫn quay';

  @override
  String get recordMaxDurationReached =>
      'Đã đạt giới hạn thời lượng — tự dừng.';

  @override
  String get recordMaxSizeReached => 'Đã đạt giới hạn dung lượng — tự dừng.';

  @override
  String get audioRecordNarration => 'Ghi lời thuyết minh cho slide này';

  @override
  String get audioNoNarration => 'Chưa có lời thuyết minh';

  @override
  String get audioDuration => 'Thời lượng';

  @override
  String get audioTrimApply => 'Cắt';

  @override
  String get audioTrimNoFfmpeg =>
      'Không tìm thấy FFmpeg — mốc cắt chỉ áp dụng cho trình phát HTML';

  @override
  String get audioAutoplay => 'Tự phát';

  @override
  String get audioLoop => 'Lặp lại';

  @override
  String get audioAcrossSlides => 'Phát xuyên slide';

  @override
  String get audioHideIcon => 'Ẩn icon';

  @override
  String get audioRemove => 'Xóa lời thuyết minh';

  @override
  String get insertModel3d => 'Chèn mô hình 3D';

  @override
  String get editModel3d => 'Sửa mô hình 3D';

  @override
  String get model3dInserted => 'Đã chèn mô hình 3D';

  @override
  String get model3dUpdated => 'Đã cập nhật mô hình 3D';

  @override
  String get model3dExisting => 'Mô hình 3D trong slide';

  @override
  String get model3dPickFile => 'Chọn tệp GLB…';

  @override
  String get model3dInvalidFile =>
      'Đây không phải tệp GLB (glTF binary) hợp lệ';

  @override
  String get model3dName => 'Tên mô hình';

  @override
  String get model3dRotate => 'Tự xoay khi mở slide';

  @override
  String get model3dRotateHint =>
      'Phát animation nhúng đầu tiên của mô hình (cần GLB có animation)';

  @override
  String get insertIcon => 'Chèn biểu tượng';

  @override
  String get iconSearch => 'Tìm biểu tượng...';

  @override
  String get iconRecent => 'Gần đây';

  @override
  String get iconColor => 'Màu';

  @override
  String get iconNoResults => 'Không có biểu tượng phù hợp';

  @override
  String get iconInserted => 'Đã chèn biểu tượng';

  @override
  String get insertStockMedia => 'Ảnh kho';

  @override
  String get mediaSearch => 'Tìm ảnh...';

  @override
  String get mediaNoResults => 'Không có ảnh phù hợp';

  @override
  String get mediaInserted => 'Đã chèn ảnh';

  @override
  String get screenshot => 'Chụp màn hình';

  @override
  String get screenshotFullscreen => 'Toàn màn hình';

  @override
  String get screenshotWindow => 'Cửa sổ';

  @override
  String get screenshotRegion => 'Vùng chọn';

  @override
  String get screenshotRegionHint =>
      'Tọa độ tính theo pixel màn hình (gốc trên-trái).';

  @override
  String get screenshotCapture => 'Chụp';

  @override
  String get screenshotRecapture => 'Chụp lại';

  @override
  String get screenshotFailed =>
      'Chụp thất bại. Kiểm tra màn hình đang hoạt động rồi thử lại.';

  @override
  String get screenshotUse => 'Dùng ảnh chụp';

  @override
  String get screenshotInserted => 'Đã chèn ảnh chụp màn hình';

  @override
  String get screenshotCropHint => 'Bạn có thể cắt ảnh ở bước tiếp theo.';

  @override
  String get photoAlbum => 'Album ảnh';

  @override
  String get photoAlbumEmpty => 'Chọn ảnh để tạo slide album ảnh.';

  @override
  String get photoAlbumPick => 'Chọn ảnh...';

  @override
  String get photoAlbumCount => 'ảnh';

  @override
  String get photoAlbumCaption => 'Chú thích';

  @override
  String get photoAlbumFrame => 'Khung viền';

  @override
  String get photoAlbumTransition => 'Chuyển tiếp';

  @override
  String get photoAlbumCreate => 'Tạo slide';

  @override
  String photoAlbumCreated(Object count) {
    return 'Đã tạo $count slide từ ảnh';
  }

  @override
  String get freeTextAdd => 'Thêm hộp văn bản';

  @override
  String get freeTextEdit => 'Sửa hộp văn bản';

  @override
  String get freeTextContent => 'Nội dung văn bản';

  @override
  String get freeTextFontSize => 'Cỡ chữ';

  @override
  String get freeTextColor => 'Màu chữ';

  @override
  String get freeTextBg => 'Nền';

  @override
  String get freeTextBorder => 'Viền';

  @override
  String get freeTextShadow => 'Đổ bóng';

  @override
  String get freeTextWordArt => 'Kiểu WordArt';

  @override
  String get freeTextAdded => 'Đã thêm hộp văn bản';

  @override
  String get actionButton => 'Nút hành động';

  @override
  String get actionButtonKind => 'Loại nút';

  @override
  String get actionButtonAction => 'Hành động';

  @override
  String get actionButtonLabel => 'Nhãn';

  @override
  String get actionButtonUrl => 'URL';

  @override
  String get actionButtonColor => 'Màu';

  @override
  String get actionButtonInsert => 'Chèn nút';

  @override
  String get actionButtonInserted => 'Đã chèn nút hành động';

  @override
  String get equation => 'Công thức';

  @override
  String get equationTemplate => 'Mẫu';

  @override
  String get equationCustom => 'MathML tùy chỉnh';

  @override
  String get equationInsert => 'Chèn công thức';

  @override
  String get equationInserted => 'Đã chèn công thức';

  @override
  String get symbol => 'Ký hiệu';

  @override
  String get symbolSearch => 'Tìm ký hiệu';

  @override
  String get symbolNoResults => 'Không có ký hiệu phù hợp';

  @override
  String get symbolInserted => 'Đã chèn ký hiệu';

  @override
  String get ole => 'Đối tượng OLE';

  @override
  String get olePickFile => 'Chọn tệp... (xlsx, docx, pdf, pptx)';

  @override
  String get olePickHint =>
      'Nhúng bảng tính, tài liệu hoặc PDF vào slide. Double-click trong PowerPoint để mở.';

  @override
  String get oleLabel => 'Nhãn biểu tượng';

  @override
  String get oleInsert => 'Nhúng';

  @override
  String get oleInserted => 'Đã nhúng đối tượng OLE';

  @override
  String get headerFooter => 'Đầu trang & Chân trang';

  @override
  String get hfHeader => 'Đầu trang';

  @override
  String get hfFooter => 'Chân trang';

  @override
  String get hfSlideNumber => 'Số trang';

  @override
  String get hfDateTime => 'Ngày & giờ';

  @override
  String get hfDateTimeAuto => 'Cập nhật tự động (động)';

  @override
  String get hfDateTimeFormat => 'Định dạng ngày';

  @override
  String get hfExcludeFirst => 'Không hiện trên slide bìa';

  @override
  String get hfApplyToSlide => 'Áp cho slide này';

  @override
  String get hfApplyToAll => 'Áp cho tất cả';

  @override
  String get hfApplied => 'Đã cập nhật đầu trang & chân trang';

  @override
  String get zoom => 'Thu phóng';

  @override
  String get zoomTargetSlide => 'Slide đích';

  @override
  String get zoomFrameStyle => 'Kiểu khung';

  @override
  String get zoomLabel => 'Nhãn';

  @override
  String get zoomLabelHint => 'Nhãn tùy chọn';

  @override
  String get zoomInsert => 'Chèn zoom';

  @override
  String get zoomInserted => 'Đã chèn zoom slide';

  @override
  String get cameo => 'Cameo';

  @override
  String get cameoLabel => 'Nhãn camera';

  @override
  String get cameoInsert => 'Chèn cameo';

  @override
  String get cameoInserted => 'Đã chèn cameo';

  @override
  String get shape => 'Hình dạng';

  @override
  String get shapeInserted => 'Đã chèn hình dạng';

  @override
  String get shapeType => 'Loại';

  @override
  String get shapeFillColor => 'Màu nền';

  @override
  String get shapeStrokeColor => 'Màu viền';

  @override
  String get shapeStrokeWidth => 'Độ dày viền';

  @override
  String get shapeInsert => 'Chèn hình';

  @override
  String get shapeEditPoints => 'Chỉnh điểm';

  @override
  String get shapeAddPoint => 'Thêm điểm';

  @override
  String get shapeDeletePoint => 'Xóa điểm';

  @override
  String get shapePoint => 'Điểm';

  @override
  String get shapeProperties => 'Thuộc tính hình';

  @override
  String get shapePropertiesUpdated => 'Đã cập nhật thuộc tính hình';

  @override
  String get shapeNoSelection => 'Chưa chọn hình';

  @override
  String get shapeTransparency => 'Trong suốt';

  @override
  String get shapeShadow => 'Đổ bóng';

  @override
  String get shapeGradient => 'Tô chuyển sắc';

  @override
  String get shapeGradientStart => 'Màu đầu gradient';

  @override
  String get shapeGradientEnd => 'Màu cuối gradient';

  @override
  String get shapeGradientAngle => 'Góc gradient';

  @override
  String get shapeMerge => 'Ghép hình dạng';

  @override
  String get shapeMergeNeedTwo => 'Cần ít nhất hai hình để ghép';

  @override
  String get shapeMergeHint =>
      'Chọn hai hình (bấm, Shift+bấm để chọn nhiều), rồi chọn phép toán boolean:';

  @override
  String get shapeMergeUnion => 'Hợp (Union)';

  @override
  String get shapeMergeCombine => 'Kết hợp (XOR)';

  @override
  String get shapeMergeIntersect => 'Giao (Intersect)';

  @override
  String get shapeMergeSubtract => 'Trừ (Subtract)';

  @override
  String get shapeMergeEmpty => 'Phép ghép cho kết quả rỗng';

  @override
  String get shapeMerged => 'Đã ghép hình dạng';

  @override
  String get shapeScribble => 'Vẽ tự do';

  @override
  String get zoomSlide => 'Zoom Slide';

  @override
  String get zoomSection => 'Zoom Mục / Tổng hợp';

  @override
  String get zoomPickSlides => 'Chọn các slide đưa vào lưới (tối thiểu 2):';

  @override
  String get zoomColumns => 'Số cột:';

  @override
  String get imageTabBasic => 'Cơ bản';

  @override
  String get imageTabCrop => 'Cắt';

  @override
  String get imageTabBackground => 'Xóa nền';

  @override
  String get imageTabAdjust => 'Hiệu chỉnh';

  @override
  String get imageTabArtistic => 'Nghệ thuật';

  @override
  String get imageCropAspect => 'Tỷ lệ khóa';

  @override
  String get imageAspectNone => 'Tự do';

  @override
  String get imageAspectSquare => '1:1';

  @override
  String get imageAspect169 => '16:9';

  @override
  String get imageAspect32 => '3:2';

  @override
  String get imageAspect43 => '4:3';

  @override
  String get imageCropApply => 'Áp dụng cắt';

  @override
  String get imageCropShape => 'Cắt theo hình';

  @override
  String get imageShapeRect => 'Hình chữ nhật';

  @override
  String get imageShapeOval => 'Hình bầu dục';

  @override
  String get imageShapeRounded => 'Bo góc';

  @override
  String get imageShapeTriangle => 'Tam giác';

  @override
  String get imageShapeDiamond => 'Hình thoi';

  @override
  String get imageShapeHeart => 'Trái tim';

  @override
  String get imageRemoveBg => 'Xóa nền';

  @override
  String get imageBgHint =>
      'Thuật toán flood-fill loại màu quanh điểm gốc. Chọn vị trí điểm gốc và độ dung sai rồi áp dụng.';

  @override
  String get imageTolerance => 'Dung sai';

  @override
  String get imageSeedX => 'Điểm gốc X (%)';

  @override
  String get imageSeedY => 'Điểm gốc Y (%)';

  @override
  String get imageBrush => 'Chổi (tinh chỉnh)';

  @override
  String get imageBrushSize => 'Kích thước chổi';

  @override
  String get imageErase => 'Xóa';

  @override
  String get imageRestore => 'Khôi phục';

  @override
  String get imageBrushHint =>
      'Dùng nút Xóa/Khôi phục với kích thước chổi đã chọn.';

  @override
  String get imageSaturation => 'Bão hòa';

  @override
  String get imageTone => 'Nhiệt độ';

  @override
  String get imageSharpness => 'Sắc nét';

  @override
  String get imageDuotoneA => 'Màu A';

  @override
  String get imageDuotoneB => 'Màu B';

  @override
  String get imageEffect => 'Hiệu ứng nghệ thuật';

  @override
  String get imageIntensity => 'Cường độ';

  @override
  String get imageEffectBlur => 'Mờ (Blur)';

  @override
  String get imageEffectMosaic => 'Khảm';

  @override
  String get imageEffectPencil => 'Bút chì';

  @override
  String get imageEffectOil => 'Sơn dầu';

  @override
  String get imageEffectFilm => 'Phim cũ';

  @override
  String get imagePreset => 'Preset nhanh';

  @override
  String get imagePresetBw => 'Đen trắng';

  @override
  String get imagePresetVintage => 'Vintage';

  @override
  String get imagePresetCool => 'Mát';

  @override
  String get imagePresetWarm => 'Ấm';

  @override
  String get imagePresetSoft => 'Mềm';

  @override
  String get imagePresetVivid => 'Rực rỡ';

  @override
  String get imageApply => 'Áp dụng';

  @override
  String get imageEditTitle => 'Chỉnh sửa ảnh';

  @override
  String get imageCancel => 'Hủy';

  @override
  String get imageUse => 'Sử dụng ảnh này';

  @override
  String get imageSize => 'Kích thước';

  @override
  String get imageRotate => 'Xoay';

  @override
  String get imageFlip => 'Lật';

  @override
  String get imageFlipH => 'Ngang';

  @override
  String get imageFlipV => 'Dọc';

  @override
  String get imageBrightness => 'Độ sáng';

  @override
  String get imageContrast => 'Tương phản';

  @override
  String get imageCropX => 'Cắt X';

  @override
  String get imageCropY => 'Cắt Y';

  @override
  String get imageCropW => 'Chiều rộng cắt';

  @override
  String get imageCropH => 'Chiều cao cắt';

  @override
  String get imageRadius => 'Bán kính bo góc';

  @override
  String get fxTitle => 'Hiệu ứng';

  @override
  String get fxShadow => 'Đổ bóng';

  @override
  String get fxShadowOffsetX => 'Lệch X';

  @override
  String get fxShadowOffsetY => 'Lệch Y';

  @override
  String get fxShadowBlur => 'Mờ';

  @override
  String get fxShadowAlpha => 'Độ đậm';

  @override
  String get fxShadowColor => 'Màu bóng';

  @override
  String get fxGlow => 'Phát sáng';

  @override
  String get fxGlowColor => 'Màu sáng';

  @override
  String get fxGlowSize => 'Độ rộng sáng';

  @override
  String get fxSoftEdge => 'Viền mềm';

  @override
  String get fxBevel => 'Bevel / 3D';

  @override
  String get fxRot3d => 'Xoay 3D (X/Y/Z)';

  @override
  String get fxPresets => 'Preset nhanh';

  @override
  String get fxPresetNone => 'Không hiệu ứng';

  @override
  String get fxPresetSoft => 'Mềm';

  @override
  String get fxPresetHard => 'Sắc';

  @override
  String get fxPresetGlow => 'Phát sáng';

  @override
  String get fxPresetNeumorphism => 'Neumorphism';

  @override
  String get selectionPane => 'Ngăn Vùng Chọn';

  @override
  String get alignGuides => 'Căn & Gióng';

  @override
  String get textLayout => 'Bố Cục Văn Bản';

  @override
  String get animationPane => 'Hoạt Hình';

  @override
  String get transitions => 'Hiệu Ứng Chuyển';

  @override
  String get presentExit => 'Thoát';

  @override
  String get presentLaunchFailed => 'Không thể khởi chạy trình chiếu';

  @override
  String get webviewRuntimeMissing =>
      'Không tìm thấy WebView2 runtime — hãy cài Microsoft Edge WebView2 để trình chiếu mượt';

  @override
  String get presentHelp => 'Phím tắt';

  @override
  String get presentHelpClose => 'Bấm vào bất kỳ đâu để đóng trợ giúp này.';

  @override
  String get presentHelpKeysG => 'Mở lưới điều hướng slide';

  @override
  String get presentHelpKeysB => 'Màn hình đen / trắng';

  @override
  String get presentHelpKeysP => 'Bút vẽ';

  @override
  String get presentHelpKeysL => 'Con trỏ laser';

  @override
  String get presentHelpKeysM => 'Kính lúp';

  @override
  String get presentHelpKeysNumber => 'Nhảy thẳng tới một slide';

  @override
  String get presentHelpKeysEsc => 'Thoát trình chiếu';

  @override
  String get presentGridTitle => 'Nhảy tới slide';

  @override
  String get presentPen => 'Bút vẽ';

  @override
  String get presentHighlighter => 'Bút dạ';

  @override
  String get presentLaser => 'Con trỏ laser';

  @override
  String get presentMagnifier => 'Kính lúp';

  @override
  String get presentClearInk => 'Xóa hình vẽ';

  @override
  String get presenterNextSlide => 'Slide kế tiếp';

  @override
  String get presenterSpeakerNotes => 'Ghi chú diễn giả';

  @override
  String get presenterNoNotes => 'Không có ghi chú cho slide này';

  @override
  String get presenterEndOfPresentation => 'Hết bài trình bày';

  @override
  String get slide => 'Slide';

  @override
  String get setupShowTitle => 'Cài đặt trình chiếu';

  @override
  String get setupShowMode => 'Kiểu trình chiếu';

  @override
  String get setupShowModePresenter => 'Diễn giả điều khiển (toàn màn hình)';

  @override
  String get setupShowModeBrowsed => 'Người xem tự duyệt (cửa sổ)';

  @override
  String get setupShowModeKiosk => 'Kiosk (toàn màn hình, tự lặp)';

  @override
  String get setupShowLoop => 'Lặp liên tục đến khi bấm Esc';

  @override
  String get setupShowNoNarration => 'Trình chiếu không có lời thuyết minh';

  @override
  String get setupShowNoAnimation => 'Trình chiếu không có hiệu ứng động';

  @override
  String get setupShowAdvance => 'Tự chuyển mỗi';

  @override
  String get setupShowPenColor => 'Màu bút mặc định';

  @override
  String get setupShowCustomShow => 'Trình chiếu tùy chỉnh';

  @override
  String get setupShowCustomShowAll => 'Tất cả slide (mặc định)';

  @override
  String get startShow => 'Bắt đầu trình chiếu';

  @override
  String get customShowsTitle => 'Trình chiếu tùy chỉnh';

  @override
  String get customShowName => 'Tên trình chiếu';

  @override
  String get customShowPickSlides =>
      'Bấm chọn slide muốn đưa vào (bấm lại để bỏ)';

  @override
  String get customShowCreate => 'Tạo';

  @override
  String get customShowEmpty => 'Chưa có trình chiếu tùy chỉnh nào';

  @override
  String get done => 'Xong';

  @override
  String get exportingInProgress => 'Đang xuất…';

  @override
  String get m6Title =>
      'Milestone 6 — Xuất nâng cao (video / ảnh / in / định dạng / bảo mật)';

  @override
  String get m6Video => 'Video/GIF';

  @override
  String get m6Images => 'Ảnh slide';

  @override
  String get m6Print => 'In (Windows)';

  @override
  String get m6Formats => 'Định dạng';

  @override
  String get m6Protect => 'Bảo mật';

  @override
  String get m6MovieFormat => 'Định dạng phim';

  @override
  String get m6IncludeNarration => 'Gộp narration (audio từng slide) vào MP4';

  @override
  String get m6FfmpegMissing =>
      'FFmpeg không tìm thấy — MP4 cần FFmpeg cài trên máy; GIF vẫn hoạt động.';

  @override
  String get m6ExportMovie => 'Xuất video / GIF';

  @override
  String get m6ImageFormat => 'Định dạng ảnh';

  @override
  String get m6TransparentPng => 'Nền trong suốt (PNG)';

  @override
  String get m6ContactSheet => 'Tạo 1 sheet ảnh tổng hợp (contact sheet)';

  @override
  String get m6ExportImages => 'Xuất ảnh hàng loạt';

  @override
  String get m6ChooseFolder => 'Chọn thư mục xuất ảnh';

  @override
  String get m6HandoutsPerPage => 'Handouts: số slide mỗi trang';

  @override
  String get m6PrintNotes => 'In ghi chú speaker dưới slide';

  @override
  String get m6Grayscale => 'In đen trắng (grayscale)';

  @override
  String get m6OutlineRtf => 'Outline RTF cho Word';

  @override
  String get m6PrintDone => 'Đã gửi tới máy in';

  @override
  String get m6Inspect => 'Quét metadata (Inspector)';

  @override
  String get m6Package => 'Đóng gói thư mục + ZIP';

  @override
  String get m6InspectorClean => 'Không phát hiện dữ liệu ẩn.';

  @override
  String m6InspectorFound(Object count) {
    return 'Phát hiện $count dữ liệu ẩn (tác giả/email/phone/slide trống).';
  }

  @override
  String get m6CleanExport => 'Xuất deck đã làm sạch (.pptx)';

  @override
  String get m6ModifyPassword => 'Mật khẩu chống sửa (để trống = không đặt)';

  @override
  String get m6MarkFinal => 'Mark as Final';

  @override
  String get m6ApplyPassword => 'Đặt mật khẩu chống sửa';

  @override
  String get m6PptFallback =>
      'Cần LibreOffice trên máy để xuất .ppt — dùng .pptx và Save As từ PowerPoint.';

  @override
  String get collabViewLink => 'Link xem (chỉ đọc)';

  @override
  String get collabViewLinkHint =>
      'Ai có link này chỉ xem được, không sửa được.';

  @override
  String get collabCopyViewLink => 'Sao chép link xem';

  @override
  String get collabRole => 'Vai trò';

  @override
  String get collabRoleHost => 'Chủ phiên';

  @override
  String get collabRoleEditor => 'Người sửa';

  @override
  String get collabRoleViewer => 'Người xem';

  @override
  String get collabViewModeNotice => 'Chế độ xem — phiên này chỉ đọc.';

  @override
  String get collabKick => 'Xóa khỏi phiên';

  @override
  String get collabLockSession => 'Khóa phiên (từ chối người mới)';

  @override
  String get collabUnlockSession => 'Mở khóa phiên';

  @override
  String get collabLockSlide => 'Đang sửa…';

  @override
  String get collabHistory => 'Lịch sử đồng bộ';

  @override
  String collabHistoryEntry(Object name, Object slide) {
    return '$name sửa slide $slide';
  }

  @override
  String collabReconnecting(Object attempt) {
    return 'Đang nối lại… (lần $attempt)';
  }

  @override
  String get collabReconnected => 'Đã nối lại.';

  @override
  String get collabConnectionLost => 'Mất kết nối — đang thử lại…';

  @override
  String collabLockedBy(Object name) {
    return 'Slide này đang được $name sửa';
  }

  @override
  String collabConflictDetail(Object name, Object slide, Object time) {
    return '$name đổi slide $slide lúc $time';
  }

  @override
  String get comments => 'Bình luận';

  @override
  String get commentsAdd => 'Thêm bình luận';

  @override
  String get commentsEmpty => 'Chưa có bình luận trên slide này.';

  @override
  String get commentsResolve => 'Đóng';

  @override
  String get commentsUnresolve => 'Mở lại';

  @override
  String get commentsReply => 'Trả lời';

  @override
  String get commentsDelete => 'Xóa';

  @override
  String get commentsMentionHint => 'Gõ @ để nhắc người cộng tác';

  @override
  String get commentsNewChip => 'Bình luận mới';

  @override
  String get commentsExportNote => 'Ghi chú thảo luận';

  @override
  String get profileTitle => 'Hồ sơ của bạn';

  @override
  String get profileName => 'Tên hiển thị';

  @override
  String get profileAvatar => 'Ảnh đại diện';

  @override
  String get profileSave => 'Lưu hồ sơ';

  @override
  String get profileSaved => 'Đã lưu hồ sơ.';

  @override
  String get profileAuthorHint =>
      'Dùng làm tác giả bình luận và metadata xuất.';

  @override
  String get cloudTitle => 'Đồng bộ đám mây';

  @override
  String get cloudUrl => 'Địa chỉ máy chủ WebDAV';

  @override
  String get cloudUsername => 'Tên người dùng';

  @override
  String get cloudPassword => 'Mật khẩu';

  @override
  String get cloudSave => 'Lưu tài khoản đám mây';

  @override
  String get cloudSaved => 'Đã lưu tài khoản đám mây.';

  @override
  String get cloudSyncNow => 'Đồng bộ ngay';

  @override
  String get cloudSyncing => 'Đang đồng bộ…';

  @override
  String get cloudSynced => 'Đã đồng bộ.';

  @override
  String get cloudConflictSaved => 'Xung đột được lưu thành .conflict';

  @override
  String get cloudNoAccount => 'Chưa cấu hình tài khoản đám mây.';

  @override
  String get versions => 'Phiên bản';

  @override
  String get versionsRestore => 'Khôi phục';

  @override
  String get versionsDelete => 'Xóa';

  @override
  String get versionsEmpty => 'Chưa có phiên bản nào.';

  @override
  String get versionsMax => 'Giữ tối đa 20 phiên bản mỗi dự án';

  @override
  String get reuseTitle => 'Tái sử dụng slide';

  @override
  String get designerTitle => 'Designer';

  @override
  String get designerSelectSlide => 'Chọn slide để xem gợi ý thiết kế';

  @override
  String get designerUndo => 'Hoàn tác thiết kế';

  @override
  String get designerDark => 'Tối';

  @override
  String get designerApply => 'Áp dụng';

  @override
  String get reusePasteHint =>
      'Dán bundle .ghita (JSON) hoặc text/HTML. Slide tách theo --- hoặc h1/h2.';

  @override
  String get reuseKeepOriginal => 'Giữ định dạng gốc';

  @override
  String get reuseParse => 'Phân tích';

  @override
  String get reuseCompare => 'So sánh / Trộn';

  @override
  String get reuseInserted => 'Đã chèn slide';

  @override
  String get compareVersionA => 'Phiên bản A (.ghita JSON)';

  @override
  String get compareVersionB => 'Phiên bản B (.ghita JSON)';

  @override
  String get compareRun => 'So sánh';

  @override
  String get compareMergeIntoDeck => 'Trộn vào deck';

  @override
  String get copilotCreateDeck => 'Tạo bài thuyết trình';

  @override
  String get copilotSummarize => 'Tóm tắt deck';

  @override
  String get copilotAskDeck => 'Hỏi về deck';

  @override
  String get dictationMic => 'Đọc chính tả';

  @override
  String get dictationListening => 'Đang nghe…';

  @override
  String get dictationStop => 'Dừng đọc chính tả';

  @override
  String get translateDeck => 'Dịch toàn deck';

  @override
  String get aiContextToggle => 'AI dùng ngữ cảnh deck';

  @override
  String get findReplace => 'Tìm / Thay thế';

  @override
  String get accessibilityTitle => 'Trợ năng';

  @override
  String get addinsTitle => 'Add-in';

  @override
  String get readAloudTitle => 'Đọc to';

  @override
  String get ribbonCustomize => 'Tùy chỉnh ribbon';

  @override
  String get viewNormal => 'Bình thường';

  @override
  String get viewSorter => 'Trình sắp xếp';

  @override
  String get viewNotes => 'Ghi chú';

  @override
  String get viewReading => 'Chế độ đọc';

  @override
  String get outlineView => 'Chế độ dàn ý';

  @override
  String get spellcheck => 'Kiểm tra chính tả';

  @override
  String get templateOnline => 'Template trực tuyến';

  @override
  String get versionsRestored => 'Đã khôi phục phiên bản.';

  @override
  String get deckEmpty => 'Bài thuyết trình đang trống — hãy thêm slide trước.';

  @override
  String get summarySlideAdded => 'Đã thêm slide tóm tắt.';

  @override
  String get askDeckHint => 'Ví dụ: Slide nào nói về ngân sách?';

  @override
  String get slideTitleHint => 'Tiêu đề slide...';

  @override
  String get slideUpdated => 'Đã cập nhật slide!';

  @override
  String get slideAddedSuccess => 'Đã thêm slide thành công!';

  @override
  String get templateSearchHint => 'Tìm kiếm template...';

  @override
  String get importSlides => 'Nhập Slides';

  @override
  String addAllSlides(Object count) {
    return 'Thêm tất cả ($count)';
  }

  @override
  String addedSlideNotice(Object title) {
    return 'Đã thêm \"$title\" vào bài thuyết trình!';
  }

  @override
  String get openGhitaFile => 'Mở file .ghita';

  @override
  String openedProject(Object project) {
    return 'Đã mở: $project';
  }

  @override
  String get moreTools => 'Công cụ khác';

  @override
  String get collapseTools => 'Thu gọn công cụ';

  @override
  String get presenterBroadcastStart => 'Phát qua Wi-Fi';

  @override
  String get presenterBroadcastStop => 'Dừng phát qua Wi-Fi';

  @override
  String get presenterBroadcastCopy => 'Sao chép liên kết người xem';

  @override
  String get presenterBroadcastCopied =>
      'Đã sao chép liên kết xem bảo mật vào clipboard.';

  @override
  String get presenterBroadcastFailed =>
      'Không thể khởi động máy chủ phát qua Wi-Fi.';

  @override
  String presenterViewerCount(int count) {
    return '$count người xem';
  }

  @override
  String get diagramDialogTitle => 'Chèn Sơ đồ';

  @override
  String get diagramModeFlowchart => 'Sơ đồ quy trình';

  @override
  String get diagramModeMindmap => 'Sơ đồ tư duy';

  @override
  String get diagramTopicLabel => 'Chủ đề trung tâm';

  @override
  String get diagramAccentLabel => 'Màu nhấn';

  @override
  String get diagramStepsLabel => 'Các bước (theo thứ tự)';

  @override
  String get diagramSubtopicsLabel => 'Nhánh con';

  @override
  String get diagramAddStep => 'Thêm bước';

  @override
  String get diagramAddSubtopic => 'Thêm nhánh';

  @override
  String get diagramRemoveField => 'Bỏ ô cuối';

  @override
  String get diagramPreviewLabel => 'Xem trước';

  @override
  String get diagramCentralChip => 'Chủ đề chính';

  @override
  String get diagramInsert => 'Chèn vào slide';

  @override
  String get pdfNotesPages => 'Trang ghi chú người trình bày';

  @override
  String get pdfBookmarks => 'Dấu trang PDF (outline)';
}
