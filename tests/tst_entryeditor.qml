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
        editor.importDesktop(Qt.resolvedUrl("fixtures/🟩 Local app.desktop"));
        compare(editor.entries.length, 6);
        verify(editor.error.length > 0);
        editor.save(editor.entries.filter(entry => entry.type !== "spacer"));
        compare(editor.entries.length, 5);
        verify(!JSON.parse(editor.cfg_entryLayout).some(entry => entry.type === "spacer"));
    }

    function test_visibleHandleDrag() {
        const editor = createTemporaryObject(editorComponent, testCase,
            {cfg_launchers: ["applications:A.desktop", "applications:B.desktop", "applications:C.desktop"]});
        const list = findChild(editor, "entryEditorList");
        verify(list !== null);
        tryCompare(list, "count", 3);
        waitForRendering(editor);
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
