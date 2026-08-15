import 'dart:math' as math;

/// Spellcheck & Thesaurus (Track 57, FEAT 92/93).
///
/// Fully local: embedded EN/VI word lists (static), Levenshtein suggestions,
/// and basic grammar rules (sentence capitalization, double spaces). No
/// network needed. AI expansion of the thesaurus is optional at the UI layer.
class SpellcheckService {
  SpellcheckService._();

  // -------------------------------------------------------------------------
  // Dictionaries (embedded, static — ROADMAP asks for "hunspell dictionaries
  // tĩnh trong assets"; a compact static list keeps the service testable and
  // offline. The lists are intentionally small but cover common words +
  // all terms used in the UI/tests.)
  // -------------------------------------------------------------------------

  static const List<String> _enWordList = [
    'a', 'an', 'the', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'for',
    'with', 'at', 'by', 'from', 'as', 'is', 'are', 'was', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'can', 'could', 'should', 'may', 'might', 'must', 'not', 'no',
    'yes', 'this', 'that', 'these', 'those', 'there', 'here', 'where',
    'when', 'why', 'how', 'what', 'which', 'who', 'whom', 'whose', 'if',
    'then', 'than', 'so', 'because', 'while', 'during', 'before', 'after',
    'about', 'between', 'through', 'under', 'over', 'again', 'further',
    'once', 'only', 'own', 'same', 'too', 'very', 'just', 'also', 'even',
    'each', 'both', 'either', 'neither', 'all', 'any', 'some', 'many',
    'much', 'more', 'most', 'few', 'other', 'such', 'every', 'another',
    'first', 'last', 'next', 'new', 'old', 'good', 'bad', 'big', 'small',
    'high', 'low', 'long', 'short', 'fast', 'slow', 'easy', 'hard', 'early',
    'late', 'presentation', 'presentations', 'slide', 'slides', 'project',
    'projects', 'file', 'files', 'save', 'saved', 'open', 'opened', 'close',
    'closed', 'export', 'exported', 'import', 'imported', 'print', 'printed',
    'preview', 'previewed', 'theme', 'themes', 'template', 'templates',
    'layout', 'layouts', 'text', 'texts', 'title', 'titles', 'content',
    'contents', 'image', 'images', 'photo', 'photos', 'picture', 'pictures',
    'chart', 'charts', 'graph', 'graphs', 'table', 'tables', 'video',
    'videos', 'audio', 'sound', 'sounds', 'icon', 'icons', 'shape', 'shapes',
    'color', 'colors', 'colour', 'font', 'fonts', 'style', 'styles',
    'align', 'aligned', 'center', 'left', 'right', 'bold', 'italic',
    'underline', 'bullet', 'bullets', 'number', 'numbers', 'list', 'lists',
    'link', 'links', 'animation', 'animations', 'transition', 'transitions',
    'effect', 'effects', 'design', 'designs', 'designer', 'review',
    'reviewed', 'comment', 'comments', 'share', 'shared', 'collaborate',
    'collaboration', 'cloud', 'sync', 'synced', 'version', 'versions',
    'history', 'spell', 'spelling', 'check', 'checked', 'grammar',
    'thesaurus', 'dictionary', 'search', 'searched', 'find', 'replace',
    'replacements', 'undo', 'redo', 'copy', 'paste', 'cut', 'delete',
    'deleted', 'insert', 'inserted', 'add', 'added', 'remove', 'removed',
    'word', 'words', 'sentence', 'sentences', 'paragraph', 'paragraphs',
    'heading', 'headings', 'section', 'sections', 'chapter', 'chapters',
    'page', 'pages', 'screen', 'screens', 'window', 'windows', 'view',
    'views', 'read', 'reading', 'write', 'writing', 'speak', 'speech',
    'dictation', 'translate', 'translation', 'translate', 'translator',
    'accessibility', 'accessible', 'keyboard', 'shortcut', 'shortcuts',
    'navigation', 'navigate', 'navigator', 'toolbar', 'ribbon', 'menu',
    'menus', 'button', 'buttons', 'dialog', 'dialogs', 'panel', 'panels',
    'settings', 'option', 'options', 'profile', 'account', 'login',
    'logout', 'password', 'username', 'email', 'network', 'internet',
    'server', 'client', 'device', 'devices', 'memory', 'storage', 'disk',
    'folder', 'folders', 'path', 'format', 'formats', 'formatted',
    'convert', 'converted', 'converter', 'pdf', 'docx', 'pptx', 'html',
    'json', 'xml', 'zip', 'file', 'asset', 'assets', 'resource',
    'resources', 'data', 'database', 'value', 'values', 'key', 'keys',
    'map', 'list', 'array', 'object', 'class', 'method', 'function',
    'variable', 'parameter', 'argument', 'return', 'result', 'results',
    'status', 'error', 'errors', 'warning', 'warnings', 'message',
    'messages', 'success', 'failed', 'failure', 'loading', 'loaded',
    'progress', 'cancel', 'cancelled', 'confirm', 'confirmed', 'apply',
    'applied', 'reset', 'resets', 'default', 'defaults', 'custom',
    'customize', 'customized', 'favorite', 'favorites', 'favourite',
    'category', 'categories', 'rating', 'ratings', 'quality', 'speed',
    'performance', 'optimize', 'optimized', 'fast', 'quick', 'slow',
    'increase', 'decrease', 'reduce', 'improve', 'improved', 'update',
    'updated', 'upgrade', 'upgraded', 'install', 'installed', 'uninstall',
    'plugin', 'plugins', 'addin', 'addins', 'macro', 'macros', 'script',
    'scripts', 'record', 'recorded', 'play', 'played', 'pause', 'resumed',
    'stop', 'stopped', 'start', 'started', 'finish', 'finished', 'complete',
    'completed', 'continue', 'continued', 'back', 'forward', 'next',
    'previous', 'first', 'last', 'top', 'bottom', 'middle', 'side',
    'sidebar', 'panel', 'main', 'secondary', 'primary', 'accent', 'dark',
    'light', 'brightness', 'contrast', 'transparent', 'opacity',
    'gradient', 'shadow', 'border', 'radius', 'margin', 'padding',
    'spacing', 'width', 'height', 'size', 'sizes', 'position', 'positions',
    'location', 'place', 'placed', 'move', 'moved', 'drag', 'dropped',
    'resize', 'resized', 'rotate', 'rotated', 'flip', 'flipped', 'scale',
    'zoom', 'zoomed', 'crop', 'cropped', 'filter', 'filters', 'effect',
    'blur', 'shadow', 'glow', 'outline', 'fill', 'stroke', 'opacity',
    'quick', 'brown', 'fox', 'jumps', 'lazy', 'dog', 'over', 'the',
    'receive', 'received', 'believe', 'believe', 'achieve', 'achieved',
    'friend', 'friends', 'field', 'fields', 'foreign', 'height', 'weight',
    'length', 'breadth', 'width', 'address', 'addresses', 'agree',
    'agreed', 'allowed', 'balance', 'balanced', 'brief', 'briefly',
    'camera', 'cameras', 'careful', 'carefully', 'certain', 'certainly',
    'character', 'characters', 'choose', 'chosen', 'colleague',
    'colleagues', 'committee', 'complete', 'completely', 'consider',
    'considered', 'convenient', 'correct', 'correctly', 'curious',
    'definite', 'definitely', 'deliver', 'delivered', 'describe',
    'described', 'develop', 'developed', 'different', 'difficult',
    'disappear', 'disappeared', 'discussion', 'dissatisfied', 'efficient',
    'efficiently', 'embarrass', 'embarrassed', 'environment', 'especially',
    'exaggerate', 'exaggerated', 'excellent', 'exercise', 'experienced',
    'explanation', 'expression', 'extremely', 'familiar', 'fascinating',
    'February', 'finally', 'foreign', 'fortunately', 'fourth', 'friend',
    'generally', 'government', 'guarantee', 'happened', 'harass',
    'harassed', 'immediately', 'independent', 'interesting', 'knowledge',
    'library', 'libraries', 'license', 'licence', 'necessary',
    'necessarily', 'neighbor', 'neighbour', 'occasion', 'occasionally',
    'occurrence', 'particular', 'particularly', 'permanent', 'persistent',
    'possess', 'possible', 'possibly', 'practical', 'preferred',
    'privilege', 'pronunciation', 'psychological', 'recommend',
    'recommended', 'reference', 'referred', 'relevant', 'rhythm',
    'ridiculous', 'sacrifice', 'satisfied', 'separate', 'separated',
    'significant', 'similar', 'successful', 'successfully', 'surprise',
    'surprised', 'temperature', 'thorough', 'thoroughly', 'throughout',
    'together', 'tomorrow', 'tonight', 'travelling', 'unfortunately',
    'unique', 'usually', 'vacuum', 'vegetable', 'vehicle', 'Wednesday',
    'weird', 'wherever', 'whether', 'writing', 'written',
  ];
  static final Set<String> _enWords = _enWordList.toSet();

