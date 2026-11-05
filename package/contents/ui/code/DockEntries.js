// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function parse(text) {
    const entries = JSON.parse(text || "[]");
    if (!Array.isArray(entries)) throw new Error("Entry layout must be a list.");
    for (const entry of entries) {
        if (!entry || !["launcher", "command", "spacer", "separator"].includes(entry.type))
            throw new Error("Unknown dock entry type.");
        if (entry.type === "launcher" && (!entry.url || typeof entry.url !== "string"))
            throw new Error("A launcher must have a URL.");
        if (entry.type === "command" && (typeof entry.title !== "string" || !entry.title.trim()
            || typeof entry.command !== "string" || !entry.command.trim()))
            throw new Error("A manual entry must have a name and command.");
        if (["spacer", "separator"].includes(entry.type)
            && (!Number.isFinite(entry.size) || entry.size < 1 || entry.size > 256))
            throw new Error("Entry size must be between 1 and 256 pixels.");
    }
    return entries;
}

function reconcile(entries, launchers) {
    const result = [];
    const seen = new Set();
    for (const entry of entries) {
        if (entry.type !== "launcher") result.push(entry);
        else if (launchers.includes(entry.url) && !seen.has(entry.url)) {
            result.push(entry);
            seen.add(entry.url);
        }
    }
    for (const url of launchers) {
        if (!seen.has(url)) {
            result.push({type: "launcher", url: url});
            seen.add(url);
        }
    }
    return result;
}

function launcherUrls(entries) {
    return entries.filter(entry => entry.type === "launcher").map(entry => entry.url);
}

function move(entries, from, to) {
    const result = entries.slice();
    if (from < 0 || to < 0 || from >= result.length || to >= result.length)
        throw new Error("Entry move indices are outside the list.");
    result.splice(to, 0, result.splice(from, 1)[0]);
    return result;
}

function arrange(taskSizes, taskUrls, entries, widgets, iconSize, spacing) {
    const taskOffsets = [];
    const entryOffsets = [];
    const widgetOffsets = [];
    const used = new Set();
    let length = 0;
    let count = 0;
    function append(size) {
        if (count++) length += spacing;
        const offset = length;
        length += size;
        return offset;
    }
    function appendTask(index) {
        for (let w = 0; w < widgets.length; ++w) {
            if (Math.min(taskSizes.length, Math.max(0, widgets[w].position)) === index
                && widgetOffsets[w] === undefined) widgetOffsets[w] = append(widgets[w].size);
        }
        taskOffsets[index] = append(taskSizes[index]);
        used.add(index);
    }
    for (let e = 0; e < entries.length; ++e) {
        const entry = entries[e];
        if (entry.type === "launcher") {
            for (let t = 0; t < taskSizes.length; ++t) {
                if (!used.has(t) && taskUrls[t] === entry.url) appendTask(t);
            }
        } else {
            entryOffsets[e] = append(entry.type === "command" ? iconSize : entry.size);
        }
    }
    for (let t = 0; t < taskSizes.length; ++t) {
        if (!used.has(t)) appendTask(t);
    }
    for (let w = 0; w < widgets.length; ++w) {
        if (widgetOffsets[w] === undefined) widgetOffsets[w] = append(widgets[w].size);
    }
    return {taskOffsets, entryOffsets, widgetOffsets, length};
}
