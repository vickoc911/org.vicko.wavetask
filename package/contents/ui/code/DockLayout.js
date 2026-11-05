// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function arrange(taskSizes, widgets, spacing) {
    const taskOffsets = [];
    const widgetOffsets = [];
    let length = 0;
    let count = 0;

    function append(size) {
        if (count > 0) length += spacing;
        const offset = length;
        length += size;
        ++count;
        return offset;
    }

    for (let slot = 0; slot <= taskSizes.length; ++slot) {
        for (let i = 0; i < widgets.length; ++i) {
            if (Math.min(taskSizes.length, Math.max(0, widgets[i].position)) === slot) {
                widgetOffsets[i] = append(widgets[i].size);
            }
        }
        if (slot < taskSizes.length) {
            taskOffsets[slot] = append(taskSizes[slot]);
        }
    }
    return { taskOffsets, widgetOffsets, length };
}
