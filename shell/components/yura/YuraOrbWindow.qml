import QtQuick
import Quickshell
import Quickshell.Wayland
import "../content/ai" as Ai

PanelWindow {
    id: orbWindow

    required property var yuraState
    required property var theme

    color: "transparent"
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        x: orb.x
        y: orb.y
        width: yuraState.aiDropdownOpen ? 0 : orb.width
        height: yuraState.aiDropdownOpen ? 0 : orb.height
    }

    function syncScreenSize() {
        yuraState.screenWidth = orbWindow.width
        yuraState.screenHeight = orbWindow.height
    }

    onWidthChanged: syncScreenSize()
    onHeightChanged: syncScreenSize()

    Item {
        id: orb

        x: yuraState.orbX
        y: yuraState.orbY
        width: yuraState.orbSize
        height: yuraState.orbSize

        property real dropdownGate: yuraState.aiDropdownOpen ? 0 : 1
        Behavior on dropdownGate { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }

        property real expandGate: 0

        SequentialAnimation {
            id: orbOpenAnim
            PauseAnimation { duration: 250 }
            NumberAnimation { target: orb; property: "expandGate"; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }

        NumberAnimation {
            id: orbCloseAnim
            target: orb; property: "expandGate"; to: 0; duration: 750; easing.type: Easing.OutCubic
        }

        Connections {
            target: yuraState
            function onExpandedChanged() {
                if (yuraState.expanded) {
                    orbCloseAnim.stop()
                    orb.expandGate = 0
                    orbOpenAnim.restart()
                } else {
                    orbOpenAnim.stop()
                    orbCloseAnim.restart()
                }
            }
        }

        opacity: dropdownGate * expandGate
        scale: 0.3 + expandGate * 0.7
        transformOrigin: Item.Center

        transform: Translate {
            x: (1 - orb.expandGate) * (yuraState.orbRestX - yuraState.orbActiveX)
        }

        smooth: true
        antialiasing: true

        Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: orbWindow.theme ? orbWindow.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            showHalo: false
            coreOpacity: 0.6
            corePointCount: 48
            coreWaveAmplitude: 0.5
            idleBreathPeak: 1.20
            idleBreathDuration: 1400
            active: yuraState.expanded
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: yuraState.toggle()
        }
    }
}
