import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string repoRoot: "/home/dev/REPOS/petshell"
    readonly property string settingsPath: repoRoot + "/config/settings.json"
    readonly property string eventPath: repoRoot + "/config/event.json"
    property string activePet: "dhh-pet"
    property real petScale: 1.0
    property var petMeta: ({})
    property var petStates: ({})
    property int lastEventId: 0
    property bool eventFilePrimed: false
    property int eventId: 0
    property string eventMessage: ""
    property string eventState: "wave"
    property int eventDuration: 2200

    function loadSettings(raw) {
        try {
            const parsed = JSON.parse(raw || "{}");
            activePet = parsed.activePet || "dhh-pet";
            petScale = Number(parsed.scale || 1.0);
            if (!isFinite(petScale) || petScale <= 0) {
                petScale = 1.0;
            }
            petScale = Math.max(0.35, Math.min(2.0, petScale));
        } catch (error) {
            console.warn("petshell: failed to parse settings:", error);
            activePet = "dhh-pet";
            petScale = 1.0;
        }
        petFile.path = repoRoot + "/pets/" + activePet + "/pet.json";
        petFile.reload();
    }

    function loadPet(raw) {
        try {
            const parsed = JSON.parse(raw || "{}");
            petMeta = parsed;
            petStates = parsed.states || {};
        } catch (error) {
            console.warn("petshell: failed to parse pet metadata:", error);
            petMeta = {};
            petStates = {};
        }
    }

    function stateSpec(name) {
        const states = petStates || {};
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
            console.warn("petshell: failed to parse event:", error);
        }
    }

    FileView {
        id: settingsFile
        path: shell.settingsPath
        watchChanges: true
        onLoaded: shell.loadSettings(text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            console.warn("petshell: settings unavailable:", error);
            shell.loadSettings("{}");
        }
    }

    FileView {
        id: petFile
        path: shell.repoRoot + "/pets/" + shell.activePet + "/pet.json"
        watchChanges: true
        onLoaded: shell.loadPet(text())
        onFileChanged: reload()
        onLoadFailed: function(error) {
            console.warn("petshell: pet metadata unavailable:", error);
            shell.loadPet("{}");
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
            id: petWindow
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
            WlrLayershell.namespace: "petshell"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property int frameWidth: Number(shell.petMeta.frameWidth || 142)
            property int frameHeight: Number(shell.petMeta.frameHeight || 154)
            property int cols: Number(shell.petMeta.cols || 8)
            property int rows: Number(shell.petMeta.rows || 9)
            property real petScale: shell.petScale
            property int petWidth: Math.round(frameWidth * petScale)
            property int petHeight: Math.round(frameHeight * petScale)
            property string sheetSource: "file://" + shell.repoRoot + "/pets/" + shell.activePet + "/" + (shell.petMeta.spritesheetPath || "spritesheet.png")
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

            function clampPet() {
                petHitbox.x = Math.max(0, Math.min(width - petWidth, petHitbox.x));
                petHitbox.y = Math.max(0, Math.min(height - petHeight, petHitbox.y));
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
                    console.warn("petshell: failed to parse system state:", error);
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
                item: petHitbox
            }

            Connections {
                target: shell
                function onEventIdChanged() {
                    if (shell.eventId <= 0 || shell.eventId === petWindow.handledEventId) {
                        return;
                    }
                    petWindow.handledEventId = shell.eventId;
                    petWindow.showEventBubble(shell.eventMessage, shell.eventState, shell.eventDuration);
                }
            }

            Timer {
                id: frameTimer
                running: true
                repeat: true
                interval: Math.round(1000 / petWindow.fps)
                onTriggered: {
                    if (petWindow.frameList.length > 0) {
                        petWindow.frameIndex = (petWindow.frameIndex + 1) % petWindow.frameList.length;
                        petWindow.frame = Number(petWindow.frameList[petWindow.frameIndex] || 0);
                    } else if (petWindow.animated) {
                        petWindow.frame = (petWindow.frame + 1) % petWindow.cols;
                    }
                }
            }

            Timer {
                id: bubbleTimer
                interval: 1800
                repeat: false
                onTriggered: petWindow.bubbleText = ""
            }

            Timer {
                id: transientTimer
                interval: 1400
                repeat: false
                onTriggered: {
                    petWindow.transientState = false;
                    petWindow.applySystemState();
                }
            }

            Process {
                id: systemProbe
                command: [shell.repoRoot + "/bin/petshell-system-state"]
                stdout: StdioCollector {
                    id: systemProbeOut
                    waitForEnd: true
                }
                onExited: function(exitCode) {
                    if (exitCode === 0) {
                        petWindow.applySystemSnapshot(systemProbeOut.text);
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
                id: petHitbox
                x: Math.max(16, petWindow.width - petWindow.petWidth - 72)
                y: Math.max(48, petWindow.height - petWindow.petHeight - 52)
                width: petWindow.petWidth
                height: petWindow.petHeight

                Behavior on x {
                    enabled: !petWindow.dragging
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on y {
                    enabled: !petWindow.dragging
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Item {
                    id: spriteViewport
                    anchors.fill: parent
                    clip: true

                    Image {
                        source: petWindow.sheetSource
                        width: petWindow.frameWidth * petWindow.cols * petWindow.petScale
                        height: petWindow.frameHeight * petWindow.rows * petWindow.petScale
                        x: -petWindow.frame * petWindow.petWidth
                        y: -petWindow.stateRow * petWindow.petHeight
                        smooth: false
                        cache: true
                    }
                }

                Rectangle {
                    visible: petWindow.bubbleText.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: -6
                    width: bubbleLabel.implicitWidth + 22
                    height: 30
                    radius: 13
                    color: Qt.rgba(0.07, 0.07, 0.10, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        id: bubbleLabel
                        anchors.centerIn: parent
                        text: petWindow.bubbleText
                        color: "#f5e0dc"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: petHitbox
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, petWindow.width - petWindow.petWidth)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, petWindow.height - petWindow.petHeight)

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            petWindow.dragging = true;
                            petWindow.transientState = true;
                            petWindow.dragLastX = petHitbox.x;
                        }
                    }

                    onPositionChanged: {
                        if (!petWindow.dragging) {
                            return;
                        }

                        const dx = petHitbox.x - petWindow.dragLastX;
                        petWindow.clampPet();
                        if (Math.abs(dx) > 1) {
                            petWindow.setState(dx < 0 ? "walk_left" : "walk_right", true);
                            petWindow.dragLastX = petHitbox.x;
                        }
                    }

                    onReleased: {
                        petWindow.dragging = false;
                        petWindow.transientState = false;
                        petWindow.applySystemState();
                    }

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            petWindow.bubbleText = petWindow.systemSummary || "petshell";
                            bubbleTimer.restart();
                            petWindow.transientState = true;
                            petWindow.setState("wave", true);
                            transientTimer.restart();
                        } else if (mouse.button === Qt.MiddleButton) {
                            petHitbox.x = Math.max(16, petWindow.width - petWindow.petWidth - 72);
                            petHitbox.y = Math.max(48, petWindow.height - petWindow.petHeight - 52);
                            petWindow.applySystemState();
                        }
                    }
                }
            }
        }
    }
}
