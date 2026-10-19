import QtQuick
import "Theme.js" as Theme

// Share the page's left edge, while keeping labels close to their controls.
Column {
    width: Math.min(parent.width, Theme.settingsMaximumWidth)
}