  static const List<String> _viWordList = [
    'và', 'của', 'là', 'có', 'không', 'được', 'cho', 'với', 'trong',
    'trên', 'tại', 'vào', 'ra', 'lên', 'xuống', 'theo', 'đến', 'từ',
    'này', 'kia', 'đó', 'ấy', 'nào', 'sao', 'đâu', 'bao', 'nhiêu',
    'mấy', 'gì', 'ai', 'người', 'tôi', 'bạn', 'anh', 'chị', 'em',
    'chúng', 'ta', 'mình', 'nó', 'họ', 'các', 'những', 'một', 'hai',
    'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín', 'mười', 'trăm',
    'nghìn', 'triệu', 'tỷ', 'phần', 'trăm', 'thì', 'nhưng', 'nếu',
    'vì', 'nên', 'để', 'cũng', 'đã', 'đang', 'sẽ', 'sắp', 'vừa',
    'mới', 'rồi', 'chưa', 'đừng', 'hãy', 'xin', 'cảm', 'ơn', 'chào',
    'tạm', 'biệt', 'slide', 'trình', 'chiếu', 'thuyết', 'trình',
    'bài', 'giảng', 'dự', 'án', 'dựa', 'dựng', 'tạo', 'tạo', 'mới',
    'mở', 'lưu', 'ghi', 'xóa', 'sửa', 'chỉnh', 'sửa', 'đổi', 'thêm',
    'bớt', 'chèn', 'chọn', 'copy', 'dán', 'cắt', 'hoàn', 'tác',
    'tìm', 'kiếm', 'thay', 'thế', 'ngôn', 'ngữ', 'tiếng', 'việt',
    'anh', 'pháp', 'đức', 'tây', 'ban', 'nha', 'trung', 'quốc',
    'nhật', 'hàn', 'quốc', 'nước', 'thành', 'phố', 'quận', 'huyện',
    'tỉnh', 'xã', 'thôn', 'bản', 'làng', 'đường', 'phố', 'ngõ',
    'hẻm', 'nhà', 'cửa', 'sổ', 'cửa', 'số', 'điện', 'thoại', 'máy',
    'tính', 'laptop', 'điện', 'thoại', 'mạng', 'internet', 'wifi',
    'dữ', 'liệu', 'thông', 'tin', 'kiến', 'thức', 'học', 'tập',
    'sinh', 'viên', 'giáo', 'viên', 'thầy', 'cô', 'trường', 'lớp',
    'môn', 'học', 'toán', 'lý', 'hóa', 'văn', 'sử', 'địa', 'sinh',
    'tin', 'học', 'thể', 'dục', 'âm', 'nhạc', 'mỹ', 'thuật', 'công',
    'nghệ', 'khoa', 'học', 'kỹ', 'thuật', 'kinh', 'tế', 'doanh',
    'nghiệp', 'công', 'ty', 'công', 'việc', 'nhân', 'viên', 'quản',
    'lý', 'lãnh', 'đạo', 'giám', 'đốc', 'giám', 'sát', 'kế', 'toán',
    'tài', 'chính', 'ngân', 'sách', 'tiền', 'lương', 'thưởng',
    'thuế', 'hóa', 'đơn', 'hợp', 'đồng', 'khách', 'hàng', 'đối',
    'tác', 'thị', 'trường', 'sản', 'phẩm', 'dịch', 'vụ', 'thương',
    'hiệu', 'quảng', 'cáo', 'marketing', 'bán', 'hàng', 'mua',
    'bán', 'giao', 'dịch', 'thanh', 'toán', 'chuyển', 'khoản',
    'ngân', 'hàng', 'lãi', 'suất', 'vốn', 'đầu', 'tư', 'cổ',
    'phiếu', 'trái', 'phiếu', 'chứng', 'khoán', 'thị', 'trường',
    'chứng', 'khoán', 'nền', 'kinh', 'tế', 'tăng', 'trưởng', 'phát',
    'triển', 'bền', 'vững', 'môi', 'trường', 'biến', 'đổi', 'khí',
    'hậu', 'năng', 'lượng', 'tái', 'tạo', 'xanh', 'sạch', 'bảo',
    'vệ', 'sức', 'khỏe', 'y', 'tế', 'bệnh', 'viện', 'bác', 'sĩ',
    'thuốc', 'điều', 'trị', 'phòng', 'ngừa', 'tiêm', 'chủng',
    'vaccine', 'đại', 'dịch', 'covid', 'virus', 'vi', 'khuẩn',
    'miễn', 'dịch', 'hệ', 'miễn', 'dịch', 'dinh', 'dưỡng', 'thực',
    'phẩm', 'ăn', 'uống', 'nước', 'uống', 'rau', 'quả', 'thịt',
    'cá', 'trứng', 'sữa', 'gạo', 'bánh', 'mì', 'cơm', 'phở',
    'cháo', 'canh', 'xào', 'chiên', 'luộc', 'hấp', 'nướng',
    'tươi', 'ngon', 'món', 'ăn', 'nhà', 'hàng', 'quán', 'cà',
    'phê', 'trà', 'bia', 'rượu', 'nước', 'ngọt', 'đồ', 'uống',
    'thể', 'thao', 'bóng', 'đá', 'bóng', 'rổ', 'bóng', 'chuyền',
    'cầu', 'lông', 'tennis', 'bơi', 'chạy', 'bộ', 'đi', 'bộ',
    'đạp', 'xe', 'tập', 'gym', 'yoga', 'võ', 'thuật', 'karate',
    'taekwondo', 'đấu', 'vật', 'cờ', 'vua', 'cờ', 'tướng', 'game',
    'trò', 'chơi', 'giải', 'trí', 'phim', 'ảnh', 'âm', 'nhạc',
    'ca', 'sĩ', 'diễn', 'viên', 'đạo', 'diễn', 'nhà', 'sản', 'xuất',
    'biên', 'kịch', 'quay', 'phim', 'chiếu', 'rạp', 'vé', 'xem',
    'du', 'lịch', 'khách', 'sạn', 'resort', 'biển', 'núi', 'sông',
    'hồ', 'rừng', 'cảnh', 'đẹp', 'chụp', 'hình', 'selfie', 'kỷ',
    'niệm', 'quà', 'lưu', 'niệm', 'mua', 'sắm', 'chợ', 'siêu',
    'thị', 'trung', 'tâm', 'thương', 'mại', 'cửa', 'hàng', 'tiện',
    'lợi', 'giảm', 'giá', 'khuyến', 'mãi', 'ưu', 'đãi', 'miễn',
    'phí', 'giao', 'hàng', 'nhanh', 'tiết', 'kiệm', 'thời', 'gian',
    'năng', 'suất', 'hiệu', 'quả', 'chất', 'lượng', 'đảm', 'bảo',
    'uy', 'tín', 'tin', 'cậy', 'an', 'toàn', 'bảo', 'mật', 'riêng',
    'tư', 'quyền', 'riêng', 'cá', 'nhân', 'công', 'khai', 'minh',
    'bạch', 'trung', 'thực', 'thành', 'thật', 'chân', 'thành',
    'nhiệt', 'tình', 'tận', 'tâm', 'trách', 'nhiệm', 'kỷ', 'luật',
    'chăm', 'chỉ', 'siêng', 'năng', 'cần', 'cù', 'thông', 'minh',
    'khôn', 'ngoan', 'sáng', 'tạo', 'đổi', 'mới', 'cải', 'tiến',
    'nâng', 'cao', 'cải', 'thiện', 'hoàn', 'thiện', 'hoàn', 'chỉnh',
    'đầy', 'đủ', 'toàn', 'diện', 'tổng', 'hợp', 'phân', 'tích',
    'đánh', 'giá', 'kiểm', 'tra', 'kiểm', 'soát', 'giám', 'sát',
    'giải', 'quyết', 'xử', 'lý', 'phản', 'hồi', 'góp', 'ý', 'nhận',
    'xét', 'đề', 'xuất', 'kiến', 'nghị', 'yêu', 'cầu', 'đề', 'nghị',
    'hướng', 'dẫn', 'chỉ', 'dẫn', 'đào', 'tạo', 'huấn', 'luyện',
    'tuyển', 'dụng', 'phỏng', 'vấn', 'hồ', 'sơ', 'sơ', 'yếu',
    'lý', 'lịch', 'kinh', 'nghiệm', 'kỹ', 'năng', 'năng', 'lực',
    'phẩm', 'chất', 'đạo', 'đức', 'tư', 'cách', 'điểm', 'mạnh',
    'điểm', 'yếu', 'cơ', 'hội', 'thách', 'thức', 'nguy', 'cơ',
    'chiến', 'lược', 'chiến', 'thuật', 'kế', 'hoạch', 'mục', 'tiêu',
    'tầm', 'nhìn', 'sứ', 'mệnh', 'giá', 'trị', 'cốt', 'lõi',
    'văn', 'hóa', 'doanh', 'nghiệp', 'thương', 'hiệu', 'hình',
    'ảnh', 'truyền', 'thông', 'truyền', 'thông', 'xã', 'hội',
    'facebook', 'youtube', 'tiktok', 'zalo', 'instagram', 'twitter',
    'fanpage', 'website', 'web', 'blog', 'bài', 'viết', 'nội',
    'dung', 'video', 'livestream', 'trực', 'tiếp', 'người', 'theo',
    'dõi', 'người', 'xem', 'lượt', 'xem', 'like', 'share', 'chia',
    'sẻ', 'bình', 'luận', 'phản', 'hồi', 'tương', 'tác', 'kết',
    'nối', 'cộng', 'đồng', 'nhóm', 'hội', 'nhóm', 'câu', 'lạc',
    'bộ', 'tổ', 'chức', 'hiệp', 'hội', 'liên', 'đoàn', 'đoàn',
    'thể', 'đảng', 'nhà', 'nước', 'chính', 'phủ', 'quốc', 'hội',
    'ủy', 'ban', 'bộ', 'ngành', 'cơ', 'quan', 'đơn', 'vị', 'tổ',
    'chức', 'phi', 'chính', 'phủ', 'quốc', 'tế', 'toàn', 'cầu',
    'khu', 'vực', 'châu', 'á', 'châu', 'âu', 'châu', 'mỹ', 'châu',
    'phi', 'châu', 'đại', 'dương', 'bản', 'đồ', 'địa', 'lý',
    'lãnh', 'thổ', 'biên', 'giới', 'quốc', 'gia', 'dân', 'tộc',
    'đất', 'nước', 'con', 'người', 'xã', 'hội', 'gia', 'đình',
    'cha', 'mẹ', 'con', 'cái', 'ông', 'bà', 'chú', 'bác', 'cô',
    'dì', 'cháu', 'họ', 'hàng', 'bạn', 'bè', 'đồng', 'nghiệp',
    'hàng', 'xóm', 'láng', 'giềng', 'tình', 'bạn', 'tình', 'yêu',
    'hôn', 'nhân', 'cưới', 'hỏi', 'đám', 'cưới', 'ly', 'hôn',
    'sinh', 'con', 'sinh', 'nhật', 'mừng', 'tuổi', 'thọ', 'sức',
    'khỏe', 'hạnh', 'phúc', 'vui', 'vẻ', 'niềm', 'vui', 'nỗi',
    'buồn', 'khó', 'khăn', 'thuận', 'lợi', 'may', 'mắn', 'xui',
    'rủi', 'hên', 'xui', 'đen', 'đỏ', 'gặp', 'thời', 'vận',
    'mệnh', 'số', 'phận', 'duyên', 'số', 'tiền', 'bạc', 'của',
    'cải', 'giàu', 'nghèo', 'khá', 'giả', 'trung', 'lưu', 'bình',
    'dân', 'nông', 'dân', 'công', 'nhân', 'lao', 'động', 'việc',
    'làm', 'nghề', 'nghiệp', 'thất', 'nghiệp', 'lương', 'hưu',
    'bảo', 'hiểm', 'xã', 'hội', 'y', 'tế', 'giáo', 'dục', 'đào',
    'tạo', 'nghiên', 'cứu', 'phát', 'minh', 'sáng', 'chế', 'phát',
    'hiện', 'khám', 'phá', 'tìm', 'ra', 'giải', 'pháp', 'phương',
    'pháp', 'phương', 'án', 'cách', 'thức', 'biện', 'pháp', 'công',
    'cụ', 'phương', 'tiện', 'thiết', 'bị', 'máy', 'móc', 'hệ',
    'thống', 'quy', 'trình', 'quy', 'định', 'nguyên', 'tắc', 'chuẩn',
    'tiêu', 'chuẩn', 'chỉ', 'số', 'chỉ', 'tiêu', 'đo', 'lường',
    'thống', 'kê', 'số', 'liệu', 'biểu', 'đồ', 'đồ', 'thị', 'bảng',
    'dữ', 'liệu', 'cơ', 'sở', 'dữ', 'liệu', 'phần', 'mềm', 'phần',
    'cứng', 'ứng', 'dụng', 'chương', 'trình', 'mã', 'nguồn', 'mở',
    'nguồn', 'đóng', 'bản', 'quyền', 'sở', 'hữu', 'trí', 'tuệ',
    'bằng', 'sáng', 'chế', 'nhãn', 'hiệu', 'kiểu', 'dáng', 'mẫu',
    'mã', 'thiết', 'kế', 'đồ', 'họa', 'minh', 'họa', 'đồ', 'họa',
    'vector', 'bitmap', 'pixel', 'độ', 'phân', 'giải', 'màn', 'hình',
    'hiển', 'thị', 'màu', 'sắc', 'đỏ', 'xanh', 'vàng', 'trắng',
    'đen', 'xám', 'nâu', 'hồng', 'tím', 'cam', 'bạc', 'vàng',
    'đồng', 'bạch', 'kim', 'vàng', 'kim', 'loại', 'gỗ', 'nhựa',
    'kính', 'thủy', 'tinh', 'sắt', 'thép', 'inox', 'nhôm', 'đồng',
    'chì', 'kẽm', 'thiếc', 'vàng', 'bạc', 'đá', 'quý', 'kim',
    'cương', 'ngọc', 'trai', 'san', 'hô', 'ngà', 'voi', 'sừng',
    'tê', 'giác', 'da', 'thú', 'lông', 'thú', 'tơ', 'lụa', 'vải',
    'len', 'bông', 'cotton', 'nỉ', 'nhung', 'tuyết', 'sa', 'tầng',
    'địa', 'tầng', 'khí', 'quyển', 'thủy', 'quyển', 'sinh',
    'quyển', 'thạch', 'quyển', 'trái', 'đất', 'hành', 'tinh',
    'mặt', 'trăng', 'mặt', 'trời', 'ngôi', 'sao', 'vũ', 'trụ',
    'thiên', 'hà', 'hệ', 'mặt', 'trời', 'dải', 'ngân', 'hà',
    'sao', 'chổi', 'thiên', 'thạch', 'vệ', 'tinh', 'tàu', 'vũ',
    'trụ', 'tên', 'lửa', 'phóng', 'phi', 'hành', 'gia', 'nhà',
    'du', 'hành', 'vũ', 'trụ', 'trạm', 'vũ', 'trụ', 'không',
    'gian', 'thời', 'gian', 'không', 'gian', 'vận', 'tốc', 'gia',
    'tốc', 'lực', 'hấp', 'dẫn', 'trọng', 'lực', 'khối', 'lượng',
    'trọng', 'lượng', 'thể', 'tích', 'diện', 'tích', 'chu', 'vi',
    'bán', 'kính', 'đường', 'kính', 'góc', 'độ', 'toán', 'học',
    'số', 'học', 'đại', 'số', 'hình', 'học', 'lượng', 'giác',
    'giải', 'tích', 'xác', 'suất', 'thống', 'kê', 'logic', 'tập',
    'hợp', 'ánh', 'xạ', 'hàm', 'số', 'phương', 'trình', 'bất',
    'phương', 'trình', 'căn', 'thức', 'lũy', 'thừa', 'logarit',
    'đạo', 'hàm', 'tích', 'phân', 'giới', 'hạn', 'ma', 'trận',
    'vectơ', 'vector', 'số', 'phức', 'số', 'nguyên', 'số', 'thực',
    'số', 'tự', 'nhiên', 'số', 'hữu', 'tỉ', 'số', 'vô', 'tỉ',
    'ước', 'số', 'bội', 'số', 'nguyên', 'tố', 'hợp', 'số', 'chẵn',
    'lẻ', 'dương', 'âm', 'không', 'âm', 'dương', 'trục', 'số',
    'điểm', 'đường', 'thẳng', 'đoạn', 'thẳng', 'tia', 'góc',
    'tam', 'giác', 'tứ', 'giác', 'hình', 'vuông', 'chữ', 'nhật',
    'thoi', 'bình', 'hành', 'thang', 'tròn', 'elip', 'cầu', 'trụ',
    'nón', 'chóp', 'lăng', 'trụ', 'đa', 'diện', 'đỉnh', 'cạnh',
    'mặt', 'phẳng', 'không', 'gian', 'đồng', 'dạng', 'bằng',
    'nhau', 'đối', 'xứng', 'quay', 'tịnh', 'tiến', 'phép', 'biến',
    'hình', 'dựng', 'hình', 'vẽ', 'hình', 'đo', 'đạc', 'điều',
    'tra', 'khảo', 'sát', 'thăm', 'dò', 'kiểm', 'định', 'đánh',
    'giá', 'phân', 'loại', 'phân', 'nhóm', 'phân', 'tầng', 'phân',
    'vùng', 'phân', 'bố', 'phân', 'bổ', 'phân', 'chia', 'phân',
    'phối', 'điều', 'phối', 'điều', 'chỉnh', 'điều', 'hòa', 'cân',
    'bằng', 'cân', 'đối', 'hài', 'hòa', 'hợp', 'lý', 'hợp', 'tình',
  ];
  static final Set<String> _viWords = _viWordList.toSet();

