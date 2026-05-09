import QtQuick

QtObject {
    id: state

    property bool expanded: false
    property string panelSide: "left"

    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool isLeft: panelSide !== "right"

    property int panelWidth: 480
    property int panelMargin: 16

    property int orbCollapsedSize: 64
    property int orbExpandedSize: 80

    property real orbInPanelX: panelWidth / 2 - orbExpandedSize / 2
    property real orbInPanelY: 64

    readonly property int panelRestX: isLeft
        ? panelMargin
        : screenWidth - panelWidth - panelMargin
    readonly property int panelHiddenX: isLeft
        ? -panelWidth
        : screenWidth

    readonly property real orbRestX: isLeft
        ? panelMargin
        : screenWidth - orbCollapsedSize - panelMargin
    readonly property real orbRestY: screenHeight - orbCollapsedSize - panelMargin - 48

    readonly property real orbActiveX: panelRestX + orbInPanelX
    readonly property real orbActiveY: orbInPanelY

    readonly property real orbX: expanded ? orbActiveX : orbRestX
    readonly property real orbY: expanded ? orbActiveY : orbRestY
    readonly property real orbSize: expanded ? orbExpandedSize : orbCollapsedSize

    readonly property real panelX: expanded ? panelRestX : panelHiddenX
    readonly property real panelOpacity: expanded ? 1.0 : 0.0

    function toggle() { expanded = !expanded }
    function open()   { expanded = true }
    function close()  { expanded = false }
}
