/*
 *    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
 *
 *    SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "backend.h"

#include "log_settings.h"

#include <KActionCollection>
#include <KConfigGroup>
#include <KDesktopFile>
#include <KFileItem>
#include <KFilePlacesModel>
#include <KLocalizedString>
#include <KNotificationJobUiDelegate>
#include <KProtocolInfo>
#include <KService>
#include <KServiceAction>
#include <KWindowEffects>
#include <KWindowSystem>

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>

#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QDir>
#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QMenu>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSet>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTimer>
#include <QVersionNumber>

#include <KGlobalAccel>

#include <mutex>

#include <PlasmaActivities/Consumer>
#include <PlasmaActivities/Stats/Cleaning>
#include <PlasmaActivities/Stats/ResultSet>
#include <PlasmaActivities/Stats/Terms>

#include <processcore/process.h>
#include <processcore/processes.h>

#include <cerrno>
#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace KAStats = KActivities::Stats;

using namespace KAStats;
using namespace KAStats::Terms;

static constexpr int NoApplications = 2; // kactivitymanager StatsPlugin WhatToRemember.

QVector<Backend *> Backend::s_instances;

Backend::Backend(QObject *parent)
: QObject(parent)
, m_actionGroup(new QActionGroup(this))
, m_activityManagerPluginsSettingsWatcher(KConfigWatcher::create(m_activityManagerPluginsSettings.sharedConfig()))
{
    connect(m_activityManagerPluginsSettingsWatcher.get(),
            &KConfigWatcher::configChanged,
            this,
            [this](const KConfigGroup &group, const QByteArrayList &names) {
                if (group.name() == QLatin1String("Plugin-org.kde.ActivityManager.Resources.Scoring")
                    && names.contains(QByteArrayLiteral("what-to-remember"))) {
                    m_activityManagerPluginsSettings.load();
                    }
            });

    s_instances.append(this);
    setupShortcuts();

    // Direct /dev/input keyboard monitoring (instant, no focus dependency)
    initInputMonitor();
}

Backend::~Backend()
{
    s_instances.removeAll(this);

    for (auto it = m_inputMonitors.constBegin(); it != m_inputMonitors.constEnd(); ++it) {
        delete it.value().notifier;
        close(it.key());
    }
}

int Backend::screen() const
{
    return m_screen;
}

void Backend::setScreen(int screen)
{
    if (m_screen != screen) {
        m_screen = screen;
        Q_EMIT screenChanged();
    }
}

bool Backend::hasActiveTask() const
{
    return m_hasActiveTask;
}

void Backend::setHasActiveTask(bool active)
{
    if (m_hasActiveTask != active) {
        m_hasActiveTask = active;
        Q_EMIT hasActiveTaskChanged();
    }
}

bool Backend::showsOnlyCurrentScreen() const
{
    return m_showsOnlyCurrentScreen;
}

void Backend::setShowsOnlyCurrentScreen(bool shows)
{
    if (m_showsOnlyCurrentScreen != shows) {
        m_showsOnlyCurrentScreen = shows;
        Q_EMIT showsOnlyCurrentScreenChanged();
    }
}

// --- Meta Key Detection ---

bool Backend::isMetaKeyHeld() const
{
    return m_metaKeyHeld;
}

void Backend::setMetaKeyHeld(bool held)
{
    if (m_metaKeyHeld != held) {
        qCDebug(WAVETASK_DEBUG) << "Backend: metaKeyHeld changed to" << held;
        m_metaKeyHeld = held;
        Q_EMIT metaKeyHeldChanged();
    }
}

// --- /dev/input Keyboard Monitoring ---

void Backend::initInputMonitor()
{
    // Initial scan for keyboards that are already connected
    scanInputDevices();

    // Short settle delay after a /dev/input change so udev finishes applying permissions to the new node
    m_inputSettleTimer = new QTimer(this);
    m_inputSettleTimer->setSingleShot(true);
    m_inputSettleTimer->setInterval(500);
    connect(m_inputSettleTimer, &QTimer::timeout, this, &Backend::scanInputDevices);

    // inotify on /dev/input: probe only when nodes appear or disappear, no periodic polling
    m_inputDirWatcher = new QFileSystemWatcher(this);
    if (m_inputDirWatcher->addPath(QStringLiteral("/dev/input"))) {
        connect(m_inputDirWatcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
            pruneProbedPaths();
            m_inputSettleTimer->start();
        });
    } else {
        // Fallback in case inotify is unavailable: periodic polling, now cheap because probed paths are remembered
        auto *rescanTimer = new QTimer(this);
        rescanTimer->setInterval(5000);
        connect(rescanTimer, &QTimer::timeout, this, [this]() {
            pruneProbedPaths();
            scanInputDevices();
        });

        rescanTimer->start();
    }
}

void Backend::scanInputDevices()
{
    QDir inputDir(QStringLiteral("/dev/input"));
    const auto entries = inputDir.entryList({QStringLiteral("event*")}, QDir::System, QDir::Name);

    for (const auto &name : entries) {
        QString path = inputDir.absoluteFilePath(name);

        if (m_probedPaths.contains(path)) {
            continue; // Already probed before (monitored or rejected)
        }

        int fd = open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK);
        if (fd < 0) {
            // Don't remember the path: if udev hasn't applied permissions yet, the next /dev/input change retries it
            continue;
        }

        // Each device is probed at most once per lifetime, monitored or not
        m_probedPaths.insert(path);

        // Check if this device supports EV_KEY events
        unsigned long evBits[EV_CNT / (sizeof(unsigned long) * 8) + 1] = {};
        if (ioctl(fd, EVIOCGBIT(0, sizeof(evBits)), evBits) < 0) {
            close(fd);
            continue;
        }

        if (!(evBits[EV_KEY / (sizeof(unsigned long) * 8)] & (1UL << (EV_KEY % (sizeof(unsigned long) * 8))))) {
            close(fd);
            continue;
        }

        // Check if it has the Meta keys
        unsigned long keyBits[KEY_CNT / (sizeof(unsigned long) * 8) + 1] = {};
        if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keyBits)), keyBits) < 0) {
            close(fd);
            continue;
        }

        bool hasLeftMeta = keyBits[KEY_LEFTMETA / (sizeof(unsigned long) * 8)] & (1UL << (KEY_LEFTMETA % (sizeof(unsigned long) * 8)));
        bool hasRightMeta = keyBits[KEY_RIGHTMETA / (sizeof(unsigned long) * 8)] & (1UL << (KEY_RIGHTMETA % (sizeof(unsigned long) * 8)));

        if (!hasLeftMeta && !hasRightMeta) {
            close(fd);
            continue;
        }

        // This is a keyboard with Meta keys — monitor it
        auto *notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
        connect(notifier, &QSocketNotifier::activated, this, [this, fd]() {
            onInputEvent(fd);
        });

        m_inputMonitors.insert(fd, {path, notifier});

        qCDebug(WAVETASK_DEBUG) << "Backend: monitoring keyboard" << path
                                << "(fd=" << fd << ")";
    }
}

void Backend::pruneProbedPaths()
{
    QDir inputDir(QStringLiteral("/dev/input"));
    const auto entries = inputDir.entryList({QStringLiteral("event*")}, QDir::System, QDir::Name);

    QSet<QString> currentPaths;
    for (const auto &name : entries) {
        currentPaths.insert(inputDir.absoluteFilePath(name));
    }

    // Forget nodes that no longer exist, so a reconnection reusing the same path gets probed again
    m_probedPaths.intersect(currentPaths);
}

void Backend::onInputEvent(int fd)
{
    struct input_event ev;

    while (true) {
        const ssize_t bytesRead = read(fd, &ev, sizeof(ev));

        if (bytesRead == static_cast<ssize_t>(sizeof(ev))) {
            if (ev.type == EV_KEY &&
                (ev.code == KEY_LEFTMETA || ev.code == KEY_RIGHTMETA)) {
                if (ev.value == 1) {
                    // Press
                    qCDebug(WAVETASK_DEBUG) << "Backend: Meta pressed (fd=" << fd << ")";
                    setMetaKeyHeld(true);
                } else if (ev.value == 0) {
                    // Release
                    qCDebug(WAVETASK_DEBUG) << "Backend: Meta released (fd=" << fd << ")";
                    setMetaKeyHeld(false);
                }

                // value == 2 (auto-repeat): ignored for modifier keys
            }

            continue;
        }

        if (bytesRead < 0 && errno == EINTR) {
            continue;
        }

        if (bytesRead < 0 && errno == EAGAIN) {
            break; // No more events pending
        }

        // EOF or error (e.g. ENODEV on keyboard unplug): tear down the monitor so the notifier doesn't fire in a busy loop
        removeInputDevice(fd);
        break;
    }
}

void Backend::removeInputDevice(int fd)
{
    const InputDeviceMonitor monitor = m_inputMonitors.take(fd);
    if (!monitor.notifier) {
        return;
    }

    monitor.notifier->setEnabled(false);
    monitor.notifier->deleteLater();
    close(fd);

    // Forget the path (unless another fd already monitors the node that reused it) so a reconnection gets probed again
    bool pathStillMonitored = false;
    for (const auto &other : std::as_const(m_inputMonitors)) {
        if (other.path == monitor.path) {
            pathStillMonitored = true;
            break;
        }
    }

    if (!pathStillMonitored) {
        m_probedPaths.remove(monitor.path);
    }

    qCDebug(WAVETASK_DEBUG) << "Backend: stopped monitoring" << monitor.path << "(fd=" << fd << ")";
}

// --- End Meta Key Detection ---

QUrl Backend::tryDecodeApplicationsUrl(const QUrl &launcherUrl)
{
    if (launcherUrl.isValid() && launcherUrl.scheme() == QLatin1String("applications")) {
        const KService::Ptr service = KService::serviceByMenuId(launcherUrl.path());

        if (service) {
            return QUrl::fromLocalFile(service->entryPath());
        }
    }

    return launcherUrl;
}

QStringList Backend::applicationCategories(const QUrl &launcherUrl)
{
    const QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QStringList();
    }

    KDesktopFile desktopFile(desktopEntryUrl.toLocalFile());

    // Since we can't have dynamic jump list actions, at least add the user's "Places" for file managers.
    return desktopFile.desktopGroup().readXdgListEntry(QStringLiteral("Categories"));
}

QVariantList Backend::jumpListActions(const QUrl &launcherUrl, QObject *parent)
{
    QVariantList actions;

    if (!parent) {
        return actions;
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return actions;
    }

    const KService::Ptr service = KService::serviceByDesktopPath(desktopEntryUrl.toLocalFile());
    if (!service) {
        return actions;
    }

    if (service->storageId() == QLatin1String("systemsettings.desktop")) {
        actions = systemSettingsActions(parent);
        if (!actions.isEmpty()) {
            return actions;
        }
    }

    const auto jumpListActions = service->actions();

    for (const KServiceAction &serviceAction : jumpListActions) {
        if (serviceAction.noDisplay()) {
            continue;
        }

        QAction *action = new QAction(parent);
        action->setText(serviceAction.text());
        action->setIcon(QIcon::fromTheme(serviceAction.icon()));
        if (serviceAction.isSeparator()) {
            action->setSeparator(true);
        }

        connect(action, &QAction::triggered, this, [serviceAction]() {
            auto *job = new KIO::ApplicationLauncherJob(serviceAction);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);
            job->start();
        });

        actions << QVariant::fromValue<QAction *>(action);
    }

    return actions;
}

QVariantList Backend::systemSettingsActions(QObject *parent) const
{
    QVariantList actions;

    if (m_activityManagerPluginsSettings.whatToRemember() == NoApplications) {
        return actions;
    }

    auto query = AllResources | Agent(QStringLiteral("org.kde.systemsettings")) | HighScoredFirst | Limit(5);

    ResultSet results(query);

    QStringList ids;
    for (const ResultSet::Result &result : results) {
        ids << QUrl(result.resource()).path();
    }

    if (ids.count() < 5) {
        // We'll load the default set of settings from its jump list actions.
        return actions;
    }

    for (const QString &id : std::as_const(ids)) {
        KService::Ptr service = KService::serviceByStorageId(id);
        if (!service || !service->isValid()) {
            continue;
        }

        QAction *action = new QAction(parent);
        action->setText(service->name());
        action->setIcon(QIcon::fromTheme(service->icon()));

        connect(action, &QAction::triggered, this, [service]() {
            auto *job = new KIO::ApplicationLauncherJob(service);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);
            job->start();
        });

        actions << QVariant::fromValue<QAction *>(action);
    }
    return actions;
}

QVariantList Backend::placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent)
{
    if (!parent) {
        return QVariantList();
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QVariantList();
    }

    QVariantList actions;

    // Since we can't have dynamic jump list actions, at least add the user's "Places" for file managers.
    if (!applicationCategories(launcherUrl).contains(QLatin1String("FileManager"))) {
        return actions;
    }

    QString previousGroup;
    QMenu *subMenu = nullptr;

    std::unique_ptr<KFilePlacesModel> placesModel(new KFilePlacesModel());
    for (int i = 0; i < placesModel->rowCount(); ++i) {
        QModelIndex idx = placesModel->index(i, 0);

        if (placesModel->isHidden(idx)) {
            continue;
        }

        const QString &title = idx.data(Qt::DisplayRole).toString();
        const QIcon &icon = idx.data(Qt::DecorationRole).value<QIcon>();
        const QUrl &url = idx.data(KFilePlacesModel::UrlRole).toUrl();

        QAction *placeAction = new QAction(icon, title, parent);

        connect(placeAction, &QAction::triggered, this, [url, desktopEntryUrl] {
            KService::Ptr service = KService::serviceByDesktopPath(desktopEntryUrl.toLocalFile());
            if (!service) {
                return;
            }

            auto *job = new KIO::ApplicationLauncherJob(service);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);

            job->setUrls({url});
            job->start();
        });

        const QString &groupName = idx.data(KFilePlacesModel::GroupRole).toString();
        if (previousGroup.isEmpty()) { // Skip first group heading.
            previousGroup = groupName;
        }

        // Put all subsequent categories into a submenu.
        if (previousGroup != groupName) {
            QAction *subMenuAction = new QAction(groupName, parent);
            subMenu = new QMenu();
            // Breeze and Oxygen have rounded corners on menus. They set this attribute in polish()
            // but at that time the underlying surface has already been created where setting this
            // flag makes no difference anymore (Bug 385311)
            subMenu->setAttribute(Qt::WA_TranslucentBackground);
            // Cannot parent a QMenu to a QAction, need to delete it manually.
            connect(parent, &QObject::destroyed, subMenu, &QObject::deleteLater);
            subMenuAction->setMenu(subMenu);

            actions << QVariant::fromValue(subMenuAction);

            previousGroup = groupName;
        }

        if (subMenu) {
            subMenu->addAction(placeAction);
        } else {
            actions << QVariant::fromValue(placeAction);
        }
    }

    // There is nothing more frustrating than having a "More" entry that ends up showing just one or two
    // additional entries. Therefore we truncate to max. 5 entries only if there are more than 7 in total.
    if (!showAllPlaces && actions.count() > 7) {
        const int totalActionCount = actions.count();

        while (actions.count() > 5) {
            actions.removeLast();
        }

        QAction *action = new QAction(parent);
        action->setIcon(QIcon::fromTheme(QStringLiteral("view-more-symbolic")));
        action->setText(i18ncp("Show all user Places", "%1 more Place…", "%1 more Places…", totalActionCount - actions.count()));
        connect(action, &QAction::triggered, this, &Backend::showAllPlaces);
        actions << QVariant::fromValue(action);
    }

    return actions;
}

QVariantList Backend::recentDocumentActions(const QUrl &launcherUrl, QObject *parent)
{
    QVariantList actions;
    if (!parent) {
        return actions;
    }

    if (m_activityManagerPluginsSettings.whatToRemember() == NoApplications) {
        return actions;
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QVariantList();
    }

    QString desktopName = desktopEntryUrl.fileName();
    QString storageId = desktopName;

    if (storageId.endsWith(QLatin1String(".desktop"))) {
        storageId = storageId.left(storageId.length() - 8);
    }

    auto query = UsedResources | RecentlyUsedFirst | Agent(storageId) | Type::any() | Activity::current();

    ResultSet results(query);

    ResultSet::const_iterator resultIt = results.begin();

    int actionCount = 0;

    bool allFolders = true;
    bool allDownloads = true;
    bool allRemoteWithoutFileName = true;
    const QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);

    while (actionCount < 5 && resultIt != results.end()) {
        const QString mimetype = (*resultIt).mimetype();
        const QUrl url = (*resultIt).url();
        ++resultIt;

        if (!url.isValid()) {
            continue;
        }

        allFolders = allFolders && mimetype == QLatin1String("inode/directory");
        allDownloads = allDownloads && url.toLocalFile().startsWith(downloadsPath);
        allRemoteWithoutFileName = allRemoteWithoutFileName && !url.isLocalFile() && url.fileName().isEmpty();

        QString name;

        if (url.isLocalFile() && !url.fileName().isEmpty()) {
            name = url.fileName();
        } else {
            name = url.toDisplayString();
        }

        QAction *action = new QAction(parent);
        action->setText(name);
        action->setIcon(QIcon::fromTheme(KIO::iconNameForUrl(url)));
        action->setProperty("agent", storageId);
        action->setProperty("entryPath", desktopEntryUrl);
        action->setProperty("mimeType", mimetype);
        action->setData(url);
        connect(action, &QAction::triggered, this, &Backend::handleRecentDocumentAction);

        actions << QVariant::fromValue<QAction *>(action);

        ++actionCount;
    }

    if (actionCount > 0) {
        // Overrides section heading on QML side
        if (allDownloads) {
            actions.prepend(i18n("Recent Downloads"));
        } else if (allRemoteWithoutFileName) {
            actions.prepend(i18n("Recent Connections"));
        } else if (allFolders) {
            actions.prepend(i18n("Recent Places"));
        }

        QAction *separatorAction = new QAction(parent);
        separatorAction->setSeparator(true);
        actions << QVariant::fromValue<QAction *>(separatorAction);

        QAction *action = new QAction(parent);
        if (allDownloads) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Downloads"));
        } else if (allRemoteWithoutFileName) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Connections"));
        } else if (allFolders) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Places"));
        } else {
            action->setText(i18nc("@action:inmenu", "Forget Recent Files"));
        }
        action->setIcon(QIcon::fromTheme(QStringLiteral("edit-clear-history")));
        action->setProperty("agent", storageId);
        connect(action, &QAction::triggered, this, &Backend::handleRecentDocumentAction);
        actions << QVariant::fromValue<QAction *>(action);
    }

    return actions;
}

void Backend::handleRecentDocumentAction() const
{
    const QAction *action = qobject_cast<QAction *>(sender());

    if (!action) {
        return;
    }

    const QString agent = action->property("agent").toString();

    if (agent.isEmpty()) {
        return;
    }

    const QString desktopPath = action->property("entryPath").toUrl().toLocalFile();
    const QUrl url = action->data().toUrl();

    if (desktopPath.isEmpty() || url.isEmpty()) {
        auto query = UsedResources | Agent(agent) | Type::any() | Activity::current();

        KAStats::forgetResources(query);

        return;
    }

    KService::Ptr service = KService::serviceByDesktopPath(desktopPath);

    if (!service) {
        return;
    }

    // prevents using a service file that does not support opening a mime type for a file it created
    // for instance spectacle
    const auto mimetype = action->property("mimeType").toString();
    if (!mimetype.isEmpty() && mimetype != QLatin1String("application/octet-stream")) {
        if (!service->hasMimeType(mimetype)) {
            // needs to find the application that supports this mimetype
            service = KApplicationTrader::preferredService(mimetype);

            if (!service) {
                // no service found to handle the mimetype
                return;
            } else {
                qCWarning(WAVETASK_DEBUG) << "Preventing the file to open with " << service->desktopEntryName() << "no alternative found";
            }
        }
    }

    auto *job = new KIO::ApplicationLauncherJob(service);
    auto *delegate = new KNotificationJobUiDelegate;
    delegate->setAutoErrorHandlingEnabled(true);
    job->setUiDelegate(delegate);
    job->setUrls({url});
    job->start();
}

void Backend::setActionGroup(QAction *action) const
{
    if (action) {
        action->setActionGroup(m_actionGroup);
    }
}

QRect Backend::globalRect(QQuickItem *item) const
{
    if (!item || !item->window()) {
        return QRect();
    }

    QRect iconRect(item->x(), item->y(), item->width(), item->height());
    iconRect.moveTopLeft(item->parentItem()->mapToScene(iconRect.topLeft()).toPoint());
    iconRect.moveTopLeft(item->window()->mapToGlobal(iconRect.topLeft()));

    return iconRect;
}

bool Backend::isApplication(const QUrl &url) const
{
    if (!url.isValid() || !url.isLocalFile()) {
        return false;
    }

    const QString &localPath = url.toLocalFile();

    if (!KDesktopFile::isDesktopFile(localPath)) {
        return false;
    }

    KDesktopFile desktopFile(localPath);
    return desktopFile.hasApplicationType();
}

qint64 Backend::parentPid(qint64 pid) const
{
    KSysGuard::Processes procs;
    procs.updateOrAddProcess(pid);

    KSysGuard::Process *proc = procs.getProcess(pid);
    if (!proc) {
        return -1;
    }

    int parentPid = proc->parentPid();
    if (parentPid != -1) {
        procs.updateOrAddProcess(parentPid);

        KSysGuard::Process *parentProc = procs.getProcess(parentPid);
        if (!parentProc) {
            return -1;
        }

        if (!proc->cGroup().isEmpty() && parentProc->cGroup() == proc->cGroup()) {
            return parentProc->pid();
        }
    }

    return -1;
}

void Backend::setupShortcuts()
{
    static std::once_flag once;
    std::call_once(once, [] {
        auto *collection = new KActionCollection(QCoreApplication::instance(), QStringLiteral("org.vicko.wavetask"));
        collection->setComponentDisplayName(i18n("Wave Task Manager"));

        auto *activatePreviousTaskAction = collection->addAction(QStringLiteral("activate previous task manager entry"));
        QObject::connect(activatePreviousTaskAction, &QAction::triggered, collection, [](bool) {
            dispatchActivatePreviousTask();
        });
        activatePreviousTaskAction->setText(i18n("Activate Previous Task Manager Entry"));
        KGlobalAccel::self()->setGlobalShortcut(activatePreviousTaskAction, QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::Key_PageUp));

        auto *activateNextTaskAction = collection->addAction(QStringLiteral("activate next task manager entry"));
        QObject::connect(activateNextTaskAction, &QAction::triggered, collection, [](bool) {
            dispatchActivateNextTask();
        });
        activateNextTaskAction->setText(i18n("Activate Next Task Manager Entry"));
        KGlobalAccel::self()->setGlobalShortcut(activateNextTaskAction, QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::Key_PageDown));

        auto *moveTaskBackwardAction = collection->addAction(QStringLiteral("move active task to left"));
        QObject::connect(moveTaskBackwardAction, &QAction::triggered, collection, [](bool) {
            dispatchMoveActiveTaskBackward();
        });
        moveTaskBackwardAction->setText(i18n("Move Active Task Manager Entry Backward"));
        KGlobalAccel::self()->setGlobalShortcut(moveTaskBackwardAction,
                                                QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::SHIFT | Qt::Key_PageUp));

        auto *moveTaskForwardAction = collection->addAction(QStringLiteral("move active task to right"));
        QObject::connect(moveTaskForwardAction, &QAction::triggered, collection, [](bool) {
            dispatchMoveActiveTaskForward();
        });
        moveTaskForwardAction->setText(i18n("Move Active Task Manager Entry Forward"));
        KGlobalAccel::self()->setGlobalShortcut(moveTaskForwardAction,
                                                QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::SHIFT | Qt::Key_PageDown));

        for (int i = 0; i < 10; ++i) {
            const int entryNumber = i + 1;
            const auto key = static_cast<Qt::Key>(Qt::Key_0 + (entryNumber % 10));

            QAction *action = collection->addAction(QStringLiteral("activate task manager entry %1").arg(QString::number(entryNumber)));
            action->setText(i18n("Activate Task Manager Entry %1", entryNumber));
            KGlobalAccel::setGlobalShortcut(action, entryNumber < 10 ? QKeySequence(Qt::META | key) : QKeySequence());
            QObject::connect(action, &QAction::triggered, collection, [i](bool) {
                dispatchActivateTaskAtIndex(i);
            });
        }
    });
}

Backend *Backend::findTargetBackend()
{
    // Prefer a bar that shows tasks from all screens so that cycling
    // shortcuts can see the full task list.  Screen-filtered bars are
    // only used as fallback when no full-view bar has the active task.
    // This avoids trapping shortcuts on a screen-filtered bar that may
    // only have a single task to cycle through (e.g. when a grouped app
    // has its only visible child on that screen).

    Backend *fallback = nullptr;

    for (auto *instance : std::as_const(s_instances)) {
        if (!instance->m_hasActiveTask) {
            continue;
        }
        if (!instance->m_showsOnlyCurrentScreen) {
            return instance;
        }
        if (!fallback) {
            fallback = instance;
        }
    }

    return fallback;
}

void Backend::dispatchActivateTaskAtIndex(int index)
{
    // Prefer the same priority order as the other task shortcuts:
    // 1. Non-screen-filtered taskbar with the active task
    // 2. Screen-filtered taskbar with the active task
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activateTaskAtIndexRequested(index);
        return;
    }

    // If no task is active on any taskmanager (e.g. the user wants to
    // launch a pinned app), fallback: prefer a non-screen-filtered
    // instance, then the first available instance.
    Backend *fallback = nullptr;
    for (auto *instance : std::as_const(s_instances)) {
        if (!instance->m_showsOnlyCurrentScreen) {
            Q_EMIT instance->activateTaskAtIndexRequested(index);
            return;
        }
        if (!fallback) {
            fallback = instance;
        }
    }
    if (fallback) {
        Q_EMIT fallback->activateTaskAtIndexRequested(index);
    }
}

void Backend::dispatchActivatePreviousTask()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activatePreviousTaskRequested();
    }
}

void Backend::dispatchActivateNextTask()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activateNextTaskRequested();
    }
}

void Backend::dispatchMoveActiveTaskBackward()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->moveActiveTaskBackwardRequested();
    }
}

void Backend::dispatchMoveActiveTaskForward()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->moveActiveTaskForwardRequested();
    }
}

#include "moc_backend.cpp"
