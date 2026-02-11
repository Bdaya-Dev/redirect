import 'package:meta/meta.dart';

/// Configuration for the iframe element created for iframe-mode redirects.
///
/// Controls visibility, dimensions, sandbox policy, permissions, and styling
/// of the iframe element.
///
/// ```dart
/// WebRedirectOptions(
///   mode: WebRedirectMode.iframe,
///   iframeOptions: IframeOptions(
///     hidden: true,
///     sandbox: 'allow-same-origin allow-scripts allow-forms',
///   ),
/// )
/// ```
@immutable
class IframeOptions {
  /// Creates iframe options.
  const IframeOptions({
    this.id = 'redirect_iframe',
    this.hidden = true,
    this.width,
    this.height,
    this.sandbox = 'allow-same-origin allow-scripts allow-forms',
    this.allow,
    this.style,
    this.parentSelector = 'body',
  });

  /// The DOM `id` attribute of the iframe element.
  ///
  /// Defaults to `'redirect_iframe'`.
  final String id;

  /// Whether the iframe is hidden (`display: none`).
  ///
  /// Defaults to `true`. Set to `false` to make the iframe visible,
  /// for example when embedding a payment or consent form.
  final bool hidden;

  /// Width of the iframe in pixels.
  ///
  /// Only applied when [hidden] is `false`. Ignored when the iframe is hidden.
  final int? width;

  /// Height of the iframe in pixels.
  ///
  /// Only applied when [hidden] is `false`. Ignored when the iframe is hidden.
  final int? height;

  /// The `sandbox` attribute value for the iframe.
  ///
  /// Controls security restrictions on the embedded content.
  /// See [MDN sandbox docs](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/iframe#sandbox)
  /// for available tokens.
  ///
  /// Defaults to `'allow-same-origin allow-scripts allow-forms'`.
  ///
  /// Set to an empty string (`''`) to apply maximum restrictions, or
  /// set to `null` to omit the sandbox attribute entirely (no restrictions).
  final String? sandbox;

  /// The Permissions Policy (`allow` attribute) for the iframe.
  ///
  /// Controls which browser features the iframe content can access
  /// (camera, microphone, geolocation, etc.).
  ///
  /// See [MDN allow docs](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/iframe#allow).
  ///
  /// Example: `'camera; microphone; geolocation'`
  ///
  /// When null, no `allow` attribute is set (browser defaults apply).
  final String? allow;

  /// Custom inline CSS style string for the iframe element.
  ///
  /// When [hidden] is `true`, `display: none` is always applied regardless
  /// of this value. When [hidden] is `false`, this style string is set
  /// directly on the iframe element.
  ///
  /// Example: `'border: 1px solid #ccc; border-radius: 8px;'`
  final String? style;

  /// A CSS selector for the parent element to append the iframe to.
  ///
  /// Uses `document.querySelector()` to locate the parent. Defaults to
  /// `'body'`.
  ///
  /// Examples:
  /// - `'body'` (default) — appends to `<body>`
  /// - `'#my-container'` — appends to the element with `id="my-container"`
  /// - `'.iframe-wrapper'` — appends to the first element with that class
  final String parentSelector;

  /// Creates a copy with the given fields replaced.
  IframeOptions copyWith({
    String? id,
    bool? hidden,
    int? width,
    int? height,
    String? sandbox,
    String? allow,
    String? style,
    String? parentSelector,
  }) {
    return IframeOptions(
      id: id ?? this.id,
      hidden: hidden ?? this.hidden,
      width: width ?? this.width,
      height: height ?? this.height,
      sandbox: sandbox ?? this.sandbox,
      allow: allow ?? this.allow,
      style: style ?? this.style,
      parentSelector: parentSelector ?? this.parentSelector,
    );
  }
}
