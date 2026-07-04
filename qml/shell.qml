import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string repoRoot: "@DHH_SHELL_ROOT@"
    readonly property string settingsPath: repoRoot + "/config/settings.json"
    readonly property string eventPath: repoRoot + "/config/event.json"
    property real dhhScale: 1.0
    property var dhhMeta: ({})
    property var dhhStates: ({})
    property int lastEventId: 0
    property bool eventFilePrimed: false
    property int eventId: 0
    property string eventMessage: ""
    property string eventState: "wave"
    property int eventDuration: 2200

    function loadSettings(raw) {
        try {
            const parsed = JSON.parse(raw || "{}");
            dhhScale = Number(parsed.scale || 1.0);
            if (!isFinite(dhhScale) || dhhScale <= 0) {
                dhhScale = 1.0;
            }
            dhhScale = Math.max(0.35, Math.min(2.0, dhhScale));
        } catch (error) {
            console.warn("dhh-shell: failed to parse settings:", error);
            dhhScale = 1.0;
        }
    }

    function loadDhh(raw) {
        try {
            const parsed = JSON.parse(raw || "{}");
            dhhMeta = parsed;
            dhhStates = parsed.states || {};
        } catch (error) {
            console.warn("dhh-shell: failed to parse DHH metadata:", error);
            dhhMeta = {};
            dhhStates = {};
        }
    }

    function stateSpec(name) {
        const states = dhhStates || {};
        let spec = states[name];
        if (spec && spec.fallback && spec.row === undefined) {
            spec = states[spec.fallback];
        }
        if (!spec && name === "walk_left" && states.walk_right) {
            spec = states.walk_right;
        }
        if (!spec && name !== "idle") {
            spec = states.idle;
        }
        return spec || { row: 0, fps: 6, loop: true };
    }

    function handleEvent(raw) {
        try {
            const event = JSON.parse(raw || "{}");
            const eventId = Number(event.id || 0);
            if (!eventFilePrimed) {
                lastEventId = eventId;
                eventFilePrimed = true;
                return;
            }
            if (eventId <= 0 || eventId === lastEventId) {
                return;
            }
            lastEventId = eventId;

            const message = String(event.message || "").trim();
            if (message.length === 0) {
                return;
            }
            eventState = String(event.state || "wave").trim() || "wave";
            eventDuration = Math.max(700, Math.min(8000, Number(event.duration || 2200)));
            eventMessage = message;
            shell.eventId = eventId;
        } catch (error) {
            console.warn("dhh-shell: failed to parse event:", error);
        }
    }

    FileView {
        id: settingsFile
        path: shell.settingsPath
        watchChanges: true
        onLoaded: shell.loadSettings(text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            console.warn("dhh-shell: settings unavailable:", error);
            shell.loadSettings("{}");
        }
    }

    FileView {
        id: dhhFile
        path: shell.repoRoot + "/assets/dhh/dhh.json"
        watchChanges: true
        onLoaded: shell.loadDhh(text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            console.warn("dhh-shell: DHH metadata unavailable:", error);
            shell.loadDhh("{}");
        }
    }

    FileView {
        id: eventFile
        path: shell.eventPath
        watchChanges: true
        onLoaded: shell.handleEvent(text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            shell.eventFilePrimed = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dhhWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dhh-shell"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property int frameWidth: Number(shell.dhhMeta.frameWidth || 142)
            property int frameHeight: Number(shell.dhhMeta.frameHeight || 154)
            property int cols: Number(shell.dhhMeta.cols || 8)
            property int rows: Number(shell.dhhMeta.rows || 9)
            property real dhhScale: shell.dhhScale
            property int dhhWidth: Math.round(frameWidth * dhhScale)
            property int dhhHeight: Math.round(frameHeight * dhhScale)
            property string sheetSource: "file://" + shell.repoRoot + "/assets/dhh/" + (shell.dhhMeta.spritesheetPath || "spritesheet.png")
            property int frame: 0
            property int frameIndex: 0
            property var frameList: []
            property int stateRow: 0
            property int fps: 6
            property bool animated: false
            property bool dragging: false
            property bool transientState: false
            property real dragLastX: 0
            property string bubbleText: ""
            property string systemState: "idle"
            property string systemSummary: ""
            property string systemRule: "default"
            property int handledEventId: 0
            property int bubbleMaxWidth: Math.max(180, Math.min(360, width - 32))

            function clampDhh() {
                dhhHitbox.x = Math.max(0, Math.min(width - dhhWidth, dhhHitbox.x));
                dhhHitbox.y = Math.max(0, Math.min(height - dhhHeight, dhhHitbox.y));
            }

            function setState(name, shouldAnimate) {
                const spec = shell.stateSpec(name);
                const row = Number(spec.row || 0);
                const stateFps = Number(spec.fps || 6);
                if (stateRow !== row) {
                    stateRow = row;
                    frame = 0;
                    frameIndex = 0;
                }
                fps = stateFps;
                frameList = Array.isArray(spec.frames) ? spec.frames : [];
                animated = shouldAnimate;
                if (frameList.length > 0) {
                    frameIndex = 0;
                    frame = Number(frameList[0] || 0);
                    animated = true;
                } else if (!animated) {
                    frame = 0;
                }
                frameTimer.interval = Math.max(40, Math.round(1000 / fps));
            }

            function applySystemState() {
                if (dragging || transientState) {
                    return;
                }

                const state = systemState || "idle";
                setState(state, state !== "idle");
            }

            function applySystemSnapshot(raw) {
                try {
                    const snapshot = JSON.parse(raw || "{}");
                    systemState = snapshot.state || "idle";
                    systemSummary = snapshot.summary || "";
                    systemRule = snapshot.rule || "default";
                    applySystemState();
                } catch (error) {
                    console.warn("dhh-shell: failed to parse system state:", error);
                }
            }

            function showEventBubble(message, state, duration) {
                bubbleText = message;
                bubbleTimer.interval = duration;
                bubbleTimer.restart();
                transientState = true;
                setState(state || "wave", true);
                transientTimer.interval = duration;
                transientTimer.restart();
            }

            mask: Region {
                item: dhhHitbox
            }

            Connections {
                target: shell
                function onEventIdChanged() {
                    if (shell.eventId <= 0 || shell.eventId === dhhWindow.handledEventId) {
                        return;
                    }
                    dhhWindow.handledEventId = shell.eventId;
                    dhhWindow.showEventBubble(shell.eventMessage, shell.eventState, shell.eventDuration);
                }
            }

            Timer {
                id: frameTimer
                running: true
                repeat: true
                interval: Math.round(1000 / dhhWindow.fps)
                onTriggered: {
                    if (dhhWindow.frameList.length > 0) {
                        dhhWindow.frameIndex = (dhhWindow.frameIndex + 1) % dhhWindow.frameList.length;
                        dhhWindow.frame = Number(dhhWindow.frameList[dhhWindow.frameIndex] || 0);
                    } else if (dhhWindow.animated) {
                        dhhWindow.frame = (dhhWindow.frame + 1) % dhhWindow.cols;
                    }
                }
            }

            Timer {
                id: bubbleTimer
                interval: 1800
                repeat: false
                onTriggered: dhhWindow.bubbleText = ""
            }

            Timer {
                id: transientTimer
                interval: 1400
                repeat: false
                onTriggered: {
                    dhhWindow.transientState = false;
                    dhhWindow.applySystemState();
                }
            }

            Process {
                id: systemProbe
                command: [shell.repoRoot + "/bin/dhh-shell-system-state"]
                stdout: StdioCollector {
                    id: systemProbeOut
                    waitForEnd: true
                }
                onExited: function(exitCode) {
                    if (exitCode === 0) {
                        dhhWindow.applySystemSnapshot(systemProbeOut.text);
                    }
                }
            }

            Timer {
                interval: 5000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!systemProbe.running) {
                        systemProbe.running = true;
                    }
                }
            }

            Item {
                id: dhhHitbox
                x: Math.max(16, dhhWindow.width - dhhWindow.dhhWidth - 72)
                y: Math.max(48, dhhWindow.height - dhhWindow.dhhHeight - 52)
                width: dhhWindow.dhhWidth
                height: dhhWindow.dhhHeight

                Behavior on x {
                    enabled: !dhhWindow.dragging
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on y {
                    enabled: !dhhWindow.dragging
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Item {
                    id: spriteViewport
                    anchors.fill: parent
                    clip: true

                    Image {
                        source: dhhWindow.sheetSource
                        width: dhhWindow.frameWidth * dhhWindow.cols * dhhWindow.dhhScale
                        height: dhhWindow.frameHeight * dhhWindow.rows * dhhWindow.dhhScale
                        x: -dhhWindow.frame * dhhWindow.dhhWidth
                        y: -dhhWindow.stateRow * dhhWindow.dhhHeight
                        smooth: false
                        cache: true
                    }
                }

                Rectangle {
                    visible: dhhWindow.bubbleText.length > 0
                    x: Math.max(12 - dhhHitbox.x, Math.min((dhhWindow.width - width - 12) - dhhHitbox.x, (dhhHitbox.width - width) / 2))
                    y: -height + 6
                    width: Math.min(dhhWindow.bubbleMaxWidth, Math.max(150, bubbleLabel.implicitWidth + 24))
                    height: bubbleLabel.implicitHeight + 16
                    radius: 14
                    color: Qt.rgba(0.07, 0.07, 0.10, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        id: bubbleLabel
                        anchors.centerIn: parent
                        width: parent.width - 24
                        text: dhhWindow.bubbleText
                        color: "#f5e0dc"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.12
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: dhhHitbox
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, dhhWindow.width - dhhWindow.dhhWidth)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, dhhWindow.height - dhhWindow.dhhHeight)

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            dhhWindow.dragging = true;
                            dhhWindow.transientState = true;
                            dhhWindow.dragLastX = dhhHitbox.x;
                        }
                    }

                    onPositionChanged: {
                        if (!dhhWindow.dragging) {
                            return;
                        }

                        const dx = dhhHitbox.x - dhhWindow.dragLastX;
                        dhhWindow.clampDhh();
                        if (Math.abs(dx) > 1) {
                            dhhWindow.setState(dx < 0 ? "walk_left" : "walk_right", true);
                            dhhWindow.dragLastX = dhhHitbox.x;
                        }
                    }

                    onReleased: {
                        dhhWindow.dragging = false;
                        dhhWindow.transientState = false;
                        dhhWindow.applySystemState();
                    }

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            dhhWindow.bubbleText = dhhWindow.systemSummary || "dhh-shell";
                            bubbleTimer.restart();
                            dhhWindow.transientState = true;
                            dhhWindow.setState("wave", true);
                            transientTimer.restart();
                        } else if (mouse.button === Qt.MiddleButton) {
                            dhhHitbox.x = Math.max(16, dhhWindow.width - dhhWindow.dhhWidth - 72);
                            dhhHitbox.y = Math.max(48, dhhWindow.height - dhhWindow.dhhHeight - 52);
                            dhhWindow.applySystemState();
                        }
                    }
                }
            }
        }
    }
}
