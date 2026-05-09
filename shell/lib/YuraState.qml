import QtQuick

QtObject {
    id: state

    property bool expanded: false
    property string panelSide: "left"

    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool isLeft: panelSide !== "right"

    property int panelWidth: 520
    property int panelHeight: 640
    property int panelMargin: 16

    property int orbCollapsedSize: 56
    property int orbExpandedSize: 72
    property int orbHeaderInset: 18

    readonly property int panelRestX: isLeft
        ? panelMargin
        : screenWidth - panelWidth - panelMargin
    readonly property int panelRestY: screenHeight - panelHeight - panelMargin
    readonly property int panelHiddenX: isLeft
        ? panelMargin - 32
        : screenWidth - panelWidth - panelMargin + 32

    readonly property real orbRestX: isLeft
        ? panelMargin
        : screenWidth - orbCollapsedSize - panelMargin
    readonly property real orbRestY: screenHeight - orbCollapsedSize - panelMargin

    readonly property real orbActiveX: panelRestX + panelWidth / 2 - orbExpandedSize / 2
    readonly property real orbActiveY: panelRestY + orbHeaderInset

    readonly property real orbX: expanded ? orbActiveX : orbRestX
    readonly property real orbY: expanded ? orbActiveY : orbRestY
    readonly property real orbSize: expanded ? orbExpandedSize : orbCollapsedSize

    readonly property real panelX: expanded ? panelRestX : panelHiddenX
    readonly property real panelY: panelRestY
    readonly property real panelOpacity: expanded ? 1.0 : 0.0

    function toggle() { expanded = !expanded }
    function open()   { expanded = true }
    function close()  { expanded = false }
}
