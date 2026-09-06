pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    readonly property int minimumSelectionSize: 8
    property bool active: false
    property bool isFreezing: false
    property string currentAction: ""
    property var currentOptions: ({})
    property string pendingAction: ""
    property string pendingGeometry: ""
    property var pendingOptions: ({})
    property string pendingScreenName: ""
    property real pendingLocalX: 0
    property real pendingLocalY: 0
    property real pendingWidth: 0
    property real pendingHeight: 0
    property double freezeTimestamp: 0

    signal selectionAccepted(string action, string geometry, var options)
    signal selectionCancelled(string action)

    function begin(action, options) {
        if (root.active || root.isFreezing || commitDelay.running || !action)
            return false;

        root.currentAction = String(action);
        root.currentOptions = options || {};
        root.isFreezing = true;
        root.freezeTimestamp = Date.now();

        const cmd = `
            for s in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null); do
                grim -l 0 -o "$s" "/dev/shm/mshell_freeze_$s.png" &
            done
            wait
        `;
        freezeProcess.command = ["bash", "-c", cmd];
        freezeProcess.running = true;
        return true;
    }

    Process {
        id: freezeProcess
        onExited: (exitCode) => {
            root.isFreezing = false;
            root.active = true;
        }
    }

    function accept(targetScreen, x, y, width, height) {
        if (!root.active || !targetScreen)
            return false;

        const localX = Math.round(x);
        const localY = Math.round(y);
        const selectedWidth = Math.round(width);
        const selectedHeight = Math.round(height);
        if (selectedWidth < root.minimumSelectionSize || selectedHeight < root.minimumSelectionSize)
            return false;

        const globalX = Math.round(targetScreen.x + localX);
        const globalY = Math.round(targetScreen.y + localY);
        root.pendingAction = root.currentAction;
        root.pendingGeometry = selectedWidth + "x" + selectedHeight + "+" + globalX + "+" + globalY;
        root.pendingOptions = root.currentOptions;
        root.pendingScreenName = targetScreen.name || "";
        root.pendingLocalX = localX;
        root.pendingLocalY = localY;
        root.pendingWidth = selectedWidth;
        root.pendingHeight = selectedHeight;
        root.active = false;
        commitDelay.restart();
        return true;
    }

    function cancel() {
        if (!root.active && !root.isFreezing)
            return false;

        const action = root.currentAction;
        root.active = false;
        root.isFreezing = false;
        root.currentAction = "";
        root.currentOptions = {};
        cleanupProcess.command = ["bash", "-c", "rm -f /dev/shm/mshell_freeze_*.png"];
        cleanupProcess.running = true;
        root.selectionCancelled(action);
        return true;
    }

    Process {
        id: cleanupProcess
    }

    Timer {
        id: commitDelay
        interval: 40
        repeat: false

        onTriggered: {
            const action = root.pendingAction;
            const geometry = root.pendingGeometry;
            const options = root.pendingOptions;
            const screenName = root.pendingScreenName;
            const lx = root.pendingLocalX;
            const ly = root.pendingLocalY;
            const w = root.pendingWidth;
            const h = root.pendingHeight;

            root.pendingAction = "";
            root.pendingGeometry = "";
            root.pendingOptions = {};
            root.pendingScreenName = "";
            root.currentAction = "";
            root.currentOptions = {};
            root.selectionAccepted(action, geometry, options);
            root.executeAction(action, geometry, screenName, lx, ly, w, h);
        }
    }

    Process {
        id: captureProcess
    }

    function executeAction(action, geometry, screenName, lx, ly, w, h) {
        if (action === "screenshot") {
            const cmd = `
                OUT_DIR="$HOME/Pictures/Screenshots"
                mkdir -p "$OUT_DIR"
                FILE="$OUT_DIR/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
                FROZEN="/dev/shm/mshell_freeze_${screenName}.png"
                if [ -f "$FROZEN" ]; then
                    magick "$FROZEN" -crop "${w}x${h}+${lx}+${ly}" +repage "$FILE"
                else
                    grim -g "${geometry}" "$FILE"
                fi
                rm -f /dev/shm/mshell_freeze_*.png
                if [ -f "$FILE" ]; then
                    wl-copy < "$FILE"
                    notify-send -a "mshell" -u normal -t 3000 -i "$FILE" "Screenshot Captured" "Saved to Screenshots and copied to clipboard"
                fi
            `;
            captureProcess.command = ["bash", "-c", cmd];
            captureProcess.running = true;
        } else if (action === "ocr") {
            const cmd = `
                FROZEN="/dev/shm/mshell_freeze_${screenName}.png"
                TMP_CROP="/dev/shm/mshell_ocr_crop.png"
                if [ -f "$FROZEN" ]; then
                    magick "$FROZEN" -crop "${w}x${h}+${lx}+${ly}" +repage "$TMP_CROP"
                else
                    grim -g "${geometry}" "$TMP_CROP"
                fi
                TEXT=$(tesseract "$TMP_CROP" stdout 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                rm -f "$TMP_CROP" /dev/shm/mshell_freeze_*.png
                if [ -n "$TEXT" ]; then
                    echo -n "$TEXT" | wl-copy
                    notify-send -a "mshell" -u normal -t 3500 "OCR Text Copied" "$TEXT"
                else
                    notify-send -a "mshell" -u normal -t 2500 "OCR" "No text detected in selected region"
                fi
            `;
            captureProcess.command = ["bash", "-c", cmd];
            captureProcess.running = true;
        }
    }
}
