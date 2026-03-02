var panel = new Panel();
panel.location = "bottom";
panel.height = 76;

// --- AJUSTE DE CONTENIDO ---
panel.lengthMode = 1; // FitContent
panel.minimumLength = 0;
panel.maximumLength = 0;
panel.alignment = "center";
panel.hiding = "dodgewindows";

// --- ELIMINAR EL SVG DE FONDO (Transparencia Real) ---
// El valor 4 desactiva el renderizado del fondo del tema (BackgroundSvg)
panel.writeConfig("backgroundHints", 4);
panel.writeConfig("userBackgroundHints", 4);
panel.writeConfig("opacityMode", 1); // Forzado de opacidad
panel.writeConfig("floating", 0);    // Desactiva el flotado para evitar que el shadow del SVG aparezca

// --- LIMPIEZA DE WIDGETS POR DEFECTO ---
// Si hay un spacer, el panel se estira y el SVG se redibuja.
var currentWidgets = panel.widgets();
for (var i = 0; i < currentWidgets.length; i++) {
    currentWidgets[i].remove();
}

// Añadimos solo el gestor de tareas (IconTasks)
panel.addWidget("org.vicko.wavetask");

// --- FORZADO DE RECARGA ---
panel.reloadConfig();
