/*
 *   SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
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

    implicitWidth: Math.max(height, Math.round(label.contentWidth + radius / 2)) // Add some padding around.[cite: 2]
    implicitHeight: implicitWidth

    radius: height / 2

    color: Kirigami.Theme.backgroundColor //[cite: 2]

    antialiasing: true

    // --- CUSTOM TRANSLATION ---
    // Shifts the badge slightly further up and to the right relative to its parent anchors.
    transform: Translate {
        x: 6   // Positive value pushes rightwards
        y: -6  // Negative value pushes upwards
    }

    // Colored background
    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.3) //[cite: 2]
        border.color: Kirigami.Theme.highlightColor //[cite: 2]
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
        font.pixelSize: Math.round(parent.height * 0.55 * badgeRect.renderScale) //[cite: 2]

        // Reducimos visualmente
        scale: 1 / badgeRect.renderScale //[cite: 2]
        transformOrigin: Item.Center

        renderType: Text.NativeRendering //[cite: 2]
        renderTypeQuality: Text.HighRenderTypeQuality //[cite: 2]

        font.hintingPreference: Font.PreferFullHinting //[cite: 2]

        layer.enabled: true
        smooth: true

        text: {
            if (badgeRect.number < 0) { //[cite: 2]
                return i18nc("Invalid number of new messages, overlay, keep short", "—"); //[cite: 2]
            } else if (badgeRect.number > 9999) { //[cite: 2]
                return i18nc("Over 9999 new messages, overlay, keep short", "9,999+"); //[cite: 2]
            } else {
                return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0); //[cite: 2]
            }
        }

        textFormat: Text.PlainText //[cite: 2]
    }
}
