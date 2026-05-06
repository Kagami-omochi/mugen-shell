import QtQuick

Item {
    id: root

    property var theme
    property var modeManager
    property string label: ""

    signal clicked()

    implicitWidth: chipText.implicitWidth + (modeManager ? modeManager.scale(28) : 28)
    implicitHeight: modeManager ? modeManager.scale(34) : 34

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: chipMouse.containsMouse
            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
            : (theme ? theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
        border.color: chipMouse.containsMouse
            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
            : (theme ? theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.18))
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: root.label
        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
        opacity: chipMouse.containsMouse ? 1.0 : 0.85
        font.pixelSize: modeManager ? modeManager.scale(12) : 12
        font.family: "M PLUS 2"
        font.letterSpacing: 0.4
        font.italic: true

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
