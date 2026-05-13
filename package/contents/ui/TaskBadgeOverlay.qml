/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.graphicaleffects as KGraphicalEffects
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property int iconWidthDelta: (Plasmoid.configuration.iconSize - icon.paintedWidth) / 2
    readonly property bool shiftBadgeDown: (Plasmoid.pluginName === "org.vicko.wavetask") && task.audioStreamIcon !== null

    Item {
        id: badgeMask
        anchors.fill: parent

        Rectangle {
            readonly property int offset: Math.round(Math.max(Kirigami.Units.smallSpacing / 2, badgeMask.width / 32))

            anchors.right: parent.right
            anchors.rightMargin: -offset
            y: root.shiftBadgeDown ? (Plasmoid.configuration.iconSize / 2) : 0

            Behavior on y {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }

            visible: task.smartLauncherItem.countVisible
            width: badgeRect.width + offset * 2
            height: badgeRect.height + offset * 2
            radius: badgeRect.radius + offset * 2

            // Badge changes width based on number.
            onWidthChanged: maskShaderSource.scheduleUpdate()
            onVisibleChanged: maskShaderSource.scheduleUpdate()
            onYChanged: maskShaderSource.scheduleUpdate()
        }
    }

    ShaderEffectSource {
        id: iconShaderSource
        sourceItem: icon
        hideSource: GraphicsInfo.api !== GraphicsInfo.Software
    }

    ShaderEffectSource {
        id: maskShaderSource
        sourceItem: badgeMask
        hideSource: true
        live: false
    }

    KGraphicalEffects.BadgeEffect {
        id: shader

        anchors.fill: parent
        source: iconShaderSource
        mask: maskShaderSource

        onWidthChanged: maskShaderSource.scheduleUpdate()
        onHeightChanged: maskShaderSource.scheduleUpdate()
    }

    Badge {
        id: badgeRect

        anchors.right: parent.right
        y: {
            const offset = Math.round(Math.max(Kirigami.Units.smallSpacing / 2, badgeMask.width / 32));
            return offset + (root.shiftBadgeDown ? (Plasmoid.configuration.iconSize / 2) : 0);
        }

        Behavior on y {
            NumberAnimation { duration: Kirigami.Units.longDuration }
        }

        height: Math.round(Plasmoid.configuration.iconSize * 0.45)
        visible: task.smartLauncherItem.countVisible
        number: task.smartLauncherItem.count
    }
}
