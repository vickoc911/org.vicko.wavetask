import QtQuick
import QtTest
import QtQuick.Controls as QQC2
import "../package/contents/ui" as Dock

TestCase {
    id: testCase
    name: "EntryEditor"
    width: 900
    height: 800
    visible: true
    when: windowShown

    Component {
        id: editorComponent
        Dock.ConfigEntries {
            width: 850
            height: 750
            // Plasma supplies this context function when opening configuration pages.
            function i18n(text, argument) {
                return argument === undefined ? text : text.arg(argument);
            }
        }
    }

    function test_editSaveReloadAndImport() {
        const editor = createTemporaryObject(editorComponent, testCase,
            {cfg_launchers: ["applications:A.desktop", "applications:B.desktop"]});
        verify(editor !== null);
        compare(editor.escapeFilePath("/tmp/a b\tc\n`d$e"), "/tmp/a\\ b\\tc\\n\\`d\\$e");
        const desktopUrl = Qt.resolvedUrl("fixtures/🟩 Local app.desktop").toString();
        const metadataEditor = createTemporaryObject(editorComponent, testCase, {
            cfg_entryLayout: JSON.stringify([{type: "launcher", url: desktopUrl, title: "Stale title",
                path: "/stale/path.desktop"}]),
            cfg_launchers: [desktopUrl]
        });
        compare(metadataEditor.entries, [{type: "launcher", url: desktopUrl}]);
        compare(metadataEditor.desktopMetadata[desktopUrl].title, "WaveTask local launcher test");
        verify(metadataEditor.desktopMetadata[desktopUrl].path.endsWith("/🟩 Local app.desktop"));
        compare(Object.keys(metadataEditor.entries[0]).sort(), ["type", "url"]);
        metadataEditor.save(metadataEditor.entries);
        verify(!metadataEditor.cfg_entryLayout.includes("Stale title"));
        compare(editor.entries.length, 2);
        editor.save(editor.entries.concat([{type: "spacer", size: 24}, {type: "separator", size: 12},
            {type: "command", title: "True", command: "/usr/bin/true", icon: "application-x-executable"}]));
        editor.moveEntry(4, 0);
        compare(editor.entries[0].type, "command");
        compare(editor.cfg_launchers, ["applications:A.desktop", "applications:B.desktop"]);
        const saved = editor.cfg_entryLayout;
        const restored = createTemporaryObject(editorComponent, testCase,
            {cfg_entryLayout: saved, cfg_launchers: editor.cfg_launchers});
        compare(restored.entries, editor.entries);
        editor.importDesktop(Qt.resolvedUrl("fixtures/🟩 Local app.desktop"));
        compare(editor.entries.length, 6);
        compare(editor.entries[5].type, "launcher");
        compare(editor.entries[5], {type: "launcher", url: editor.entries[5].url});
        compare(editor.desktopMetadata[editor.entries[5].url].title, "WaveTask local launcher test");
        compare(editor.entryModel[5].mainLabel, "WaveTask local launcher test");
        compare(editor.entryModel[5].url, editor.entries[5].url);
        compare(editor.entryModel[5].path, editor.desktopMetadata[editor.entries[5].url].path);
        verify(editor.entryModel[5].path.startsWith("/"));
        verify(editor.entryModel[5].path !== editor.entryModel[5].url);
        compare(editor.entryModel[5].altLabel,
            editor.escapeFilePath(editor.entryModel[5].path));
        compare(editor.entryModel[3].mainLabel, "Spacer");
        compare(editor.entryModel[3].altLabel, "");
        compare(editor.entryModel[4].mainLabel, "Separator");
        compare(editor.entryModel[4].altLabel, "");
        const list = findChild(editor, "entryEditorList");
        list.positionViewAtIndex(5, ListView.Contain);
        tryVerify(() => list.itemAtIndex(5) !== null);
        const importedRow = list.itemAtIndex(5);
        compare(findChild(importedRow, "entryTitle").text, "WaveTask local launcher test");
        compare(findChild(importedRow, "entryPath").text,
            editor.escapeFilePath(editor.desktopMetadata[editor.entries[5].url].path));
        verify(findChild(importedRow, "entryPath").text.includes("\\ "));
        verify(editor.desktopMetadata[editor.entries[5].url].path.endsWith("/🟩 Local app.desktop"));
        verify(!editor.desktopMetadata[editor.entries[5].url].path.includes("\\ "));
        for (const index of [3, 4]) {
            list.positionViewAtIndex(index, ListView.Contain);
            const entryRow = list.itemAtIndex(index);
            const title = findChild(entryRow, "entryTitle");
            const secondary = findChild(entryRow, "entryPath");
            compare(title.text, index === 3 ? "Spacer" : "Separator");
            verify(!secondary.visible);
            compare(secondary.text, "");
        }
        editor.importDesktop(Qt.resolvedUrl("fixtures/🟩 Local app.desktop"));
        compare(editor.entries.length, 6);
        verify(editor.error.length > 0);
        editor.save(editor.entries.filter(entry => entry.type !== "spacer"));
        compare(editor.entries.length, 5);
        verify(!JSON.parse(editor.cfg_entryLayout).some(entry => entry.type === "spacer"));
    }

    function test_activityLauncherMetadata_data() {
        return [
            {tag: "newline", separator: "\n"},
            {tag: "escaped-newline", separator: "\\n"}
        ];
    }

    function test_activityLauncherMetadata(data) {
        const url = Qt.resolvedUrl("fixtures/🟩 Local app.desktop").toString();
        const storedUrl = "[9326a42c-37a6-4324-b77c-36945030739c]" + data.separator + url;
        const editor = createTemporaryObject(editorComponent, testCase, {cfg_launchers: [storedUrl]});
        compare(editor.error, "");
        compare(editor.entries[0].url, storedUrl);
        compare(editor.entryModel[0].url, url);
        compare(editor.entryModel[0].mainLabel, "WaveTask local launcher test");
        verify(editor.entryModel[0].path.endsWith("/fixtures/🟩 Local app.desktop"));
        editor.save(editor.entries);
        compare(editor.cfg_launchers, [storedUrl]);
        compare(JSON.parse(editor.cfg_entryLayout)[0].url, storedUrl);
        editor.importDesktop(url);
        compare(editor.entries.length, 1);
        verify(editor.error.length > 0);
    }

    function test_reloadResynchronizesLegacyDesktopMetadata() {
        const url = Qt.resolvedUrl("fixtures/Legacy link.desktop").toString();
        const editor = createTemporaryObject(editorComponent, testCase, {
            cfg_entryLayout: JSON.stringify([{type: "launcher", url: url, title: "Old cached name",
                path: "/old/path.desktop"}]),
            cfg_launchers: [url]
        });
        verify(editor !== null);
        compare(editor.entries, [{type: "launcher", url: url}]);
        compare(editor.desktopMetadata[url].name, "Legacy desktop link");
        compare(editor.desktopMetadata[url].description, "Legacy link description");
        verify(editor.desktopMetadata[url].path.endsWith("/fixtures/Legacy link.desktop"));
        editor.desktopMetadata = ({[url]: {name: "Stale value", path: "/stale/path.desktop"}});
        editor.reload();
        compare(editor.desktopMetadata[url].name, "Legacy desktop link");
        verify(editor.desktopMetadata[url].path.endsWith("/fixtures/Legacy link.desktop"));
    }

    function test_reloadReportsMissingDesktopMetadata() {
        const url = Qt.resolvedUrl("fixtures/missing.desktop").toString();
        const editor = createTemporaryObject(editorComponent, testCase, {
            cfg_entryLayout: JSON.stringify([{type: "launcher", url: url}]),
            cfg_launchers: [url]
        });
        verify(editor.error.length > 0);
        verify(editor.error.includes("missing.desktop"));
        compare(editor.desktopMetadata[url], undefined);
        compare(editor.entryModel[0].url, url);
        compare(editor.entryModel[0].path, "");
    }

    function test_reloadKeepsSpecialLaunchersWithoutDesktopErrors() {
        const editor = createTemporaryObject(editorComponent, testCase, {
            cfg_launchers: ["", "preferred://filemanager", "preferred://browser"]
        });
        compare(editor.entries.map(entry => entry.url),
            ["preferred://filemanager", "preferred://browser"]);
        compare(editor.error, "");
        compare(editor.entryModel.map(entry => entry.url),
            ["preferred://filemanager", "preferred://browser"]);
        compare(Object.keys(editor.desktopMetadata), []);
    }

    function test_visibleHandleDrag() {
        const editor = createTemporaryObject(editorComponent, testCase,
            {cfg_launchers: ["applications:A.desktop", "applications:B.desktop", "applications:C.desktop"]});
        const list = findChild(editor, "entryEditorList");
        verify(list !== null);
        tryCompare(list, "count", 3);
        waitForRendering(editor);
        const initialListHeight = list.height;
        editor.height -= 100;
        tryVerify(() => list.height < initialListHeight);
        verify(list.height > 0);
        const first = list.itemAtIndex(0);
        verify(first !== null);
        const handle = findChild(first, "entryDragHandle");
        verify(handle !== null);
        verify(handle.visible);
        const preview = findChild(list, "entryDragPreview");
        verify(preview !== null);
        const marker = findChild(list.contentItem, "entryInsertionMarker");
        verify(marker !== null);
        verify(!preview.visible);
        mousePress(handle, handle.width / 2, handle.height / 2);
        tryCompare(preview, "visible", true);
        compare(first.opacity, 0.65);
        verify(!marker.visible);
        const startY = preview.y;
        mouseMove(handle, handle.width / 2, handle.height / 2 + (first.height + list.spacing) * 2, 50);
        tryCompare(list, "dragDestination", 2);
        verify(marker.visible);
        verify(preview.y > startY);
        const last = list.itemAtIndex(2);
        compare(marker.y, last.y + last.height);
        compare(editor.cfg_launchers, ["applications:A.desktop", "applications:B.desktop", "applications:C.desktop"]);
        mouseRelease(handle, handle.width / 2, handle.height / 2 + (first.height + list.spacing) * 2);
        tryVerify(() => editor.entries[2].url === "applications:A.desktop");
        compare(editor.cfg_launchers, ["applications:B.desktop", "applications:C.desktop", "applications:A.desktop"]);
        verify(!preview.visible);
        verify(!marker.visible);

        const lastHandle = findChild(list.itemAtIndex(2), "entryDragHandle");
        mousePress(lastHandle, lastHandle.width / 2, lastHandle.height / 2);
        mouseMove(lastHandle, lastHandle.width / 2,
            lastHandle.height / 2 - (last.height + list.spacing) * 2, 50);
        tryCompare(list, "dragDestination", 0);
        verify(marker.visible);
        compare(marker.y, list.itemAtIndex(0).y);
        mouseRelease(lastHandle, lastHandle.width / 2,
            lastHandle.height / 2 - (last.height + list.spacing) * 2);
        tryCompare(editor, "cfg_launchers", ["applications:A.desktop", "applications:B.desktop", "applications:C.desktop"]);
        verify(!preview.visible);
        verify(!marker.visible);
    }

    function test_manualEntryDialogAndCancel() {
        const editor = createTemporaryObject(editorComponent, testCase, {cfg_launchers: []});
        const add = findChild(editor, "addManualEntry");
        verify(add !== null);
        add.clicked();
        const dialog = findChild(editor, "manualEntryDialog");
        verify(dialog !== null);
        tryCompare(dialog, "visible", true);
        const name = findChild(editor, "manualEntryName");
        const command = findChild(editor, "manualEntryCommand");
        const save = dialog.standardButton(QQC2.Dialog.Save);
        verify(!save.enabled);
        name.text = "True";
        command.text = "echo hello | cat";
        verify(!save.enabled);
        command.text = "/usr/bin/true";
        tryCompare(save, "enabled", true);
        mouseClick(save);
        tryCompare(dialog, "visible", false);
        compare(editor.entries.length, 1);
        compare(editor.entries[0].command, "/usr/bin/true");
        const original = editor.cfg_entryLayout;
        add.clicked();
        name.text = "Cancelled";
        command.text = "/usr/bin/true";
        dialog.reject();
        compare(editor.cfg_entryLayout, original);
    }
}
