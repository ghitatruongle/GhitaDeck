import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enum định nghĩa tất cả actions có thể bind với keyboard shortcuts
enum ShortcutAction {
  // File operations
  newSlide,
  saveProject,
  exportPresentation,
  
  // Edit operations
  undo,
  redo,
  duplicateSlide,
  deleteSlide,
  
  // Navigation
  previousSlide,
  nextSlide,
  goToSlide,
  
  // Presentation
  startPresentation,
  startFromCurrentSlide,
  presenterView,
  
  // View
  toggleSidebar,
  toggleGrid,
  toggleRuler,
  commandPalette,
  
  // Editor
  selectAll,
  copy,
  paste,
  cut,

  // Format painter (Track 24)
  copyFormat,
  pasteFormat,
  eyedropper,
  
  // Zoom
  zoomIn,
  zoomOut,
  zoomReset,
}

/// Lớp quản lý keyboard shortcuts mặc định
class AppShortcuts {
  /// Map từ action → default shortcut
  static final Map<ShortcutAction, SingleActivator> _defaults = {
    // File operations
    ShortcutAction.newSlide: const SingleActivator(
      LogicalKeyboardKey.keyN,
      control: true,
    ),
    ShortcutAction.saveProject: const SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
    ),
    ShortcutAction.exportPresentation: const SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      shift: true,
    ),
    
    // Edit operations
    ShortcutAction.undo: const SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
    ),
    ShortcutAction.redo: const SingleActivator(
      LogicalKeyboardKey.keyY,
      control: true,
    ),
    ShortcutAction.duplicateSlide: const SingleActivator(
      LogicalKeyboardKey.keyD,
      control: true,
    ),
    ShortcutAction.deleteSlide: const SingleActivator(
      LogicalKeyboardKey.delete,
    ),
    
    // Navigation
    ShortcutAction.previousSlide: const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
    ),
    ShortcutAction.nextSlide: const SingleActivator(
      LogicalKeyboardKey.arrowRight,
    ),
    ShortcutAction.goToSlide: const SingleActivator(
      LogicalKeyboardKey.keyG,
      control: true,
    ),
    
    // Presentation
    ShortcutAction.startPresentation: const SingleActivator(
      LogicalKeyboardKey.f5,
    ),
    ShortcutAction.startFromCurrentSlide: const SingleActivator(
      LogicalKeyboardKey.f5,
      shift: true,
    ),
    ShortcutAction.presenterView: const SingleActivator(
      LogicalKeyboardKey.keyP,
      control: true,
      shift: true,
    ),
    
    // View
    ShortcutAction.toggleSidebar: const SingleActivator(
      LogicalKeyboardKey.keyB,
      control: true,
    ),
    ShortcutAction.toggleGrid: const SingleActivator(
      LogicalKeyboardKey.keyG,
      control: true,
      alt: true,
    ),
    ShortcutAction.toggleRuler: const SingleActivator(
      LogicalKeyboardKey.keyR,
      control: true,
      alt: true,
    ),
    ShortcutAction.commandPalette: const SingleActivator(
      LogicalKeyboardKey.keyK,
      control: true,
    ),
    
    // Editor
    ShortcutAction.selectAll: const SingleActivator(
      LogicalKeyboardKey.keyA,
      control: true,
    ),
    ShortcutAction.copy: const SingleActivator(
      LogicalKeyboardKey.keyC,
      control: true,
    ),
    ShortcutAction.paste: const SingleActivator(
      LogicalKeyboardKey.keyV,
      control: true,
    ),
    ShortcutAction.cut: const SingleActivator(
      LogicalKeyboardKey.keyX,
      control: true,
    ),

    // Format painter (Track 24): Ctrl+Shift+C / Ctrl+Shift+V
    ShortcutAction.copyFormat: const SingleActivator(
      LogicalKeyboardKey.keyC,
      control: true,
      shift: true,
    ),
    ShortcutAction.pasteFormat: const SingleActivator(
      LogicalKeyboardKey.keyV,
      control: true,
      shift: true,
    ),
    ShortcutAction.eyedropper: const SingleActivator(
      LogicalKeyboardKey.keyI,
      control: true,
      shift: true,
    ),
    
    // Zoom
    ShortcutAction.zoomIn: const SingleActivator(
      LogicalKeyboardKey.equal,
      control: true,
    ),
    ShortcutAction.zoomOut: const SingleActivator(
      LogicalKeyboardKey.minus,
      control: true,
    ),
    ShortcutAction.zoomReset: const SingleActivator(
      LogicalKeyboardKey.digit0,
      control: true,
    ),
  };

  /// Get default shortcut cho một action
  static SingleActivator getDefault(ShortcutAction action) {
    // orElse guards against a future enum entry missing a default — the
    // previous `!` would hard-crash on lookup.
    return _defaults[action] ??
        const SingleActivator(LogicalKeyboardKey.keyA, control: true);
  }

  /// Get tất cả default shortcuts
  static Map<ShortcutAction, SingleActivator> getAllDefaults() {
    return Map.from(_defaults);
  }

  /// Convert shortcut thành string để hiển thị
  static String shortcutToString(SingleActivator shortcut) {
    final parts = <String>[];
    
    if (shortcut.control) parts.add('Ctrl');
    if (shortcut.shift) parts.add('Shift');
    if (shortcut.alt) parts.add('Alt');
    
    // Convert logical key to readable string
    final keyLabel = _keyLabel(shortcut.trigger);
    parts.add(keyLabel);
    
    return parts.join(' + ');
  }

  /// Get readable label cho một action
  static String actionLabel(ShortcutAction action) {
    return switch (action) {
      ShortcutAction.newSlide => 'New Slide',
      ShortcutAction.saveProject => 'Save Project',
      ShortcutAction.exportPresentation => 'Export Presentation',
      ShortcutAction.undo => 'Undo',
      ShortcutAction.redo => 'Redo',
      ShortcutAction.duplicateSlide => 'Duplicate Slide',
      ShortcutAction.deleteSlide => 'Delete Slide',
      ShortcutAction.previousSlide => 'Previous Slide',
      ShortcutAction.nextSlide => 'Next Slide',
      ShortcutAction.goToSlide => 'Go to Slide',
      ShortcutAction.startPresentation => 'Start Presentation',
      ShortcutAction.startFromCurrentSlide => 'Start from Current Slide',
      ShortcutAction.presenterView => 'Presenter View',
      ShortcutAction.toggleSidebar => 'Toggle Sidebar',
      ShortcutAction.toggleGrid => 'Toggle Grid',
      ShortcutAction.toggleRuler => 'Toggle Ruler',
      ShortcutAction.commandPalette => 'Command Palette',
      ShortcutAction.selectAll => 'Select All',
      ShortcutAction.copy => 'Copy',
      ShortcutAction.paste => 'Paste',
      ShortcutAction.cut => 'Cut',
      ShortcutAction.copyFormat => 'Copy Format',
      ShortcutAction.pasteFormat => 'Paste Format',
      ShortcutAction.eyedropper => 'Eyedropper',
      ShortcutAction.zoomIn => 'Zoom In',
      ShortcutAction.zoomOut => 'Zoom Out',
      ShortcutAction.zoomReset => 'Reset Zoom',
    };
  }

  /// Convert LogicalKeyboardKey thành readable string
  static String _keyLabel(LogicalKeyboardKey key) {
    final keyId = key.keyId;
    
    // Special keys
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';
    
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'Page Up';
    if (key == LogicalKeyboardKey.pageDown) return 'Page Down';
    
    // Regular keys
    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty) return keyLabel.toUpperCase();
    
    // Fallback to keyId
    return 'Key $keyId';
  }

  /// Parse shortcut từ string (format: "Ctrl+Shift+A")
  static SingleActivator? parseShortcut(String shortcutString) {
    try {
      final parts = shortcutString.split('+').map((s) => s.trim()).toList();
      
      bool control = false;
      bool shift = false;
      bool alt = false;
      LogicalKeyboardKey? trigger;
      
      for (final part in parts) {
        final lower = part.toLowerCase();
        if (lower == 'ctrl' || lower == 'control') {
          control = true;
        } else if (lower == 'shift') {
          shift = true;
        } else if (lower == 'alt') {
          alt = true;
        } else {
          // This is the trigger key
          trigger = _parseKey(part);
          if (trigger == null) return null;
        }
      }
      
      if (trigger == null) return null;
      
      return SingleActivator(
        trigger,
        control: control,
        shift: shift,
        alt: alt,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse key string thành LogicalKeyboardKey
  static LogicalKeyboardKey? _parseKey(String keyString) {
    final lower = keyString.toLowerCase();
    
    // Function keys
    if (lower == 'f1') return LogicalKeyboardKey.f1;
    if (lower == 'f2') return LogicalKeyboardKey.f2;
    if (lower == 'f3') return LogicalKeyboardKey.f3;
    if (lower == 'f4') return LogicalKeyboardKey.f4;
    if (lower == 'f5') return LogicalKeyboardKey.f5;
    if (lower == 'f6') return LogicalKeyboardKey.f6;
    if (lower == 'f7') return LogicalKeyboardKey.f7;
    if (lower == 'f8') return LogicalKeyboardKey.f8;
    if (lower == 'f9') return LogicalKeyboardKey.f9;
    if (lower == 'f10') return LogicalKeyboardKey.f10;
    if (lower == 'f11') return LogicalKeyboardKey.f11;
    if (lower == 'f12') return LogicalKeyboardKey.f12;
    
    // Special keys
    if (lower == 'delete' || lower == 'del') return LogicalKeyboardKey.delete;
    if (lower == 'backspace') return LogicalKeyboardKey.backspace;
    if (lower == 'enter' || lower == 'return') return LogicalKeyboardKey.enter;
    if (lower == 'escape' || lower == 'esc') return LogicalKeyboardKey.escape;
    if (lower == 'space') return LogicalKeyboardKey.space;
    if (lower == 'tab') return LogicalKeyboardKey.tab;
    
    // Arrow keys
    if (lower == 'up' || lower == '↑') return LogicalKeyboardKey.arrowUp;
    if (lower == 'down' || lower == '↓') return LogicalKeyboardKey.arrowDown;
    if (lower == 'left' || lower == '←') return LogicalKeyboardKey.arrowLeft;
    if (lower == 'right' || lower == '→') return LogicalKeyboardKey.arrowRight;
    
    // Navigation keys
    if (lower == 'home') return LogicalKeyboardKey.home;
    if (lower == 'end') return LogicalKeyboardKey.end;
    if (lower == 'pageup') return LogicalKeyboardKey.pageUp;
    if (lower == 'pagedown') return LogicalKeyboardKey.pageDown;
    
    // Letters A-Z
    if (lower.length == 1 && lower.codeUnitAt(0) >= 97 && lower.codeUnitAt(0) <= 122) {
      return LogicalKeyboardKey(0x0000000061 + lower.codeUnitAt(0) - 97);
    }
    
    // Numbers 0-9
    if (lower.length == 1 && lower.codeUnitAt(0) >= 48 && lower.codeUnitAt(0) <= 57) {
      return LogicalKeyboardKey(0x0000000030 + lower.codeUnitAt(0) - 48);
    }
    
    // Symbols
    if (lower == '=' || lower == 'equal' || lower == 'plus') return LogicalKeyboardKey.equal;
    if (lower == '-' || lower == 'minus') return LogicalKeyboardKey.minus;
    
    return null;
  }
}
