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

    property var rows: []

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        if (rows.length === 0) return "none configured"
        let connected = 0
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].connected) connected++
        }
        return connected + " / " + rows.length + " connected"
    }

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Process {
        id: loadProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/mcp/servers"]
        stdout: SplitParser { onRead: data => loadProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let obj = JSON.parse(loadProcess.buf)
                section.rows = obj.servers || []
                section.loaded = true
            } catch (e) {}
        }
    }

    Component.onCompleted: loadProcess.running = true

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
                text: "MCP servers"
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
                font.italic: !section.loaded
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
        spacing: 8
        visible: section.isExpanded

        Text {
            Layout.fillWidth: true
            text: "Read-only status. Add servers under [mcp.servers.*] via the Edit toml button in Personality, then Restart AI."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: section.loaded && section.rows.length === 0
            text: "No MCP servers configured."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.7
        }

        Repeater {
            model: section.rows

            Rectangle {
                id: serverRow
                required property var modelData
                readonly property bool failed: !modelData.connected && !modelData.disabled

                Layout.fillWidth: true
                Layout.preferredHeight: serverBody.implicitHeight + 16
                radius: 10
                color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
                border.width: 1
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

                ColumnLayout {
                    id: serverBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: serverRow.modelData.connected
                                ? Qt.rgba(0.45, 0.85, 0.55, 0.95)
                                : serverRow.modelData.disabled
                                    ? Qt.rgba(0.6, 0.6, 0.65, 0.7)
                                    : Qt.rgba(0.85, 0.45, 0.45, 0.85)
                        }

                        Text {
                            text: serverRow.modelData.name
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: serverRow.modelData.connected
                                ? "running"
                                : serverRow.modelData.disabled
                                    ? "disabled"
                                    : "failed"
                            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            opacity: 0.7
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: serverRow.modelData.connected
                            ? (serverRow.modelData.tool_count + " tool" + (serverRow.modelData.tool_count === 1 ? "" : "s"))
                            : serverRow.modelData.disabled
                                ? "Skipped — remove disabled = true in config to enable."
                                : (serverRow.modelData.error || "Handshake failed.")
                        color: serverRow.failed
                            ? Qt.rgba(0.9, 0.55, 0.55, 0.9)
                            : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                        font.pixelSize: 10
                        font.family: "M PLUS 2"
                        opacity: serverRow.failed ? 0.95 : 0.75
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 96
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignRight
            radius: 14
            color: refreshMouse.containsMouse
                ? Qt.rgba(0.55, 0.55, 0.65, 0.32)
                : Qt.rgba(0.55, 0.55, 0.65, 0.22)
            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
                anchors.centerIn: parent
                text: "Refresh"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { loadProcess.running = true; section.bump() }
            }
        }
    }
}
