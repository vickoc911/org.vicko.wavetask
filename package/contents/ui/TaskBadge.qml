/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: badge

    property alias text: label.text
    property alias font: label.font
    property real padding: Kirigami.Units.smallSpacing

    implicitWidth: label.implicitWidth + padding * 2
    implicitHeight: label.implicitHeight + padding

    radius: height / 2
    color: Kirigami.Theme.highlightColor

    QQC2.Label {
        id: label

        anchors.centerIn: parent
        color: Kirigami.Theme.highlightedTextColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
