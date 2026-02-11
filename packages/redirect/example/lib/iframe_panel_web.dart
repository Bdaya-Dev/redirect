import 'package:web/web.dart' as web;

/// Toggles the iframe side panel visibility via the DOM.
void setIframePanelVisible(bool visible) {
  final container =
      web.document.getElementById('iframe-container') as web.HTMLElement?;
  if (container != null) {
    container.style.display = visible ? '' : 'none';
  }
}
