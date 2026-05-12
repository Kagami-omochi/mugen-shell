import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    Theme.AiBackend { id: aiBackend }

    width: parent ? parent.width : 420
    height: section.isExpanded ? expandedHeight : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false
    property bool loaded: false
    property bool saving: false
    property string statusText: ""

    property var formCommands: []
    property string addCommandText: ""

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        if (!formCommands || formCommands.length === 0) return "permissive (any command)"
        return formCommands.length + " command" + (formCommands.length === 1 ? "" : "s") + " allowed"
    }

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Process {
        id: loadProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.statusText = "load failed"
                return
            }
            try {
                let obj = JSON.parse(loadProcess.buf)
                let cmds = obj.config && obj.config.tools && obj.config.tools.app_launch
                    ? obj.config.tools.app_launch.allowed_commands
                    : null
                section.formCommands = cmds || []
                section.loaded = true
                section.statusText = ""
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: getCurrentProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => getCurrentProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.saving = false
                section.statusText = "load before save failed"
                return
            }
            try {
                let obj = JSON.parse(getCurrentProcess.buf)
                let cfg = obj.config || {}
                if (!cfg.tools) cfg.tools = {}
                if (!cfg.tools.app_launch) cfg.tools.app_launch = {}
                cfg.tools.app_launch.allowed_commands = section.formCommands
                saveProcess.payload = JSON.stringify(cfg)
                saveProcess.running = true
            } catch (e) {
                section.saving = false
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: saveProcess
        running: false
        property string buf: ""
        property string payload: ""
        command: ["curl", "-sS", "--max-time", "5",
                  "-X", "PUT", aiBackend.baseUrl + "/config",
                  "-H", "Content-Type: application/json",
                  "-d", payload]
        stdout: SplitParser { onRead: data => saveProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode === 0 && saveProcess.buf.indexOf("saved") >= 0) {
                section.statusText = "saved, applying…"
                restartProcess.running = true
            } else {
                section.saving = false
                section.statusText = "save failed"
            }
        }
    }

    Process {
        id: restartProcess
        running: false
        command: ["curl", "-sS", "--max-time", "3",
                  "-X", "POST", aiBackend.baseUrl + "/config/restart"]
        onExited: (exitCode) => {
            section.saving = false
            section.statusText = exitCode === 0 ? "applied" : "applied (restart pending)"
        }
    }

    function reload() { loadProcess.running = true }

    function save() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    function removeCommand(cmd) {
        let next = []
        for (let i = 0; i < formCommands.length; i++) {
            if (formCommands[i] !== cmd) next.push(formCommands[i])
        }
        formCommands = next
    }

    function addCommand() {
        let v = addCommandText.trim()
        if (!v) return
        for (let i = 0; i < formCommands.length; i++) {
            if (formCommands[i] === v) {
                addCommandText = ""
                return
            }
        }
        let next = formCommands.slice()
        next.push(v)
        formCommands = next
        addCommandText = ""
    }

    Component.onCompleted: reload()

    MouseArea {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "App launcher allowlist"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }

            Text {
                text: section.summary()
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: !section.loaded || section.summary() === "permissive (any command)"
                opacity: 0.85
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        spacing: 12
        visible: section.isExpanded

        Text {
            Layout.fillWidth: true
            text: "Empty list = any command can be launched. Add entries to enforce strict allowlisting (basename match, e.g. firefox matches /usr/bin/firefox)."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: chipFlow.implicitHeight + 16
            radius: 10
            color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18)
            visible: section.formCommands && section.formCommands.length > 0

            Flow {
                id: chipFlow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 6

                Repeater {
                    model: section.formCommands

                    Rectangle {
                        required property var modelData
                        height: 26
                        // leftMargin (10) + text + spacing (4) + chipX (16) + rightMargin (6)
                        width: chipText.implicitWidth + 36
                        radius: 13
                        color: section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20)
                        border.width: 1
                        border.color: section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 4

                            Text {
                                id: chipText
                                text: modelData
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                            }

                            Rectangle {
                                id: chipX
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 8
                                color: chipXMouse.containsMouse
                                    ? Qt.rgba(0.95, 0.55, 0.65, 0.40)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                                    font.pixelSize: 11
                                    font.family: "M PLUS 2"
                                }

                                MouseArea {
                                    id: chipXMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: section.removeCommand(parent.parent.parent.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "transparent"
                radius: 8
                border.width: 1
                border.color: addInput.activeFocus
                    ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                Behavior on border.color { ColorAnimation { duration: 180 } }

                TextInput {
                    id: addInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: section.addCommandText
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onTextChanged: section.addCommandText = text
                    Keys.onReturnPressed: section.addCommand()
                    Keys.onEnterPressed: section.addCommand()

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "command name (e.g. firefox, kitty)"
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.5)
                        font: addInput.font
                        opacity: addInput.text.length === 0 ? 0.5 : 0
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 28
                radius: 14
                enabled: section.addCommandText.trim().length > 0
                color: addMouse.containsMouse && enabled
                    ? Qt.rgba(0.45, 0.65, 0.90, 0.45)
                    : Qt.rgba(0.45, 0.65, 0.90, 0.25)
                opacity: enabled ? 1.0 : 0.5
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: "Add"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.addCommand()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: section.statusText
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: section.statusText ? 0.85 : 0
                elide: Text.ElideRight
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 28
                radius: 14
                enabled: !section.saving
                color: saveMouse.containsMouse
                    ? Qt.rgba(0.45, 0.65, 0.90, 0.45)
                    : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                opacity: section.saving ? 0.5 : 1.0
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: section.saving ? "…" : "Save & Apply"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !section.saving
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.save(); section.bump() }
                }
            }
        }
    }
}
