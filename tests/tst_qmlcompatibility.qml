import QtQuick
import QtTest
import org.vicko.wavetask as WaveTask
import "../package/contents/ui/code/TaskTools.js" as TaskTools
import "../package/contents/ui/code/DockLayout.js" as DockLayout
import "../package/contents/ui/code/DockEntries.js" as DockEntries
import "../package/contents/ui/code/DragTools.js" as DragTools

TestCase {
    name: "QmlCompatibility"

    Component {
        id: backendComponent
        WaveTask.Backend {}
    }

    function test_launchApplication_unregisteredDesktopFile() {
        const backend = createTemporaryObject(backendComponent, this);
        verify(backend !== null);
        verify(backend.launchApplication(Qt.resolvedUrl("fixtures/🟩 Local app.desktop")));
    }

    function test_debugInformation() {
        const backend = createTemporaryObject(backendComponent, this);
        const info = backend.debugInformation();
        verify(info.operatingSystem.length > 0);
        verify(info.qtVersion.length > 0);
        verify(info.platform.length > 0);
        verify(info.plasmaConfiguration.startsWith("/"));
        verify(info.plasmaConfiguration.endsWith("/plasma-org.kde.plasma.desktop-appletsrc"));
        verify(info.shellConfiguration.endsWith("/plasmashellrc"));
        verify(info.userPackageDirectory.endsWith("/plasma/plasmoids/org.vicko.wavetask"));
        compare(info.loggingCategory, "org.vicko.wavetask");
    }

    function test_components_data() {
        return [
            { tag: "main", file: "main.qml" },
            { tag: "embeddedWidget", file: "EmbeddedWidget.qml" },
            { tag: "entryEditor", file: "ConfigEntries.qml" },
            { tag: "diagnostics", file: "ConfigDiagnostics.qml" },
            { tag: "dockEntry", file: "DockEntry.qml" },
            { tag: "cairoPenguin", file: "CairoPenguin.qml" },
            { tag: "badge", file: "TaskBadge.qml" },
            { tag: "badgeOverlay", file: "TaskBadgeOverlay.qml" },
            { tag: "contextMenu", file: "ContextMenu.qml" },
            { tag: "tooltip", file: "ToolTipInstance.qml" }
        ];
    }

    function test_components(data) {
        const component = Qt.createComponent("../package/contents/ui/" + data.file);
        compare(component.status, Component.Ready, component.errorString());
        component.destroy();
    }

    function test_currentDesktop_legacy() {
        compare(TaskTools.currentDesktopForScreen({ currentDesktop: "desktop-1" }, Qt.rect(0, 0, 1920, 1080)), "desktop-1");
    }

    function test_currentDesktop_perScreen() {
        const geometry = Qt.rect(1920, 0, 1920, 1080);
        const info = {
            currentDesktopByScreenGeometry: function(screen) {
                compare(screen, geometry);
                return "desktop-2";
            }
        };
        compare(TaskTools.currentDesktopForScreen(info, geometry), "desktop-2");
    }

    function test_widgetLayout_data() {
        return [
            { tag: "empty", tasks: [], widgets: [], expectedTasks: [], expectedWidgets: [], length: 0 },
            { tag: "between", tasks: [44, 44], widgets: [{position: 1, size: 18}],
                expectedTasks: [0, 70], expectedWidgets: [48], length: 114 },
            { tag: "zoom", tasks: [88, 66], widgets: [{position: 1, size: 18}],
                expectedTasks: [0, 114], expectedWidgets: [92], length: 180 },
            { tag: "noTasks", tasks: [], widgets: [{position: 5, size: 18}],
                expectedTasks: [], expectedWidgets: [0], length: 18 },
            { tag: "clampAndOrder", tasks: [44], widgets: [{position: 5, size: 18}, {position: 2, size: 24}],
                expectedTasks: [0], expectedWidgets: [48, 70], length: 94 },
            { tag: "before", tasks: [44], widgets: [{position: 0, size: 18}],
                expectedTasks: [22], expectedWidgets: [0], length: 66 }
        ];
    }

    function test_widgetLayout(data) {
        const layout = DockLayout.arrange(data.tasks, data.widgets, 4);
        compare(layout.taskOffsets, data.expectedTasks);
        compare(layout.widgetOffsets, data.expectedWidgets);
        compare(layout.length, data.length);
    }

    function test_entryOrderAndPersistence() {
        compare(DockEntries.launcherUrl("[activity-id]\nfile:///tmp/app.desktop"), "file:///tmp/app.desktop");
        compare(DockEntries.launcherUrl("[activity-id]\\nfile:///tmp/app.desktop"), "file:///tmp/app.desktop");
        compare(DockEntries.launcherUrl("file:///tmp/[folder]/app.desktop"), "file:///tmp/[folder]/app.desktop");
        const entries = [
            {type: "launcher", url: "file:///B.desktop"},
            {type: "separator", size: 12},
            {type: "command", title: "True", command: "/usr/bin/true", icon: "application-x-executable"},
            {type: "spacer", size: 24},
            {type: "launcher", url: "file:///A.desktop"}
        ];
        compare(DockEntries.parse(JSON.stringify(entries)), entries);
        compare(DockEntries.launcherUrls(entries), ["file:///B.desktop", "file:///A.desktop"]);
        const layout = DockEntries.arrange([44, 44, 44], ["file:///A.desktop", "file:///B.desktop", ""],
            entries, [], 44, 4);
        compare(layout.taskOffsets, [140, 0, 188]);
        compare(layout.entryOffsets[1], 48);
        compare(layout.entryOffsets[2], 64);
        compare(layout.entryOffsets[3], 112);
        compare(layout.length, 232);
        const moved = DockEntries.move(entries, 4, 0);
        compare(moved[0].url, "file:///A.desktop");
        compare(entries[0].url, "file:///B.desktop");
        compare(DockEntries.reconcile(entries, ["file:///B.desktop", "file:///C.desktop"])
            .map(entry => entry.type), ["launcher", "separator", "command", "spacer", "launcher"]);
        compare(DockEntries.reconcile([], ["", "  ", "preferred://filemanager", "applications:editor.desktop"])
            .map(entry => entry.url), ["preferred://filemanager", "applications:editor.desktop"]);
    }

    function test_entryValidation() {
        const invalid = ["{}", "[{\"type\":\"widget\"}]", "[{\"type\":\"spacer\",\"size\":0}]",
            "[{\"type\":\"launcher\"}]", "[{\"type\":\"command\",\"title\":\"Empty\"}]"];
        for (const text of invalid) {
            let threw = false;
            try { DockEntries.parse(text); } catch (error) { threw = true; }
            verify(threw, text);
        }

        function test_desktopDropPreserved() {
            verify(!DragTools.isWidgetOnly(["text/uri-list"], true));
            verify(!DragTools.isWidgetOnly(["text/uri-list", "text/x-plasmoidservicename"], true));
            verify(DragTools.isWidgetOnly(["text/x-plasmoidservicename"], false));
            verify(!DragTools.isWidgetOnly(["application/x-orgkdeplasmataskmanager_taskbuttonitem"], false));
            const backend = createTemporaryObject(backendComponent, this);
            verify(backend.isApplication(Qt.resolvedUrl("fixtures/🟩 Local app.desktop")));
        }

        function test_cairoSize_data() {
            return [
                {tag: "minimum", percent: 25, size: 10},
                {tag: "default", percent: 100, size: 40},
                {tag: "double", percent: 200, size: 80},
                {tag: "maximum", percent: 300, size: 120},
                {tag: "clampLow", percent: 0, size: 10},
                {tag: "clampHigh", percent: 500, size: 120}
            ];
        }

        function test_cairoSize(data) {
            const component = Qt.createComponent("../package/contents/ui/CairoPenguin.qml");
            compare(component.status, Component.Ready, component.errorString());
            const penguin = createTemporaryObject(component, this, {iconSize: 60, sizePercent: data.percent});
            verify(penguin !== null);
            compare(penguin.width, data.size);
            compare(penguin.height, data.size);
            compare(penguin.groundOffset, data.size / 4);
            penguin.sizePercent = 150;
            compare(penguin.width, 60);
            compare(penguin.height, 60);
            penguin.iconSize = 90;
            compare(penguin.width, 90);
            component.destroy();
        }
    }

    function test_desktopImportAndManualCommand() {
        const backend = createTemporaryObject(backendComponent, this);
        const entry = backend.desktopEntry(Qt.resolvedUrl("fixtures/🟩 Local app.desktop"));
        compare(entry.type, "launcher");
        verify(entry.url.includes(".desktop"));
        verify(entry.title.length > 0);
        compare(entry.description, "Local app description");
        compare(entry.comment, "Local app comment");
        verify(entry.path.endsWith("/tests/fixtures/🟩 Local app.desktop"));
        const metadata = backend.desktopEntryMetadata(entry.url);
        compare(metadata.url, entry.url);
        compare(metadata.name, "WaveTask local launcher test");
        verify(metadata.path.endsWith("/tests/fixtures/🟩 Local app.desktop"));
        const desktopUrl = Qt.resolvedUrl("fixtures/🟩 Local app.desktop").toString();
        const rawDesktopPath = decodeURIComponent(desktopUrl.slice("file://".length));
        const rawPathMetadata = backend.desktopEntryMetadata(rawDesktopPath);
        compare(rawPathMetadata.name, "WaveTask local launcher test");
        verify(rawPathMetadata.path.endsWith("/tests/fixtures/🟩 Local app.desktop"));
        compare(backend.desktopEntry(rawDesktopPath).title, "WaveTask local launcher test");
        compare(backend.desktopEntryMetadata("preferred://filemanager"), {});
        compare(backend.desktopEntryMetadata(""), {});
        verify(backend.desktopEntryMetadata(Qt.resolvedUrl("fixtures/missing.desktop")).error.length > 0);
        const linkMetadata = backend.desktopEntryMetadata(Qt.resolvedUrl("fixtures/Legacy link.desktop"));
        compare(linkMetadata.name, "Legacy desktop link");
        compare(linkMetadata.description, "Legacy link description");
        compare(linkMetadata.comment, "Legacy link comment");
        verify(linkMetadata.path.endsWith("/tests/fixtures/Legacy link.desktop"));
        compare(linkMetadata.icon, "folder");
        verify(backend.desktopEntry(Qt.resolvedUrl("fixtures/missing.desktop")).error.length > 0);
        compare(backend.validateCommand('/usr/bin/true "argument with spaces"'), "");
        verify(backend.validateCommand('echo hello | cat').length > 0);
        verify(backend.validateCommand('"unterminated').length > 0);
        verify(backend.launchCommand("/usr/bin/true"));
    }
}
