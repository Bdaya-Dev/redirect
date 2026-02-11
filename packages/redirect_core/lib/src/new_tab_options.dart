import 'package:meta/meta.dart';

/// Configuration for the new browser tab opened via `window.open()`.
///
/// ```dart
/// WebRedirectOptions(
///   mode: WebRedirectMode.newTab,
///   newTabOptions: NewTabOptions(
///     windowName: '_blank',
///     windowFeatures: 'noopener',
///   ),
/// )
/// ```
@immutable
class NewTabOptions {
  /// Creates new tab options.
  const NewTabOptions({
    this.windowName = '_blank',
    this.windowFeatures,
  });

  /// The target name passed to `window.open()`.
  ///
  /// Defaults to `'_blank'` which opens a new tab.
  final String windowName;

  /// Optional browser features string passed to `window.open()`.
  ///
  /// When null, no features string is passed (browser defaults apply).
  ///
  /// Example: `'noopener,noreferrer'`
  final String? windowFeatures;

  /// Creates a copy with the given fields replaced.
  NewTabOptions copyWith({
    String? windowName,
    String? windowFeatures,
  }) {
    return NewTabOptions(
      windowName: windowName ?? this.windowName,
      windowFeatures: windowFeatures ?? this.windowFeatures,
    );
  }
}
