// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.vicko.wavetask as WaveTask

Item {
    id: root
    required property var entry
    required property WaveTask.Backend backend
    required property bool vertical
    required property real iconSize
    visible: entry.type !== "launcher"
    readonly property real length: entry.type === "command" ? iconSize : (entry.size || 1)
    width: vertical ? iconSize : length
    height: vertical ? length : iconSize
    Rectangle {
        anchors.centerIn: parent
        visible: root.entry.type === "separator"
        width: root.vertical ? root.iconSize * 0.65 : 1
        height: root.vertical ? 1 : root.iconSize * 0.65
        color: Kirigami.Theme.textColor
        opacity: 0.3
    }
    QQC2.ToolButton {
        anchors.fill: parent
        visible: root.entry.type === "command"
        icon.name: root.entry.icon && !root.entry.icon.includes("/")
            ? root.entry.icon : "application-x-executable"
        icon.source: root.entry.icon && root.entry.icon.includes("/") ? root.entry.icon : ""
        icon.width: root.iconSize
        icon.height: root.iconSize
        background: null
        text: root.entry.title || ""
        display: QQC2.AbstractButton.IconOnly
        onClicked: root.backend.launchCommand(root.entry.command)
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
    }
}
