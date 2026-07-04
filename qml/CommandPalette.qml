import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var panelScreen
    property string repoRoot: ""
    property bool open: false
    property int requestId: 0
    property string searchQuery: ""
    property bool aiMode: false
    property bool aiGenerating: false
    property string aiQuery: ""
    property string aiSubmittedQuery: ""
    property string aiResponse: ""
    property int highlightedRow: -1
    property var visibleRows: []
    property string pendingCommand: ""
    readonly property string uiFont: "sans-serif"
    readonly property color bg: "#000000"
    readonly property color chrome: "#050505"
    readonly property color panel: "#0a0a0a"
    readonly property color panelLift: "#111111"
    readonly property color panelSoft: "#171717"
    readonly property color muted: "#a1a1aa"
    readonly property color subtle: "#71717a"
    readonly property color text: "#fafafa"
    readonly property color accent: "#ffffff"
    readonly property color border: Qt.rgba(1, 1, 1, 0.12)

    signal closeRequested()

    screen: panelScreen
    visible: open
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
    WlrLayershell.namespace: "dhh-shell-command"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var commandGroups: [
        {
            label: "DHH",
            items: [
                { label: "Announce DHH is online", value: "dhh-wave", shortcut: "d w", keywords: ["hello", "wave", "online"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " dhh-wave" },
                { label: "Think about the smallest useful thing", value: "dhh-think", shortcut: "d t", keywords: ["think", "waiting", "essence"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " dhh-think" },
                { label: "Review the diff like it owes you money", value: "dhh-review", shortcut: "d r", keywords: ["review", "code", "diff"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " dhh-review" }
            ]
        },
        {
            label: "Omarchy Decisions",
            items: [
                { label: "Summon only the tool you need", value: "launcher", shortcut: "super space", keywords: ["walker", "apps", "launcher"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " launcher; omarchy-launch-walker" },
                { label: "Learn the keyboard instrument", value: "keybindings", shortcut: "super k", keywords: ["help", "shortcuts", "keys"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " keybindings; omarchy-menu-keybindings" },
                { label: "Choose power deliberately", value: "system-menu", shortcut: "super esc", keywords: ["power", "logout", "shutdown"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " system-menu; omarchy-menu system" },
                { label: "Capture receipts before explaining", value: "capture-menu", shortcut: "super ctrl c", keywords: ["screenshot", "record", "capture"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " capture-menu; omarchy-menu capture" },
                { label: "Change the robe, keep the opinions", value: "theme-menu", shortcut: "theme", keywords: ["theme", "style", "robe"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " theme-menu; omarchy-menu theme" }
            ]
        },
        {
            label: "Machine Discipline",
            items: [
                { label: "Reload the compositor without drama", value: "reload-hyprland", shortcut: "hypr", keywords: ["config", "reload", "hyprland"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " reload-hyprland; hyprctl reload" },
                { label: "Restart the status bar", value: "restart-waybar", shortcut: "bar", keywords: ["status", "panel", "waybar"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " restart-waybar; omarchy restart waybar" },
                { label: "Measure before you panic", value: "activity", shortcut: "super ctrl t", keywords: ["btop", "stats", "activity"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " activity; omarchy-launch-tui btop" },
                { label: "Commit with future-you in mind", value: "lazygit", shortcut: "git", keywords: ["git", "lazygit", "commit"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " lazygit; omarchy-launch-tui lazygit" },
                { label: "Inspect the container opinions", value: "lazydocker", shortcut: "docker", keywords: ["docker", "containers", "lazydocker"], command: quote(repoRoot + "/bin/dhh-shell-omarchy-event") + " lazydocker; omarchy-launch-tui lazydocker" }
            ]
        }
    ]

    function quote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function includesText(value, query) {
        return String(value || "").toLowerCase().indexOf(query) !== -1;
    }

    function itemMatches(item, query) {
        if (query.length === 0) {
            return true;
        }
        if (includesText(item.label, query) || includesText(item.value, query)) {
            return true;
        }
        const keywords = item.keywords || [];
        for (let i = 0; i < keywords.length; i++) {
            if (includesText(keywords[i], query)) {
                return true;
            }
        }
        return false;
    }

    function buildRows() {
        const query = searchQuery.trim().toLowerCase();
        const rows = [];
        for (let i = 0; i < commandGroups.length; i++) {
            const group = commandGroups[i];
            const matched = [];
            for (let j = 0; j < group.items.length; j++) {
                const item = group.items[j];
                if (itemMatches(item, query)) {
                    matched.push(item);
                }
            }
            if (matched.length > 0) {
                if (rows.length > 0) {
                    rows.push({ type: "separator" });
                }
                rows.push({ type: "group", label: group.label });
                for (let k = 0; k < matched.length; k++) {
                    rows.push({ type: "item", item: matched[k] });
                }
            }
        }
        return rows;
    }

    function firstItemIndex() {
        for (let i = 0; i < visibleRows.length; i++) {
            if (visibleRows[i].type === "item") {
                return i;
            }
        }
        return -1;
    }

    function moveHighlight(delta) {
        if (visibleRows.length === 0) {
            highlightedRow = -1;
            return;
        }

        let current = highlightedRow;
        for (let i = 0; i < visibleRows.length; i++) {
            current = (current + delta + visibleRows.length) % visibleRows.length;
            if (visibleRows[current].type === "item") {
                highlightedRow = current;
                commandList.positionViewAtIndex(current, ListView.Contain);
                return;
            }
        }
        highlightedRow = -1;
    }

    function refreshRows() {
        visibleRows = buildRows();
        highlightedRow = firstItemIndex();
    }

    function resetPalette() {
        searchQuery = "";
        aiMode = false;
        aiGenerating = false;
        aiQuery = "";
        aiSubmittedQuery = "";
        aiResponse = "";
        refreshRows();
    }

    function closePalette() {
        closeRequested();
        resetPalette();
    }

    function askAi(query) {
        const clean = String(query || searchQuery || aiQuery || "").trim();
        aiMode = true;
        aiGenerating = true;
        aiSubmittedQuery = clean.length > 0 ? clean : "How should I drive this machine?";
        aiQuery = "";
        aiResponse = "";
        aiTimer.restart();
    }

    function executeHighlighted() {
        if (highlightedRow < 0 || highlightedRow >= visibleRows.length) {
            if (searchQuery.trim().length > 0) {
                askAi(searchQuery);
            }
            return;
        }
        const row = visibleRows[highlightedRow];
        if (row.type !== "item") {
            return;
        }
        runItem(row.item);
    }

    function runItem(item) {
        if (!item || !item.command) {
            return;
        }
        pendingCommand = item.command;
        actionRunner.running = true;
        closePalette();
    }

    onSearchQueryChanged: refreshRows()
    onOpenChanged: {
        if (open) {
            resetPalette();
            focusTimer.restart();
        }
    }
    onRequestIdChanged: {
        if (open) {
            focusTimer.restart();
        }
    }
    Component.onCompleted: refreshRows()

    Process {
        id: actionRunner
        command: ["bash", "-lc", root.pendingCommand]
        onExited: root.pendingCommand = ""
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: aiTimer
        interval: 900
        repeat: false
        onTriggered: {
            root.aiGenerating = false;
            root.aiResponse = "DHH says: keep the interface small, the commands sharp, and the defaults opinionated. This AI slot is mocked for now; the shell wiring is ready for a real backend later.";
            aiInput.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePalette()
        }
    }

    Rectangle {
        id: popup
        width: Math.min(640, root.width - 40)
        height: Math.min(530, root.height - 120)
        x: Math.round((root.width - width) / 2)
        y: Math.max(48, Math.round(root.height * 0.12))
        radius: 18
        color: root.panel
        border.width: 1
        border.color: root.border
        scale: root.open ? 1 : 0.98
        opacity: root.open ? 1 : 0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 17
            color: Qt.rgba(1, 1, 1, 0.018)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.04)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: 58

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 17
                    color: root.chrome

                    // Keep only the frame's outer top corners rounded.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.radius + 2
                        color: parent.color
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: aiMode ? parent.width - 148 : parent.width - 132
                        height: 42
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: aiMode ? "✦" : ""
                            color: root.subtle
                            font.family: aiMode ? root.uiFont : "JetBrainsMono Nerd Font"
                            font.pixelSize: aiMode ? 15 : 14
                            font.weight: Font.Bold
                        }

                        TextInput {
                            id: searchInput
                            visible: !root.aiMode
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            color: root.text
                            selectionColor: root.accent
                            selectedTextColor: root.bg
                            font.family: root.uiFont
                            font.pixelSize: 14
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.closePalette();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.moveHighlight(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.moveHighlight(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.executeHighlighted();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    root.askAi(root.searchQuery);
                                    event.accepted = true;
                                }
                            }
                        }

                        TextInput {
                            id: aiInput
                            visible: root.aiMode
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            enabled: !root.aiGenerating
                            color: root.text
                            selectionColor: root.accent
                            selectedTextColor: root.bg
                            font.family: root.uiFont
                            font.pixelSize: 14
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            text: root.aiQuery
                            onTextChanged: root.aiQuery = text
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.aiMode = false;
                                    root.searchQuery = "";
                                    root.refreshRows();
                                    focusTimer.restart();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !root.aiGenerating) {
                                    root.askAi(root.aiQuery);
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            visible: !root.aiMode && searchInput.text.length === 0
                            anchors.left: searchInput.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type a command or search..."
                            color: root.subtle
                            font.family: root.uiFont
                            font.pixelSize: 14
                        }

                        Text {
                            visible: root.aiMode && aiInput.text.length === 0
                            anchors.left: aiInput.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ask DHH anything..."
                            color: root.subtle
                            font.family: root.uiFont
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        width: root.aiMode ? 126 : 112
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 9
                        color: buttonMouse.containsMouse ? root.panelSoft : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: root.aiMode ? "<" : "✦"
                                color: root.subtle
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.aiMode ? "Back" : "Ask DHH"
                                color: root.text
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            Rectangle {
                                visible: !root.aiMode
                                width: 28
                                height: 20
                                radius: 5
                                color: root.panelSoft
                                Text {
                                    anchors.centerIn: parent
                                    text: "Tab"
                                    color: root.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                }
                            }
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.aiMode) {
                                    root.aiMode = false;
                                    root.searchQuery = "";
                                    root.refreshRows();
                                    focusTimer.restart();
                                } else {
                                    root.askAi(root.searchQuery);
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 107

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    anchors.rightMargin: 1
                    anchors.topMargin: 1
                    color: root.panelLift
                    radius: 14
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    // The body is inset under the frame header, but the footer
                    // owns the outer bottom corners.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.radius + 2
                        color: parent.color
                        border.width: 0
                    }
                }

                ListView {
                    id: commandList
                    visible: !root.aiMode
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 12
                    anchors.bottomMargin: 10
                    clip: true
                    spacing: 1
                    model: root.visibleRows

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: commandList.width
                        height: modelData.type === "group" ? 31 : modelData.type === "separator" ? 14 : 36
                        property bool isItem: modelData.type === "item"
                        property bool isHighlighted: isItem && root.highlightedRow === index

                        Rectangle {
                            visible: row.isItem
                            anchors.fill: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: 8
                            color: row.isHighlighted ? root.text : "transparent"
                            border.width: row.isHighlighted ? 1 : 0
                            border.color: root.text
                        }

                        Text {
                            visible: modelData.type === "group"
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            text: modelData.label || ""
                            color: root.subtle
                            opacity: 1
                            font.family: root.uiFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            visible: modelData.type === "separator"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Row {
                            visible: row.isItem
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 11
                            spacing: 10

                            Text {
                                width: parent.width - shortcutBox.width - 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.isItem ? modelData.item.label : ""
                                color: row.isHighlighted ? root.bg : root.text
                                font.family: root.uiFont
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: shortcutBox
                                width: shortcutText.implicitWidth + 16
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 6
                                color: row.isHighlighted ? Qt.rgba(0, 0, 0, 0.18) : root.panelSoft
                                border.width: row.isHighlighted ? 1 : 0
                                border.color: Qt.rgba(0, 0, 0, 0.22)

                                Text {
                                    id: shortcutText
                                    anchors.centerIn: parent
                                    text: row.isItem ? (modelData.item.shortcut || "") : ""
                                    color: row.isHighlighted ? root.bg : root.muted
                                    opacity: 0.82
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        MouseArea {
                            visible: row.isItem
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.highlightedRow = row.index
                            onClicked: root.runItem(row.modelData.item)
                        }
                    }
                }

                Column {
                    visible: !root.aiMode && root.visibleRows.length === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 80, 420)
                    spacing: 10

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 14
                        color: root.panelSoft
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            color: root.accent
                            font.family: root.uiFont
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        width: parent.width
                        text: "No command found."
                        color: root.text
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.uiFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    Text {
                        width: parent.width
                        text: "Press Enter to ask AI about: " + root.searchQuery
                        color: root.muted
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: root.uiFont
                        font.pixelSize: 12
                    }
                }

                Item {
                    visible: root.aiMode
                    anchors.fill: parent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        Column {
                            visible: root.aiGenerating
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: [0.95, 0.88, 0.72, 0.96, 0.64]
                                Rectangle {
                                    required property real modelData
                                    width: parent.width * modelData
                                    height: 12
                                    radius: 6
                                    color: root.panelSoft
                                }
                            }
                        }

                        Text {
                            visible: !root.aiGenerating && root.aiResponse.length > 0
                            width: parent.width
                            text: root.aiResponse
                            color: root.muted
                            wrapMode: Text.WordWrap
                            lineHeight: 1.18
                            font.family: root.uiFont
                            font.pixelSize: 13
                        }

                        Row {
                            visible: !root.aiGenerating && root.aiResponse.length > 0
                            spacing: 8
                            Repeater {
                                model: ["Omarchy hooks", "DHH commands", "AI backend later"]
                                Rectangle {
                                    required property string modelData
                                    width: tagLabel.implicitWidth + 18
                                    height: 28
                                    radius: 8
                                    color: root.panelSoft
                                    Text {
                                        id: tagLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.text
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 49
                radius: 17
                color: root.chrome

                // Keep only the frame's outer bottom corners rounded.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.radius + 2
                    color: parent.color
                }

                Row {
                    visible: !root.aiMode && root.visibleRows.length > 0
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Row {
                        spacing: 5
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 6
                            color: root.panelSoft
                            Text {
                                anchors.centerIn: parent
                                text: "↑"
                                color: root.muted
                                font.family: root.uiFont
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 6
                            color: root.panelSoft
                            Text {
                                anchors.centerIn: parent
                                text: "↓"
                                color: root.muted
                                font.family: root.uiFont
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Navigate"
                            color: root.muted
                            font.family: root.uiFont
                            font.pixelSize: 11
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 24
                            height: 22
                            radius: 6
                            color: root.panelSoft
                            Text {
                                anchors.centerIn: parent
                                text: "↵"
                                color: root.muted
                                font.family: root.uiFont
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Open"
                            color: root.muted
                            font.family: root.uiFont
                            font.pixelSize: 11
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 22
                        radius: 6
                        color: root.panelSoft
                        Text {
                            anchors.centerIn: parent
                            text: "Esc"
                            color: root.muted
                            font.family: root.uiFont
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.aiMode ? "Back" : "Close"
                        color: root.muted
                        font.family: root.uiFont
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
