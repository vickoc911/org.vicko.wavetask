/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// This top-level item is an opaque background that goes behind the colored
// background, for contrast. It's not an Item since that it would be square,
// and not round, as required here
Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0

    property real renderScale: 1.8

    implicitWidth: Math.max(height, Math.round(label.contentWidth + radius / 2)) // Add some padding around.
    implicitHeight: implicitWidth

    radius: height / 2

    color: Kirigami.Theme.backgroundColor

    antialiasing: true

    // Colored background
    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
        border.color: Kirigami.Theme.highlightColor
        border.width: 1
        antialiasing: true
    }

    // Number
    PlasmaComponents3.Label {
        id: label

        anchors.centerIn: parent

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        // Render grande para mantener nitidez
        font.pixelSize: Math.round(parent.height * 0.55 * badgeRect.renderScale)

        // Reducimos visualmente
        scale: 1 / badgeRect.renderScale
        transformOrigin: Item.Center

        renderType: Text.NativeRendering
        renderTypeQuality: Text.HighRenderTypeQuality

        font.hintingPreference: Font.PreferFullHinting

        layer.enabled: true
        smooth: true

        text: {
            if (badgeRect.number < 0) {
                return i18nc("Invalid number of new messages, overlay, keep short", "—");
            } else if (badgeRect.number > 9999) {
                return i18nc("Over 9999 new messages, overlay, keep short", "9,999+");
            } else {
                return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
            }
        }

        textFormat: Text.PlainText
    }
}
