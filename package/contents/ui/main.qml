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

    preferredRepresentation: fullRepresentation

  //  Plasmoid.constraintHints: Plasmoid.CanFillArea

  // --- LÓGICA DE TRANSPARENCIA ---
  property Item containmentItem: null
  readonly property int depth: 14
  property bool isBackgroundDisabled: true

  function lookForContainer(object, tries) {
      if (tries === 0 || object === null) return;
      // Esta es la línea clave que dijiste que funciona
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
      image: "", imagetask: "",
      left: 0, top: 0, right: 0, bottom: 0,
      outLeft: 0, outTop: 0, outRight: 0, outBottom: 0
  })

  function loadSkinConfig() {
      let skinName = Plasmoid.configuration.skinName || "default";
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
            sourceComponent: (Plasmoid.configuration.skinName === "default") ? defaultSkin : customSkin
        }

        // --- Componente 1: DEFAULT (SVG) ---
        Component {
            id: defaultSkin
            Item {
                id: internalCanvas

                // Definimos cuánto queremos que crezca el fondo lateralmente
                readonly property int expansionAmount: tasks.isZoomActive ? 74 : 0

                // 2. CAPA DE FONDO
                KSvg.FrameSvgItem {
                    id: backgroundItem
                    imagePath: "widgets/panel-background"
                    prefix: ""
                    z: -1

                    // Altura (Tu lógica original)
                    height: (Plasmoid.configuration.iconSize < 48) ? taskList.height - (shadowItem.margins.top + 6) : taskList.height - (shadowItem.margins.top - 4)
                    y: (Plasmoid.configuration.iconSize < 48) ? shadowItem.margins.top + 6 : shadowItem.margins.top - 4

                    // --- ANCHO Y POSICIÓN DINÁMICA ---
                    width: (taskList.width - 56) + internalCanvas.expansionAmount
                    x: 28 - (internalCanvas.expansionAmount / 2)

                    // Animaciones para suavizar el estiramiento
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    // Respetamos los hints del SVG
                    anchors.leftMargin: shadowItem.margins.left
                    anchors.topMargin: shadowItem.margins.top
                    anchors.rightMargin: shadowItem.margins.right
                    anchors.bottomMargin: shadowItem.margins.bottom
                }

                // 1. CAPA DE SOMBRA
                KSvg.FrameSvgItem {
                    id: shadowItem
                    imagePath: "widgets/panel-background"
                    prefix: "shadow"
                    z: -2

                    // Altura (Tu lógica original)
                    height: (Plasmoid.configuration.iconSize < 48) ? taskList.height + (shadowItem.margins.top - 6) : taskList.height + (shadowItem.margins.top + 4)
                    y: (Plasmoid.configuration.iconSize < 48) ? 6 : -4

                    // --- ANCHO Y POSICIÓN DE SOMBRA DINÁMICA ---
                    width: (taskList.width - 32) + internalCanvas.expansionAmount
                    x: 16 - (internalCanvas.expansionAmount / 2)

                    // Animaciones para que la sombra siga al fondo suavemente
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }

        // --- Componente 2: CUSTOM (Imagen) ---
        Component {
            id: customSkin
            BorderImage {
                id: dockBackground
                asynchronous: false
                visible: source.toString() !== ""
                opacity: 1.0

                // 1. Definimos propiedades para animar los laterales
                // Si hay zoom, restamos un valor (ej. 20px) para que el fondo se extienda
                property int dynamicLeftMargin: tasks.isZoomActive ? (tasks.skinParams.outLeft - 27) : tasks.skinParams.outLeft
                property int dynamicRightMargin: tasks.isZoomActive ? (tasks.skinParams.outRight - 27) : tasks.skinParams.outRight

                anchors {
                    fill: parent
                    topMargin: tasks.skinParams.outTop
                    bottomMargin: tasks.skinParams.outBottom

                    // 2. Vinculamos las anclas a nuestras propiedades dinámicas
                    leftMargin: dockBackground.dynamicLeftMargin
                    rightMargin: dockBackground.dynamicRightMargin
                }

                // 3. Animamos ambos márgenes para un efecto suave de expansión
                Behavior on dynamicLeftMargin {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on dynamicRightMargin {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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

                property real smoothMouseX: -1
                property bool insideDock: false
                property alias animating: taskList.animating


                width: Math.ceil(taskRepeater.count * (Plasmoid.configuration.iconSize +  14))  // 10 menos que la  altura del panel
                height: tasks.height

                // 2. Calculamos el ancho real de todos los iconos sumados
                readonly property real iconsTotalWidth: {
                    let total = 0;
                    for (let i = 0; i < taskRepeater.count; ++i) {
                        let item = taskRepeater.itemAt(i);
                        if (item) total += item.width;
                    }
                    return total;
                }

                // 3. El desplazamiento necesario para centrar el bloque
                readonly property real centerOffset: (width - iconsTotalWidth) / 2

                Layout.maximumWidth: width

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

                        if (taskList.smoothMouseX < 0) {
                            taskList.smoothMouseX = mappedPos.x
                        } else {
                            taskList.smoothMouseX +=
                            (mappedPos.x - taskList.smoothMouseX) * 0.3
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
                            cleanupTimer.restart();
                        }
                    }
                }

                // Limpiar las coordenadas del ratón SOLO CUANDO termine la animación de salida
                Timer {
                    id: cleanupTimer
                    // 220 ms para cubrir de forma segura la animación Task.qml de 200 ms.
                    interval: 220
                    repeat: false
                    onTriggered: {
                        if (!dockMouseArea.containsMouse) {
                            dockMouseArea.smoothMouseX = -1;
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
                            let posX = taskList.centerOffset; // Empezamos en el centro calculado
                            for (let i = 0; i < index; ++i) {
                                let previousItem = taskRepeater.itemAt(i);
                                // Si el item anterior existe, sumamos su ancho.
                                // Si no, sumamos el ancho base estimado (60) para que no se encimen.
                                posX += (previousItem ? previousItem.width : 60);
                            }
                            return posX;
                        }
                        width: (Plasmoid.configuration.iconSize * zoomFactor) + 6
                    }
                }
            }
        }
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
