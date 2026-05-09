//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications as NS
import "./windows" as Windows
import "./lib" as Theme
import "./components/yura" as Yura

ShellRoot {
    id: root

    Windows.Bar {
        id: barWindow
    }

    Theme.YuraState {
        id: yuraState
        panelSide: barWindow.settingsManager
            ? barWindow.settingsManager.yuraPanelSide
            : "left"
    }

    Yura.YuraChatPanel {
        yuraState: yuraState
        theme: barWindow.theme
        icons: barWindow.icons
        aiBackend: barWindow.aiBackend
        settingsManager: barWindow.settingsManager
    }

    Yura.YuraOrbWindow {
        yuraState: yuraState
        theme: barWindow.theme
    }

    IpcHandler {
        target: "yura"
        function toggle() { yuraState.toggle() }
        function open()   { yuraState.open() }
        function close()  { yuraState.close() }
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }

        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup()
        }
    }

    NS.NotificationServer {
        id: notifySrv

        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true
    }

    Connections {
        target: notifySrv

        function onNotification(n) {
            barWindow.notificationManager.addNotification(n)
        }
    }
}
