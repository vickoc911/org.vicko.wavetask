/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

import "code/LayoutMetrics.js" as LayoutMetrics

GridLayout {
    property bool animating: false

    rowSpacing: 0
    columnSpacing: 0

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Smallest visible task width; consumed by Task.qml's standalone-icon
    // state to clamp the icon box. Single-pass over `children` avoids the
    // intermediate filtered array of the original `.filter().reduce()`.
    readonly property real minimumWidth: {
        let min = Infinity;
        for (let i = 0; i < children.length; ++i) {
            const item = children[i];
            if (item.visible && item.width > 0 && item.width < min) {
                min = item.width;
            }
        }
        return min;
    }

    readonly property int stripeCount: {
        if (Plasmoid.configuration.maxStripes === 1) {
            return 1;
        }

        // The maximum number of stripes allowed by the applet's size
        const stripeSizeLimit = vertical
            ? Math.floor(parent.width / children[0].implicitWidth)
            : Math.floor(parent.height / children[0].implicitHeight)
        const maxStripes = Math.min(Plasmoid.configuration.maxStripes, stripeSizeLimit)

        if (Plasmoid.configuration.forceStripes) {
            return maxStripes;
        }

        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = vertical
            ? Math.ceil(parent.height / LayoutMetrics.preferredMinHeight())
            : Math.ceil(parent.width / LayoutMetrics.preferredMinWidth())

        return Math.min(Math.ceil(count / maxTasksPerStripe), maxStripes)
    }

    readonly property int orthogonalCount: {
        return Math.ceil(count / stripeCount);
    }

    rows: vertical ? orthogonalCount : stripeCount
    columns: vertical ? stripeCount : orthogonalCount
}
