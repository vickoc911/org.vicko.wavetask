// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.vicko.wavetask as WaveTask
import "code/DockEntries.js" as DockEntries

KCMUtils.SimpleKCM {
    id: root
    property string cfg_entryLayout: "[]"
    property var cfg_launchers: []
    property var entries: []
    property string error: ""
    property bool updating: false

    function reload() {
        if (updating) return;
        try {
            entries = DockEntries.reconcile(DockEntries.parse(cfg_entryLayout), cfg_launchers);
            error = "";
        } catch (exception) {
            error = i18n("Cannot read the entry layout: %1", exception.message);
        }
    }
    function save(next) {
        updating = true;
        entries = next;
        cfg_entryLayout = JSON.stringify(next);
        cfg_launchers = DockEntries.launcherUrls(next);
        updating = false;
    }
    function moveEntry(from, to) {
        save(DockEntries.move(entries, from, to));
    }
    function importDesktop(url) {
        const entry = backend.desktopEntry(url);
        if (entry.error) {
            error = entry.error;
            return;
        }
        if (entries.some(item => item.type === "launcher" && item.url === entry.url)) {
            error = i18n("This launcher is already in the list.");
            return;
        }
        error = "";
        save(entries.concat([entry]));
    }
    onCfg_entryLayoutChanged: reload()
    onCfg_launchersChanged: reload()
    Component.onCompleted: reload()

    WaveTask.Backend { id: backend }
    FileDialog {
        id: desktopDialog
        title: i18n("Import desktop entries")
        fileMode: FileDialog.OpenFiles
        nameFilters: [i18n("Desktop files (*.desktop)")]
        onAccepted: {
            for (const url of selectedFiles) root.importDesktop(url);
        }
    }

    ColumnLayout {
        width: parent.width
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.error.length > 0
            type: Kirigami.MessageType.Error
            text: root.error
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Drag the handles to arrange entries. Changes take effect when you Apply.")
            wrapMode: Text.Wrap
        }
        RowLayout {
            QQC2.Button {
                text: i18n("Spacer")
                icon.name: "list-add"
                onClicked: root.save(root.entries.concat([{type: "spacer", size: 24}]))
            }
            QQC2.Button {
                text: i18n("Separator")
                icon.name: "list-add"
                onClicked: root.save(root.entries.concat([{type: "separator", size: 12}]))
            }
            QQC2.Button {
                objectName: "addManualEntry"
                text: i18n("Manual entry")
                icon.name: "list-add"
                onClicked: {
                    manualDialog.editIndex = -1;
                    manualName.text = "";
                    manualCommand.text = "";
                    manualIcon.text = "application-x-executable";
                    manualDialog.open();
                }
            }
            QQC2.Button {
                text: i18n("Import .desktop")
                icon.name: "document-open"
                onClicked: desktopDialog.open()
            }
        }
        DropArea {
            Layout.fillWidth: true
            Layout.preferredHeight: entryList.height
            onDropped: event => {
                if (event.hasUrls) {
                    for (const url of event.urls) root.importDesktop(url);
                    event.acceptProposedAction();
                }
            }
            ListView {
                id: entryList
                objectName: "entryEditorList"
                width: parent.width
                height: Math.min(contentHeight, Kirigami.Units.gridUnit * 22)
                clip: true
                model: root.entries
                spacing: Kirigami.Units.smallSpacing
                property int dragSource: -1
                property int dragDestination: -1
                property real dragY: 0
                property string dragTitle: ""
                property string dragIcon: ""
                function finishDrag() {
                    dragSource = -1;
                    dragDestination = -1;
                }
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                Rectangle {
                    id: insertionMarker
                    objectName: "entryInsertionMarker"
                    parent: entryList.contentItem
                    z: 3
                    width: entryList.width
                    height: 3
                    radius: 1
                    color: Kirigami.Theme.highlightColor
                    visible: entryList.dragSource >= 0
                        && entryList.dragDestination >= 0
                        && entryList.dragSource !== entryList.dragDestination
                    y: {
                        const target = entryList.itemAtIndex(entryList.dragDestination);
                        if (!target) return 0;
                        return entryList.dragDestination > entryList.dragSource
                            ? target.y + target.height : target.y;
                    }
                }
                QQC2.Frame {
                    objectName: "entryDragPreview"
                    parent: entryList
                    z: 4
                    x: Kirigami.Units.smallSpacing
                    y: Math.max(0, Math.min(entryList.height - height, entryList.dragY - height / 2))
                    width: entryList.width - Kirigami.Units.smallSpacing * 2
                    visible: entryList.dragSource >= 0
                    background: Rectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.highlightColor
                        border.width: 2
                    }
                    contentItem: RowLayout {
                        Kirigami.Icon {
                            source: entryList.dragIcon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: width
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: entryList.dragTitle
                            elide: Text.ElideMiddle
                        }
                    }
                }
                delegate: QQC2.Frame {
                    id: row
                    required property var modelData
                    required property int index
                    width: entryList.width
                    height: rowContent.implicitHeight + topPadding + bottomPadding
                    opacity: reorder.pressed ? 0.65 : 1
                    RowLayout {
                        id: rowContent
                        anchors.fill: parent
                        QQC2.Label {
                            id: handle
                            objectName: "entryDragHandle"
                            text: "\u2630"
                            font.pixelSize: Kirigami.Units.gridUnit
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                            horizontalAlignment: Text.AlignHCenter
                            Accessible.name: i18n("Drag to reorder")
                            MouseArea {
                                id: reorder
                                objectName: "entryReorder"
                                anchors.fill: parent
                                preventStealing: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property int sourceIndex: -1
                                property int destinationIndex: -1
                                function updateTarget() {
                                    if (!pressed) return;
                                    const point = mapToItem(entryList, mouseX, mouseY);
                                    entryList.dragY = point.y;
                                    const y = Math.max(0, Math.min(entryList.contentHeight - 1, point.y + entryList.contentY));
                                    const index = entryList.indexAt(entryList.width / 2, y);
                                    if (index >= 0) {
                                        destinationIndex = index;
                                        entryList.dragDestination = index;
                                    }
                                }
                                onPressed: {
                                    sourceIndex = row.index;
                                    destinationIndex = row.index;
                                    entryList.dragSource = row.index;
                                    entryList.dragDestination = row.index;
                                    entryList.dragTitle = entryTitle.text;
                                    entryList.dragIcon = entryIcon.source;
                                    updateTarget();
                                }
                                onPositionChanged: updateTarget()
                                onReleased: {
                                    const from = sourceIndex;
                                    const to = destinationIndex;
                                    sourceIndex = -1;
                                    entryList.finishDrag();
                                    if (from >= 0) root.moveEntry(from, to);
                                }
                                onCanceled: {
                                    sourceIndex = -1;
                                    entryList.finishDrag();
                                }
                                Timer {
                                    interval: 60
                                    repeat: true
                                    running: reorder.pressed
                                    onTriggered: {
                                        const point = reorder.mapToItem(entryList, reorder.mouseX, reorder.mouseY);
                                        const step = Kirigami.Units.gridUnit;
                                        if (point.y < step) entryList.contentY = Math.max(0, entryList.contentY - step);
                                        else if (point.y > entryList.height - step)
                                            entryList.contentY = Math.max(0, Math.min(entryList.contentHeight - entryList.height,
                                                entryList.contentY + step));
                                        reorder.updateTarget();
                                    }
                                }
                            }
                        }
                        Kirigami.Icon {
                            id: entryIcon
                            source: row.modelData.icon || (row.modelData.type === "separator"
                                ? "insert-horizontal-rule" : "application-x-executable")
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: width
                        }
                        QQC2.Label {
                            id: entryTitle
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            text: row.modelData.title || (row.modelData.type === "spacer" ? i18n("Spacer")
                                : row.modelData.type === "separator" ? i18n("Separator") : row.modelData.url)
                        }
                        QQC2.SpinBox {
                            visible: ["spacer", "separator"].includes(row.modelData.type)
                            from: 1
                            to: 256
                            value: row.modelData.size || 1
                            onValueModified: {
                                const next = root.entries.slice();
                                next[row.index] = Object.assign({}, row.modelData, {size: value});
                                root.save(next);
                            }
                            QQC2.ToolTip.text: i18n("Size in pixels")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            icon.name: "go-up"
                            enabled: row.index > 0
                            onClicked: root.moveEntry(row.index, row.index - 1)
                            QQC2.ToolTip.text: i18n("Move up")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            icon.name: "go-down"
                            enabled: row.index < root.entries.length - 1
                            onClicked: root.moveEntry(row.index, row.index + 1)
                            QQC2.ToolTip.text: i18n("Move down")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            icon.name: "document-edit"
                            visible: row.modelData.type === "command"
                            onClicked: {
                                manualDialog.editIndex = row.index;
                                manualName.text = row.modelData.title;
                                manualCommand.text = row.modelData.command;
                                manualIcon.text = row.modelData.icon;
                                manualDialog.open();
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            onClicked: {
                                const next = root.entries.slice();
                                next.splice(row.index, 1);
                                root.save(next);
                            }
                            QQC2.ToolTip.text: i18n("Remove entry")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Unpinned windows appear after these entries. Manual commands are independent launch buttons; use .desktop files for normal task/window integration.")
            wrapMode: Text.Wrap
        }
    }
    QQC2.Dialog {
        id: manualDialog
        objectName: "manualEntryDialog"
        property int editIndex: -1
        readonly property string commandError: backend.validateCommand(manualCommand.text)
        title: i18n("Manual entry")
        width: Kirigami.Units.gridUnit * 28
        modal: true
        standardButtons: QQC2.Dialog.Save | QQC2.Dialog.Cancel
        onOpened: standardButton(QQC2.Dialog.Save).enabled = Qt.binding(() =>
            manualName.text.trim().length > 0 && manualCommand.text.trim().length > 0
                && manualDialog.commandError.length === 0);
        onAccepted: {
            const validation = backend.validateCommand(manualCommand.text);
            if (validation.length > 0) {
                root.error = validation;
                return;
            }
            const entry = {type: "command", title: manualName.text.trim(),
                command: manualCommand.text.trim(), icon: manualIcon.text.trim()};
            const next = root.entries.slice();
            if (editIndex < 0) next.push(entry);
            else next[editIndex] = entry;
            root.error = "";
            root.save(next);
        }
        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: manualName
                objectName: "manualEntryName"
                Kirigami.FormData.label: i18n("Name:")
            }
            QQC2.TextField {
                id: manualCommand
                objectName: "manualEntryCommand"
                Kirigami.FormData.label: i18n("Command:")
                placeholderText: i18n("Executable and arguments, with quotes if needed")
            }
            QQC2.TextField { id: manualIcon; Kirigami.FormData.label: i18n("Icon name or path:") }
            QQC2.Label {
                Layout.fillWidth: true
                text: manualDialog.commandError
                visible: manualCommand.text.length > 0 && text.length > 0
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            }
        }
    }
}
