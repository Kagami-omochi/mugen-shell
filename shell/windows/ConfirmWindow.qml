import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../lib" as Theme
import "../components/common" as Common

// Full-screen overlay that asks the user to confirm a tool-call before
// mugen-ai executes it. Reached via IpcRouter.confirm.request; once the
// user clicks a button we POST the result back to the mugen-ai callback
// URL the request carried.
PanelWindow {
    id: confirmWindow

    required property var theme
    required property var icons

    // Cover the whole screen so it sits over Bar and any detached panels.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    visible: false

    property string requestId: ""
    property string message: ""
    property string callbackUrl: ""
    property string iconKey: ""

    // 0 → 1 over a short ease so the icon + orb fade in instead of popping.
    // Driven by show() / respond(); a delayed timer also defers the actual
    // hide so the fade-out is visible too.
    property real openProgress: 0
    Behavior on openProgress {
        NumberAnimation { duration: 650; easing.type: Easing.OutCubic }
    }

    // Resolve "lock" / "suspend" / "logout" / "reboot" / "shutdown" to the
    // icon data the shared IconProvider exposes; suspend has no entry there
    // yet so we fall back to a moon emoji.
    readonly property var resolvedIcon: {
        if (!iconKey) return null
        if (iconKey === "suspend") return { type: "text", value: "💤" }
        if (icons && icons.iconData && icons.iconData[iconKey]) {
            return icons.iconData[iconKey]
        }
        return null
    }

    function show(id: string, msg: string, url: string, icon: string): void {
        confirmWindow.requestId = id
        confirmWindow.message = msg
        confirmWindow.callbackUrl = url
        confirmWindow.iconKey = icon || ""
        confirmWindow.visible = true
        focusGrabber.forceActiveFocus()
        confirmWindow.openProgress = 1
    }

    function respond(approved: bool): void {
        if (confirmWindow.callbackUrl !== "") {
            responseProcess.payload = JSON.stringify({ approved: approved })
            responseProcess.targetUrl = confirmWindow.callbackUrl
            responseProcess.running = true
        }
        confirmWindow.openProgress = 0
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 670
        repeat: false
        onTriggered: confirmWindow.visible = false
    }

    Process {
        id: responseProcess
        property string payload: ""
        property string targetUrl: ""
        running: false
        command: ["curl", "-sS", "-X", "POST", targetUrl,
                  "-H", "Content-Type: application/json",
                  "-d", payload]
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        // Click outside dismisses as deny — same as cancel.
        MouseArea {
            anchors.fill: parent
            onClicked: confirmWindow.respond(false)
        }
    }

    // Soft orb halo behind the icon — matches the rest of mugen-shell's
    // BlobEffect aesthetic. Sits above the dim overlay but below the
    // content column so the icon / text always read on top. Kept subtle
    // so the buttons remain legible against it.
    Item {
        id: orbWrapper
        anchors.centerIn: parent
        width: 480
        height: 480
        opacity: confirmWindow.openProgress

        property real pulseScale: 1.0

        SequentialAnimation on pulseScale {
            running: confirmWindow.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.10; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 1800; easing.type: Easing.InOutSine }
        }

        transform: Scale {
            origin.x: orbWrapper.width / 2
            origin.y: orbWrapper.height / 2
            xScale: orbWrapper.pulseScale * (0.88 + 0.12 * confirmWindow.openProgress)
            yScale: orbWrapper.pulseScale * (0.88 + 0.12 * confirmWindow.openProgress)
        }

        Common.BlobEffect {
            anchors.fill: parent
            blobColor: confirmWindow.theme
                ? Qt.rgba(confirmWindow.theme.accent.r, confirmWindow.theme.accent.g, confirmWindow.theme.accent.b, 0.10)
                : Qt.rgba(0.65, 0.55, 0.85, 0.10)
            layers: 3
            waveAmplitude: 8.0
            baseOpacity: 0.30
            animationSpeed: 0.03
            pointCount: 18
            running: confirmWindow.visible
        }
    }

    Item {
        id: focusGrabber
        anchors.fill: parent
        focus: confirmWindow.visible

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                confirmWindow.respond(false)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                confirmWindow.respond(true)
                event.accepted = true
            }
        }
    }

    ColumnLayout {
        id: cardCol
        anchors.centerIn: parent
        width: 480
        spacing: 28
        opacity: confirmWindow.openProgress

        transform: Scale {
            origin.x: cardCol.width / 2
            origin.y: cardCol.height / 2
            xScale: 0.92 + 0.08 * confirmWindow.openProgress
            yScale: 0.92 + 0.08 * confirmWindow.openProgress
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            visible: confirmWindow.resolvedIcon !== null

            Common.GlowSvgIcon {
                anchors.fill: parent
                visible: confirmWindow.resolvedIcon && confirmWindow.resolvedIcon.type === "svg"
                source: confirmWindow.resolvedIcon && confirmWindow.resolvedIcon.type === "svg"
                    ? confirmWindow.resolvedIcon.value
                    : ""
                color: confirmWindow.theme ? confirmWindow.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                glowColor: confirmWindow.theme ? Qt.rgba(confirmWindow.theme.accent.r, confirmWindow.theme.accent.g, confirmWindow.theme.accent.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)
                glowRadius: 12
                glowSamples: 20
            }

            Text {
                anchors.centerIn: parent
                visible: confirmWindow.resolvedIcon && confirmWindow.resolvedIcon.type === "text"
                text: confirmWindow.resolvedIcon ? confirmWindow.resolvedIcon.value : ""
                font.pixelSize: 128
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Confirm action"
            color: confirmWindow.theme ? confirmWindow.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
            font.pixelSize: 16
            font.family: "M PLUS 2"
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: confirmWindow.message
            color: confirmWindow.theme ? confirmWindow.theme.textSecondary : Qt.rgba(0.85, 0.85, 0.92, 0.85)
            font.pixelSize: 14
            font.family: "M PLUS 2"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 14

            Rectangle {
                width: 120
                height: 40
                radius: 12
                color: cancelMouse.containsMouse
                    ? (confirmWindow.theme ? confirmWindow.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
                    : "transparent"
                border.color: confirmWindow.theme ? confirmWindow.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.30)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: confirmWindow.theme ? confirmWindow.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                    font.pixelSize: 13
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmWindow.respond(false)
                }
            }

            Rectangle {
                width: 120
                height: 40
                radius: 12
                color: confirmMouse.containsMouse
                    ? (confirmWindow.theme ? Qt.darker(confirmWindow.theme.accent, 1.15) : Qt.rgba(0.55, 0.45, 0.78, 1.0))
                    : (confirmWindow.theme ? confirmWindow.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0))

                Text {
                    anchors.centerIn: parent
                    text: "Confirm"
                    color: "white"
                    font.pixelSize: 13
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: confirmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmWindow.respond(true)
                }
            }
        }
    }
}