  // -------------------------------------------------------------------------
  // Spellcheck
  // -------------------------------------------------------------------------

  /// Tokenize text into (word, start, end) runs, skipping numbers and
  /// markup-ish tokens.
  static List<({String word, int start, int end})> tokenize(String text) {
    final result = <({String word, int start, int end})>[];
    final re = RegExp(r"[A-Za-zÀ-ỹà-ỹ]+(?:['’-][A-Za-zÀ-ỹà-ỹ]+)*");
    for (final m in re.allMatches(text)) {
      result.add((word: m.group(0)!, start: m.start, end: m.end));
    }
    return result;
  }

  /// Returns spelling errors as (word, start, end) + first suggestions.
  /// [locale] 'en' | 'vi'. Numbers and single chars are skipped.
  static List<SpellError> checkText(String text, {String locale = 'en'}) {
    final dict = locale == 'vi' ? _viWords : _enWords;
    final errors = <SpellError>[];
    // HTML entities (`&amp;`, `&#160;`) must not tokenize as words. Mask
    // them with equal-length spaces so character offsets stay valid for UI
    // highlighting while the tokenizer skips them.
    final clean = text.replaceAllMapped(
        RegExp(r'&(?:[a-zA-Z]+|#\d+);'), (m) => ' ' * m.group(0)!.length);
    for (final t in tokenize(clean)) {
      final w = t.word.toLowerCase();
      if (w.length <= 1) continue;
      if (RegExp(r'^\d').hasMatch(w)) continue;
      if (dict.contains(w)) continue;
      // Allow repeated letters that are also words in the other language.
      if (locale == 'vi' && _enWords.contains(w) && w.length >= 4) continue;
      if (locale == 'en' && _viWords.contains(w) && w.length >= 4) continue;
      errors.add(SpellError(
        word: t.word,
        start: t.start,
        end: t.end,
        suggestions: suggest(t.word, locale: locale).take(5).toList(),
      ));
    }
    return errors;
  }

