import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'snackbar_helper.dart';

/// Utility class để map technical errors thành user-friendly messages
/// Hỗ trợ cả tiếng Việt và tiếng Anh
class ErrorMapper {
  /// Map error object thành message thân thiện với user
  /// [error]: Error object (Exception, Error, etc.)
  /// [locale]: Locale để xác định ngôn ngữ ('vi' hoặc 'en')
  /// [context]: Optional context cho các trường hợp đặc biệt
  static String mapErrorToUserMessage(
    Object error, {
    String locale = 'vi',
    BuildContext? context,
  }) {
    final errorString = error.toString();
    
    // Network errors
    if (error is SocketException) {
      return locale == 'vi'
          ? 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối internet của bạn.'
          : 'Cannot connect to network. Please check your internet connection.';
    }
    
    // Timeout errors
    if (error is TimeoutException) {
      return locale == 'vi'
          ? 'Yêu cầu đã hết thời gian. Vui lòng thử lại.'
          : 'Request timed out. Please try again.';
    }
    
    // HTTP errors
    if (error is HttpException) {
      return _mapHttpException(error, locale);
    }
    
    // File system errors
    if (error is FileSystemException) {
      return _mapFileSystemException(error, locale);
    }
    
    // Format errors
    if (error is FormatException) {
      return locale == 'vi'
          ? 'Dữ liệu không hợp lệ. Vui lòng kiểm tra định dạng.'
          : 'Invalid data. Please check the format.';
    }
    
    // Path errors
    if (error is PathAccessException) {
      return locale == 'vi'
          ? 'Không thể truy cập đường dẫn. Vui lòng kiểm tra quyền truy cập.'
          : 'Cannot access path. Please check permissions.';
    }
    
    // HTTP status code errors (từ response)
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return locale == 'vi'
          ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
          : 'Session expired. Please log in again.';
    }
    
    if (errorString.contains('403') || errorString.contains('Forbidden')) {
      return locale == 'vi'
          ? 'Bạn không có quyền thực hiện thao tác này.'
          : 'You do not have permission to perform this action.';
    }
    
    if (errorString.contains('404') || errorString.contains('Not Found')) {
      return locale == 'vi'
          ? 'Không tìm thấy tài nguyên. Vui lòng kiểm tra lại.'
          : 'Resource not found. Please check again.';
    }
    
    if (errorString.contains('429') || errorString.contains('Too Many Requests')) {
      return locale == 'vi'
          ? 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng đợi một lúc rồi thử lại.'
          : 'Too many requests. Please wait a moment and try again.';
    }
    
    if (errorString.contains('500') || errorString.contains('Internal Server Error')) {
      return locale == 'vi'
          ? 'Lỗi máy chủ. Vui lòng thử lại sau.'
          : 'Server error. Please try again later.';
    }
    
    if (errorString.contains('503') || errorString.contains('Service Unavailable')) {
      return locale == 'vi'
          ? 'Dịch vụ tạm thời không khả dụng. Vui lòng thử lại sau.'
          : 'Service temporarily unavailable. Please try again later.';
    }
    
    // AI API specific errors
    if (errorString.contains('rate limit') || errorString.contains('quota')) {
      return locale == 'vi'
          ? 'Đã vượt quá giới hạn sử dụng API. Vui lòng đợi hoặc nâng cấp gói.'
          : 'API usage limit exceeded. Please wait or upgrade your plan.';
    }
    
    if (errorString.contains('invalid api key') || errorString.contains('unauthorized')) {
      return locale == 'vi'
          ? 'API key không hợp lệ. Vui lòng kiểm tra cài đặt.'
          : 'Invalid API key. Please check your settings.';
    }
    
    // Markdown/HTML parsing errors
    if (errorString.contains('markdown') || errorString.contains('parse')) {
      return locale == 'vi'
          ? 'Không thể phân tích nội dung. Vui lòng kiểm tra định dạng.'
          : 'Cannot parse content. Please check the format.';
    }
    
    // Default fallback
    return locale == 'vi'
        ? 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.'
        : 'An unexpected error occurred. Please try again.';
  }
  
  /// Map HTTP exception thành message
  static String _mapHttpException(HttpException error, String locale) {
    final message = error.message;
    
    if (message.contains('Connection refused')) {
      return locale == 'vi'
          ? 'Kết nối bị từ chối. Máy chủ có thể không khả dụng.'
          : 'Connection refused. Server may be unavailable.';
    }
    
    if (message.contains('Failed host lookup')) {
      return locale == 'vi'
          ? 'Không thể tìm thấy máy chủ. Vui lòng kiểm tra địa chỉ.'
          : 'Cannot find server. Please check the address.';
    }
    
    return locale == 'vi'
        ? 'Lỗi HTTP: ${error.message}'
        : 'HTTP error: ${error.message}';
  }
  
  /// Map file system exception thành message
  static String _mapFileSystemException(FileSystemException error, String locale) {
    final message = error.message;
    
    if (message.contains('No such file or directory') || 
        message.contains('does not exist')) {
      return locale == 'vi'
          ? 'Không tìm thấy tệp hoặc thư mục.'
          : 'File or directory not found.';
    }
    
    if (message.contains('Permission denied')) {
      return locale == 'vi'
          ? 'Không có quyền truy cập tệp. Vui lòng kiểm tra quyền.'
          : 'No permission to access file. Please check permissions.';
    }
    
    if (message.contains('File exists') || 
        message.contains('already exists')) {
      return locale == 'vi'
          ? 'Tệp đã tồn tại. Vui lòng chọn tên khác.'
          : 'File already exists. Please choose a different name.';
    }
    
    if (message.contains('No space left')) {
      return locale == 'vi'
          ? 'Không đủ dung lượng ổ đĩa. Vui lòng giải phóng không gian.'
          : 'Not enough disk space. Please free up space.';
    }
    
    return locale == 'vi'
        ? 'Lỗi tệp: ${error.message}'
        : 'File error: ${error.message}';
  }
  
  /// Hiển thị error message dưới dạng SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    Object error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final locale = Localizations.localeOf(context).languageCode;
    final message = mapErrorToUserMessage(error, locale: locale, context: context);
    
    showAppSnackBar(context, message);
  }
  
  /// Hiển thị error message dưới dạng dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    Object error, {
    String? title,
  }) async {
    final locale = Localizations.localeOf(context).languageCode;
    final message = mapErrorToUserMessage(error, locale: locale, context: context);
    
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? (locale == 'vi' ? 'Lỗi' : 'Error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(locale == 'vi' ? 'Đóng' : 'Close'),
          ),
        ],
      ),
    );
  }
}
