/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel // Importante para listar las carpetas de skins

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import QtQuick.Layouts

KCMUtils.SimpleKCM {
    id: root

    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: Plasmoid.pluginName === "org.vicko.wavetask"

    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property bool cfg_tooltipControls
    property alias cfg_fill: fill.checked
    property alias cfg_maxStripes: maxStripes.value
    property alias cfg_forceStripes: forceStripes.checked
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex
    property int cfg_iconSpacing: 0
    // wavetask
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_magnification: magnificationSlider.value
    property alias cfg_amplitud: amplitudSlider.value
    property string cfg_skinName: Plasmoid.configuration.skinName
    property alias cfg_showReflection: showReflection.checked

    Component.onCompleted: {
        /* Don't rely on bindings for checking the radiobuttons
           When checking forceStripes, the condition for the checked value for the allow stripes button
           became true and that one got checked instead, stealing the checked state for the just clicked checkbox
        */
        if (maxStripes.value === 1) {
            forbidStripes.checked = true;
        } else if (!Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            allowStripes.checked = true;
        } else if (Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            forceStripes.checked = true;
        }
    }
    Kirigami.FormLayout {

        // ComboBox para mostrar los skins
        QQC2.ComboBox {
            id: skinChooser
            Kirigami.FormData.label: "Skin:"
            textRole: "fileName"

            // Usamos una propiedad local para rastrear si ya sincronizamos el valor inicial
            property bool initialSyncDone: false

            model: FolderListModel {
                id: folderModel
                folder: Qt.resolvedUrl("../skins")
                showDirs: true
                showFiles: false
                showDotAndDotDot: false
                // Forzamos a que el modelo se mantenga actualizado
                sortField: FolderListModel.Name
            }

            onActivated: {
                // Actualizamos la configuración al elegir manualmente
                cfg_skinName = textAt(currentIndex)
            }

            function syncValue() {
                // Si el modelo ya tiene carpetas y aún no hemos sincronizado...
                if (count > 0 && !initialSyncDone) {
                    for (let i = 0; i < count; i++) {
                        if (textAt(i) === cfg_skinName) {
                            currentIndex = i;
                            initialSyncDone = true; // Marcamos como hecho
                            return;
                        }
                    }
                }
            }

            // Monitoreamos cuando el modelo termine de cargar los archivos
            Connections {
                target: folderModel
                // 'status' cambia a FolderListModel.Ready cuando termina de leer el disco
                function onStatusChanged() {
                    if (folderModel.status === FolderListModel.Ready) {
                        skinChooser.syncValue();
                    }
                }
                // Por si acaso los archivos ya estaban listos
                function onCountChanged() { skinChooser.syncValue() }
            }

            // Intentar sincronizar al completar por si el disco es ultra rápido
            Component.onCompleted: syncValue()
        }
        // --- Selector de Tamaño de Iconos ---
        RowLayout {
            Kirigami.FormData.label: "Icon Size:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: iconSizeSlider
                Layout.fillWidth: true

                from: 32
                to: 64
                stepSize: 2
                snapMode: QQC2.Slider.SnapOnRelease

                // El valor inicial vendrá de la configuración de Plasma
                value: Plasmoid.configuration.iconSize || 44
            }

            QQC2.Label {
                text: Math.floor(iconSizeSlider.value) + "px"
                font.family: "Monospace"
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }
        }
        // --- Selector de Tamaño de Zoom ---
        RowLayout {
            Kirigami.FormData.label: "Zoom Percentage:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: magnificationSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapOnRelease
                // El valor inicial viene de la configuración (ej: 90% -> 0.9)
                value: Plasmoid.configuration.magnification || 50
            }
            QQC2.Label {
                text: Math.floor(magnificationSlider.value) + "%"
                font.family: "Monospace"
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }
        }

        // --- Selector de Amplitud ---
        RowLayout {
            Kirigami.FormData.label: "Amplitude:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: amplitudSlider
                Layout.fillWidth: true

                from: 1.1
                to: 2.5
                stepSize: 0.1
                snapMode: QQC2.Slider.SnapOnRelease

                // El valor inicial vendrá de la configuración de Plasma
                value: Plasmoid.configuration.amplitud || 1.8
            }

            QQC2.Label {
                text: amplitudSlider.value.toFixed(1)
                font.family: "Monospace"
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.2
            }
        }

        QQC2.CheckBox {
            id: showReflection
            Kirigami.FormData.label: i18nc("@label", "Reflection:")
            text: i18nc("@option:check", "Show icon reflection below dock")
        }

        QQC2.CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:")
            text: i18nc("@option:check section General", "Show small window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            text: showToolTips.checked ? i18nc("@option:check section General", "Hide other windows when hovering over previews") : i18nc("@option:check section General", "Hide other windows when hovering over tooltips")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check section General", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            leftPadding: mirrored ? 0 : (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing)
            rightPadding: mirrored ? (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing) : 0
            text: i18nc("@option:check section General", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: tooltipControls
            text: i18nc("@option:check section General", "Show media and volume controls in tooltip")
            checked: root.cfg_tooltipControls && root.plasmaPaAvailable
            onToggled: root.cfg_tooltipControls = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: fill
            text: i18nc("@option:check section General", "Fill free space on panel")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !root.iconOnly
        }

        QQC2.ComboBox {
            id: taskMaxWidth
            visible: !root.iconOnly && !root.plasmoidVertical

            Kirigami.FormData.label: i18nc("@label:listbox", "Maximum task width:")

            model: [
                i18nc("@item:inlistbox how wide a task item should be", "Narrow"),
                i18nc("@item:inlistbox how wide a task item should be", "Medium"),
                i18nc("@item:inlistbox how wide a task item should be", "Wide")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: forbidStripes
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-column view:")
                : i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-row view:")
            onToggled: {
                if (checked) {
                    maxStripes.value = 1
                }
            }
            text: i18nc("@option:radio Never use multi-column view for Task Manager", "Never")
        }

        QQC2.RadioButton {
            id: allowStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "When panel is low on space and thick enough")
        }

        QQC2.RadioButton {
            id: forceStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "Always when panel is thick enough")
        }

        QQC2.SpinBox {
            id: maxStripes
            enabled: maxStripes.value > 1
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label:spinbox maximum number of columns for tasks", "Maximum columns:")
                : i18nc("@label:spinbox maximum number of rows for tasks", "Maximum rows:")
            from: 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            visible: root.iconOnly
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing between icons:")

            model: [
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Small"),
                    "spacing": 0
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Normal"),
                    "spacing": 1
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Large"),
                    "spacing": 3
                },
            ]

            textRole: "label"
            enabled: !Kirigami.Settings.tabletMode

            currentIndex: {
                if (Kirigami.Settings.tabletMode) {
                    return 2; // Large
                }

                switch (root.cfg_iconSpacing) {
                    case 0: return 0; // Small
                    case 1: return 1; // Normal
                    case 3: return 2; // Large
                }
            }
            onActivated: index => {
                root.cfg_iconSpacing = model[currentIndex]["spacing"];
            }
        }

        QQC2.Label {
            visible: Kirigami.Settings.tabletMode
            text: i18nc("@info:usagetip under a set of radio buttons when Touch Mode is on", "Automatically set to Large when in Touch mode")
            font: Kirigami.Theme.smallFont
        }
    }
}
