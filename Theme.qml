pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property var fallback: {
        "background": "#1e1e2e",
        "surface": "#313244",
        "surfaceHover": "#45475a",
        "highlight": "#585b70",
        "accent": "#cba6f7",
        "accentAlt": "#f38ba8",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "danger": "#f38ba8",
        "dangerBg": "#45475a",
        "dangerHover": "#eba0ac",
        "border": "#89b4fa"
    }

    // 1. Real QML properties instead of a JS object binding
    property color background: fallback.background
    property color surface: fallback.surface
    property color surfaceHover: fallback.surfaceHover
    property color highlight: fallback.highlight
    property color accent: fallback.accent
    property color accentAlt: fallback.accentAlt
    property color text: fallback.text
    property color subtext: fallback.subtext
    property color danger: fallback.danger
    property color dangerBg: fallback.dangerBg
    property color dangerHover: fallback.dangerHover
    property color border: fallback.border

    // 2. The Live-Reload Watcher
    property var colorWatcher: FileView {
        id: fileView
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: fileView.reload()
        onTextChanged: {
            // Read the text as a property
            let currentText = fileView.text() ? fileView.text().trim() : ""
            
            // Only parse if the string actually looks like a JSON object
            if (currentText.startsWith("{") && currentText.endsWith("}")) {
                try {
                    let parsed = JSON.parse(currentText)
                    
                    root.background = parsed.background || fallback.background
                    root.surface = parsed.surface || fallback.surface
                    root.surfaceHover = parsed.surfaceHover || fallback.surfaceHover
                    root.highlight = parsed.highlight || fallback.highlight
                    root.accent = parsed.accent || fallback.accent
                    root.accentAlt = parsed.accentAlt || fallback.accentAlt
                    root.text = parsed.text || fallback.text
                    root.subtext = parsed.subtext || fallback.subtext
                    root.danger = parsed.danger || fallback.danger
                    root.dangerBg = parsed.dangerBg || fallback.dangerBg
                    root.dangerHover = parsed.dangerHover || fallback.dangerHover
                    root.border = parsed.border || fallback.border
                    
                    console.log("[Theme] Colors successfully updated!")
                } catch (e) {
                    console.log("[Theme] JSON Parse Error on valid string:", e)
                }
            }
        }
    }
}
