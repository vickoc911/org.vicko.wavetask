// SPDX-License-Identifier: GPL-2.0-or-later
#include "widgethost.h"

#include "log_settings.h"

#include <KConfigGroup>
#include <KLocalizedString>
#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <Plasma/PluginLoader>
#include <PlasmaQuick/AppletQuickItem>
#include <QAction>
#include <algorithm>
#include <memory>

namespace WaveTask
{
static const QString containmentPlugin = QStringLiteral("org.vicko.wavetask.widgets");

WidgetHost::WidgetHost(QObject *parent)
    : QObject(parent)
{
}

QObject *WidgetHost::owner() const
{
    return m_owner;
}

void WidgetHost::setOwner(QObject *owner)
{
    auto *applet = qobject_cast<Plasma::Applet *>(owner);
    if (m_owner == applet) {
        return;
    }
    if (m_owner) {
        disconnect(m_owner, nullptr, this, nullptr);
    }
    if (m_containment) {
        disconnect(m_containment, nullptr, this, nullptr);
        for (auto *child : m_containment->applets()) {
            disconnect(child, nullptr, this, nullptr);
        }
    }
    m_containment = nullptr;
    m_owner = applet;
    Q_EMIT ownerChanged();
    if (m_owner) {
        connect(m_owner, &Plasma::Applet::formFactorChanged, this, &WidgetHost::syncConstraints);
        connect(m_owner, &Plasma::Applet::locationChanged, this, &WidgetHost::syncConstraints);
        connect(m_owner, &Plasma::Applet::immutabilityChanged, this, &WidgetHost::syncConstraints);
        // Existing containments must be adopted even while widgets are locked.
        if (m_owner->config().readEntry("WidgetContainmentId", 0u)) {
            ensureContainment();
        }
    }
    Q_EMIT entriesChanged();
    Q_EMIT needsAttentionChanged();
}

void WidgetHost::fail(const QString &message)
{
    qCWarning(WAVETASK_DEBUG) << message;
    m_error = message;
    Q_EMIT errorChanged();
}

QString WidgetHost::error() const
{
    return m_error;
}

bool WidgetHost::ensureContainment()
{
    if (m_containment) {
        return true;
    }
    if (!m_owner || !m_owner->containment() || !m_owner->containment()->corona()) {
        fail(i18n("The dock is not attached to a Plasma containment."));
        return false;
    }
    auto *corona = m_owner->containment()->corona();
    const uint id = m_owner->config().readEntry("WidgetContainmentId", 0u);
    for (auto *containment : corona->containments()) {
        if (containment->id() == id && containment->pluginMetaData().pluginId() == containmentPlugin) {
            m_containment = containment;
            break;
        }
    }
    if (!m_containment) {
        m_containment = corona->createContainment(containmentPlugin);
        if (!m_containment || !m_containment->pluginMetaData().isValid() || m_containment->failedToLaunch()) {
            fail(i18n("Cannot load the WaveTask widget containment. Install the updated WaveTask package."));
            if (m_containment) {
                m_containment->destroy();
                m_containment = nullptr;
            }
            return false;
        }
        m_owner->config().writeEntry("WidgetContainmentId", m_containment->id());
        Q_EMIT m_owner->configNeedsSaving();
    }
    if (m_containment->parent() != m_owner) {
        auto removed = std::make_shared<bool>(false);
        auto *containment = m_containment.data();
        connect(m_owner, &Plasma::Applet::destroyedChanged, containment, [removed](bool destroyed) {
            *removed = destroyed;
        });
        // Keep cleanup alive even if the dock's QML host is destroyed first.
        connect(m_owner, &QObject::destroyed, containment, [removed, containment] {
            if (*removed) containment->destroy();
        });
        containment->setParent(m_owner);
    }
    syncConstraints();
    // Load the containment UI before creating any applet representations.
    if (!PlasmaQuick::AppletQuickItem::itemForApplet(m_containment)) {
        fail(i18n("Cannot load the WaveTask widget containment interface."));
        m_containment = nullptr;
        return false;
    }
    connect(m_containment, &Plasma::Containment::appletAdded, this, [this](Plasma::Applet *applet) {
        observeApplet(applet);
        Q_EMIT entriesChanged();
        Q_EMIT needsAttentionChanged();
    });
    connect(m_containment, &Plasma::Containment::appletRemoved, this, [this](Plasma::Applet *applet) {
        disconnect(applet, nullptr, this, nullptr);
        Q_EMIT entriesChanged();
        Q_EMIT needsAttentionChanged();
    });
    for (auto *applet : m_containment->applets()) {
        observeApplet(applet);
    }
    return true;
}

void WidgetHost::syncConstraints()
{
    if (!m_owner || !m_containment) {
        return;
    }
    m_containment->setFormFactor(m_owner->formFactor());
    m_containment->setLocation(m_owner->location());
    m_containment->setImmutability(m_owner->immutability());
}

void WidgetHost::observeApplet(Plasma::Applet *applet)
{
    connect(applet, &Plasma::Applet::statusChanged, this, &WidgetHost::needsAttentionChanged);
    connect(applet, &Plasma::Applet::destroyedChanged, this, &WidgetHost::entriesChanged);
    connect(applet, &Plasma::Applet::destroyedChanged, this, &WidgetHost::needsAttentionChanged);
    connect(applet, &Plasma::Applet::configNeedsSaving, this, [this] {
        if (m_owner) {
            Q_EMIT m_owner->configNeedsSaving();
        }
    });
}

QVariantList WidgetHost::entries() const
{
    QVariantList result;
    if (!m_containment) {
        return result;
    }
    for (auto *applet : m_containment->applets()) {
        if (applet->destroyed()) {
            continue;
        }
        auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
        result.append(QVariantMap{
            {QStringLiteral("id"), applet->id()},
            {QStringLiteral("title"), applet->title()},
            {QStringLiteral("position"), applet->config().readEntry("WaveTaskPosition", 0)},
            {QStringLiteral("item"), QVariant::fromValue(static_cast<QObject *>(item))},
        });
    }
    return result;
}

bool WidgetHost::needsAttention() const
{
    if (m_containment) {
        for (auto *applet : m_containment->applets()) {
            if (!applet->destroyed() && (applet->status() == Plasma::Types::NeedsAttentionStatus
                || applet->status() == Plasma::Types::AcceptingInputStatus)) {
                return true;
            }
        }
    }
    return false;
}

QVariantList WidgetHost::availableWidgets() const
{
    QVariantList result;
    const auto metadata = Plasma::PluginLoader::self()->listAppletMetaData(QString());
    for (const auto &data : metadata) {
        if (data.pluginId() == QStringLiteral("org.vicko.wavetask")
            || data.pluginId() == containmentPlugin
            || !data.value(QStringLiteral("X-Plasma-ContainmentType")).isEmpty()
            || data.isHidden()) {
            continue;
        }
        result.append(QVariantMap{
            {QStringLiteral("plugin"), data.pluginId()},
            {QStringLiteral("title"), data.name()},
        });
    }
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("title")).toString(),
            b.toMap().value(QStringLiteral("title")).toString()) < 0;
    });
    return result;
}