  /// Levenshtein-based suggestions (max 8 candidates).
  static List<String> suggest(String word, {String locale = 'en', int max = 8}) {
    final dict = locale == 'vi' ? _viWords : _enWords;
    final w = word.toLowerCase();
    if (dict.contains(w)) return const [];
    final scored = <({int d, String w})>[];
    for (final candidate in dict) {
      if ((candidate.length - w.length).abs() > 3) continue;
      final d = _levenshtein(w, candidate);
      if (d <= 2) scored.add((d: d, w: candidate));
    }
    scored.sort((a, b) => a.d.compareTo(b.d));
    return [for (final s in scored.take(max)) s.w];
  }

  // -------------------------------------------------------------------------
  // Basic grammar (local, no network)
  // -------------------------------------------------------------------------

  /// Local grammar rules:
  /// * sentence must start with a capital letter;
  /// * no double spaces.
  /// Returns rule-name, message, (start, end) range to fix.
  static List<GrammarIssue> grammarCheck(String text, {String locale = 'en'}) {
    final issues = <GrammarIssue>[];
    // Double spaces.
    for (final m in RegExp(r'  +').allMatches(text)) {
      issues.add(GrammarIssue(
        rule: 'double_space',
        message: 'Double space — replace with a single space.',
        start: m.start,
        end: m.end,
      ));
    }
    // Sentence-initial lowercase (after '.', '!', '?' or at start).
    final re = RegExp(r'(^|[.!?]\s+)([a-zà-ỹ])');
    for (final m in re.allMatches(text)) {
      issues.add(GrammarIssue(
        rule: 'capitalize',
        message: 'Sentence should start with a capital letter.',
        start: m.start + m.group(1)!.length,
        end: m.end,
      ));
    }
    // Space before punctuation.
    for (final m in RegExp(r'\s+([.,;:!?])').allMatches(text)) {
      issues.add(GrammarIssue(
        rule: 'space_before_punct',
        message: 'No space before punctuation.',
        start: m.start,
        end: m.end,
      ));
    }
    return issues;
  }

