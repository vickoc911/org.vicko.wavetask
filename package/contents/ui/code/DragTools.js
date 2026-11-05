// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function isWidgetOnly(formats, hasUrls) {
    return !hasUrls && formats.indexOf("text/x-plasmoidservicename") >= 0;
}
