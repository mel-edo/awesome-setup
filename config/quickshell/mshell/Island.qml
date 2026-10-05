import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "."

Scope {
    IpcHandler {
        target: "island"
        function showOsd(value: string, type: string) {
            islandWindow.showOsd(Number(value), type)
        }
        function toggleCalendar() {
            if (islandWindow.islandState === "calendar") {
                islandWindow.closeToIdle()
            } else {
                islandWindow.islandState = "calendar"
            }
        }
        function openCalendar() {
            islandWindow.islandState = "calendar"
        }
        function showAgenda(day: string) {
            islandWindow.islandState = "calendar"
            if (day && day !== "") {
                let now = new Date()
                calendarPanel.selectDate(now.getFullYear(), now.getMonth() + 1, Number(day))
            } else {
                calendarPanel.setTab("agenda")
            }
        }
        function refreshCalendar() {
            if (!calendarProcess.running) calendarProcess.running = true
        }
    }

    IpcHandler {
        target: "record"
        function start() {
            islandWindow.isGpuRecording = true
            updateScreenShareState()
        }
        function stop() {
            islandWindow.isGpuRecording = false
            updateScreenShareState()
        }
    }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSource ].concat(Pipewire.nodes.values)
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            updateScreenShareState()
        }
    }

    function updateScreenShareState() {
        let sharing = false
        if (Pipewire.nodes && Pipewire.nodes.values) {
            for (let i = 0; i < Pipewire.nodes.values.length; i++) {
                let node = Pipewire.nodes.values[i]
                if (!node) continue
                let p = node.properties || {}
                let nodeName = (p["node.name"] || node.name || "").toLowerCase()
                let mediaClass = p["media.class"] || ""
                let mediaRole = p["media.role"] || ""
                
                // Detect xdg-desktop-portal-hyprland screencast streams (xdph-streaming-...)
                // or general portal screencopy streams
                if (nodeName.startsWith("xdph-") || nodeName.startsWith("xdg-desktop-portal") || nodeName.includes("screencopy")) {
                    sharing = true
                    break
                }
                // Check if Video/Source node exists that is not a hardware webcam
                if (mediaClass === "Video/Source" && mediaRole !== "Camera" && !nodeName.includes("v4l2")) {
                    sharing = true
                    break
                }
                if (mediaClass === "Stream/Input/Video" || mediaClass === "Stream/Output/Video") {
                    sharing = true
                    break
                }
            }
        }
        islandWindow.isScreenSharing = sharing || islandWindow.isGpuRecording
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            updateScreenShareState()
        }
    }

    Component.onCompleted: {
        updateScreenShareState()
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            let vol = Pipewire.defaultAudioSink.audio.volume;
            if (!isNaN(vol) && !SharedState.isSuppressingOsd) {
                islandWindow.showOsd(Math.round(vol * 100), "volume")
            }
        }
    }

    WlrLayershell {
        id: islandWindow
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: -1
        layer: WlrLayer.Top
        implicitHeight: 500
        implicitWidth: Screen.width
        color: "transparent"
        mask: Region {
            Region { item: mainPill }
            Region { item: recSatellite }
        }
        property var cavaValues: []
        property bool cavaActive: false
        property bool showClock: true
        property string islandState: "idle"
        property bool isHovered: false
        property bool postHubCava: false
        property var weatherToday: null
        property var weatherForecast: []
        property var calendarData: null
        property var calendarEventsByDate: ({})
        property var activePlayer: null
        property string currentTrackTitle: ""
        property int osdValue: 50
        property string osdType: "volume"
        property bool isOsdIdle: false
        property bool btInitialized: false
        property var btDeviceState: ({})
        property string latestBtDevice: ""
        property string latestBtBattery: ""
        property Notification activeNotification
        property string notifAppName: "System"
        property string notifSummary: ""
        property string notifBody: ""
        property string notifIcon: ""
        property string notifImage: ""
        property string weDir: Quickshell.env("HOME") + "/yo/SteamLibrary/steamapps/workshop/content/431960"
        property bool isDnd: false
        property string themeMode: "dark"
        property string activeWallCache: ""
        property bool wasPlaying: false
        property string persistentArtUrl: ""
        property var pendingOsd: null
        property bool pendingBt: false
        property string currentAudioSink: ""
        property bool isMediaPinned: false
        property bool isStartingUp: true
        property bool ignorePillHover: false
        property string lastTrackArtRaw: ""
        property bool isScreenSharing: false
        property bool isGpuRecording: false
        readonly property bool isMediaPlaying: activePlayer !== null && (activePlayer.playbackState === 1 || activePlayer.playbackState === "Playing")
        readonly property string currentArtUrl: persistentArtUrl || (activePlayer ? (activePlayer.trackArtUrl || "") : "")
        readonly property real mediaProgress: {
            if (!activePlayer || !activePlayer.length || activePlayer.length <= 0) return 0.0
            return Math.min(1.0, Math.max(0.0, (activePlayer.position || 0) / activePlayer.length))
        }
        property var pendingWallSwap: null
        property string currentWallType: activeWallCache.includes("431960") ? "animated" : "static"

        onWasPlayingChanged: {
            if (wasPlaying) {
                mediaUnpinTimer.stop()
            } else if (isMediaPinned) {
                mediaUnpinTimer.restart()
            }
        }

        Timer {
            id: mediaUnpinTimer
            interval: 5000 
            onTriggered: {
                if (islandWindow.isMediaPinned && !islandWindow.wasPlaying) {
                    islandWindow.isMediaPinned = false
                    if (islandWindow.islandState === "media") {
                        if (!pillHover.hovered) {
                            islandWindow.closeToIdle()
                        } else {
                            islandWindow.islandState = "hub"
                            islandWindow.postHubCava = false
                        }
                    }
                }
            }
        }

        Timer {
            id: asyncArtTimer
            interval: 1500
            onTriggered: {
                let player = islandWindow.activePlayer;
                if (player && player.trackArtUrl) {
                    let art = player.trackArtUrl;
                    islandWindow.persistentArtUrl = art + (art.includes('?') ? '&' : '?') + "nocache=" + Date.now();
                }
            }
        }

        Timer {
            id: startupTimer
            interval: 2000
            running: true
            onTriggered: islandWindow.isStartingUp = false
        }

        Timer {
            id: ignoreHoverTimer
            interval: 1000 
            onTriggered: {
                islandWindow.ignorePillHover = false;
                if (pillHover.hovered && !islandWindow.isMediaPinned) {
                    hubStayTimer.stop();
                    idleStayTimer.stop();
                    islandWindow.postHubCava = false;
                    hubDelayTimer.start();
                }
            }
        }

        Process {
            running: true
            command: ["bash", "-c", "cat ~/.cache/mshell/wall_cache.txt 2>/dev/null || echo ''"]
            stdout: StdioCollector { onStreamFinished: islandWindow.activeWallCache = text.trim() }
        }

        Process {
            id: brightnessWatcher
            running: true
            command: ["bash", "-c", "inotifywait -m -q -e modify /sys/class/backlight/*/brightness | while read -r _; do brightnessctl -m | awk -F, '{print int($4)}'; done"]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseInt(data.trim());
                    if (!isNaN(val) && !SharedState.isSuppressingOsd) {
                        islandWindow.showOsd(val, "brightness");
                    }
                }
            }
        }
        
        Process {
            running: true
            command: ["bash", "-c", "cat ~/.cache/mshell/mode_cache.txt 2>/dev/null || echo 'dark'"]
            stdout: StdioCollector { onStreamFinished: islandWindow.themeMode = text.trim() }
        }

        function closeToIdle() {
            if (islandWindow.isMediaPinned) {
                islandWindow.islandState = "media"
                islandWindow.postHubCava = true
                islandWindow.showClock = false
                hubDelayTimer.stop()
                hubStayTimer.stop()
                idleStayTimer.stop()
                notificationTimer.stop()
                osdTimeoutTimer.stop()
                alternateTimer.stop()
                return
            }
            islandState = "idle"
            islandWindow.postHubCava = false
            hubDelayTimer.stop()
            hubStayTimer.stop()
            idleStayTimer.stop()
            notificationTimer.stop()
            osdTimeoutTimer.stop()
            islandWindow.showClock = true 
            if (islandWindow.cavaActive) {
                alternateTimer.restart()
            } else {
                alternateTimer.stop()
            }
        }

        function showBtPopup() {
            if (islandWindow.islandState === "osd") {
                islandWindow.pendingBt = true
                return
            }
            
            if (islandWindow.islandState === "calendar" || 
                islandWindow.islandState === "notification" || 
                islandWindow.islandState === "notifications") return
                
            islandWindow.islandState = "bluetooth"
            islandWindow.postHubCava = false
            islandWindow.showClock = true
            alternateTimer.stop()
            hubStayTimer.restart()
        }

        Process { id: curtainProcess }

        function beginWallTransition(type, path, rawPreview, mode) {
            let nextCache = type === "animated" ? rawPreview : path
            if (islandWindow.activeWallCache === nextCache) return
            
            islandWindow.pendingWallSwap = { type: type, path: path, rawPreview: rawPreview, mode: mode }
            
            let isWeInvolved = (islandWindow.currentWallType === "animated" || type === "animated")
            
            if (!isWeInvolved) {
                islandWindow.activeWallCache = nextCache
                islandWindow.runPendingWallSwap()
                return
            }

            let curtainScript = "awww img --transition-type fade --transition-step 30 " + Quickshell.env("HOME") + "/.cache/mshell/curtain.png"
            curtainProcess.command = ["bash", "-c", curtainScript]
            curtainProcess.running = true
            
            islandWindow.activeWallCache = nextCache
            wallSettleTimer.interval = 500
            wallSettleTimer.restart()
        }

        Timer {
            id: wallSettleTimer
            onTriggered: islandWindow.runPendingWallSwap()
        }

        function runPendingWallSwap() {
            if (!islandWindow.pendingWallSwap) return
            let p = islandWindow.pendingWallSwap
            islandWindow.pendingWallSwap = null
            
            let script = Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/set_wall.sh"
            wallChangerProcess.command = ["bash", script, p.type, p.path, p.rawPreview, p.mode]
            wallChangerProcess.running = true
        }

        function weatherIcon(code) {
            let isNight = code.endsWith("n")
            if (code.startsWith("01")) return isNight ? "󰖔" : "󰖙" 
            if (code.startsWith("02")) return isNight ? "" : "󰖕" 
            if (code.startsWith("03") || code.startsWith("04")) return "󰖐" 
            if (code.startsWith("09") || code.startsWith("10")) return "󰖗" 
            if (code.startsWith("11")) return "󰖓" 
            if (code.startsWith("13")) return "󰖘" 
            if (code.startsWith("50")) return "󰖑" 
            return isNight ? "󰖔" : "󰖙" 
        }

        function showOsd(value, type) {
            if (SharedState.isSuppressingOsd) return;
            if (islandWindow.isStartingUp) {
                osdValue = value;
                osdType = type;
                return;
            }
            if (islandWindow.islandState === "bluetooth") {
                islandWindow.pendingBt = true
                hubStayTimer.stop()
            }
            islandWindow.pendingOsd = null
            osdValue = value
            osdType = type
            islandWindow.islandState = "osd"
            islandWindow.isOsdIdle = false
            osdIdleTimer.restart()
            osdTimeoutTimer.restart()
            islandWindow.showClock = true
            if (islandWindow.cavaActive) {
                alternateTimer.restart()
            }
        }

        function showMediaPopup() {
            if (islandWindow.islandState === "osd" || 
                islandWindow.islandState === "calendar" || 
                islandWindow.islandState === "notification" || 
                islandWindow.islandState === "notifications") return
            islandWindow.islandState = "media"
            islandWindow.postHubCava = true
            islandWindow.showClock = false
            alternateTimer.stop()
            if (!islandWindow.isMediaPinned) {
                hubStayTimer.restart()
            }
        }

        Timer {
            id: alternateTimer
            interval: islandWindow.showClock ? 11000 : 6000
            repeat: true
            onTriggered: {
                islandWindow.showClock = !islandWindow.showClock
                interval = islandWindow.showClock ? 11000 : 6000
                alternateTimer.restart()
            }
        }

        ListModel {
            id: wallpaperList
            Component.onCompleted: {
                fetchStaticWalls.running = true
                fetchWeWalls.running = true
            }
        }

        // Static wallpaper scan
        Process {
            id: fetchStaticWalls
            command: ["bash", "-c", "find ~/Downloads/Wallpapers -type f \\( -iname \\*.jpg -o -iname \\*.png -o -iname \\*.jpeg \\)"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let files = text.trim().split("\n").filter(x => x !== "")
                    for (let i = 0; i < files.length; i++) {
                        wallpaperList.append({
                            wallName: files[i].split('/').pop(),
                            type: "static",
                            path: files[i],
                            preview: "file://" + files[i] 
                        })
                    }
                }
            }
        }

        // Animated wallpaper scan
        Process {
            id: fetchWeWalls
            command: ["bash", "-c", "for p in " + islandWindow.weDir + "/*/project.json; do [ -f \"$p\" ] || continue; dir=$(dirname \"$p\"); title=$(grep -m 1 '\"title\"' \"$p\" | cut -d'\"' -f4); preview=$(find \"$dir\" -maxdepth 1 -type f \\( -iname 'preview.jpg' -o -iname 'preview.jpeg' -o -iname 'preview.png' -o -iname 'preview.gif' \\) | head -n 1); echo \"$dir:::$title:::$preview\"; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n").filter(x => x !== "")
                    for (let i = 0; i < lines.length; i++) {
                        let parts = lines[i].split(":::")
                        if (parts.length >= 3) {
                            let previewPath = parts[2] ? "file://" + parts[2] : "" 
                            wallpaperList.append({
                                wallName: parts[1],
                                type: "animated",
                                path: parts[0], 
                                preview: previewPath 
                            })
                        }
                    }
                }
            }
        }

        Process { id: wallChangerProcess }

        ListModel {
            id: notifQueue
            property int lastCount: 0
            onCountChanged: {
                if (count === 0 && count < lastCount && islandWindow.islandState === "notification") {
                    islandWindow.closeToIdle()
                }
                lastCount = count
            }
        }


        NotificationServer {
            id: notifServer
            function stripMarkup(str) {
                if (!str) return ""
                return str
                    .replace(/<(?!\/?(b|i|u|s|a)\b)[^>]*>/gi, "")
                    .replace(/&amp;/g, "&")
                    .replace(/&lt;/g, "<")
                    .replace(/&gt;/g, ">")
                    .replace(/&quot;/g, "\"")
            }

            onNotification: notification => {
                notification.tracked = true
                notifQueue.insert(0, {
                    nApp: notification.appName || "System",
                    nSum: notification.summary || "",
                    nBod: stripMarkup(notification.body || ""),
                    nIco: notification.appIcon || "",
                    nImg: notification.image || "",
                    nTime: Qt.formatDateTime(new Date(), "HH:mm")
                })

                if (notifQueue.count > 50) {
                    notifQueue.remove(50)
                }

                if (!islandWindow.isDnd) {
                    hubDelayTimer.stop()
                    hubStayTimer.stop()
                    idleStayTimer.stop()
                    osdTimeoutTimer.stop()
                    notifRenderTimer.restart()
                }
            }
        }

        Timer {
            id: notifRenderTimer
            interval: 30 
            onTriggered: {
                islandWindow.islandState = "notification"
                notificationTimer.restart()
            }
        }

        Timer {
            id: notificationTimer
            interval: 3000 
            onTriggered: {
                if (islandWindow.islandState === "notification") {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                let players = Mpris.players.values
                if (!players || players.length === 0) {
                    islandWindow.activePlayer = null
                    islandWindow.currentTrackTitle = ""
                    islandWindow.wasPlaying = false
                    return
                }
                
                let currentlyPlaying = null
                for (let i = 0; i < players.length; i++) {
                    let state = players[i].playbackState
                    if (state === 1 || state === "Playing") { 
                        currentlyPlaying = players[i]
                        break
                    }
                }

                if (!currentlyPlaying) {
                    let stillExists = false;
                    if (islandWindow.activePlayer) {
                        for (let i = 0; i < players.length; i++) {
                            if (players[i] === islandWindow.activePlayer) {
                                stillExists = true;
                                break;
                            }
                        }
                    }
                    currentlyPlaying = stillExists ? islandWindow.activePlayer : players[0]
                }
                
                islandWindow.activePlayer = currentlyPlaying ? currentlyPlaying : players[0]
                
                let isNowPlaying = currentlyPlaying !== null && (currentlyPlaying.playbackState === 1 || currentlyPlaying.playbackState === "Playing")
                let newTitle = islandWindow.activePlayer ? (islandWindow.activePlayer.trackTitle || "") : ""
                
                let titleChanged = (islandWindow.currentTrackTitle !== "" && newTitle !== "" && islandWindow.currentTrackTitle !== newTitle)
                let stateChangedToPlaying = (isNowPlaying && !islandWindow.wasPlaying)
                
                if ((titleChanged && isNowPlaying) || stateChangedToPlaying) {
                    if (titleChanged) {
                        let len = Number(islandWindow.activePlayer.length) || 0;
                        let pos = Number(islandWindow.activePlayer.position) || 0;
                        
                        let scale = 1000000;
                        if (len > 0 && len < 100000) scale = 1;
                        
                        let posSec = pos / scale;
                        let h = Math.floor(posSec / 3600);
                        let m = Math.floor((posSec % 3600) / 60);
                        let s = Math.floor(posSec % 60);
                        
                        let mStr = (h > 0 && m < 10) ? "0" + m : m;
                        let sStr = s < 10 ? "0" + s : s;
                        
                        progressContainer.ratio = len > 0 ? Math.min(Math.max(posSec / (len / scale), 0), 1) : 0;
                        progressContainer.durationText = isNaN(posSec) || posSec <= 0 ? "0:00" : (h > 0 ? h + ":" + mStr + ":" + sStr : mStr + ":" + sStr);
                    }
                    islandWindow.showMediaPopup()
                }

                let newArt = islandWindow.activePlayer ? (islandWindow.activePlayer.trackArtUrl || "") : ""
                let rawArtChanged = (islandWindow.lastTrackArtRaw !== newArt)
                let trackSwitched = (islandWindow.currentTrackTitle !== newTitle)

                if (trackSwitched || rawArtChanged) {
                    if (newArt !== "") {
                        islandWindow.persistentArtUrl = newArt + (newArt.includes('?') ? '&' : '?') + "nocache=" + Date.now()
                        if (trackSwitched && !rawArtChanged && newArt.startsWith("file://")) {
                            asyncArtTimer.restart()
                        }
                    } else if (!islandWindow.activePlayer) {
                        islandWindow.persistentArtUrl = ""
                    }
                    islandWindow.lastTrackArtRaw = newArt
                }
                
                islandWindow.currentTrackTitle = newTitle
                islandWindow.wasPlaying = isNowPlaying
            }
        }

        Timer {
            id: silenceTimer
            interval: 2500
            onTriggered: {
                islandWindow.cavaActive = false
                islandWindow.showClock = true
                islandWindow.postHubCava = false
                alternateTimer.stop()
            }
        }

        Timer {
            id: hubStayTimer
            interval: 3000
            onTriggered: {
                islandWindow.islandState = "idle" 
                if (islandWindow.cavaActive && islandWindow.postHubCava) {
                    idleStayTimer.start() 
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: btPopupDelayTimer
            interval: 1200 
            onTriggered: islandWindow.showBtPopup()
        }

        Timer {
            id: idleStayTimer
            interval: 3000 
            onTriggered: {
                islandWindow.postHubCava = false
                islandWindow.showClock = true 
                if (islandWindow.cavaActive) {
                    alternateTimer.restart() 
                }
                islandWindow.closeToIdle()
            }
        }

        Timer {
            id: hubDelayTimer
            interval: 80
            onTriggered: islandWindow.islandState = "hub"
        }

        Timer {
            id: osdTimeoutTimer
            interval: 2500 
            onTriggered: {
                if (islandWindow.pendingBt) {
                    islandWindow.pendingBt = false
                    islandWindow.islandState = "idle"
                    islandWindow.showBtPopup()
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: osdIdleTimer
            interval: 800
            onTriggered: islandWindow.isOsdIdle = true
        }

        Process {
            id: btWatcher
            running: true
            command: ["bash", "-c", "dbus-monitor --system \"interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'\" | grep --line-buffered '\"Connected\"'"]
            stdout: SplitParser {
                onRead: data => {
                    btFetchDelay.restart()
                }
            }
        }

        Timer {
            id: btFetchDelay
            interval: 2000 
            onTriggered: if (!btProcess.running) btProcess.running = true
        }

        Process {
            id: btProcess
            running: true
            command: ["bash", "-c", "bluetoothctl devices Connected | while read -r _ mac name; do bat=$(bluetoothctl info \"$mac\" | grep 'Battery Percentage:' | awk -F '[()]' '{print $2}'); [ -z \"$bat\" ] && bat=\"--\"; echo \"$mac|$name|$bat\"; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n").filter(x => x !== "")
                    let currentMacs = []
                    let now = Date.now()
                    let isMacPattern = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i

                    for (let i = 0; i < lines.length; i++) {
                        let parts = lines[i].split("|")
                        if (parts.length < 3) continue;
                        
                        let mac = parts[0].trim()
                        let name = parts[1].trim()
                        let bat = parts[2].trim()
                        
                        currentMacs.push(mac)

                        let altMac = mac.replace(/:/g, "-")
                        if (isMacPattern.test(name) || name === mac || name === altMac) continue;

                        if (!islandWindow.btDeviceState[mac]) {
                            islandWindow.btDeviceState[mac] = { firstSeen: now, shown: false }
                        }

                        let device = islandWindow.btDeviceState[mac]

                        if (!islandWindow.btInitialized) {
                            device.shown = true
                            continue;
                        }

                        if (!device.shown) {
                            let hasBattery = bat !== "--" && bat !== ""
                            let waitedLongEnough = (now - device.firstSeen) > 1000

                            if (hasBattery || waitedLongEnough) {
                                islandWindow.latestBtDevice = name
                                islandWindow.latestBtBattery = bat
                                btPopupDelayTimer.restart()
                                device.shown = true
                            }
                        }
                    }
                    let keys = Object.keys(islandWindow.btDeviceState)
                    for (let k = 0; k < keys.length; k++) {
                        if (!currentMacs.includes(keys[k])) {
                            delete islandWindow.btDeviceState[keys[k]]
                        }
                    }

                    if (!islandWindow.btInitialized) {
                        islandWindow.btInitialized = true
                    }
                }
            }
        }

        Process {
            id: cavaProcess
            command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/mshell.conf"]
            running: islandWindow.wasPlaying
            stdout: SplitParser {
                onRead: data => {
                    let bars = data.trim().split(";").filter(x => x !== "").map(Number)
                    if (bars.length > 0) {
                        islandWindow.cavaValues = bars
                        if (bars.some(v => v > 1)) {
                            if (!islandWindow.cavaActive) {
                                islandWindow.cavaActive = true
                                islandWindow.showClock = true 
                                if (islandWindow.islandState === "idle") {
                                    alternateTimer.restart()
                                }
                            }
                            silenceTimer.restart()
                        }
                    }
                }
            }
        }

        Process {
            id: weatherProcess
            command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/calendar/weather.sh"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
                        islandWindow.weatherToday = data.today
                        islandWindow.weatherForecast = data.forecast
                    } catch(e) {
                        console.log("[Weather] parse error:", e)
                    }
                }
            }
        }

        // Refresh weather every 15 minutes
        Timer { interval: 900000; running: true; repeat: true; onTriggered: { if (!weatherProcess.running) weatherProcess.running = true } }

        Process {
            id: calendarProcess
            command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/calendar/calendar_sync.py"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
                        islandWindow.calendarData = data
                        islandWindow.calendarEventsByDate = data.eventsByDate || ({})
                    } catch(e) {
                        console.log("[CalendarSync] parse error:", e)
                    }
                }
            }
        }

        // Refresh calendar every 15 minutes
        Timer { interval: 900000; running: true; repeat: true; onTriggered: { if (!calendarProcess.running) calendarProcess.running = true } }

        Rectangle {
            id: mainPill
            x: (parent.width - width) / 2
            anchors.top: parent.top
            
            // Main Width vals
            width: {
                let baseW = 180;
                if (islandWindow.islandState === "idle") baseW = 180
                else if (islandWindow.islandState === "audio") baseW = 460
                else if (islandWindow.islandState === "osd") baseW = 252
                else if (islandWindow.islandState === "media" || islandWindow.islandState === "hub" || islandWindow.islandState === "bluetooth") baseW = 350
                else if (islandWindow.islandState === "notification" || islandWindow.islandState === "notifications") baseW = 410
                else if (islandWindow.islandState === "calendar" || islandWindow.islandState === "wallpaper") baseW = 660

                return baseW
            }
            
            // Main Height vals
            height: {
                let baseH = 34;
                if (islandWindow.islandState === "idle") baseH = 34
                else if (islandWindow.islandState === "audio") baseH = 56 + Math.max(1, Math.min(audioPanel.outputDevices.length, 4)) * 40 + 16
                else if (islandWindow.islandState === "osd") baseH = 52
                else if (islandWindow.islandState === "media" || islandWindow.islandState === "hub" || islandWindow.islandState === "bluetooth") baseH = 68
                else if (islandWindow.islandState === "wallpaper") baseH = 290
                else if (islandWindow.islandState === "calendar") baseH = 320
                else if (islandWindow.islandState === "notification") {
                    if (notifQueue.count === 0) baseH = 34
                    else baseH = singleNotifCard.height + 16
                }
                else if (islandWindow.islandState === "notifications") {
                    if (notifQueue.count === 0) baseH = 68 
                    else baseH = notifCenterContainer.height + 16
                }

                return baseH
            }
            radius: {
                if (islandWindow.islandState === "calendar" || islandWindow.islandState === "wallpaper" || islandWindow.islandState === "audio" || islandWindow.islandState === "notifications") return 24
                return Math.min(24, height / 3)
            }
            topLeftRadius: 0
            topRightRadius: 0
            
            color: recMorphSurface.visible ? "transparent" : Theme.surface
            clip: true

            // Mask to keep top corners sharp during fluid morph animation
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: Theme.surface
                visible: recMorphSurface.visible
                z: -1
            }

            scale: 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutElastic; easing.overshoot: 2.0 } }

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }

            HoverHandler {
                id: pillHover
                onHoveredChanged: {
                    if (islandWindow.ignorePillHover || islandWindow.isMediaPinned) {
                        hubDelayTimer.stop();
                        return;
                    }
                    if (islandWindow.islandState === "notification" || notifRenderTimer.running) {
                        return;
                    }
                    if (hovered) {
                        if (islandWindow.isMediaPinned) return;
                        hubStayTimer.stop()
                        idleStayTimer.stop()
                        islandWindow.postHubCava = false
                        hubDelayTimer.start()
                    } else {
                        if (islandWindow.isMediaPinned) return;
                        hubDelayTimer.stop()
                        
                        if (islandWindow.cavaActive) {
                            islandWindow.islandState = "media" 
                            islandWindow.postHubCava = true
                            islandWindow.showClock = false
                            alternateTimer.stop()
                            hubStayTimer.start()
                        } else {
                            islandWindow.closeToIdle()
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 8



                Item {
                    id: osdLayout
                    anchors.centerIn: parent
                    width: 220
                    height: 36 
                    
                    property bool isActiveOsd: islandWindow.islandState === "osd"
                    visible: isActiveOsd
                    opacity: isActiveOsd ? 1 : 0
                    Behavior on opacity { 
                        SequentialAnimation {
                            PauseAnimation { duration: osdLayout.isActiveOsd ? 150 : 0 }
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }
                    }

                    // Base track
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.highlight
                    }

                    // Progress fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        
                        width: sliderHead.x + sliderHead.width 
                        radius: height / 2 
                        
                        color: islandWindow.osdValue > 100 ? Theme.danger : Theme.accent
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Draggable head
                    Rectangle {
                        id: sliderHead
                        width: parent.height 
                        height: parent.height
                        radius: width / 2
                        color: Theme.text
                        
                        x: (Math.min(islandWindow.osdValue, 100) / 100) * (parent.width - width)
                        
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (islandWindow.osdType === "volume") {
                                    if (islandWindow.osdValue <= 0) return "󰖁" 
                                    if (islandWindow.osdValue < 33) return "󰕿" 
                                    if (islandWindow.osdValue < 66) return "󰖀" 
                                    return "󰕾" 
                                } else {
                                    if (islandWindow.osdValue < 33) return "󰃞" 
                                    if (islandWindow.osdValue < 66) return "󰃟" 
                                    return "󰃠" 
                                }
                            }
                            color: Theme.background
                            font.pixelSize: {
                                if (islandWindow.osdType === "volume") {
                                    return 18
                                } else {
                                    return 16
                                }
                            }
                            
                            opacity: islandWindow.isOsdIdle ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }

                        // Hover percentage label
                        Text {
                            anchors.centerIn: parent
                            text: islandWindow.osdValue
                            color: Theme.background
                            font.pixelSize: 13
                            font.bold: true
                            
                            opacity: islandWindow.isOsdIdle ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }
                    }
                }

                // Single notification popup
                Item {
                    id: singleNotifCard
                    width: 380
                    height: popupCard.height
                    anchors.centerIn: parent

                    property bool isActivePopup: islandWindow.islandState === "notification"
                    visible: isActivePopup
                    opacity: isActivePopup ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) notificationTimer.stop()
                            else if (singleNotifCard.isActivePopup) notificationTimer.restart()
                        }
                    }

                    NotifCard {
                        id: popupCard
                        width: 380
                        nApp: notifQueue.count > 0 ? notifQueue.get(0).nApp : ""
                        nSum: notifQueue.count > 0 ? notifQueue.get(0).nSum : ""
                        nBod: notifQueue.count > 0 ? notifQueue.get(0).nBod : ""
                        nIco: notifQueue.count > 0 ? notifQueue.get(0).nIco : ""
                        nImg: notifQueue.count > 0 ? notifQueue.get(0).nImg : ""
                        nTime: notifQueue.count > 0 ? notifQueue.get(0).nTime : ""
                        index: 0
                        isPopup: true
                        visible: notifQueue.count > 0
                    }
                }

                // Full notification center
                Item {
                    id: notifCenterContainer
                    width: 380
                    height: notifQueue.count === 0 ? 32 : Math.min(notifList.contentHeight + 48, 300)
                    anchors.centerIn: parent

                    property bool isActiveCenter: islandWindow.islandState === "notifications"
                    visible: isActiveCenter
                    opacity: isActiveCenter ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                notificationTimer.stop()
                            } else if (notifCenterContainer.isActiveCenter) {
                                notificationTimer.restart()
                            }
                        }
                    }

                    // Header Section
                    Item {
                        id: notifHeader
                        width: parent.width
                        height: 32
                        anchors.top: parent.top

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰂚  Notifications" + (notifQueue.count > 0 ? " - " + notifQueue.count : "")
                            color: Theme.text
                            font.pixelSize: 14
                            font.bold: true
                            opacity: notifQueue.count > 0 ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        Text {
                            id: emptyStateText
                            anchors.centerIn: parent
                            text: "No new notifications"
                            color: Theme.subtext
                            font.pixelSize: 14
                            font.bold: true
                            property bool showEmpty: notifQueue.count === 0 && islandWindow.islandState === "notifications"
                            
                            visible: opacity > 0
                            opacity: showEmpty ? 1 : 0
                            
                            Behavior on opacity { 
                                SequentialAnimation {
                                    PauseAnimation { duration: emptyStateText.showEmpty ? 250 : 0 }
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // Header actions
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Clear all action
                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: Theme.surfaceHover
                                visible: notifQueue.count > 0
                                
                                scale: clearTap.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Text { anchors.centerIn: parent; text: "󰎟"; color: Theme.text; font.pixelSize: 14 }

                                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                                Rectangle { anchors.fill: parent; radius: 8; color: "white"; opacity: clearHover.hovered ? 0.1 : 0; Behavior on opacity { NumberAnimation{duration:100} } }
                                
                                TapHandler { 
                                    id: clearTap
                                    onTapped: notifQueue.clear()
                                }
                            }

                            // Do not disturb toggle
                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: islandWindow.isDnd ? Theme.danger : Theme.surfaceHover
                                
                                scale: dndTap.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Text { anchors.centerIn: parent; text: islandWindow.isDnd ? "󰂛" : "󰂚"; color: islandWindow.isDnd ? Theme.background : Theme.text; font.pixelSize: 14 }

                                HoverHandler { id: dndHover; cursorShape: Qt.PointingHandCursor }
                                Rectangle { anchors.fill: parent; radius: 8; color: "white"; opacity: dndHover.hovered ? 0.1 : 0; Behavior on opacity { NumberAnimation{duration:100} } }
                                
                                TapHandler { id: dndTap; onTapped: islandWindow.isDnd = !islandWindow.isDnd }
                            }
                        }
                    }

                    ListView {
                        id: notifList
                        anchors.top: notifHeader.bottom
                        anchors.topMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        model: notifQueue
                        spacing: 8
                        clip: true
                        interactive: true 
                        boundsBehavior: Flickable.StopAtBounds
                        visible: notifQueue.count > 0

                        delegate: NotifCard {
                            nApp: model.nApp
                            nSum: model.nSum
                            nBod: model.nBod
                            nIco: model.nIco
                            nImg: model.nImg
                            nTime: model.nTime
                            index: model.index
                        }
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; to: 0; duration: 250 }
                                NumberAnimation { property: "height"; to: 0; duration: 300; easing.type: Easing.OutQuad }
                            }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { property: "y"; duration: 400; easing.type: Easing.OutQuad }
                        }
                    }

                    // Scroll Indicator
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.top: notifList.top
                        anchors.bottom: notifList.bottom
                        width: 4
                        radius: 2
                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                        
                        visible: notifList.visibleArea.heightRatio < 1.0 && notifQueue.count > 0
                        
                        Rectangle {
                            width: parent.width
                            radius: 2
                            color: Theme.accent
                            
                            height: Math.max(16, parent.height * notifList.visibleArea.heightRatio)
                            y: parent.height * notifList.visibleArea.yPosition
                        }
                    }
                }

                // Idle clock
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd")
                    color: Theme.text
                    font.pixelSize: 14
                    
                    property bool isActiveText: islandWindow.islandState === "idle" && !islandWindow.postHubCava && (!islandWindow.cavaActive || islandWindow.showClock)
                    visible: isActiveText
                    opacity: isActiveText ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd") }
                }

                // Idle visualizer
                Row {
                    id: cavaRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 24 
                    spacing: 4
                    
                    property bool isActiveCava: islandWindow.islandState === "idle" && 
                                                (islandWindow.postHubCava || (islandWindow.cavaActive && !islandWindow.showClock))
                    
                    visible: isActiveCava
                    opacity: isActiveCava ? 1 : 0
                    
                    Behavior on opacity { 
                        SequentialAnimation {
                            PauseAnimation { duration: cavaRow.isActiveCava ? 200 : 0 }
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }

                    Repeater {
                        model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                        Rectangle {
                            property real calcWidth: (cavaRow.width - (cavaRow.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                            width: Math.max(2, calcWidth)
                            height: {
                                let val = islandWindow.cavaValues[index] || 0
                                let h = (val / 9) * cavaRow.height
                                return Math.max(3, Math.min(h, cavaRow.height)) 
                            }
                            anchors.bottom: parent.bottom
                            radius: width / 2
                            color: Theme.accent
                            Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                // Navigation hub
                Row {
                    id: hubRow
                    anchors.centerIn: parent
                    spacing: 16
                    
                    property bool isActiveHub: islandWindow.islandState === "hub" && !islandWindow.postHubCava
                    visible: isActiveHub
                    opacity: isActiveHub ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Repeater {
                        model: {
                            let items = [
                                { icon: "󰃶", state: "calendar", accent: Theme.accent },
                                { icon: "󰂚", state: "notifications", accent: Theme.accent },
                                { icon: "󰸉", state: "wallpaper", accent: Theme.accent },
                                { icon: "󰕾", state: "audio", accent: Theme.accent }
                            ];
                            if (islandWindow.wasPlaying || islandWindow.cavaActive) {
                                items.push({ icon: "󰝚", state: "media_pin", accent: Theme.accent });
                            }
                            return items;
                        }
                        
                        Item {
                            required property var modelData
                            width: 44; height: 44
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: parent.modelData.accent
                                opacity: hubBtnHover.hovered ? 0.2 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.icon
                                font.pixelSize: 20
                                color: hubBtnHover.hovered ? parent.modelData.accent : Theme.text
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            HoverHandler { id: hubBtnHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    if (parent.modelData.state === "media_pin") {
                                        islandWindow.isMediaPinned = true
                                        islandWindow.islandState = "media"
                                        islandWindow.postHubCava = true
                                        islandWindow.showClock = false
                                        alternateTimer.stop()
                                        hubDelayTimer.stop()
                                        hubStayTimer.stop()
                                    } else {
                                        islandWindow.islandState = parent.modelData.state
                                    }
                                }
                            }
                        }
                    }
                }

                // Media player
                Item {
                    id: mediaPanel
                    width: 334
                    height: 52
                    anchors.centerIn: parent
                    
                    property bool isActiveMedia: islandWindow.islandState === "media"
                    visible: isActiveMedia
                    opacity: isActiveMedia ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    TapHandler {
                        onTapped: {
                            if (islandWindow.isMediaPinned) {
                                islandWindow.isMediaPinned = false
                                islandWindow.ignorePillHover = true
                                ignoreHoverTimer.restart()
                                hubDelayTimer.stop()
                                islandWindow.closeToIdle()
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 12

                        // Album art container
                        Item {
                            width: 52; height: 52
                            
                            // Fallback background
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Theme.surfaceHover
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    color: Theme.subtext
                                    font.pixelSize: 24
                                }
                            }

                            // Source image
                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: islandWindow.persistentArtUrl
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                layer.enabled: true 
                                visible: false 
                            }

                            // Alpha mask
                            Rectangle {
                                id: artMask
                                width: 52; height: 52
                                radius: 12
                                
                                layer.enabled: true
                                visible: false
                            }

                            // Ambient Glow Source separating internal states
                            Image {
                                id: albumGlowSrc
                                anchors.fill: parent
                                source: albumArt.source
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                layer.enabled: true
                                visible: false
                            }

                            // Glow Container Masked to Main Pill
                            Item {
                                width: mainPill.width
                                height: mainPill.height
                                x: -(mainPill.width - mediaPanel.width) / 2
                                y: -(mainPill.height - mediaPanel.height) / 2
                                z: -1
                                
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: pillMaskRect
                                }

                                Rectangle {
                                    id: pillMaskRect
                                    anchors.fill: parent
                                    radius: mainPill.radius
                                    topLeftRadius: mainPill.topLeftRadius
                                    topRightRadius: mainPill.topRightRadius
                                    color: "black"
                                    layer.enabled: true
                                    visible: false
                                }

                                MultiEffect {
                                    width: 52
                                    height: mainPill.height
                                    x: (mainPill.width - mediaPanel.width) / 2
                                    y: 0
                                    source: albumGlowSrc
                                    blurEnabled: true
                                    blurMax: 64
                                    blur: 1.0
                                    saturation: 2.2
                                    brightness: 1.0
                                    opacity: albumArt.status === Image.Ready ? 0.50 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            // Masked output
                            MultiEffect {
                                anchors.fill: parent
                                source: albumArt
                                maskEnabled: true
                                maskSource: artMask
                                
                                opacity: albumArt.status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }

                        // Track metadata and Progress Bar
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 4
                            width: 140 
                            spacing: 4 

                            Column {
                                width: parent.width
                                spacing: 0
                                Text { 
                                    text: islandWindow.activePlayer ? (islandWindow.activePlayer.trackTitle || "Unknown Track") : "No Media"
                                    color: Theme.text; font.pixelSize: 14; font.bold: true
                                    elide: Text.ElideRight; width: parent.width 
                                }
                                Text { 
                                    text: islandWindow.activePlayer ? (islandWindow.activePlayer.trackArtist || "Unknown Artist") : ""
                                    color: Theme.subtext; font.pixelSize: 11
                                    elide: Text.ElideRight; width: parent.width 
                                }
                            }

                            // Squiggly Progress Bar
                            Item {
                                id: progressContainer
                                anchors.left: parent.left
                                width: 140
                                height: 16 

                                property real ratio: 0
                                property real wavePhase: 0
                                property string durationText: ""
                                property real activeAmplitude: islandWindow.wasPlaying ? 2.5 : 0 
                                Behavior on activeAmplitude { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                                Timer {
                                    interval: 32; running: islandWindow.islandState === "media"; repeat: true
                                    onTriggered: {
                                        progressContainer.wavePhase -= 0.15; 
                                        
                                        let player = islandWindow.activePlayer;
                                        if (player) {
                                            let pos = Number(player.position) || 0;
                                            let len = Number(player.length) || 0;

                                            let scale = 1000000; 
                                            if (len > 0 && len < 100000) {
                                                scale = 1;
                                            }

                                            let posSec = pos / scale;
                                            let lenSec = len / scale;

                                            let formatTime = (secs) => {
                                                if (isNaN(secs) || secs <= 0) return "0:00";
                                                
                                                let h = Math.floor(secs / 3600);
                                                let m = Math.floor((secs % 3600) / 60);
                                                let s = Math.floor(secs % 60);
                                                
                                                let mStr = (h > 0 && m < 10) ? "0" + m : m;
                                                let sStr = s < 10 ? "0" + s : s;
                                                
                                                if (h > 0) return h + ":" + mStr + ":" + sStr;
                                                return mStr + ":" + sStr;
                                            };

                                            progressContainer.durationText = formatTime(posSec);

                                            if (lenSec > 0) {
                                                let r = posSec / lenSec;
                                                if (r > 1.05 && !islandWindow.wasPlaying) {
                                                    r = progressContainer.ratio;
                                                }
                                                progressContainer.ratio = Math.min(Math.max(r, 0), 1);
                                            } else {
                                                progressContainer.ratio = 0;
                                            }
                                        }
                                        waveCanvas.requestPaint();
                                    }
                                }

                                Canvas {
                                    id: waveCanvas
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 100
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        let pad = 5; 
                                        let usableWidth = width - (pad * 2);
                                        let midY = height / 2;
                                        let thumbX = pad + (progressContainer.ratio * usableWidth);

                                        let amplitude = progressContainer.activeAmplitude;
                                        let frequency = 0.3;

                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";

                                        ctx.beginPath();
                                        ctx.lineWidth = 2.5;
                                        ctx.strokeStyle = Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.3);
                                        ctx.moveTo(thumbX, midY);
                                        ctx.lineTo(width - pad, midY);
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.lineWidth = 2.5;
                                        ctx.strokeStyle = Theme.accent;
                                        ctx.moveTo(pad, midY + Math.sin(progressContainer.wavePhase) * amplitude);
                                        
                                        for (let x = pad; x <= thumbX; x += 2) {
                                            let damping = Math.min(1, (thumbX - x) / 12.0); 
                                            ctx.lineTo(x, midY + Math.sin((x - pad) * frequency + progressContainer.wavePhase) * amplitude * damping);
                                        }
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.arc(thumbX, midY, 4, 0, 2 * Math.PI);
                                        ctx.fillStyle = Theme.accent;
                                        ctx.fill();
                                    }
                                }
                                Text {
                                    text: progressContainer.durationText
                                    anchors.right: parent.right
                                    color: Theme.subtext
                                    opacity: 0.6
                                    font.pixelSize: 11
                                    font.bold: true
                                    visible: text !== ""
                                }
                            }
                        }

                        // Audio visualizer
                        Row {
                            width: 100 
                            height: 52 
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            
                            Repeater {
                                model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                                Rectangle {
                                    property real calcWidth: (parent.width - (parent.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                                    width: Math.max(2, calcWidth)
                                    height: {
                                        let val = islandWindow.cavaValues[index] || 0
                                        let h = (val / 9) * (parent.height * 0.7) 
                                        return Math.max(3, Math.min(h, parent.height))
                                    }
                                    anchors.bottom: parent.bottom
                                    radius: width / 2
                                    color: Theme.accent
                                    Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }

                // Bluetooth popup
                Item {
                    id: btPanel
                    width: 350
                    height: 68
                    anchors.centerIn: parent
                    
                    property bool isActiveBt: islandWindow.islandState === "bluetooth"
                    visible: isActiveBt
                    opacity: isActiveBt ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            width: 44; height: 44
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 12
                            color: Theme.accent
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰂱"
                                color: Theme.background
                                font.pixelSize: 24
                            }
                        }

                        // Connection details
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Row {
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Connected"
                                    color: Theme.subtext
                                    font.pixelSize: 12
                                }
                                
                                Rectangle {
                                    visible: islandWindow.latestBtBattery !== "--"
                                    width: batRow.width + 12
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 9
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                                    
                                    Row {
                                        id: batRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "󰥉"
                                            color: Theme.accent
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: islandWindow.latestBtBattery + "%"
                                            color: Theme.text
                                            font.pixelSize: 11
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Text {
                                text: islandWindow.latestBtDevice
                                color: Theme.text
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                width: 270 
                            }
                        }
                    }
                }
                // Wallpaper manager
                Item {
                    id: wallpaperPanel
                    width: 620
                    height: 290
                    anchors.centerIn: parent
                    
                    property bool isActiveWall: islandWindow.islandState === "wallpaper"
                    visible: isActiveWall
                    opacity: isActiveWall ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Text {
                        id: wallHeader
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰸉  Wallpapers"
                        color: Theme.text
                        font.pixelSize: 14
                        font.bold: true
                    }

                    // Refresh button
                    Rectangle {
                        anchors.verticalCenter: wallHeader.verticalCenter
                        anchors.right: themeToggleRect.left
                        anchors.rightMargin: 12
                        width: 32; height: 32; radius: 10
                        color: Theme.surfaceHover
                        
                        scale: refreshTap.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: Theme.text
                            font.pixelSize: 18
                        }

                        HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                        Rectangle { anchors.fill: parent; radius: 10; color: "white"; opacity: refreshHover.hovered ? 0.1 : 0; Behavior on opacity { NumberAnimation{duration:100} } }
                        
                        TapHandler { 
                            id: refreshTap
                            onTapped: {
                                wallpaperList.clear()
                                fetchStaticWalls.running = true
                                fetchWeWalls.running = true
                            }
                        }
                    }

                    // Theme control
                    Rectangle {
                        id: themeToggleRect
                        anchors.verticalCenter: wallHeader.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        width: 32; height: 32; radius: 10
                        color: Theme.surfaceHover
                        
                        scale: themeTap.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: islandWindow.themeMode === "dark" ? "" : ""
                            color: Theme.text
                            font.pixelSize: 18
                        }

                        HoverHandler { id: themeHover; cursorShape: Qt.PointingHandCursor }
                        Rectangle { anchors.fill: parent; radius: 10; color: "white"; opacity: themeHover.hovered ? 0.1 : 0; Behavior on opacity { NumberAnimation{duration:100} } }
                        
                        Process { id: themeProcess }
                        TapHandler { 
                            id: themeTap
                            onTapped: {
                                if (islandWindow.activeWallCache === "") return;
                                islandWindow.themeMode = islandWindow.themeMode === "dark" ? "light" : "dark"
                                let cmd = "echo '" + islandWindow.themeMode + "' > ~/.cache/mshell/mode_cache.txt && matugen image -t scheme-tonal-spot -m " + islandWindow.themeMode + " --source-color-index 0 " + islandWindow.activeWallCache
                                themeProcess.command = ["bash", "-c", cmd] 
                                themeProcess.running = true
                            }
                        }
                    }

                    GridView {
                        id: wallGrid
                        anchors.top: parent.top
                        anchors.topMargin: 65
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 20
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        
                        model: wallpaperList
                        clip: true
                        cacheBuffer: 1500
                        
                        cellWidth: 152
                        cellHeight: 65
                        flow: GridView.FlowTopToBottom
                        
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        property real targetX: 0
                        
                        onMovementEnded: targetX = contentX 

                        NumberAnimation {
                            id: smoothScrollAnim
                            target: wallGrid
                            property: "contentX"
                            to: wallGrid.targetX
                            duration: 350
                            easing.type: Easing.OutCubic
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton 
                            onWheel: (wheel) => {
                                let delta = wheel.angleDelta.y ? wheel.angleDelta.y : wheel.angleDelta.x;
                                
                                if (!smoothScrollAnim.running) {
                                    wallGrid.targetX = wallGrid.contentX;
                                }

                                let newX = wallGrid.targetX - delta;
                                let maxX = Math.max(0, wallGrid.contentWidth - wallGrid.width);
                                
                                wallGrid.targetX = Math.max(0, Math.min(newX, maxX));
                                smoothScrollAnim.restart();
                                wheel.accepted = true;
                            }
                        }

                        delegate: Item {
                            width: 144
                            height: 58

                            Rectangle {
                                id: wallBg
                                anchors.fill: parent
                                radius: 8
                                color: Theme.surfaceHover
                                antialiasing: true
                            }
                            
                            Rectangle {
                                id: wallMask
                                anchors.fill: parent
                                anchors.margins: wallHover.hovered ? 2 : 0
                                radius: Math.max(0, 8 - (wallHover.hovered ? 2 : 0))
                                layer.enabled: true
                                visible: false
                                antialiasing: true
                                Behavior on anchors.margins { NumberAnimation { duration: 150 } }
                            }

                            Image {
                                id: wallImg
                                anchors.fill: parent
                                anchors.margins: wallHover.hovered ? 2 : 0
                                source: preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                                visible: false
                                sourceSize.width: 144
                                sourceSize.height: 58
                                antialiasing: true
                                Behavior on anchors.margins { NumberAnimation { duration: 150 } }
                            }
                            
                            MultiEffect {
                                anchors.fill: parent
                                anchors.margins: wallHover.hovered ? 2 : 0
                                source: wallImg
                                maskEnabled: true
                                maskSource: wallMask
                                visible: preview !== ""
                                Behavior on anchors.margins { NumberAnimation { duration: 150 } }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                color: Theme.subtext
                                font.pixelSize: 24
                                visible: preview === ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 8
                                border.width: wallHover.hovered ? 2 : 0
                                border.color: Theme.accent
                                antialiasing: true
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                            }

                            HoverHandler { id: wallHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    let rawPreview = preview.replace("file://", "")
                                    islandWindow.beginWallTransition(type, path, rawPreview, islandWindow.themeMode)
                                    islandWindow.closeToIdle()
                                }
                            }
                        }
                    }

                    // Scroll indicator
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200
                        height: 4
                        radius: 2
                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                        
                        visible: wallGrid.visibleArea.widthRatio < 1.0 
                        
                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                            
                            width: parent.width * wallGrid.visibleArea.widthRatio
                            x: parent.width * wallGrid.visibleArea.xPosition
                        }
                    }
                }
                // Audio control
                Item {
                    id: audioPanel
                    width: 440
                    height: 56 + Math.max(1, Math.min(outputDevices.length, 4)) * 40 + 16
                    anchors.centerIn: parent

                    property bool isActive: islandWindow.islandState === "audio"
                    visible: isActive; opacity: isActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    onIsActiveChanged: SharedState.isSuppressingOsd = isActive

                    property var sinkNode: Pipewire.defaultAudioSink

                    property var outputDevices: {
                        let list = []
                        let nodes = Pipewire.nodes.values
                        for (let i = 0; i < nodes.length; i++) {
                            let n = nodes[i]
                            if (n.isSink && n.audio && !n.isStream) list.push(n)
                        }
                        return list
                    }

                    PwObjectTracker {
                        objects: audioPanel.outputDevices
                    }

                    function deviceIcon(node) {
                        let props = node.properties || {}
                        let formFactor = (props["device.form-factor"] || "").toLowerCase()
                        let api = (props["device.api"] || "").toLowerCase()
                        let name = (node.name || "").toLowerCase()
                        if (api === "bluez5" || name.indexOf("bluez") !== -1) return "\u{f00b1}"
                        if (formFactor === "headset" || formFactor === "headphone" || name.indexOf("headset") !== -1 || name.indexOf("headphone") !== -1) return "\u{f02cb}"
                        if (formFactor === "hdmi" || name.indexOf("hdmi") !== -1) return "\u{f0841}"
                        return "\u{f04c3}"
                    }

                    Text {
                        id: audioHeader
                        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 20
                        text: "\u{f057e}  Sound"; color: Theme.text; font.pixelSize: 14; font.bold: true
                    }

                    ListView {
                        id: audioDeviceList
                        anchors.top: audioHeader.bottom; anchors.topMargin: 16
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 20; anchors.rightMargin: 20
                        height: Math.max(1, Math.min(audioPanel.outputDevices.length, 4)) * 40 - 8
                        spacing: 8
                        clip: true
                        model: audioPanel.outputDevices
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: audioDeviceList.contentHeight > audioDeviceList.height + 2 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            interactive: true
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        delegate: Row {
                            id: deviceRow
                            required property var modelData
                            width: audioDeviceList.width - (audioDeviceList.ScrollBar.vertical.visible ? 10 : 0)
                            height: 32
                            spacing: 10

                            property bool isDefault: audioPanel.sinkNode && deviceRow.modelData.id === audioPanel.sinkNode.id
                            property bool ready: deviceRow.modelData && deviceRow.modelData.ready && deviceRow.modelData.audio
                            property real vol: deviceRow.ready ? deviceRow.modelData.audio.volume : 0
                            property bool muted: deviceRow.ready ? deviceRow.modelData.audio.muted : false

                            // Icon
                            Item {
                                width: 20; height: 32
                                Text {
                                    anchors.centerIn: parent
                                    text: audioPanel.deviceIcon(deviceRow.modelData)
                                    color: deviceRow.muted ? Theme.danger : (deviceRow.isDefault ? Theme.accent : Theme.subtext)
                                    font.pixelSize: 13
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: if (deviceRow.ready) deviceRow.modelData.audio.muted = !deviceRow.modelData.audio.muted
                                }
                            }

                            // Name
                            Item {
                                width: 110; height: 32
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: deviceRow.modelData.description || deviceRow.modelData.nickname || deviceRow.modelData.name
                                    color: deviceRow.isDefault ? Theme.text : Theme.subtext
                                    font.pixelSize: 12
                                    font.bold: deviceRow.isDefault
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Pipewire.preferredDefaultAudioSink = deviceRow.modelData }
                            }

                            // Volume bar
                            Item {
                                id: miniSlider
                                width: parent.width - 20 - 110 - parent.spacing * 2
                                height: 26
                                anchors.verticalCenter: parent.verticalCenter

                                property bool sliderHovered: false

                                Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.highlight }

                                Rectangle {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: miniHead.x + miniHead.width
                                    radius: height / 2
                                    color: (deviceRow.muted ? 0 : deviceRow.vol) * 100 > 100 ? Theme.danger : (deviceRow.isDefault ? Theme.accent : Theme.subtext)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Rectangle {
                                    id: miniHead
                                    width: parent.height; height: parent.height
                                    radius: width / 2
                                    color: Theme.text
                                    x: Math.max(0, Math.min(1, deviceRow.muted ? 0 : deviceRow.vol)) * (parent.width - width)
                                    Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (deviceRow.muted || deviceRow.vol <= 0) return "\u{f0581}"
                                            if (deviceRow.vol < 0.33) return "\u{f057f}"
                                            if (deviceRow.vol < 0.66) return "\u{f0580}"
                                            return "\u{f057e}"
                                        }
                                        color: Theme.background
                                        font.pixelSize: 13
                                        opacity: miniSlider.sliderHovered ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round((deviceRow.muted ? 0 : deviceRow.vol) * 100)
                                        color: Theme.background
                                        font.pixelSize: 11
                                        font.bold: true
                                        opacity: miniSlider.sliderHovered ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                    }
                                }

                                MouseArea {
                                    id: miniDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: miniSlider.sliderHovered = true
                                    onExited: miniSlider.sliderHovered = false
                                    function updateVol(mx) {
                                        let rawRatio = Math.max(0, Math.min(1, mx / width))
                                        let nearest5 = Math.round(rawRatio * 20) / 20
                                        let ratio = Math.abs(rawRatio - nearest5) <= 0.015 ? nearest5 : rawRatio
                                        if (deviceRow.ready) {
                                            deviceRow.modelData.audio.muted = false
                                            deviceRow.modelData.audio.volume = ratio
                                        }
                                    }
                                    onPressed: mouse => updateVol(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) updateVol(mouse.x) }
                                }
                            }
                        }
                    }
                }
                // Calendar panel
                Item {
                    id: calendarPanel
                    width: 620
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    layer.enabled: true
                    
                    property bool isActiveCalendar: islandWindow.islandState === "calendar"
                    visible: isActiveCalendar
                    opacity: isActiveCalendar ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    onVisibleChanged: {
                        if (visible) {
                            if (!weatherProcess.running && islandWindow.weatherToday === null) {
                                weatherProcess.running = true
                            }
                            if (!calendarProcess.running && islandWindow.calendarData === null) {
                                calendarProcess.running = true
                            }
                            calGrid.currentDate = new Date()
                            calGrid.selectedDate = new Date()
                        } else {
                            calGrid.monthOffset = 0 
                        }
                    }

                    function setTab(tab) { rightCard.activeTab = tab }
                    function selectDate(y, m, d) {
                        calGrid.selectedDate = new Date(y, m - 1, d)
                        rightCard.activeTab = "agenda"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 16

                        // Left: Calendar widget
                        Column {
                            id: calCol
                            width: 290
                            height: parent.height
                            spacing: 8

                            Item {
                                width: parent.width; height: 24
                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                    Text { text: "󰃮"; color: Theme.accent; font.pixelSize: 18; anchors.baseline: monthText.baseline }
                                    Text { id: monthText; text: Qt.formatDateTime(calGrid.calDate, "MMMM yyyy"); color: Theme.text; font.pixelSize: 16; font.bold: true }
                                }
                                Row {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6

                                    // Jump to today button
                                    Rectangle {
                                        visible: calGrid.monthOffset !== 0 || calGrid.selectedDateKey !== calGrid.todayDateKey
                                        width: todayTxt.implicitWidth + 12; height: 22; radius: 6
                                        color: todayHover.hovered ? Theme.accent : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            id: todayTxt
                                            anchors.centerIn: parent
                                            text: "Today"
                                            color: todayHover.hovered ? Theme.background : Theme.accent
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        HoverHandler { id: todayHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                calGrid.monthOffset = 0
                                                calGrid.selectedDate = new Date()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 24; height: 24; radius: 6
                                        color: prevHover.hovered ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: ""; color: prevHover.hovered ? Theme.background : Theme.accent; font.pixelSize: 16; font.bold: true }
                                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: calGrid.monthOffset-- }
                                    }
                                    Rectangle {
                                        width: 24; height: 24; radius: 6
                                        color: nextHover.hovered ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: ""; color: nextHover.hovered ? Theme.background : Theme.accent; font.pixelSize: 16; font.bold: true }
                                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: calGrid.monthOffset++ }
                                    }
                                }
                            }

                            Row {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                    Text {
                                        width: (parent.width - 24) / 7; horizontalAlignment: Text.AlignHCenter
                                        text: modelData; color: (index >= 5) ? Theme.accentAlt : Theme.subtext
                                        font.pixelSize: 12; font.bold: true
                                    }
                                }
                            }

                            Grid {
                                id: calGrid
                                width: parent.width
                                columns: 7; spacing: 4
                                
                                property int monthOffset: 0
                                property var currentDate: new Date()
                                property var selectedDate: new Date()
                                property string todayDateKey: Qt.formatDate(currentDate, "yyyy-MM-dd")
                                property string selectedDateKey: Qt.formatDate(selectedDate, "yyyy-MM-dd")

                                property var calDate: {
                                    let d = new Date(currentDate.getTime())
                                    d.setMonth(d.getMonth() + monthOffset)
                                    d.setDate(1); return d
                                }
                                property int startDay: (calDate.getDay() + 6) % 7
                                property int daysInMonth: new Date(calDate.getFullYear(), calDate.getMonth() + 1, 0).getDate()
                                property int daysInPrevMonth: new Date(calDate.getFullYear(), calDate.getMonth(), 0).getDate()
                                property int today: currentDate.getDate()

                                Repeater {
                                    model: 42 
                                    Item {
                                        width: (calGrid.width - 24) / 7; height: 32
                                        
                                        property bool isPrevMonth: index < calGrid.startDay
                                        property bool isNextMonth: index >= (calGrid.startDay + calGrid.daysInMonth)
                                        property bool isCurrentMonth: !isPrevMonth && !isNextMonth
                                        
                                        property int dayNumber: {
                                            if (isPrevMonth) return calGrid.daysInPrevMonth - calGrid.startDay + 1 + index
                                            if (isNextMonth) return index - (calGrid.startDay + calGrid.daysInMonth) + 1
                                            return index - calGrid.startDay + 1
                                        }

                                        property string dateKey: {
                                            if (!isCurrentMonth) return ""
                                            let y = calGrid.calDate.getFullYear()
                                            let m = calGrid.calDate.getMonth() + 1
                                            let d = dayNumber
                                            return y + "-" + (m < 10 ? "0" + m : m) + "-" + (d < 10 ? "0" + d : d)
                                        }
                                        
                                        property bool isToday: isCurrentMonth && (dayNumber === calGrid.today) && (calGrid.monthOffset === 0)
                                        property bool isSelected: isCurrentMonth && (dateKey === calGrid.selectedDateKey)
                                        
                                        property var dayEvents: isCurrentMonth && islandWindow.calendarEventsByDate ? (islandWindow.calendarEventsByDate[dateKey] || []) : []
                                        property bool hasHolidays: {
                                            for (let i = 0; i < dayEvents.length; i++) {
                                                if (dayEvents[i].isHoliday) return true
                                            }
                                            return false
                                        }
                                        property bool hasBirthdays: {
                                            for (let i = 0; i < dayEvents.length; i++) {
                                                let ev = dayEvents[i]
                                                if (ev.isBirthday || (ev.title && ev.title.toLowerCase().indexOf("birthday") !== -1)) return true
                                            }
                                            return false
                                        }
                                        property bool hasEvents: {
                                            for (let i = 0; i < dayEvents.length; i++) {
                                                if (!dayEvents[i].isHoliday) return true
                                            }
                                            return false
                                        }

                                        // Squircle date container
                                        Rectangle {
                                            id: daySquircle
                                            width: 32; height: 32; radius: 9
                                            anchors.centerIn: parent

                                            color: parent.isToday ? Theme.accent : (parent.isSelected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : (dayHover.hovered && parent.isCurrentMonth ? Theme.surfaceHover : "transparent"))
                                            border.color: parent.isSelected && !parent.isToday ? Theme.accent : "transparent"
                                            border.width: parent.isSelected && !parent.isToday ? 1.5 : 0
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                id: dayNumText
                                                anchors.centerIn: parent
                                                text: parent.parent.dayNumber 
                                                color: parent.parent.isToday ? Theme.background : (parent.parent.isSelected ? Theme.accent : (parent.parent.isCurrentMonth ? Theme.text : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.35)))
                                                font.pixelSize: 12
                                                font.bold: parent.parent.isToday || parent.parent.isSelected
                                            }

                                            // Indicator dots
                                            Row {
                                                anchors.top: dayNumText.bottom
                                                anchors.topMargin: 1
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 2
                                                visible: parent.parent.isCurrentMonth && (parent.parent.hasHolidays || parent.parent.hasEvents)

                                                Rectangle {
                                                    width: 3.5; height: 3.5; radius: 2
                                                    visible: parent.parent.parent.hasEvents
                                                    color: parent.parent.parent.isToday ? Theme.background : (parent.parent.parent.hasBirthdays ? "#f38ba8" : Theme.accent)
                                                }
                                                Rectangle {
                                                    width: 3.5; height: 3.5; radius: 2
                                                    visible: parent.parent.parent.hasHolidays
                                                    color: parent.parent.parent.isToday ? Theme.background : "#f9e2af"
                                                }
                                            }

                                            HoverHandler {
                                                id: dayHover; enabled: parent.parent.isCurrentMonth; cursorShape: Qt.PointingHandCursor
                                            }
                                        }

                                        TapHandler {
                                            enabled: parent.isCurrentMonth
                                            onTapped: {
                                                let d = new Date(calGrid.calDate.getFullYear(), calGrid.calDate.getMonth(), parent.dayNumber)
                                                calGrid.selectedDate = d
                                                rightCard.activeTab = "agenda"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Right: Tabbed Card (Weather / Agenda)
                        Rectangle {
                            id: rightCard
                            width: parent.width - calCol.width - parent.spacing
                            height: parent.height
                            radius: 12
                            color: Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 0.15)
                            clip: true

                            property string activeTab: "weather"
                            property var selectedEvents: islandWindow.calendarEventsByDate ? (islandWindow.calendarEventsByDate[calGrid.selectedDateKey] || []) : []

                            // Header Tabs
                            Item {
                                id: tabHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: 6
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                height: 28

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        spacing: 2

                                        // Weather tab
                                        Rectangle {
                                            width: (parent.width - 2) / 2
                                            height: parent.height
                                            radius: 5
                                            color: rightCard.activeTab === "weather" ? Theme.surfaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text {
                                                    text: "󰖐"
                                                    color: rightCard.activeTab === "weather" ? Theme.accent : Theme.subtext
                                                    font.pixelSize: 13
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "Weather"
                                                    color: rightCard.activeTab === "weather" ? Theme.text : Theme.subtext
                                                    font.pixelSize: 11
                                                    font.bold: rightCard.activeTab === "weather"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: 1.5
                                                }
                                            }
                                            HoverHandler { id: wHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: rightCard.activeTab = "weather" }
                                        }

                                        // Agenda tab
                                        Rectangle {
                                            width: (parent.width - 2) / 2
                                            height: parent.height
                                            radius: 5
                                            color: rightCard.activeTab === "agenda" ? Theme.surfaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text {
                                                    text: "󰃭"
                                                    color: rightCard.activeTab === "agenda" ? Theme.accent : Theme.subtext
                                                    font.pixelSize: 13
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "Agenda"
                                                    color: rightCard.activeTab === "agenda" ? Theme.text : Theme.subtext
                                                    font.pixelSize: 11
                                                    font.bold: rightCard.activeTab === "agenda"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: 1.5
                                                }
                                                
                                                // Event count badge
                                                Rectangle {
                                                    visible: rightCard.selectedEvents.length > 0
                                                    width: Math.max(16, badgeTxt.implicitWidth + 8)
                                                    height: 16
                                                    radius: 8
                                                    color: Theme.accent
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: 1.5
                                                    Text {
                                                        id: badgeTxt
                                                        anchors.centerIn: parent
                                                        anchors.verticalCenterOffset: 0.5
                                                        text: rightCard.selectedEvents.length
                                                        color: Theme.background
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                            HoverHandler { id: aHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: rightCard.activeTab = "agenda" }
                                        }
                                    }
                                }
                            }

                            // View Container
                            Item {
                                anchors.top: tabHeader.bottom
                                anchors.topMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                clip: true

                                // --- WEATHER VIEW ---
                                Item {
                                    anchors.fill: parent
                                    visible: rightCard.activeTab === "weather"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰖐   Fetching forecast..."
                                        color: Theme.subtext
                                        visible: islandWindow.weatherToday === null
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 4
                                        spacing: 8
                                        visible: islandWindow.weatherToday !== null

                                        // Main Weather Info
                                        Row {
                                            spacing: 16
                                            anchors.horizontalCenter: parent.horizontalCenter
                    
                                            Text {
                                                text: islandWindow.weatherToday ? islandWindow.weatherIcon(islandWindow.weatherToday.icon) : ""
                                                color: Theme.accent
                                                font.pixelSize: 46
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                    
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                        
                                                Text { 
                                                    text: islandWindow.weatherToday ? islandWindow.weatherToday.temp + "°C" : ""
                                                    color: Theme.text
                                                    font.pixelSize: 28
                                                    font.bold: true 
                                                }
                                                Text { 
                                                    text: islandWindow.weatherToday ? islandWindow.weatherToday.desc : ""
                                                    color: Theme.text
                                                    font.pixelSize: 12
                                                    font.bold: true 
                                                }
                                                Text { 
                                                    text: islandWindow.weatherToday ? "H: " + islandWindow.weatherToday.high + "°   L: " + islandWindow.weatherToday.low + "°" : ""
                                                    color: Theme.subtext
                                                    font.pixelSize: 11 
                                                }
                                            }
                                        }

                                        // Stats Row
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 12
                    
                                            Row {
                                                spacing: 3
                                                Text { text: "󰖎"; color: "#60A5FA"; font.pixelSize: 12; anchors.baseline: popTxt.baseline }
                                                Text { id: popTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.pop + "%" : "--%"; color: Theme.subtext; font.pixelSize: 10; font.bold: true }
                                            }
                                            Row {
                                                spacing: 3
                                                Text { text: ""; color: Theme.accentAlt; font.pixelSize: 11; anchors.baseline: feelsTxt.baseline }
                                                Text { id: feelsTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.feels + "°" : "--°"; color: Theme.subtext; font.pixelSize: 10; font.bold: true }
                                            }
                                            Row {
                                                spacing: 3
                                                Text { text: "󰖝"; color: Theme.accentAlt; font.pixelSize: 11; anchors.baseline: windTxt.baseline }
                                                Text { id: windTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.wind + " km/h" : "--"; color: Theme.subtext; font.pixelSize: 10; font.bold: true }
                                            }
                                        }

                                        // Sun Cycle Row
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 14

                                            Row {
                                                spacing: 3
                                                Text { text: "󰖜"; color: Theme.accentAlt; font.pixelSize: 12; anchors.baseline: sunriseTxt.baseline }
                                                Text { id: sunriseTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.sunrise : "--:--"; color: Theme.subtext; font.pixelSize: 10; font.bold: true }
                                            }
                                            Row {
                                                spacing: 3
                                                Text { text: "󰖛"; color: Theme.accentAlt; font.pixelSize: 12; anchors.baseline: sunsetTxt.baseline }
                                                Text { id: sunsetTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.sunset : "--:--"; color: Theme.subtext; font.pixelSize: 10; font.bold: true }
                                            }
                                        }

                                        // Divider
                                        Rectangle { 
                                            width: parent.width - 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            height: 1 
                                            color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2) 
                                        }

                                        // Forecast Grid
                                        Grid {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            columns: 2
                                            columnSpacing: 10
                                            rowSpacing: 4
                                            Repeater {
                                                model: islandWindow.weatherForecast
                                                Row {
                                                    spacing: 4
                                                    Text { text: modelData.day; color: Theme.subtext; font.pixelSize: 11; font.bold: true; width: 24; anchors.baseline: forecastHigh.baseline }
                                                    Text { text: islandWindow.weatherIcon(modelData.icon); color: Theme.accentAlt; font.pixelSize: 12; anchors.baseline: forecastHigh.baseline }
                                                    Text { id: forecastHigh; text: modelData.high + "°"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                                                    Text { text: modelData.low + "°"; color: Theme.subtext; font.pixelSize: 10; anchors.baseline: forecastHigh.baseline }
                                                    Text { text: "󰖎" + modelData.pop + "%"; color: "#60A5FA"; font.pixelSize: 10; font.bold: true; anchors.baseline: forecastHigh.baseline; visible: modelData.pop >= 20 }
                                                }
                                            }
                                        }
                                    }
                                }

                                // --- AGENDA VIEW ---
                                Item {
                                    anchors.fill: parent
                                    visible: rightCard.activeTab === "agenda"

                                    Column {
                                        anchors.fill: parent
                                        spacing: 6

                                        // Date & Status Header
                                        Item {
                                            width: parent.width
                                            height: 20

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Text {
                                                    text: Qt.formatDate(calGrid.selectedDate, "ddd, MMM d")
                                                    color: Theme.text
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                // Pill tag for today or day name
                                                Rectangle {
                                                    visible: calGrid.selectedDateKey === calGrid.todayDateKey
                                                    width: isTodayLabel.implicitWidth + 8
                                                    height: 16
                                                    radius: 4
                                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                                    Text {
                                                        id: isTodayLabel
                                                        anchors.centerIn: parent
                                                        text: "Today"
                                                        color: Theme.accent
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                }
                                            }

                                            // Refresh button
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 18; height: 18; radius: 4
                                                color: refHover.hovered ? Theme.surfaceHover : "transparent"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰑐"
                                                    color: refHover.hovered ? Theme.accent : Theme.subtext
                                                    font.pixelSize: 11
                                                }
                                                HoverHandler { id: refHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    onTapped: {
                                                        if (!calendarProcess.running) calendarProcess.running = true
                                                    }
                                                }
                                            }
                                        }

                                        // Event List or Empty State
                                        Item {
                                            width: parent.width
                                            height: parent.height - 26
                                            clip: true

                                            // Empty state
                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 5
                                                visible: rightCard.selectedEvents.length === 0

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "󰃶"
                                                    color: Theme.subtext
                                                    font.pixelSize: 26
                                                }
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "No events or holidays"
                                                    color: Theme.text
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: calGrid.selectedDateKey === calGrid.todayDateKey ? "Nothing scheduled for today" : "Enjoy your free day!"
                                                    color: Theme.subtext
                                                    font.pixelSize: 10
                                                }

                                                // Hint if personal calendar not yet configured
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "Add calendar in calendar_config.json"
                                                    color: Theme.accent
                                                    font.pixelSize: 9
                                                    visible: islandWindow.calendarData && !islandWindow.calendarData.hasPersonalCalendar
                                                }
                                            }

                                            // Scrollable ListView
                                            ListView {
                                                anchors.fill: parent
                                                visible: rightCard.selectedEvents.length > 0
                                                model: rightCard.selectedEvents
                                                spacing: 6
                                                clip: true
                                                boundsBehavior: Flickable.StopAtBounds

                                                delegate: Rectangle {
                                                    property bool isBday: modelData.isBirthday || (modelData.title && modelData.title.toLowerCase().indexOf("birthday") !== -1)
                                                    width: ListView.view.width
                                                    height: itemCol.implicitHeight + 10
                                                    radius: 8
                                                    color: isBday ? Qt.rgba(243/255, 139/255, 168/255, 0.12) : (modelData.isHoliday ? Qt.rgba(249/255, 226/255, 175/255, 0.12) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6))
                                                    border.color: isBday ? Qt.rgba(243/255, 139/255, 168/255, 0.3) : (modelData.isHoliday ? Qt.rgba(249/255, 226/255, 175/255, 0.3) : Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 0.2))
                                                    border.width: 1

                                                    // Left accent stripe
                                                    Rectangle {
                                                        width: 3
                                                        height: parent.height - 8
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 4
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        radius: 1.5
                                                        color: isBday ? "#f38ba8" : (modelData.isHoliday ? "#f9e2af" : (modelData.color || Theme.accent))
                                                    }

                                                    Column {
                                                        id: itemCol
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        Row {
                                                            spacing: 5
                                                            Text {
                                                                text: isBday ? "󰣆" : (modelData.isHoliday ? "󰣐" : "󰥔")
                                                                color: isBday ? "#f38ba8" : (modelData.isHoliday ? "#f9e2af" : Theme.accent)
                                                                font.pixelSize: 10
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                            Text {
                                                                text: modelData.time
                                                                color: Theme.subtext
                                                                font.pixelSize: 10
                                                                font.bold: true
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                            Text {
                                                                text: "• " + modelData.source
                                                                color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.7)
                                                                font.pixelSize: 9
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                        }

                                                        Text {
                                                            width: parent.width
                                                            text: modelData.title
                                                            color: Theme.text
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                            maximumLineCount: 2
                                                            wrapMode: Text.Wrap
                                                        }

                                                        Row {
                                                            visible: modelData.location !== ""
                                                            spacing: 4
                                                            Text { text: "󰍎"; color: Theme.subtext; font.pixelSize: 9 }
                                                            Text { text: modelData.location; color: Theme.subtext; font.pixelSize: 9; elide: Text.ElideRight; width: itemCol.width - 20 }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        function smoothStep(value) {
            let clamped = Math.max(0, Math.min(1, value));
            return clamped * clamped * (3 - 2 * clamped);
        }

        function interpolate(from, to, value) {
            return from + (to - from) * smoothStep(value);
        }

        PillMorphSurface {
            id: recMorphSurface
            anchors.fill: parent
            mainCenter: Qt.vector2d(mainPill.x + mainPill.width / 2, mainPill.y + mainPill.height / 2)
            mainSize: Qt.vector2d(mainPill.width, mainPill.height)
            mainRadius: mainPill.radius
            satelliteCenter: Qt.vector2d(recSatellite.x + recSatellite.width / 2, recSatellite.y + recSatellite.height / 2)
            satelliteSize: Qt.vector2d(recSatellite.width, recSatellite.height)
            satelliteRadius: recSatellite.height / 2
            blendRadius: recSatellite.customBlendRadius
            surfaceColor: Theme.surface
            visible: recSatellite.customBlendRadius > 0.01 && islandWindow.islandState === "idle"
            z: mainPill.z - 1
        }

        Item {
            id: recSatellite
            
            property bool isEmerging: (islandWindow.isGpuRecording || islandWindow.isScreenSharing)
            property real customOffsetX: -17
            property real customBlendRadius: 0
            property bool morphFinished: false

            onIsEmergingChanged: {
                emergeAnim.stop()
                disappearAnim.stop()
                if (isEmerging) {
                    emergeAnim.start()
                } else {
                    disappearAnim.start()
                }
            }

            SequentialAnimation {
                id: emergeAnim
                PropertyAction { target: recSatellite; property: "morphFinished"; value: false }
                ParallelAnimation {
                    SequentialAnimation {
                        NumberAnimation { target: recSatellite; property: "customOffsetX"; to: 28; duration: 500; easing.type: Easing.OutCubic }
                        NumberAnimation { target: recSatellite; property: "customOffsetX"; to: 26; duration: 250; easing.type: Easing.InOutQuad }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 20; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 14; duration: 180; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 0; duration: 1; }
                    }
                }
                PropertyAction { target: recSatellite; property: "morphFinished"; value: true }
            }

            SequentialAnimation {
                id: disappearAnim
                PropertyAction { target: recSatellite; property: "morphFinished"; value: false }
                ParallelAnimation {
                    NumberAnimation { target: recSatellite; property: "customOffsetX"; to: -17; duration: 400; easing.type: Easing.InCubic }
                    
                    SequentialAnimation {
                        PauseAnimation { duration: 130 }
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 20; duration: 40; easing.type: Easing.OutQuad }
                        NumberAnimation { target: recSatellite; property: "customBlendRadius"; to: 0; duration: 230; easing.type: Easing.InQuad }
                    }
                }
            }

            opacity: (isEmerging || customOffsetX > -16) && islandWindow.islandState === "idle" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

            readonly property real satelliteDiameter: 26

            z: mainPill.z - 1
            x: (mainPill.x + mainPill.width) + customOffsetX - (satelliteDiameter / 2)
            y: mainPill.y + (mainPill.height - satelliteDiameter) / 2
            width: satelliteDiameter
            height: satelliteDiameter

            // Satellite background
            Rectangle {
                id: satBg
                anchors.fill: parent
                radius: height / 2
                color: Theme.surface
            }

            // Delayed inner contents
            Item {
                anchors.fill: parent
                opacity: recSatellite.morphFinished ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                // Pulsing recording dot
                Rectangle {
                    id: recDot
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent
                    
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.35; duration: 750; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.85; to: 1.15; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.15; to: 0.85; duration: 750; easing.type: Easing.InOutSine }
                    }
                }

                // Outer glowing halo ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.accent
                    opacity: recDot.opacity * 0.7
                }
            }
        }
    }
}
