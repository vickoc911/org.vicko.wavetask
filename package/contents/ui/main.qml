/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import org.vicko.wavetask as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmoidItem {
    id: tasks

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks and group dialog as well, so we un-rotate them
    // to fix that (see Task.qml and GroupDialog.qml).
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconsOnly: Plasmoid.pluginName === "org.vicko.wavetask"

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property alias taskList: taskList
    property alias taskRepeater: taskRepeater

    readonly property bool isTopPanel: Plasmoid.location === PlasmaCore.Types.TopEdge

    preferredRepresentation: fullRepresentation

  //  Plasmoid.constraintHints: Plasmoid.CanFillArea

  // --- LÓGICA DE TRANSPARENCIA ---
  property Item containmentItem: null
  readonly property int depth: 14
  property bool isBackgroundDisabled: true

  function lookForContainer(object, tries) {
      if (tries === 0 || object === null) return;
      // busca el panel
      if (object.toString().indexOf("ContainmentItem_QML") > -1) {
          tasks.containmentItem = object;
          console.log("Contenedor encontrado en el intento: " + (depth - tries));
      } else {
          lookForContainer(object.parent, tries - 1);
      }
  }

  function applyBackgroundHint() {
      if (tasks.containmentItem === null) lookForContainer(tasks.parent, depth);
      if (tasks.containmentItem === null) return;

      // Aplicamos el NoBackground (0) o Default (1)
      tasks.containmentItem.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;

      // También lo aplicamos al objeto raíz por si acaso
      tasks.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;
  }

  // --- LÓGICA DE SKINS ---
  property int topoutimage: 0
  property var skinParams: ({
      image: "", imagetask: "", blur: false, blurRadius: 18, positionTaskIndicator: 9,
      left: 0, top: 0, right: 0, bottom: 0,
      outLeft: 0, outTop: 0, outRight: 0, outBottom: 0
  })

  function loadSkinConfig() {
      let skinName = Plasmoid.configuration.skinName || "Default Plasma";

      // LIMPIAR BLUR ANTES DE CAMBIAR
      if (tasks.backend && tasks.parent && tasks.Window && tasks.Window.window) {
          backend.setBlurBehind(tasks.Window.window, false, 0, 0, 0, 0, 0);
          tasks.Window.window.requestUpdate();
          console.log("Blur limpiado antes de aplicar nuevo skin");
      }

      // Construimos la ruta al nuevo archivo Config.qml
      let configUrl = Qt.resolvedUrl("../skins/" + skinName + "/Config.qml");

      console.log("Cargando configuración de skin desde: " + configUrl);

      let component = Qt.createComponent(configUrl);

      if (Plasmoid.configuration.iconSize <= 44) {
          tasks.topoutimage = Math.abs(Plasmoid.configuration.iconSize - 44);
      } else {
          tasks.topoutimage = 44 - Plasmoid.configuration.iconSize;
      }

      if (component.status === Component.Ready) {
          let config = component.createObject(tasks); // 'tasks' es el id de tu PlasmoidItem

          if (config) {
              let skinFolderUrl = Qt.resolvedUrl("../skins/" + skinName + "/").toString();

              // Actualizamos skinParams de forma reactiva
              tasks.skinParams = {
                  image: skinFolderUrl + config.image,
                  imagetask: skinFolderUrl + config.imagetask,
                  blur: config.blur,
                  blurRadius: config.blurRadius,
                  positionTaskIndicator: config.positionTaskIndicator,
                  left: config.leftMargin,
                  top: config.topMargin,
                  right: config.rightMargin,
                  bottom: config.bottomMargin,
                  outLeft: config.outsideLeftMargin,
                  outTop: config.outsideTopMargin + tasks.topoutimage,
                  outRight: config.outsideRightMargin,
                  outBottom: config.outsideBottomMargin
              };

              console.log("EXITO: Skin '" + skinName + "' cargada. Imagen: " + tasks.skinParams.image);

              // Limpiamos el objeto temporal de memoria
              config.destroy();
          }
      } else {
          console.log("ERROR al cargar Config.qml: " + component.errorString());
          // Fallback: Si no existe el .qml, podrías intentar cargar valores por defecto aquí
      }
  }

  // Detecta si entra zoom y si sale
  readonly property bool isZoomActive: {
      for (let i = 0; i < taskRepeater.count; ++i) {
          let item = taskRepeater.itemAt(i);
          // Si el zoomFactor es mayor a 1.0 (o un umbral mínimo como 1.01)
          if (item && item.zoomFactor > 1.01) return true;
      }
      return false;
  }

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight();
    }

