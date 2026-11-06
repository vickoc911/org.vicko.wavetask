// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.vicko.wavetask as WaveTask

KCMUtils.SimpleKCM {
    id: root

    readonly property var debugInfo: backend.debugInformation()

    WaveTask.Backend { id: backend }

    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            text: i18n("Under the hood (no magic)")
            level: 1
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Technical information for when the dock needs a little troubleshooting, not an exorcism.")
            wrapMode: Text.Wrap
        }
        Kirigami.Heading {
            text: i18n("Debug information")
            level: 2
        }
        QQC2.TextArea {
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            text: [
                i18n("Operating system: %1", root.debugInfo.operatingSystem),
                i18n("Kernel: %1", root.debugInfo.kernel),
                i18n("Architecture: %1", root.debugInfo.architecture),
                i18n("Qt version: %1", root.debugInfo.qtVersion),
                i18n("Display platform: %1", root.debugInfo.platform),
                i18n("Logging category: %1", root.debugInfo.loggingCategory)
            ].join("\n")
        }
        Kirigami.Heading {
            text: i18n("Configuration locations")
            level: 2
        }
        QQC2.TextArea {
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            text: [
                i18n("Dock configuration: %1", root.debugInfo.plasmaConfiguration),
                i18n("Plasma shell configuration: %1", root.debugInfo.shellConfiguration),
                i18n("User package directory: %1", root.debugInfo.userPackageDirectory)
            ].join("\n")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Entries are stored in the WaveTask applet's Configuration/General group, in launchers and entryLayout. Desktop metadata is refreshed in memory when the Entries page loads. The user package directory may not exist for system-wide installations.")
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Warning
            text: i18n("Do not edit the Plasma configuration while Plasma is running: it may overwrite your changes. Debug information includes local paths; review it before sharing.")
        }
    }
}
