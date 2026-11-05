// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <qqmlregistration.h>

namespace Plasma
{
class Applet;
class Containment;
}

namespace WaveTask
{
class WidgetHost : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *owner READ owner WRITE setOwner NOTIFY ownerChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(bool needsAttention READ needsAttention NOTIFY needsAttentionChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit WidgetHost(QObject *parent = nullptr);
    QObject *owner() const;
    void setOwner(QObject *owner);
    QVariantList entries() const;
    bool needsAttention() const;
    QString error() const;

    Q_INVOKABLE bool addWidget(const QString &plugin, int position);
    Q_INVOKABLE QVariantList availableWidgets() const;
    Q_INVOKABLE void moveWidget(uint id, int position);
    Q_INVOKABLE void removeWidget(uint id);
    Q_INVOKABLE void configureWidget(uint id);

Q_SIGNALS:
    void ownerChanged();
    void entriesChanged();
    void needsAttentionChanged();
    void errorChanged();

private:
    bool ensureContainment();
    void observeApplet(Plasma::Applet *applet);
    void syncConstraints();
    void fail(const QString &message);
    Plasma::Applet *findApplet(uint id) const;

    QPointer<Plasma::Applet> m_owner;
    QPointer<Plasma::Containment> m_containment;
    QString m_error;
};
}
