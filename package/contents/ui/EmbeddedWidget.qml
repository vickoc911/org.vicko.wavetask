// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.vicko.wavetask as WaveTask

Item {
    id: root

    required property var entry
    required property WaveTask.WidgetHost host
    required property bool vertical
    required property bool editing
    required property real iconSize
    required property int taskCount
    readonly property Item hostedItem: entry.item
    readonly property int position: Math.min(taskCount, Math.max(0, entry.position))
    readonly property real length: {
        if (!hostedItem) return iconSize;
        const preferred = vertical ? hostedItem.Layout.preferredHeight : hostedItem.Layout.preferredWidth;
        const minimum = vertical ? hostedItem.Layout.minimumHeight : hostedItem.Layout.minimumWidth;
        const maximum = vertical ? hostedItem.Layout.maximumHeight : hostedItem.Layout.maximumWidth;
        const implicit = vertical ? hostedItem.implicitHeight : hostedItem.implicitWidth;
        return Math.max(1, minimum, Math.min(maximum, preferred > 0 ? preferred : (implicit > 0 ? implicit : iconSize)));
    }

    width: vertical ? iconSize : length
    height: vertical ? length : iconSize

    function attach() {
        if (hostedItem) hostedItem.parent = root;
    }

    onHostedItemChanged: attach()
    Component.onCompleted: attach()
    Component.onDestruction: {
        if (hostedItem && hostedItem.parent === root) hostedItem.parent = null;
    }

    Binding {
        target: root.hostedItem
        property: "width"
        value: root.width
    }
    Binding {
        target: root.hostedItem
        property: "height"
        value: root.height
    }
    Binding {
        target: root.hostedItem
        property: "visible"
        value: true
    }

    QQC2.Label {
        anchors.centerIn: parent
        visible: !root.hostedItem
        text: "!"
        QQC2.ToolTip.text: i18n("Cannot load widget %1", root.entry.title)
        QQC2.ToolTip.visible: errorHover.hovered
        HoverHandler { id: errorHover }
    }

    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.RightButton
        onTapped: widgetMenu.popup()
    }

    QQC2.Menu {
        id: widgetMenu
        QQC2.MenuItem {
            text: i18n("Configure %1...", root.entry.title)
            onTriggered: root.host.configureWidget(root.entry.id)
        }
        QQC2.MenuItem {
            text: i18n("Move before previous application")
            enabled: root.position > 0
            onTriggered: root.host.moveWidget(root.entry.id, root.position - 1)
        }
        QQC2.MenuItem {
            text: i18n("Move after next application")
            enabled: root.position < root.taskCount
            onTriggered: root.host.moveWidget(root.entry.id, root.position + 1)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: i18n("Remove widget")
            onTriggered: root.host.removeWidget(root.entry.id)
        }
    }
}