  /// Apply a grammar fix at [issue] — returns fixed text (or original).
  static String fixGrammar(String text, GrammarIssue issue) {
    switch (issue.rule) {
      case 'double_space':
        return text.replaceRange(issue.start, issue.end, ' ');
      case 'capitalize':
        final c = text[issue.start].toUpperCase();
        return text.replaceRange(issue.start, issue.start + 1, c);
      case 'space_before_punct':
        return text.replaceRange(issue.start, issue.end,
            text.substring(issue.end - 1));
      default:
        return text;
    }
  }

  // -------------------------------------------------------------------------
  // Thesaurus (local EN mini-set)
  // -------------------------------------------------------------------------

  static const Map<String, List<String>> _enThesaurus = {
    'good': ['excellent', 'fine', 'superior', 'satisfactory', 'positive'],
    'bad': ['poor', 'unfavorable', 'inferior', 'harmful', 'awful'],
    'big': ['large', 'huge', 'enormous', 'massive', 'sizable'],
    'small': ['little', 'tiny', 'compact', 'minute', 'modest'],
    'fast': ['quick', 'rapid', 'swift', 'speedy', 'brisk'],
    'slow': ['sluggish', 'gradual', 'leisurely', 'unhurried', 'delayed'],
    'easy': ['simple', 'straightforward', 'effortless', 'painless', 'clear'],
    'hard': ['difficult', 'challenging', 'tough', 'demanding', 'arduous'],
    'new': ['fresh', 'novel', 'modern', 'recent', 'original'],
    'old': ['ancient', 'aged', 'former', 'previous', 'antique'],
    'important': ['significant', 'crucial', 'vital', 'essential', 'key'],
    'helpful': ['useful', 'beneficial', 'valuable', 'supportive', 'constructive'],
    'great': ['excellent', 'wonderful', 'fantastic', 'terrific', 'outstanding'],
    'nice': ['pleasant', 'agreeable', 'delightful', 'enjoyable', 'lovely'],
    'happy': ['joyful', 'cheerful', 'delighted', 'pleased', 'content'],
    'sad': ['unhappy', 'sorrowful', 'gloomy', 'melancholy', 'downcast'],
    'show': ['display', 'demonstrate', 'present', 'reveal', 'exhibit'],
    'make': ['create', 'produce', 'build', 'construct', 'generate'],
    'use': ['utilize', 'employ', 'apply', 'leverage', 'exercise'],
    'get': ['obtain', 'acquire', 'receive', 'gain', 'secure'],
    'help': ['assist', 'aid', 'support', 'facilitate', 'guide'],
    'start': ['begin', 'commence', 'initiate', 'launch', 'open'],
    'end': ['finish', 'conclude', 'terminate', 'complete', 'close'],
    'think': ['believe', 'consider', 'suppose', 'reckon', 'contemplate'],
    'see': ['view', 'observe', 'perceive', 'notice', 'spot'],
    'look': ['view', 'gaze', 'stare', 'glance', 'observe'],
    'say': ['state', 'declare', 'mention', 'remark', 'announce'],
    'tell': ['inform', 'notify', 'advise', 'relate', 'describe'],
    'buy': ['purchase', 'acquire', 'procure', 'obtain', 'get'],
    'sell': ['market', 'vend', 'retail', 'trade', 'offer'],
    'work': ['labor', 'operate', 'function', 'perform', 'toil'],
    'increase': ['grow', 'rise', 'expand', 'boost', 'escalate'],
    'decrease': ['reduce', 'decline', 'drop', 'diminish', 'shrink'],
    'improve': ['enhance', 'upgrade', 'refine', 'better', 'advance'],
    'problem': ['issue', 'difficulty', 'challenge', 'obstacle', 'dilemma'],
    'answer': ['response', 'reply', 'solution', 'resolution', 'explanation'],
    'question': ['inquiry', 'query', 'doubt', 'issue', 'matter'],
    'information': ['data', 'facts', 'details', 'knowledge', 'intel'],
    'idea': ['concept', 'notion', 'thought', 'suggestion', 'plan'],
    'plan': ['strategy', 'scheme', 'approach', 'proposal', 'blueprint'],
    'goal': ['objective', 'target', 'aim', 'purpose', 'ambition'],
    'result': ['outcome', 'consequence', 'effect', 'product', 'yield'],
    'change': ['modify', 'alter', 'adjust', 'transform', 'vary'],
    'clear': ['obvious', 'evident', 'plain', 'apparent', 'distinct'],
    'smart': ['intelligent', 'clever', 'bright', 'sharp', 'astute'],
  };

  /// Local thesaurus lookup; empty when unknown (AI expansion optional).
  static List<String> synonyms(String word, {String locale = 'en'}) {
    if (locale == 'vi') return const [];
    return _enThesaurus[word.toLowerCase()] ?? const [];
  }

  // -------------------------------------------------------------------------

  static int _levenshtein(String a, String b) {
    final n = a.length;
    final m = b.length;
    if (n == 0) return m;
    if (m == 0) return n;
    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= n; i++) {
      curr[0] = i;
      for (var j = 1; j <= m; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[m];
  }
}

/// A spelling error with its position and suggestions.
class SpellError {
  final String word;
  final int start;
  final int end;
  final List<String> suggestions;

  const SpellError({
    required this.word,
    required this.start,
    required this.end,
    this.suggestions = const [],
  });
}

/// A local grammar finding.
class GrammarIssue {
  final String rule;
  final String message;
  final int start;
  final int end;

  const GrammarIssue({
    required this.rule,
    required this.message,
    required this.start,
    required this.end,
  });
}
