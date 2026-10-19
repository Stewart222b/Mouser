.pragma library

var radius = 6
var pageGutter = 32
var pageMaximumWidth = 1280
var pageTopPadding = 24
var pageHeaderHeight = 52

// Brand-asset colors are intentionally theme-independent: the sidebar
// brand mark draws a pocket-sized echo of the macOS Dock tile, so it
// must render identically under light and dark appearances. Keep these
// in one place so a future brand refresh updates the squircle, the
// Dock icon source artwork, and the build pipeline together.
var brandMarkBg = "#202020"
var brandMarkFg = "#ffffff"

function palette(isDark) {
    if (isDark) {
        return {
            bg: "#202020",
            bgElevated: "#282828",
            bgCard: "#282828",
            bgCardHover: "#353535",
            bgSidebar: "#202020",
            bgInput: "#202020",
            bgSubtle: "#242424",
            accent: "#9ec2e3",
            accentHover: "#b6d4ef",
            accentDim: "#33404b",
            textPrimary: "#ececec",
            textSecondary: "#b0b0b0",
            textDim: "#999999",
            border: "#444444",
            danger: "#ff6b6b",
            dangerBg: "#5b1f26",
            success: "#9ec2e3",
            warning: "#ffb347",
            tooltipBg: "#383838",
            tooltipText: "#f8fafc",
            brandMarkBg: brandMarkBg,
            brandMarkFg: brandMarkFg
        }
    }

    return {
        bg: "#f3f3f3",
        bgElevated: "#ffffff",
        bgCard: "#ffffff",
        bgCardHover: "#ececec",
        bgSidebar: "#eeeeee",
        bgInput: "#ffffff",
        bgSubtle: "#f6f6f6",
        accent: "#315d85",
        accentHover: "#254d72",
        accentDim: "#e8edf2",
        textPrimary: "#242424",
        textSecondary: "#606060",
        textDim: "#707070",
        border: "#dedede",
        danger: "#c73c4c",
        dangerBg: "#fbe3e7",
        success: "#315d85",
        warning: "#b7791f",
        tooltipBg: "#202938",
        tooltipText: "#f8fafc",
        brandMarkBg: brandMarkBg,
        brandMarkFg: brandMarkFg
    }
}

function alpha(hex, opacity) {
    return Qt.rgba(parseInt(hex.slice(1, 3), 16) / 255,
                   parseInt(hex.slice(3, 5), 16) / 255,
                   parseInt(hex.slice(5, 7), 16) / 255, opacity)
}
