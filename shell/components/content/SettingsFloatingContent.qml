import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./settings" as Settings

Item {
    id: root

    required property var modeManager
    property var theme
    required property var settingsManager
    required property var blurPresets
    required property string currentPreset
    required property bool isLoadingPresets
    required property var notificationSounds

    signal applyPreset(string name)
    signal applySound(string name)

    property string selectedSection: "theme"

    readonly property var sectionsList: [
        { type: "theme",             label: "Theme" },
        { type: "blur",              label: "Blur" },
        { type: "timer",             label: "Auto-close timer" },
        { type: "gradient",          label: "Bar gradient" },
        { type: "battery",           label: "Battery indicator" },
        { type: "animation",         label: "Animation speed" },
        { type: "notificationSound", label: "Notification sound" },
        { type: "lockTimer",         label: "Lock timer" },
        { type: "shortcuts",         label: "Keyboard shortcuts" }
    ]

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surfaceInsetCard : Qt.rgba(0.05, 0.05, 0.08, 0.92)
        radius: 0
        border.width: 0

        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Up) {
                let idx = root.sectionsList.findIndex(s => s.type === root.selectedSection)
                if (idx <= 0) idx = root.sectionsList.length
                root.selectedSection = root.sectionsList[idx - 1].type
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                let idx = root.sectionsList.findIndex(s => s.type === root.selectedSection)
                if (idx < 0 || idx >= root.sectionsList.length - 1) idx = -1
                root.selectedSection = root.sectionsList[idx + 1].type
                event.accepted = true
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        text: "Settings"
                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.sectionsList
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: ListView.view.width
                        height: 38

                        property bool isSelected: modelData.type === root.selectedSection

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            color: isSelected
                                ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                                : (sectionHover.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                            radius: 8

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            text: modelData.label
                            color: isSelected
                                ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            font.pixelSize: 12
                            font.weight: isSelected ? Font.Medium : Font.Light
                            font.family: "M PLUS 2"

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: sectionHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedSection = modelData.type
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.1)
                opacity: 0.3
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 32

                    Loader {
                        id: sectionLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        sourceComponent: {
                            switch (root.selectedSection) {
                                case "theme":             return themeComp
                                case "blur":              return blurComp
                                case "timer":             return timerComp
                                case "gradient":          return gradientComp
                                case "battery":           return batteryComp
                                case "animation":         return animationComp
                                case "notificationSound": return notificationSoundComp
                                case "lockTimer":         return lockTimerComp
                                case "shortcuts":         return shortcutsComp
                                default:                  return null
                            }
                        }
                    }
                }
            }
        }
    }

    Component { id: themeComp; Settings.ThemeSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: blurComp; Settings.BlurSection {
        theme: root.theme
        modeManager: root.modeManager
        presets: root.blurPresets
        currentPreset: root.currentPreset
        isLoadingPresets: root.isLoadingPresets
        onApplyPreset: name => root.applyPreset(name)
    }}
    Component { id: timerComp; Settings.TimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: gradientComp; Settings.GradientSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: batteryComp; Settings.BatterySection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: animationComp; Settings.AnimationSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: notificationSoundComp; Settings.NotificationSoundSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
        sounds: root.notificationSounds
        onApplySound: name => root.applySound(name)
    }}
    Component { id: lockTimerComp; Settings.LockTimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: shortcutsComp; Settings.KeyboardShortcutsSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
}
