import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.graphicaleffects as KGraphicalEffects
import org.kde.plasma.plasmoid

Item {
    id: root
    enabled: false

    // Reflection Logic
    readonly property bool reflectionEnabled: Plasmoid.configuration.showReflection || false
    readonly property int reflectionOffset: reflectionEnabled ? -8 : 0
    readonly property bool shiftBadgeDown: (Plasmoid.pluginName === "org.vicko.wavetask") && task.audioStreamIcon !== null

    // 1. THIS REMAINS VISIBLE: The actual icon sits here
    // No ShaderEffectSource needed for the main icon.

    // 2. THE BADGE MASK: Only defines the area for the badge
    Item {
        id: badgeMask
        anchors.fill: parent

        Rectangle {
            id: maskRect
            anchors.right: parent.right
            anchors.rightMargin: -Math.round(icon.width * 0.15)
            y: (root.shiftBadgeDown ? (icon.height / 2) : -Math.round(icon.height * 0.10)) + root.reflectionOffset
            width: Math.round(icon.width * 0.38)
            height: Math.round(icon.height * 0.38)
            radius: width / 2
        }
    }

    // 3. THE SHADER: Only masks the badge area
    ShaderEffectSource {
        id: maskShaderSource
        sourceItem: badgeMask
        hideSource: true
        live: true
    }

    KGraphicalEffects.BadgeEffect {
        id: shader
        anchors.fill: parent // Fill parent to encompass the badge area
        source: icon // Use the icon as the source for the shadow
        mask: maskShaderSource
    }

    // 4. THE VISUAL BADGE: Rendered on top
    Badge {
        id: badgeRect
        anchors.right: parent.right
        anchors.rightMargin: -Math.round(icon.width * 0.15)
        y: (root.shiftBadgeDown ? (icon.height / 2) : -Math.round(icon.height * 0.10)) + root.reflectionOffset

        scale: 0.5
        height: Math.round(icon.height * 0.38)
        number: task.smartLauncherItem.count
        visible: task.smartLauncherItem.countVisible
    }
}
