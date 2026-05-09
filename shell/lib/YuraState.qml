import QtQuick

QtObject {
    id: state

    property bool expanded: false
    property string panelSide: "left"

    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool isLeft: panelSide !== "right"

    property int panelWidth: 620
    property int panelHeight: 640
    property int panelMargin: 16

    property int orbCollapsedSize: 56

    property int sidebarWidth: 200
    property bool sidebarCollapsed: false

    readonly property int mainPaneWidth: panelWidth - (sidebarCollapsed ? 0 : sidebarWidth)
    readonly property int mainPaneHeight: panelHeight

    readonly property real orbExpandedSize: Math.min(mainPaneWidth, mainPaneHeight) * 0.28

    readonly property int panelRestX: isLeft
        ? panelMargin
        : screenWidth - panelWidth - panelMargin
    readonly property int panelRestY: screenHeight - panelHeight - panelMargin
    readonly property int panelHiddenX: isLeft
        ? -panelWidth
        : screenWidth

    readonly property real orbRestX: isLeft
        ? panelMargin
        : screenWidth - orbCollapsedSize - panelMargin
    readonly property real orbRestY: screenHeight - orbCollapsedSize - panelMargin

    readonly property real orbActiveX: isLeft
        ? panelRestX + (sidebarCollapsed ? 0 : sidebarWidth) + (mainPaneWidth - orbExpandedSize) / 2
        : panelRestX + (mainPaneWidth - orbExpandedSize) / 2
    readonly property real orbActiveY: panelRestY + mainPaneHeight * 0.18

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
