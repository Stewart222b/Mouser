import QtQuick
import "Theme.js" as Theme

// Keep settings readable while following the window through resize/maximize.
Column {
    property real viewportWidth: 0
    property real maximumWidth: Theme.pageMaximumWidth
    property real gutter: Theme.pageGutter
    width: Math.max(0, Math.min(viewportWidth - 2 * gutter, maximumWidth))
    x: Math.max(gutter, (viewportWidth - width) / 2)
}
