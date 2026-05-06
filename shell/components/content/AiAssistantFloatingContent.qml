import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../common" as Common
import "./ai" as Ai

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var icons

    property var messages: []
    property bool streaming: false
    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    property bool userScrolled: false
    property string currentModel: ""
    property var availableModels: []
    property bool modelDropdownOpen: false

    readonly property bool isEmpty: messages.length === 0
    readonly property var suggestedPrompts: [
        "Help me brainstorm an idea",
        "Explain a concept simply",
        "Write a short poem about the moon"
    ]

    function appendMessage(role, content) {
        let copy = messages.slice()
        copy.push({ role: role, content: content })
        messages = copy
    }

    function updateLastMessage(content) {
        if (messages.length === 0) return
        let copy = messages.slice()
        copy[copy.length - 1] = {
            role: copy[copy.length - 1].role,
            content: copy[copy.length - 1].content + content
        }
        messages = copy
    }

    function sendMessage(text) {
        if (!text || streaming) return
        appendMessage("user", text)
        appendMessage("assistant", "")
        streaming = true
        userScrolled = false
        chatProcess.payload = JSON.stringify({ message: text })
        chatProcess.running = true
    }

    function stopStreaming() {
        if (!streaming) return
        chatProcess.signal(15)
        streaming = false
    }

    function clearHistory() {
        messages = []
        clearProcess.running = true
    }

    Timer {
        id: focusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.aiAvailable) inputField.forceActiveFocus()
        }
    }

    // ── Background: cosmic gradient ─────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.04, 0.12, 1.0) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.025, 0.09, 1.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.025, 0.015, 0.07, 1.0) }
        }
    }

    // Subtle radial nebula glow at the center of the window
    Item {
        anchors.fill: parent
        Canvas {
            id: nebula
            anchors.fill: parent
            opacity: 0.55
            property color glow: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.85)
            onGlowChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                let cx = width / 2
                let cy = height * 0.45
                let r = Math.max(width, height) * 0.55
                let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                g.addColorStop(0, Qt.rgba(glow.r, glow.g, glow.b, 0.18))
                g.addColorStop(0.6, Qt.rgba(glow.r, glow.g, glow.b, 0.04))
                g.addColorStop(1, Qt.rgba(glow.r, glow.g, glow.b, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
        }
    }

    // Drift particles — sparse dim points slowly moving
    Canvas {
        id: particles
        anchors.fill: parent
        opacity: 0.5

        property var points: []
        property color particleColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.85, 0.78, 1.0, 0.85)

        Component.onCompleted: {
            points = []
            for (let i = 0; i < 22; i++) {
                points.push({
                    x: Math.random(),
                    y: Math.random(),
                    r: 0.6 + Math.random() * 1.4,
                    phase: Math.random() * Math.PI * 2,
                    speed: 0.0006 + Math.random() * 0.0014,
                    drift: 0.00015 + Math.random() * 0.00035
                })
            }
            requestPaint()
        }

        onPaint: {
            let ctx = getContext("2d")
            ctx.reset()
            for (let i = 0; i < points.length; i++) {
                let p = points[i]
                let alpha = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(p.phase))
                let x = p.x * width
                let y = p.y * height
                ctx.beginPath()
                ctx.arc(x, y, p.r, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(particleColor.r, particleColor.g, particleColor.b, alpha)
                ctx.fill()
            }
        }

        Timer {
            interval: 60
            running: true
            repeat: true
            onTriggered: {
                let pts = particles.points
                for (let i = 0; i < pts.length; i++) {
                    pts[i].phase += pts[i].speed * 60
                    pts[i].y -= pts[i].drift
                    if (pts[i].y < -0.02) {
                        pts[i].y = 1.02
                        pts[i].x = Math.random()
                    }
                }
                particles.requestPaint()
            }
        }
    }

    // ── Top chrome: model selector + clear (active only) ────────────────
    RowLayout {
        id: topChrome
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: modeManager.scale(14)
        anchors.rightMargin: modeManager.scale(18)
        spacing: modeManager.scale(10)
        z: 5

        Ai.ModelSelector {
            visible: root.aiAvailable && root.currentModel !== ""
            theme: root.theme
            modeManager: root.modeManager
            currentModel: root.currentModel
            availableModels: root.availableModels
            isOpen: root.modelDropdownOpen

            onToggled: root.modelDropdownOpen = !root.modelDropdownOpen
            onModelChosen: name => {
                if (name !== root.currentModel) {
                    if (root.streaming) root.stopStreaming()
                    root.currentModel = name
                    switchModelProcess.payload = JSON.stringify({ model: name })
                    switchModelProcess.running = true
                }
                root.modelDropdownOpen = false
            }
        }

        Item {
            Layout.preferredWidth: modeManager.scale(28)
            Layout.preferredHeight: modeManager.scale(28)
            visible: root.aiAvailable && root.hasModel && !root.isEmpty
            opacity: clearMouse.containsMouse ? 1.0 : 0.55

            Behavior on opacity { NumberAnimation { duration: 200 } }

            UI.SvgIcon {
                anchors.centerIn: parent
                width: modeManager.scale(15)
                height: modeManager.scale(15)
                source: root.icons ? root.icons.trashSvg : ""
                color: clearMouse.containsMouse
                    ? Qt.rgba(0.95, 0.55, 0.65, 1.0)
                    : (root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.9))
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearHistory()
            }
        }
    }

    // ── The orb: morphs between empty (center, large) and active
    //    (bottom-left of latest AI message). Size + position animate together,
    //    so during streaming the orb trails the bottom of growing text.
    Item {
        id: orb
        z: 4

        readonly property real emptySize: Math.min(root.width, root.height) * 0.28
        readonly property real activeSize: modeManager.scale(36)
        readonly property real emptyX: (root.width - emptySize) / 2
        readonly property real emptyY: root.height * 0.18

        property real activeX: activeOverlay.x
        property real activeY: 0
        property bool activePosReady: false

        // Hold at empty position until we know where to land in active state,
        // so the orb doesn't briefly jump to (0,0) before reaching the message.
        readonly property bool isInEmptyState: root.isEmpty || !activePosReady

        Connections {
            target: root
            function onMessagesChanged() { Qt.callLater(orb.updateActivePos) }
        }

        function updateActivePos() {
            if (root.messages.length === 0) {
                activePosReady = false
                return
            }
            let lastIdx = root.messages.length - 1
            let item = chatList.itemAtIndex(lastIdx)
            if (!item) {
                activePosReady = false
                return
            }
            activeX = activeOverlay.x
            activeY = activeOverlay.y + item.y - chatList.contentY + item.height - modeManager.scale(40)
            activePosReady = true
        }

        x: isInEmptyState ? emptyX : activeX
        y: isInEmptyState ? emptyY : activeY
        width: isInEmptyState ? emptySize : activeSize
        height: width

        Behavior on x {
            enabled: !chatList.moving && !chatList.flicking
            NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
        }
        Behavior on y {
            enabled: !chatList.moving && !chatList.flicking
            NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
        }
        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            streaming: !root.isEmpty && root.streaming
            haloScale: root.isEmpty ? 1.5 : 1.8
            haloOpacity: root.isEmpty ? 0.45 : 0.6
        }

        Connections {
            target: chatList
            function onContentYChanged() { orb.updateActivePos() }
            function onContentHeightChanged() { orb.updateActivePos() }
            function onCountChanged() { Qt.callLater(orb.updateActivePos) }
        }
    }

    // ── Empty state: greeting + prompt chips ────────────────────────────
    Item {
        id: emptyOverlay
        anchors.fill: parent
        z: 3
        opacity: root.isEmpty && root.aiAvailable && root.hasModel ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.18 + orb.emptySize + modeManager.scale(28)
            spacing: modeManager.scale(18)
            width: Math.min(parent.width - modeManager.scale(64), modeManager.scale(560))

            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: "What's on your mind?"
                font.pixelSize: modeManager.scale(20)
                font.family: "M PLUS 2"
                font.italic: true
                font.weight: Font.Light
                font.letterSpacing: 0.8
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)

                enableGlow: true
                glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                glowSamples: 24
                glowRadius: 14
                glowSpread: 0.4
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(10)

                Repeater {
                    model: root.suggestedPrompts
                    delegate: Ai.PromptChip {
                        Layout.alignment: Qt.AlignHCenter
                        theme: root.theme
                        modeManager: root.modeManager
                        label: modelData
                        onClicked: {
                            if (!root.streaming) {
                                inputField.text = ""
                                root.sendMessage(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Active state: chat list ─────────────────────────────────────────
    Item {
        id: activeOverlay
        anchors.fill: parent
        anchors.topMargin: modeManager.scale(60)
        anchors.bottomMargin: inputBar.height + modeManager.scale(16)
        anchors.leftMargin: modeManager.scale(40)
        anchors.rightMargin: modeManager.scale(40)
        z: 3
        opacity: !root.isEmpty ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        ListView {
            id: chatList
            anchors.fill: parent
            spacing: modeManager.scale(14)
            clip: true
            model: root.messages
            interactive: true

            onContentHeightChanged: {
                if (!root.userScrolled) positionViewAtEnd()
            }

            onMovingChanged: {
                if (moving) root.userScrolled = true
            }

            onAtYEndChanged: {
                if (atYEnd) root.userScrolled = false
            }

            delegate: Item {
                id: delegateRoot
                width: chatList.width
                implicitHeight: msgCol.implicitHeight + modeManager.scale(8)

                readonly property bool isAssistant: modelData.role === "assistant"
                readonly property bool isLatest: index === root.messages.length - 1
                readonly property bool isThinking: root.streaming
                    && isLatest
                    && isAssistant
                    && modelData.content === ""
                readonly property bool showInlineOrb: isAssistant && isLatest

                Column {
                    id: msgCol
                    width: parent.width
                    spacing: modeManager.scale(6)

                    Text {
                        visible: !delegateRoot.isThinking && modelData.content !== ""
                        width: parent.width
                        horizontalAlignment: delegateRoot.isAssistant ? Text.AlignLeft : Text.AlignRight
                        text: modelData.content
                        wrapMode: Text.WordWrap
                        color: delegateRoot.isAssistant
                            ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                            : (root.theme ? root.theme.textSecondary : Qt.rgba(0.78, 0.78, 0.88, 0.85))
                        font.pixelSize: modeManager.scale(14)
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.3
                        lineHeight: 1.5
                    }

                    // Reserve space for the global orb that lands at the bottom-left
                    Item {
                        visible: delegateRoot.isAssistant && delegateRoot.isLatest
                        width: 1
                        height: modeManager.scale(40)
                    }
                }
            }
        }
    }

    // ── Bottom: thin underline input ────────────────────────────────────
    Item {
        id: inputBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: modeManager.scale(40)
        anchors.rightMargin: modeManager.scale(40)
        anchors.bottomMargin: modeManager.scale(22)
        height: modeManager.scale(46)
        z: 5
        visible: root.aiAvailable && root.hasModel

        // Underline with glow on focus
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: inputField.activeFocus
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.85) : Qt.rgba(0.65, 0.55, 0.85, 0.85))
                : Qt.rgba(0.5, 0.5, 0.65, 0.25)

            Behavior on color { ColorAnimation { duration: 250 } }

            layer.enabled: inputField.activeFocus
            layer.effect: Glow {
                samples: 18
                radius: 8
                spread: 0.3
                color: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                transparentBorder: true
            }
        }

        TextInput {
            id: inputField
            anchors.left: parent.left
            anchors.right: sendIcon.left
            anchors.rightMargin: modeManager.scale(12)
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
            font.pixelSize: modeManager.scale(15)
            font.family: "M PLUS 2"
            font.letterSpacing: 0.3
            selectByMouse: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            inputMethodHints: Qt.ImhNone

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let txt = inputField.text.trim()
                    if (txt.length > 0 && !root.streaming) {
                        root.sendMessage(txt)
                        inputField.text = ""
                    }
                    event.accepted = true
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: root.streaming ? "Thinking..." : "Ask anything"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                font.pixelSize: parent.font.pixelSize
                font.family: parent.font.family
                font.letterSpacing: parent.font.letterSpacing
                font.italic: true
                visible: parent.text.length === 0
            }
        }

        Item {
            id: sendIcon
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: modeManager.scale(34)
            height: modeManager.scale(34)
            opacity: (root.streaming || inputField.text.trim().length > 0) ? 1.0 : 0.35

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: sendMouse.containsMouse
                    ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
                    : (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.streaming ? "■" : "↑"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: modeManager.scale(root.streaming ? 12 : 16)
                font.family: "M PLUS 2"
            }

            MouseArea {
                id: sendMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.streaming) {
                        root.stopStreaming()
                    } else {
                        let txt = inputField.text.trim()
                        if (txt.length > 0) {
                            root.sendMessage(txt)
                            inputField.text = ""
                        }
                    }
                }
            }
        }
    }

    // ── Service unavailable / no model states ───────────────────────────
    Item {
        anchors.fill: parent
        z: 3
        visible: root.healthChecked && (!root.aiAvailable || !root.hasModel)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(10)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: !root.aiAvailable ? "mugen-ai is not running" : "No models available"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                font.pixelSize: modeManager.scale(16)
                font.family: "M PLUS 2"
                font.weight: Font.Light
                font.italic: true
                font.letterSpacing: 0.8
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: !root.aiAvailable
                    ? "Install mugen-ai from this repo:\nmake install-ai"
                    : "Pull an Ollama model (e.g. ollama pull gemma3:4b)\nor configure Gemini in ~/.config/mugen-ai/config.toml"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7)
                font.pixelSize: modeManager.scale(12)
                font.family: !root.aiAvailable ? "monospace" : "M PLUS 2"
                lineHeight: 1.4
            }
        }
    }

    // ── Process objects (chat / clear / health / models / switch) ───────
    Process {
        id: chatProcess
        property string payload: ""
        running: false
        command: ["curl", "-sS", "-N", "-X", "POST",
                  "http://127.0.0.1:11435/chat",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                let line = data.trim()
                if (!line.startsWith("data:")) return
                let jsonStr = line.substring(5).trim()
                if (!jsonStr) return
                try {
                    let obj = JSON.parse(jsonStr)
                    if (obj.error) {
                        root.updateLastMessage("\n[error: " + obj.error + "]")
                        return
                    }
                    if (obj.content) {
                        root.updateLastMessage(obj.content)
                    }
                } catch (e) {
                }
            }
        }

        onExited: (exitCode) => {
            root.streaming = false
            if (exitCode !== 0) {
                root.updateLastMessage("\n[connection failed]")
            }
        }
    }

    Process {
        id: clearProcess
        running: false
        command: ["curl", "-sS", "-X", "DELETE", "http://127.0.0.1:11435/history"]
    }

    Process {
        id: healthProcess
        running: false
        property string buf: ""
        command: ["curl", "-sSf", "--max-time", "2", "http://127.0.0.1:11435/health"]

        stdout: SplitParser {
            onRead: data => { healthProcess.buf += data }
        }

        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            root.aiAvailable = (exitCode === 0)
            root.healthChecked = true
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    root.currentModel = obj.model || ""
                    root.hasModel = obj.status === "ok"
                } catch (e) {}
                modelsProcess.running = true
            }
        }
    }

    Process {
        id: modelsProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", "http://127.0.0.1:11435/models"]

        stdout: SplitParser {
            onRead: data => { modelsProcess.buf += data }
        }

        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    if (obj.models) root.availableModels = obj.models
                } catch (e) {}
            }
        }
    }

    Process {
        id: switchModelProcess
        running: false
        property string payload: ""
        command: ["curl", "-sS", "-X", "PUT",
                  "http://127.0.0.1:11435/model",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.messages = []
            }
        }
    }

    Component.onCompleted: {
        healthProcess.running = true
        focusTimer.restart()
    }
}
