import 'package:meta/meta.dart';

/// Configuration for the popup window opened via `window.open()`.
///
/// Controls the size, position, and browser chrome features of the popup.
///
/// ```dart
/// WebRedirectOptions(
///   mode: WebRedirectMode.popup,
///   popupOptions: PopupOptions(
///     width: 600,
///     height: 800,
///     windowFeatures: 'scrollbars=yes,resizable=yes',
///   ),
/// )
/// ```
@immutable
class PopupOptions {
  /// Creates popup window options.
  const PopupOptions({
    this.width = 500,
    this.height = 700,
    this.left,
    this.top,
    this.windowName = 'redirect_popup',
    this.windowFeatures,
  });

  /// Width of the popup window in pixels.
  ///
  /// Defaults to 500.
  final int width;

  /// Height of the popup window in pixels.
  ///
  /// Defaults to 700.
  final int height;

  /// Left position of the popup window in pixels.
  ///
  /// If null, the popup is centered horizontally on the screen.
  final int? left;

  /// Top position of the popup window in pixels.
  ///
  /// If null, the popup is centered vertically on the screen.
  final int? top;

  /// The target name passed to `window.open()`.
  ///
  /// Defaults to `'redirect_popup'`.
  final String windowName;

  /// Additional browser-chrome features passed to `window.open()`.
  ///
  /// When set, size/position fields (`width`, `height`, `left`, `top`) are
  /// still prepended, and this string is appended. Use this to control
  /// toolbar, menubar, status bar, etc.
  ///
  /// Example: `'toolbar=yes,menubar=no,status=yes'`
  ///
  /// When null, defaults to `'toolbar=no,menubar=no,scrollbars=yes,resizable=yes'`.
  final String? windowFeatures;

  /// Creates a copy with the given fields replaced.
  PopupOptions copyWith({
    int? width,
    int? height,
    int? left,
    int? top,
    String? windowName,
    String? windowFeatures,
  }) {
    return PopupOptions(
      width: width ?? this.width,
      height: height ?? this.height,
      left: left ?? this.left,
      top: top ?? this.top,
      windowName: windowName ?? this.windowName,
      windowFeatures: windowFeatures ?? this.windowFeatures,
    );
  }
}
