// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    implicitWidth: 18
    implicitHeight: 18
    Layout.minimumWidth: 18
    Layout.preferredWidth: 18
    Layout.maximumWidth: 18
    Layout.minimumHeight: 18
    Layout.preferredHeight: 18
    Layout.maximumHeight: 18
    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height
        color: "gray"
    }
}
