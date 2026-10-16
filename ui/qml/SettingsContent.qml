import QtQuick

// Keep settings readable while following the window through resize/maximize.
Column {
    property real viewportWidth: 0
    property real maximumWidth: 1280
    property real gutter: 32
    width: Math.max(0, Math.min(viewportWidth - 2 * gutter, maximumWidth))
    x: Math.max(gutter, (viewportWidth - width) / 2)
}