bool WidgetHost::addWidget(const QString &plugin, int position)
{
    if (!m_owner || m_owner->immutability() != Plasma::Types::Mutable) {
        fail(i18n("Unlock widgets before adding them to the dock."));
        return false;
    }
    if (plugin == QStringLiteral("org.vicko.wavetask") || plugin == containmentPlugin || plugin.isEmpty() || position < 0) {
        fail(i18n("This widget cannot be embedded in the dock."));
        return false;
    }
    const auto metadata = Plasma::PluginLoader::self()->listAppletMetaData(QString());
    const auto candidate = std::find_if(metadata.cbegin(), metadata.cend(), [&plugin](const KPluginMetaData &data) {
        return data.pluginId() == plugin;
    });
    if (candidate == metadata.cend() || !candidate->value(QStringLiteral("X-Plasma-ContainmentType")).isEmpty()) {
        fail(i18n("Cannot embed widget %1. It must be an installed Plasma applet, not a containment.", plugin));
        return false;
    }
    if (!ensureContainment()) {
        return false;
    }
    auto *applet = m_containment->createApplet(plugin);
    auto *item = applet ? PlasmaQuick::AppletQuickItem::itemForApplet(applet) : nullptr;
    if (!applet || !item || applet->isContainment() || applet->failedToLaunch()) {
        fail(i18n("Cannot load widget %1.", plugin));
        if (applet) {
            applet->destroy();
        }
        return false;
    }
    applet->config().writeEntry("WaveTaskPosition", position);
    Q_EMIT applet->configNeedsSaving();
    m_error.clear();
    Q_EMIT errorChanged();
    Q_EMIT entriesChanged();
    return true;
}

Plasma::Applet *WidgetHost::findApplet(uint id) const
{
    if (m_containment) {
        for (auto *applet : m_containment->applets()) {
            if (applet->id() == id && !applet->destroyed()) {
                return applet;
            }
        }
    }
    return nullptr;
}

void WidgetHost::moveWidget(uint id, int position)
{
    if (!m_owner || m_owner->immutability() != Plasma::Types::Mutable || position < 0) {
        fail(i18n("Unlock widgets before changing the dock layout."));
        return;
    }
    if (auto *applet = findApplet(id)) {
        applet->config().writeEntry("WaveTaskPosition", position);
        Q_EMIT applet->configNeedsSaving();
        Q_EMIT entriesChanged();
    } else {
        fail(i18n("The selected widget is no longer in the dock."));
    }
}

void WidgetHost::removeWidget(uint id)
{
    if (!m_owner || m_owner->immutability() != Plasma::Types::Mutable) {
        fail(i18n("Unlock widgets before removing them from the dock."));
        return;
    }
    if (auto *applet = findApplet(id)) {
        applet->destroy();
    } else {
        fail(i18n("The selected widget is no longer in the dock."));
    }
}

void WidgetHost::configureWidget(uint id)
{
    if (auto *applet = findApplet(id)) {
        if (auto *action = applet->internalAction(QStringLiteral("configure"))) {
            action->trigger();
        }
    } else {
        fail(i18n("The selected widget is no longer in the dock."));
    }
}
}