//BEGIN TODO: this is not precise enough: launchers are smaller than full tasks
    Layout.preferredWidth: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 10;
        }
        return taskList.Layout.maximumWidth
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return taskList.Layout.maximumHeight
        }
        return Kirigami.Units.gridUnit * 2;
    }
//END TODO

    property Item dragSource

    signal requestLayout

    onDragSourceChanged: {
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function windowsHovered(winIds: var, hovered: bool): DBus.DBusPendingReply {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [hovered ? winIds : []], signature: "(as)"});
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    function activateWindowView(winIds: var): DBus.DBusPendingReply {
        if (!effectWatcher.registered) {
            return;
        }
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1", iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(s => String(s))], signature: "(as)"});
    }

    function publishIconGeometries(taskItems: /*list<Item>*/var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
        for (let i = 0; i < taskItems.length - 1; ++i) {
            const task = taskItems[i];

            if (!task.model.IsLauncher && !task.model.IsStartup) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index),
                    backend.globalRect(task), task);
            }
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;

            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i) as Task;

                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
                && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly
            ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): /*TaskManager.TasksModel.SortMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            // 5 is SortLastActivated, skipped
            case 6:
                return TaskManager.TasksModel.SortWindowPositionHorizontal;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): /*TaskManager.TasksModel.GroupMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: url => {
            tasks.addLauncher(url);
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: 200
            running: true

            onTriggered: {
                const task = parent as Task;
                if (task) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasks.backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment

        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    Item {
        anchors.fill: parent

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries(taskList.children, tasks);
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention
                ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration

            function onSkinNameChanged() {
                console.log("Nueva skin detectada: " + Plasmoid.configuration.skinName);
                loadSkinConfig(); // La función que lee el .ini y carga la imagen
            }

            function onIconSizeChanged() {
                loadSkinConfig();
            }

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame

            visible: false

            imagePath: tasks.skinParams.imagetask
            prefix: TaskTools.taskPrefix("normal", Plasmoid.location)
        }

        MouseHandler {
            id: mouseHandler

            anchors.fill: parent

            target: taskList

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => tasks.backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls((hoveredItem as Task).modelIndex(), urls);
            }
        }

        ToolTipDelegate {
            id: openWindowToolTipDelegate
            visible: false
        }

        ToolTipDelegate {
            id: pinnedAppToolTipDelegate
            visible: false
        }

        Loader {
            id: backgroundLoader

            anchors.fill: parent
            sourceComponent: (Plasmoid.configuration.skinName === "Default Plasma") ? defaultSkin : customSkin
        }

        // --- Componente 1: DEFAULT (SVG) ---
        Component {
            id: defaultSkin
            Item {
                id: internalCanvas

                readonly property bool vertical: tasks.vertical

                readonly property real horizontalMargins:
                shadowItem.margins.left + shadowItem.margins.right

                readonly property real verticalMargins:
                shadowItem.margins.top + shadowItem.margins.bottom

                readonly property real baseIconsSize:
                taskRepeater.count * Plasmoid.configuration.iconSize +
                Math.max(0, taskRepeater.count - 1) * taskList.spacing

                readonly property real verticalOffsetX: -Kirigami.Units.smallSpacing * 5

                readonly property real currentGrowth:
                Math.max(
                    0,
                    (taskList.iconsTotalSize + taskList.spacing * 2)
                    - baseIconsSize
                ) / 2

                readonly property real panelThickness:
                Plasmoid.configuration.iconSize * 1.20

                KSvg.FrameSvgItem {
                    id: shadowItem

                    imagePath: "widgets/panel-background"
                    prefix: "shadow"

                    z: -2

                    width: vertical
                    ? panelThickness + verticalMargins
                    : horizontalMargins + baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2


                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2) + verticalMargins
                    : panelThickness + verticalMargins + Kirigami.Units.smallSpacing * 0.2

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return taskList.width - width;

                        return verticalOffsetX;
                    }


                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return - ((verticalMargins / 2) + Kirigami.Units.smallSpacing * 0.8);

                        // Panel abajo
                        return (taskList.height - height + (verticalMargins / 2)) + Kirigami.Units.smallSpacing * 0.6;
                    }
                }

                KSvg.FrameSvgItem {
                    id: backgroundItem

                    imagePath: "widgets/panel-background"
                    prefix: ""

                    z: -1

                    width: vertical
                    ? panelThickness
                    : baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2

                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2)
                    : panelThickness + Kirigami.Units.smallSpacing * 0.2

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return taskList.width - width - (verticalMargins / 2);

                        return (verticalMargins / 2) + verticalOffsetX;
                    }

                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return - Kirigami.Units.smallSpacing * 0.8;

                        // Panel abajo
                       return (taskList.height - height) + Kirigami.Units.smallSpacing * 0.6;
                    }

                    readonly property int blurRadius:
                    tasks.skinParams.blurRadius || 18

                    function updateBlur() {

                        if (!tasks.skinParams.blur)
                            return;

                        const win = backgroundItem?.Window?.window;

                        if (!win)
                            return;

                        if (typeof win.visible !== "undefined" && !win.visible)
                            return;

                        var pos = mapToItem(null, 0, 0);

                        backend.setBlurBehind(
                            win,
                            true,
                            pos.x,
                            pos.y,
                            width,
                            height,
                            blurRadius
                        );

                        if (win.requestUpdate)
                            win.requestUpdate();
                    }

                    function scheduleBlurUpdate() {
                        Qt.callLater(updateBlur)
                    }

                    onWidthChanged: scheduleBlurUpdate()
                    onHeightChanged: scheduleBlurUpdate()
                    onXChanged: scheduleBlurUpdate()
                    onYChanged: scheduleBlurUpdate()
                    onWindowChanged: scheduleBlurUpdate()

                    onVisibleChanged: {
                        if (visible)
                            scheduleBlurUpdate()
                    }
                }
            }
        }

        // --- Componente 2: CUSTOM SKIN ---
        Component {
            id: customSkin
            BorderImage {
                id: dockBackground
                cache: true
                smooth: true
                asynchronous: true
                visible: source.toString() !== ""
                opacity: 1.0
                readonly property real spacing: Kirigami.Units.largeSpacing
                readonly property real topMarginSkin: tasks.containmentItem.height - 76

                // Cuánto crecieron los iconos con zoom respecto al base
                readonly property real currentGrowth: Math.max(0, taskList.maxZoom + spacing * 8
                ) / 2

                property real dynamicLeftMargin: tasks.skinParams.outLeft
                + taskList.centerOffset
                - currentGrowth

                property real dynamicRightMargin: tasks.skinParams.outRight
                + taskList.centerOffset
                - currentGrowth

                anchors {
                    fill: parent
                    leftMargin: dockBackground.dynamicLeftMargin || 0
                    rightMargin: dockBackground.dynamicRightMargin || 0

                    topMargin: tasks.isTopPanel
                    ? (tasks.skinParams.outBottom || 0)
                    : (tasks.skinParams.outTop + topMarginSkin || 0)

                    bottomMargin: tasks.isTopPanel
                    ? (tasks.skinParams.outTop + topMarginSkin || 0)
                    : (tasks.skinParams.outBottom || 0)
                }

                source: tasks.skinParams.image
                border {
                    left: tasks.skinParams.left
                    top: tasks.skinParams.top
                    right: tasks.skinParams.right
                    bottom: tasks.skinParams.bottom
                }
                horizontalTileMode: BorderImage.Stretch
                verticalTileMode: BorderImage.Stretch
                z: -1

                // Inversión visual de la imagen
                transform: Scale {
                    origin.x: width / 2
                    origin.y: height / 2
                    // Flip vertical si el panel está arriba (Location 3)
                    yScale: tasks.isTopPanel ? -1 : 1
                }


                // --- INTEGRACIÓN DEL BLUR ---

                // Radio de blur
                readonly property int blurRadius: tasks.skinParams.blurRadius || 24

                // Función centralizada para actualizar el blur
                function updateBlur() {
                    if (!tasks.skinParams.blur) {
                        return;
                    }

                    const win = dockBackground?.Window?.window;

                    if (!win) {
                        return;
                    }

                    // opcional: proteger también visible
                    if (typeof win.visible !== "undefined" && !win.visible) {
                        return;
                    }

                    var pos = mapToItem(null, 0, 0);

                    backend.setBlurBehind(
                        win,
                        true,
                        pos.x,
                        pos.y,
                        width,
                        height,
                        blurRadius
                    );

                    if (win.requestUpdate) {
                        win.requestUpdate();
                    }
                }

                // --- CONEXIONES PARA ACTUALIZACIÓN DINÁMICA ---

                // Cuando el componente termina de cargar
                function scheduleBlurUpdate() {
                    Qt.callLater(updateBlur)
                }

                onWidthChanged: scheduleBlurUpdate()
                onHeightChanged: scheduleBlurUpdate()
                onXChanged: scheduleBlurUpdate()
                onYChanged: scheduleBlurUpdate()

                onWindowChanged: scheduleBlurUpdate()

                onVisibleChanged: {
                    if (visible) {
                        scheduleBlurUpdate()
                    }
                }
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: false
            blockFirstEnter: false

            edge: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)

            anchors {
                left: parent.left
                top: parent.top
            }

            height: taskList.height
            width: taskList.width

            TaskList {
                id: taskList

                property real smoothMouse: -1
                property bool insideDock: false
                property alias animating: taskList.animating
                readonly property real spacing: Kirigami.Units.smallSpacing
                readonly property real _baseSize: Plasmoid.configuration.iconSize
                readonly property real _sigma: _baseSize * Plasmoid.configuration.amplitud

                readonly property real totalWidth: tasks.taskRepeater.count * _baseSize

                readonly property real _zoom: (Plasmoid.configuration.magnification || 0) / 100
                readonly property real maxZoom: 1.0 + (Plasmoid.configuration.magnification || 0) / 100

                readonly property real baseContentSize: taskRepeater.count * Plasmoid.configuration.iconSize + Math.max(0, taskRepeater.count - 1) * spacing

                // Integral gaussiana aproximada
                readonly property real zoomExtraSize: _zoom * _sigma * Math.sqrt(2 * Math.PI)

                property real contentSize: Math.ceil(baseContentSize + zoomExtraSize + spacing * 4)

               readonly property real iconsTotalSize: {
                   let total = 0;

                   for (let i = 0; i < taskRepeater.count; ++i) {
                       let item = taskRepeater.itemAt(i);

                       if (item) {

                           total += tasks.vertical
                           ? item.height
                           : item.width;

                           if (i > 0)
                               total += spacing;
                       }
                   }

                   return total;
               }

               readonly property real centerOffset: {
                   let availableSize = tasks.vertical
                   ? height
                   : width;

                   return (availableSize - iconsTotalSize) / 2;
               }

                Layout.maximumWidth: contentSize
                Layout.maximumHeight: contentSize

                width: {
                    if (tasks.vertical) {
                        return Math.ceil(
                            Plasmoid.configuration.iconSize *
                            taskList.maxZoom +
                            spacing * 4
                        );
                    }

                    return contentSize;
                }

                height: {
                    if (tasks.vertical) {
                        return contentSize;
                    }

                    return tasks.height;
                }

                flow: {
                    if (tasks.vertical) {
                        return Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom
                    }
                    return Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight
                }

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries(children, tasks);
                    }
                }

                HoverHandler {
                    id: dockHoverHandler

                    onPointChanged: {
                        let mappedPos = taskList.mapToItem(tasks, point.position.x, point.position.y)

                        let mousePos = tasks.vertical ? mappedPos.y : mappedPos.x

                        if (taskList.smoothMouse < 0) {
                            taskList.smoothMouse = mousePos
                        } else {
                            taskList.smoothMouse +=
                            (mousePos - taskList.smoothMouse) * 0.3
                        }

                        taskList.insideDock = true
                    }

                    onHoveredChanged: {
                        if (hovered) {
                            taskList.insideDock = true;
                        } else {
                            exitTimer.restart();
                        }
                    }
                }

                Timer {
                    id: exitTimer
                    interval: 40
                    repeat: false
                    onTriggered: {
                        if (!dockHoverHandler.hovered) {
                            taskList.insideDock = false;
                        }
                    }
                }

                Repeater {
                    id: taskRepeater
                    model: tasksModel

                    delegate: Task {
                        id: taskItem
                        tasksRoot: tasks
                        dockRef: taskList

                        x: {
                            if (tasks.vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                                return width;

                            if (tasks.vertical)
                                return -taskList.spacing * 2;

                            return itemPos;
                        }

                        y: {
                            if (tasks.vertical && Plasmoid.location === PlasmaCore.Types.TopEdge)
                                return taskList.spacing;

                            if (tasks.vertical)
                                return itemPos;

                            return taskList.height - height;
                        }

                        property real itemPos: {
                            let pos = taskList.centerOffset;

                            for (let i = 0; i < index; ++i) {
                                let previousItem = taskRepeater.itemAt(i);

                                let size = previousItem
                                ? (tasks.vertical
                                ? previousItem.height
                                : previousItem.width)
                                : Plasmoid.configuration.iconSize;

                                pos += size + taskList.spacing;
                            }

                            return pos;
                        }

                        width: tasks.vertical
                        ? Plasmoid.configuration.iconSize
                        : (Plasmoid.configuration.iconSize * zoomFactor)

                        height: tasks.vertical
                        ? (Plasmoid.configuration.iconSize * zoomFactor)
                        : undefined
                    }
                }
            }
        }

        // Gestiona la vinculación de propiedades una vez que el componente se carga en memoria.
        Loader {
            id: penguinLoader
            active: Plasmoid.configuration.cairoPenguinEnabled
            z: 999
            anchors.bottom: parent.bottom

            source: "CairoPenguin.qml"

            // Pasa los enlaces (bindings) al componente cargado
            onLoaded: {
                let calculateMinX = () => taskList.x + taskList.centerOffset;
                let calculateMaxX = () => calculateMinX() + taskList.iconsTotalWidth - item.width;

                item.minX = Qt.binding(calculateMinX);
                item.maxX = Qt.binding(calculateMaxX);
            }
        }

        readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
        property GroupDialog groupDialog
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    // TODO: Change type to int
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }

        const task = taskRepeater.itemAt(index) as Task;
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        applyBackgroundHint();
        // --- CARGAR SKIN AL INICIAR ---
        loadSkinConfig();
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }

    // para hacer panel transparente
    Timer {
        id: initializeAppletTimer
        interval: 1200
        repeat: false // Lo hacemos repetir hasta que encuentre el contenedor
        running: true

        property int step: 0
        readonly property int maxStep: 5

        onTriggered: {
            console.log("Intento de transparencia número: " + (step + 1));
            applyBackgroundHint();

            if (tasks.containmentItem !== null || step >= maxStep) {
                stop(); // Se detiene cuando lo logra o alcanza el límite
            }
            step++;
        }
    }
}
