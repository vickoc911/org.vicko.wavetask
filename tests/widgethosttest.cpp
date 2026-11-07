// SPDX-License-Identifier: GPL-2.0-or-later
#include "widgethost.h"

#include <KConfigGroup>
#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <PlasmaQuick/AppletQuickItem>
#include <QQuickWindow>
#include <QAbstractListModel>
#include <algorithm>
#include <QQuickItem>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QQmlProperty>

class TestCorona : public Plasma::Corona
{
public:
    QRect screenGeometry(int) const override { return QRect(0, 0, 1920, 1080); }
};

class DockTasksModel : public QAbstractListModel
{
public:
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : 2; }
    QHash<int, QByteArray> roleNames() const override
    {
        return {{Qt::UserRole, "AppId"}, {Qt::UserRole + 1, "AppName"},
            {Qt::UserRole + 2, "IsLauncher"}, {Qt::UserRole + 3, "IsWindow"},
            {Qt::UserRole + 4, "IsStartup"}, {Qt::UserRole + 5, "LauncherUrlWithoutIcon"},
            {Qt::DisplayRole, "display"}, {Qt::UserRole + 6, "AppPid"},
            {Qt::UserRole + 7, "ChildCount"}, {Qt::DecorationRole, "decoration"},
            {Qt::UserRole + 8, "IsDemandingAttention"}, {Qt::UserRole + 9, "IsActive"},
            {Qt::UserRole + 10, "IsMinimized"}};
    }
    QVariant data(const QModelIndex &index, int role) const override
    {
        switch (role) {
        case Qt::UserRole:
        case Qt::UserRole + 1:
        case Qt::DisplayRole:
            return QStringLiteral("test-app-%1").arg(index.row());
        case Qt::UserRole + 2: return true;
        case Qt::UserRole + 5: return QUrl(QStringLiteral("file:///test-app-%1.desktop").arg(index.row()));
        case Qt::UserRole + 6:
        case Qt::UserRole + 7: return 0;
        case Qt::DecorationRole: return QStringLiteral("application-x-executable");
        default: return false;
        }
    }
};

class WidgetHostTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void nestedWidgets()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        QCoreApplication::setApplicationName(QStringLiteral("wavetask-nested-") + directory.path().section(QLatin1Char('/'), -1));
        TestCorona corona;
        corona.loadLayout(directory.filePath(QStringLiteral("plasma-test-appletsrc")));
        auto *panel = corona.createContainment(QStringLiteral("org.vicko.wavetask.widgets"));
        QVERIFY(panel);
        panel->setFormFactor(Plasma::Types::Horizontal);
        panel->setLocation(Plasma::Types::BottomEdge);
        auto *owner = panel->createApplet(QStringLiteral("org.vicko.wavetask.testwidget"));
        QVERIFY(owner);
        QVERIFY(!owner->failedToLaunch());

        WaveTask::WidgetHost host;
        host.setOwner(owner);
        const auto available = host.availableWidgets();
        bool hasTestWidget = false;
        for (const auto &widget : available) {
            const auto plugin = widget.toMap().value(QStringLiteral("plugin")).toString();
            QVERIFY(plugin != QStringLiteral("org.vicko.wavetask"));
            QVERIFY(plugin != QStringLiteral("org.vicko.wavetask.widgets"));
            if (plugin == QStringLiteral("org.vicko.wavetask.testwidget")) hasTestWidget = true;
        }
        QVERIFY(hasTestWidget);
        QVERIFY(host.entries().isEmpty());
        QVERIFY(host.addWidget(QStringLiteral("org.vicko.wavetask.testwidget"), 1));
        QCOMPARE(host.entries().size(), 1);
        auto entry = host.entries().first().toMap();
        QCOMPARE(entry.value(QStringLiteral("position")).toInt(), 1);
        auto *item = qobject_cast<QQuickItem *>(entry.value(QStringLiteral("item")).value<QObject *>());
        QVERIFY(item);
        QCOMPARE(item->implicitWidth(), 18);
        const uint id = entry.value(QStringLiteral("id")).toUInt();
        const uint containmentId = owner->config().readEntry("WidgetContainmentId", 0u);
        QVERIFY(containmentId != 0);
        Plasma::Containment *nested = nullptr;
        for (auto *containment : corona.containments()) {
            if (containment->id() == containmentId) nested = containment;
        }
        QVERIFY(nested);
        QCOMPARE(nested->parent(), owner);
        QCOMPARE(nested->containmentType(), Plasma::Containment::CustomEmbedded);
        QCOMPARE(nested->formFactor(), Plasma::Types::Horizontal);
        QCOMPARE(nested->location(), Plasma::Types::BottomEdge);

        host.moveWidget(id, 3);
        QCOMPARE(host.entries().first().toMap().value(QStringLiteral("position")).toInt(), 3);

        nested->applets().first()->setStatus(Plasma::Types::NeedsAttentionStatus);
        QVERIFY(host.needsAttention());
        nested->applets().first()->setStatus(Plasma::Types::PassiveStatus);
        QVERIFY(!host.needsAttention());
        panel->setFormFactor(Plasma::Types::Vertical);
        QTRY_COMPARE(nested->formFactor(), Plasma::Types::Vertical);

        host.setOwner(nullptr);
        host.setOwner(owner);
        QCOMPARE(owner->config().readEntry("WidgetContainmentId", 0u), containmentId);
        QCOMPARE(host.entries().size(), 1);
        QCOMPARE(host.entries().first().toMap().value(QStringLiteral("position")).toInt(), 3);

        owner->setImmutability(Plasma::Types::UserImmutable);
        QVERIFY(!host.addWidget(QStringLiteral("org.vicko.wavetask.testwidget"), 0));
        host.moveWidget(id, 0);
        QCOMPARE(host.entries().first().toMap().value(QStringLiteral("position")).toInt(), 3);
        host.removeWidget(id);
        QCOMPARE(host.entries().size(), 1);
        owner->setImmutability(Plasma::Types::Mutable);
        QVERIFY(!host.addWidget(QStringLiteral("org.vicko.wavetask"), 0));
        QVERIFY(!host.addWidget(QStringLiteral("org.vicko.wavetask.widgets"), 0));

        host.removeWidget(id);
        QTRY_VERIFY(host.entries().isEmpty());
        host.setOwner(nullptr);
        QPointer<Plasma::Applet> ownerPointer = owner;
        QPointer<Plasma::Containment> nestedPointer = nested;
        owner->destroy();
        QTRY_VERIFY(ownerPointer.isNull());
        QTRY_VERIFY(nestedPointer.isNull());
    }

    void restoredLayout()
    {
        QTemporaryDir directory;
        QCoreApplication::setApplicationName(QStringLiteral("wavetask-restore-") + directory.path().section(QLatin1Char('/'), -1));
        const QString path = directory.filePath(QStringLiteral("appletsrc"));
        uint ownerId = 0;
        uint nestedId = 0;
        {
            TestCorona corona;
            corona.loadLayout(path);
            auto *panel = corona.createContainment(QStringLiteral("org.vicko.wavetask.widgets"));
            auto *owner = panel->createApplet(QStringLiteral("org.vicko.wavetask.testwidget"));
            QVERIFY(owner);
            ownerId = owner->id();
            WaveTask::WidgetHost host;
            host.setOwner(owner);
            QVERIFY(host.addWidget(QStringLiteral("org.vicko.wavetask.testwidget"), 2));
            nestedId = owner->config().readEntry("WidgetContainmentId", 0u);
            corona.saveLayout(path);
        }
        TestCorona restored;
        restored.loadLayout(path);
        Plasma::Applet *owner = nullptr;
        for (auto *containment : restored.containments()) {
            for (auto *applet : containment->applets()) {
                if (applet->id() == ownerId) owner = applet;
            }
        }
        QVERIFY(owner);
        WaveTask::WidgetHost host;
        host.setOwner(owner);
        QCOMPARE(owner->config().readEntry("WidgetContainmentId", 0u), nestedId);
        QCOMPARE(host.entries().size(), 1);
        QCOMPARE(host.entries().first().toMap().value(QStringLiteral("position")).toInt(), 2);
    }

    void actualDock_data()
    {
        QTest::addColumn<bool>("vertical");
        QTest::newRow("horizontal") << false;
        QTest::newRow("vertical") << true;
    }

    void entryDock_data()
    {
        actualDock_data();
    }

    void entryDock()
    {
        QFETCH(bool, vertical);
        QTemporaryDir directory;
        QCoreApplication::setApplicationName(QStringLiteral("wavetask-entries-") + directory.path().section(QLatin1Char('/'), -1));
        TestCorona corona;
        corona.loadLayout(directory.filePath(QStringLiteral("appletsrc")));
        auto *panel = corona.createContainment(QStringLiteral("org.vicko.wavetask.widgets"));
        panel->setFormFactor(vertical ? Plasma::Types::Vertical : Plasma::Types::Horizontal);
        auto *owner = panel->createApplet(QStringLiteral("org.vicko.wavetask"));
        auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(owner);
        QVERIFY(item);
        QQuickWindow window;
        item->setParentItem(window.contentItem());
        item->setSize(vertical ? QSizeF(86, 600) : QSizeF(600, 86));
        QQmlExpression expression(QQmlEngine::contextForObject(item), item, QStringLiteral("Plasmoid.configuration"));
        auto *config = expression.evaluate().value<QObject *>();
        QVERIFY2(config, qPrintable(expression.error().toString()));
        const QStringList launchers{QStringLiteral("file:///test-app-1.desktop"), QStringLiteral("file:///test-app-0.desktop")};
        QVERIFY(QQmlProperty::write(config, QStringLiteral("launchers"), launchers));
        const QString layout = QStringLiteral("["
            "{\"type\":\"launcher\",\"url\":\"file:///test-app-1.desktop\"},"
            "{\"type\":\"separator\",\"size\":12},"
            "{\"type\":\"spacer\",\"size\":24},"
            "{\"type\":\"command\",\"title\":\"True\",\"command\":\"/usr/bin/true\",\"icon\":\"application-x-executable\"},"
            "{\"type\":\"launcher\",\"url\":\"file:///test-app-0.desktop\"}]");
        QVERIFY(QQmlProperty::write(config, QStringLiteral("entryLayout"), layout));
        auto *repeater = item->property("taskRepeater").value<QObject *>();
        QVERIFY(repeater);
        DockTasksModel model;
        QVERIFY(repeater->setProperty("model", QVariant::fromValue(static_cast<QObject *>(&model))));
        QTRY_COMPARE(repeater->property("count").toInt(), 2);
        auto *list = item->property("taskList").value<QQuickItem *>();
        QVERIFY(list);
        QTest::qWait(50);
        const qreal iconSize = QQmlProperty::read(config, QStringLiteral("iconSize")).toReal();
        QCOMPARE(QQmlProperty::read(config, QStringLiteral("cairoPenguinSize")).toInt(), 100);
        QVERIFY(QQmlProperty::write(config, QStringLiteral("cairoPenguinEnabled"), true));
        if (!vertical) {
            QTRY_VERIFY(item->findChild<QQuickItem *>(QStringLiteral("cairoPenguin")));
            auto *penguin = item->findChild<QQuickItem *>(QStringLiteral("cairoPenguin"));
            QCOMPARE(penguin->width(), iconSize * 2 / 3);
            QVERIFY(QQmlProperty::write(config, QStringLiteral("cairoPenguinSize"), 200));
            QTRY_COMPARE(penguin->width(), iconSize * 2 / 3 * 2);
            QCOMPARE(penguin->height(), penguin->width());
        } else {
            QVERIFY(!item->findChild<QQuickItem *>(QStringLiteral("cairoPenguin")));
        }
        const qreal spacing = list->property("spacing").toReal();
        QCOMPARE(list->property("baseContentSize").toReal(), iconSize * 3 + 12 + 24 + spacing * 4);
        QQuickItem *firstTask = nullptr;
        QQuickItem *secondTask = nullptr;
        for (auto *child : list->childItems()) {
            if (child->property("itemPos").isValid()) {
                if (child->property("index").toInt() == 0) firstTask = child;
                else secondTask = child;
            }
        }
        QVERIFY(firstTask);
        QVERIFY(secondTask);
        QVERIFY(firstTask->property("itemPos").toReal() > secondTask->property("itemPos").toReal());
        QCOMPARE(firstTask->property("itemPos").toReal() - secondTask->property("itemPos").toReal(),
            iconSize * 2 + 12 + 24 + spacing * 4);
        QVERIFY(QQmlProperty::write(config, QStringLiteral("entryLayout"), QStringLiteral("[]")));
        QTRY_COMPARE(list->property("baseContentSize").toReal(), iconSize * 2 + spacing);
        item->setParentItem(nullptr);
    }

    void actualDock()
    {
        QFETCH(bool, vertical);
        QTemporaryDir directory;
        QCoreApplication::setApplicationName(QStringLiteral("wavetask-dock-") + directory.path().section(QLatin1Char('/'), -1));
        TestCorona corona;
        corona.loadLayout(directory.filePath(QStringLiteral("appletsrc")));
        auto *panel = corona.createContainment(QStringLiteral("org.vicko.wavetask.widgets"));
        panel->setFormFactor(vertical ? Plasma::Types::Vertical : Plasma::Types::Horizontal);
        panel->setLocation(Plasma::Types::BottomEdge);
        auto *owner = panel->createApplet(QStringLiteral("org.vicko.wavetask"));
        QVERIFY(owner);
        auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(owner);
        QVERIFY2(item, qPrintable(owner->launchErrorMessage()));
        QVERIFY2(!owner->failedToLaunch(), qPrintable(owner->launchErrorMessage()));
        QQuickWindow window;
        item->setParentItem(window.contentItem());
        item->setSize(vertical ? QSizeF(86, 600) : QSizeF(600, 86));
        window.setGeometry(0, 0, 600, 86);
        QTest::qWait(50);
        auto *repeater = item->property("taskRepeater").value<QObject *>();
        QVERIFY(repeater);
        // Offscreen has no window-system task backend; exercise the real delegates with deterministic rows.
        DockTasksModel model;
        QVERIFY(repeater->setProperty("model", QVariant::fromValue(static_cast<QObject *>(&model))));
        QTRY_COMPARE(repeater->property("count").toInt(), 2);
        auto *list = item->property("taskList").value<QQuickItem *>();
        QVERIFY(list);
        const qreal originalLength = list->property("baseContentSize").toReal();
        const qreal spacing = list->property("spacing").toReal();
        QVERIFY(!item->findChild<QObject *>(QStringLiteral("widgetPicker")));
        bool foundHost = false;
        for (auto *object : item->findChildren<QObject *>()) {
            if (object->inherits("WaveTask::WidgetHost")) {
                foundHost = true;
                bool added = false;
                QVERIFY(QMetaObject::invokeMethod(object, "addWidget", Q_RETURN_ARG(bool, added),
                    Q_ARG(QString, QStringLiteral("org.vicko.wavetask.testwidget")), Q_ARG(int, 1)));
                QVERIFY(added);
                QTRY_COMPARE(object->property("entries").toList().size(), 1);
                QTRY_VERIFY(list->property("baseContentSize").toReal() > originalLength);
                QCOMPARE(list->property("baseContentSize").toReal(), originalLength + 18 + spacing);
                QList<QQuickItem *> tasks;
                for (auto *child : list->childItems()) {
                    if (child->property("itemPos").isValid()) tasks.append(child);
                }
                QCOMPARE(tasks.size(), 2);
                std::sort(tasks.begin(), tasks.end(), [](auto *a, auto *b) {
                    return a->property("index").toInt() < b->property("index").toInt();
                });
                QCOMPARE(tasks[1]->property("itemPos").toReal() - tasks[0]->property("itemPos").toReal(),
                    (vertical ? tasks[0]->height() : tasks[0]->width()) + 18 + spacing * 2);
                QVERIFY(QMetaObject::invokeMethod(item, "showWidgetManager"));
                auto *manager = item->findChild<QObject *>(QStringLiteral("widgetManager"));
                QVERIFY(manager);
                QTRY_VERIFY(manager->property("visible").toBool());
                auto *rows = item->findChild<QObject *>(QStringLiteral("embeddedWidgetRows"));
                QVERIFY(rows);
                QTRY_COMPARE(rows->property("count").toInt(), 1);
                QQuickItem *row = nullptr;
                QVERIFY(QMetaObject::invokeMethod(rows, "itemAt", Q_RETURN_ARG(QQuickItem *, row), Q_ARG(int, 0)));
                QVERIFY(row);
                auto *removeButton = row->findChild<QObject *>(QStringLiteral("removeEmbeddedWidget"));
                QVERIFY(removeButton);
                owner->setImmutability(Plasma::Types::UserImmutable);
                QTRY_VERIFY(!removeButton->property("enabled").toBool());
                QCOMPARE(object->property("entries").toList().size(), 1);
                owner->setImmutability(Plasma::Types::Mutable);
                QTRY_VERIFY(removeButton->property("enabled").toBool());
                QVERIFY(QMetaObject::invokeMethod(removeButton, "clicked"));
                QTRY_VERIFY(object->property("entries").toList().isEmpty());
                QTRY_COMPARE(list->property("baseContentSize").toReal(), originalLength);
                manager->setProperty("visible", false);
                break;
            }
        }
        QVERIFY(foundHost);
        item->setParentItem(nullptr);
    }
};

int main(int argc, char **argv)
{
    QStandardPaths::setTestModeEnabled(true);
    QGuiApplication app(argc, argv);
    WidgetHostTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "widgethosttest.moc"
