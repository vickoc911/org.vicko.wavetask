/*
 *   SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
 *   SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.vicko.wavetask as TaskManagerApplet
import org.kde.plasma.plasmoid

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    implicitHeight: inPopup ? LayoutMetrics.preferredHeightInPopup() : (tasksRoot.vertical ? LayoutMetrics.preferredMinHeight() : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes, LayoutMetrics.preferredMinHeight()))
    implicitWidth: tasksRoot.vertical ? Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes)) : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical ? -1 : ((model.IsLauncher && !tasksRoot.iconsOnly) ? tasksRoot.height / taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ? LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse) || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open) || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    width: Plasmoid.configuration.iconSize
    height: tasksRoot.height
    clip: false

    property bool isHovered: false
    property Item dockRef: null

    readonly property real _baseSize: Plasmoid.configuration.iconSize
    readonly property real _sigma: _baseSize * Plasmoid.configuration.amplitud
    readonly property real _zoom: (Plasmoid.configuration.magnification || 0) / 100

    property real zoomFactor: {
        if (!dockRef || _zoom <= 0) return 1.0;
        let mousePos = dockRef.smoothMouse;
        if (mousePos < 0) return 1.0;

        let totalSize = tasksRoot.taskRepeater.count * _baseSize;
        let availableSize = tasksRoot.vertical ? tasksRoot.taskList.height : tasksRoot.taskList.width;
        let centerOffset = (availableSize - totalSize) / 2;
        let iconCenter = centerOffset + (index * _baseSize) + (_baseSize / 2);
        let distance = Math.abs(mousePos - iconCenter);

        if (distance > _sigma * 3) return 1.0;
        let dynamicZoom = _zoom * entryProgress;
        return 1.0 + dynamicZoom * Math.exp(-(Math.pow(distance, 2) / (2 * Math.pow(_sigma, 2))));
    }

    property real entryProgress: (dockRef && dockRef.insideDock) ? 1.0 : 0.0

    Behavior on entryProgress {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Accessible.name: model.display
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) tasksRoot.toolTipOpenedByClick = null;
        else tasksRoot.toolTipAreaItem = task;
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: { tasksRoot.cancelHighlightWindows(); }
    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksRoot.tasksModel.requestPublishDelegateGeometry(modelIndex(), tasksRoot.backend.globalRect(task), task);
        }
        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();
        if (!inPopup && !tasksRoot.vertical && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("org.vicko.wavetask", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();
            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)

    function modelIndex(): var {
        return inPopup ? tasksRoot.tasksModel.makeModelIndex(groupDialog.visualParent.index, index) : tasksRoot.tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args);
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) delayAudioStreamIndicator = !!args.delay;
        var pa = tasksRoot.pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) pa.registerPidMatch(model.AppName);
            else if (!pa.hasPidMatch(model.AppName)) streams = pa.streamsForAppName(model.AppName);
        }
        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) task.audioStreams.forEach(item => item.unmute());
        else task.audioStreams.forEach(item => item.mute());
    }

    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index) || (tasksRoot.toolTipOpenedByClick === null && !active) || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }
        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent);
        mainItem.parentTask = this;
        mainItem.rootIndex = tasksRoot.tasksModel.makeModelIndex(index, -1);
        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);
        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? (smartLauncherItem?.count ?? 0) : 0);
        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    KSvg.FrameSvgItem {
        id: frame
        anchors {
            fill: parent
            topMargin: {
                if (!task.tasksRoot.vertical && tasksRoot.taskList.rows > 1) return LayoutMetrics.iconMargin;
                let iconAlign = Math.round(parent.height - Plasmoid.configuration.iconSize * zoomFactor) - Kirigami.Units.smallSpacing;
                let indicatorOffset = -Kirigami.Units.gridUnit / tasksRoot.skinParams.positionTaskIndicator;
                return tasksRoot.isTopPanel ? indicatorOffset : iconAlign;
            }
            bottomMargin: {
                if (!task.tasksRoot.vertical && tasksRoot.taskList.rows > 1) return LayoutMetrics.iconMargin;
                let iconAlign = Math.round(parent.height - Plasmoid.configuration.iconSize * zoomFactor) - Kirigami.Units.smallSpacing;
                let indicatorOffset = -Kirigami.Units.gridUnit / tasksRoot.skinParams.positionTaskIndicator;
                return tasksRoot.isTopPanel ? iconAlign : indicatorOffset;
            }
            leftMargin: {
                if ((inPopup || tasksRoot.vertical) && tasksRoot.taskList.columns > 1) return LayoutMetrics.iconMargin;
                let iconAlign = Math.round(parent.width - Plasmoid.configuration.iconSize * zoomFactor) - Kirigami.Units.smallSpacing * 0.5;
                let indicatorOffset = -Kirigami.Units.gridUnit / tasksRoot.skinParams.positionTaskIndicator;
                return tasksRoot.isLeftPanel ? indicatorOffset : iconAlign;
            }
            rightMargin: {
                if (!task.tasksRoot.vertical && tasksRoot.taskList.rows > 1) return LayoutMetrics.iconMargin;
                let iconAlign = Math.round(parent.width - Plasmoid.configuration.iconSize * zoomFactor) - Kirigami.Units.smallSpacing * 0.5;
                let indicatorOffset = -Kirigami.Units.gridUnit / tasksRoot.skinParams.positionTaskIndicator;
                return tasksRoot.isLeftPanel ? iconAlign : indicatorOffset;
            }
        }

        imagePath: (Plasmoid.configuration.skinName === "Default Plasma") ? "widgets/tasks" : tasksRoot.skinParams.imagetask
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType
            function setRequestedInhibitDnd(value: bool): void {
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value;
                    }
                }
            }
            onActiveChanged: {
                if (active) {
                    icon.grabToImage(result => {
                        if (!dragHandler.active) return;
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        tasksRoot.dragHelper.Drag.imageSource = result.url;
                        tasksRoot.dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": tasksRoot.backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                                     [model.MimeType]: model.MimeData,
                                     "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        tasksRoot.dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    tasksRoot.dragHelper.Drag.active = false;
                    tasksRoot.dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader
        anchors.fill: frame
        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.progressVisible
        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox
        width: Plasmoid.configuration.iconSize
        height: Plasmoid.configuration.iconSize
        anchors.centerIn: tasksRoot.vertical ? parent : undefined
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ((!tasksRoot.vertical) && Plasmoid.location === PlasmaCore.Types.BottomEdge) ? 0 : Math.round((tasksRoot.height / 2) - (Kirigami.Units.iconSizes.small * 0.14))
        anchors.horizontalCenter: (!tasksRoot.vertical) ? parent.horizontalCenter : undefined

        property int baseRenderSize: Plasmoid.configuration.iconSize * 2
        property Item visualIcon: icon // Expose to sub-loaded contexts safely

        SequentialAnimation {
            id: bounceAnimation
            running: task.model.IsStartup || task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)
            loops: Animation.Infinite
            alwaysRunToEnd: true
            property real jumpHeight: {
                let currentSize = Plasmoid.configuration.iconSize * zoomFactor;
                let idealJump = currentSize * 0.6;
                let headroom = Math.max(0, tasksRoot.height - Plasmoid.configuration.iconSize);
                return Math.min(idealJump, headroom);
            }
            NumberAnimation { target: iconBox; property: "anchors.bottomMargin"; from: 0; to: bounceAnimation.jumpHeight; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconBox; property: "anchors.bottomMargin"; to: 0; duration: 300; easing.type: Easing.InQuad }
        }

        scale: zoomFactor
        transformOrigin: {
            switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge: return Item.Bottom;
                case PlasmaCore.Types.TopEdge: return Item.Top;
                case PlasmaCore.Types.LeftEdge: return Item.Left;
                case PlasmaCore.Types.RightEdge: return Item.Right;
                default: return Item.Bottom;
            }
        }

        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.countVisible
        source: "TaskBadgeOverlay.qml"

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) return margin;
            var margins = isVertical ? LayoutMetrics.horizontalMargins() : LayoutMetrics.verticalMargins();
            if ((size - margins) < Kirigami.Units.iconSizes.small) return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            return margin;
        }

        Kirigami.Icon {
            id: icon
            width: iconBox.baseRenderSize
            height: iconBox.baseRenderSize
            source: model.decoration
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: tasksRoot.isTopPanel ? 0 : Kirigami.Units.smallSpacing
            anchors.topMargin: tasksRoot.isTopPanel ? Kirigami.Units.smallSpacing : 0
            transformOrigin: Item.Bottom
            scale: 1 / (iconBox.baseRenderSize / iconBox.width)
            smooth: true; antialiasing: true
        }

        Item {
            id: reflectionContainer
            visible: Plasmoid.configuration.showReflection
            opacity: 0.4; clip: true; z: -5
            width: tasksRoot.vertical ? iconBox.width / 2 : iconBox.width
            height: tasksRoot.vertical ? iconBox.height : iconBox.height / 2
            x: {
                switch (Plasmoid.location) {
                    case PlasmaCore.Types.LeftEdge: return -width - Kirigami.Units.smallSpacing * 2.5;
                    case PlasmaCore.Types.RightEdge: return iconBox.width + Kirigami.Units.smallSpacing * 2.5;
                    default: return 0;
                }
            }
            y: {
                switch (Plasmoid.location) {
                    case PlasmaCore.Types.TopEdge: return -height - Kirigami.Units.smallSpacing * 2;
                    case PlasmaCore.Types.BottomEdge: return iconBox.height + Kirigami.Units.smallSpacing * 2;
                    default: return 0;
                }
            }
            Kirigami.Icon {
                id: reflectionIcon
                width: icon.width; height: icon.height
                source: icon.source; smooth: true; antialiasing: true
                anchors.centerIn: parent
                scale: icon.scale
                transform: Scale { origin.x: reflectionIcon.width / 2; origin.y: reflectionIcon.height / 2; xScale: tasksRoot.vertical ? -1 : 1; yScale: tasksRoot.vertical ? 1 : -1 }
            }
        }

        states: [
            State {
                name: "standalone"
                when: !label.visible && task.parent
                AnchorChanges { target: iconBox; anchors.left: undefined; anchors.horizontalCenter: parent.horizontalCenter }
                PropertyChanges { target: iconBox; anchors.leftMargin: 0; width: Math.min(task.parent.minimumWidth, tasksRoot.height) - adjustMargin(true, task.width, tasksRoot.taskFrame.margins.left) - adjustMargin(true, task.width, tasksRoot.taskFrame.margins.right) }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Plasmoid.configuration.iconSize; height: Plasmoid.configuration.iconSize
            active: model.IsStartup
            sourceComponent: busyIndicator
        }
    }

    Item {
        id: metaIndexBadge
        visible: tasksRoot.metaShowActive && Plasmoid.configuration.showTaskNumbersOnMeta
        anchors.horizontalCenter: tasksRoot.vertical ? undefined : iconBox.horizontalCenter
        anchors.verticalCenter: tasksRoot.vertical ? iconBox.verticalCenter : undefined
        anchors.bottom: tasksRoot.vertical ? undefined : (tasksRoot.isTopPanel ? undefined : iconBox.top)
        anchors.top: tasksRoot.vertical ? undefined : (tasksRoot.isTopPanel ? iconBox.bottom : undefined)
        anchors.left: tasksRoot.vertical ? (tasksRoot.isLeftPanel ? iconBox.right : undefined) : undefined
        anchors.right: tasksRoot.vertical ? (tasksRoot.isLeftPanel ? undefined : iconBox.left) : undefined
        anchors.bottomMargin: (!tasksRoot.vertical && !tasksRoot.isTopPanel) ? 4 : 0
        anchors.topMargin: (!tasksRoot.vertical && tasksRoot.isTopPanel) ? 4 : 0
        anchors.leftMargin: (tasksRoot.vertical && tasksRoot.isLeftPanel) ? 4 : 0
        anchors.rightMargin: (tasksRoot.vertical && !tasksRoot.isLeftPanel) ? 4 : 0
        width: 20; height: 20; z: 10
        Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.7); border.color: Qt.rgba(1, 1, 1, 0.5); border.width: 1; antialiasing: true }
        PlasmaComponents3.Label { anchors.centerIn: parent; text: (task.index + 1).toString(); font.pixelSize: 11; font.bold: true; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    }

    PlasmaComponents3.Label {
        id: label
        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())
        anchors { fill: parent; leftMargin: tasksRoot.taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin; topMargin: tasksRoot.taskFrame.margins.top; rightMargin: tasksRoot.taskFrame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + LayoutMetrics.labelMargin) : 0); bottomMargin: tasksRoot.taskFrame.margins.bottom }
        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap; elide: Text.ElideRight; textFormat: Text.PlainText; verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined
        Accessible.ignored: !visible
        states: State { name: "labelVisible"; when: label.visible; PropertyChanges { label.text: task.model.display } }
    }

    states: [
        State { name: "launcher"; when: task.model.IsLauncher; PropertyChanges { frame.basePrefix: "" } },
        State { name: "attention"; when: task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent); PropertyChanges { frame.basePrefix: "attention" } },
        State { name: "minimized"; when: task.model.IsMinimized; PropertyChanges { frame.basePrefix: "minimized" } },
        State { name: "active"; when: task.model.IsActive; PropertyChanges { frame.basePrefix: "focus" } }
    ]

    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            const component = Qt.createComponent("GroupExpanderOverlay.qml");
            component.createObject(task);
            component.destroy();
            updateAudioStreams({delay: false});
        }
        if (!inPopup && !model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
        }
        completed = true;
    }
}
