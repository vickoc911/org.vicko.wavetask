# -------------------------------------------------
# 1. ECM y Configuración
# -------------------------------------------------
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(ECMQtDeclareLoggingCategory)
include(KDEInstallDirs)


find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml Quick Widgets)

find_package(KF6 REQUIRED COMPONENTS
    CoreAddons
    I18n
    Service
    WindowSystem
    Config        # Para KF6::ConfigCore
    ConfigWidgets # Para KF6::ConfigWidgets
    Notifications
    KIO
    Bookmarks
)

# Workspace libs
find_package(Plasma REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(LibNotificationManager REQUIRED)
find_package(KSysGuard REQUIRED)

# -------------------------------------------------
# 3. Fuentes (Incluyendo plugin.cpp manual)
# -------------------------------------------------
set(wavetask_source
    plugin.cpp
    backend.cpp
    backend.h
    smartlauncherbackend.cpp
    smartlauncherbackend.h
    smartlauncheritem.cpp
    smartlauncheritem.h
)

ecm_qt_declare_logging_category(wavetask_LOG_SRCS
    HEADER log_settings.h
    IDENTIFIER WAVETASK_DEBUG
    CATEGORY_NAME org.vicko.wavetask
    DESCRIPTION "WaveTask plugin"
)

# -------------------------------------------------
# 4. QML Module (Target Manual)
# -------------------------------------------------
qt_policy(SET QTP0001 NEW)

# -------------------------------------------------
# Generación de archivos KCFG
# -------------------------------------------------

kconfig_add_kcfg_files(wavetask_source
    kactivitymanagerd_plugins_settings.kcfgc
)
# Creamos la librería y activamos AUTOMOC para el plugin.cpp
add_library(wavetask SHARED ${wavetask_source} ${wavetask_LOG_SRCS})
set_target_properties(wavetask PROPERTIES
    AUTOMOC ON
    AUTOUIC ON
    AUTORCC ON
)

# Módulo QML básico para generar qmldir y qmltypes
qt_add_qml_module(wavetask
    URI org.vicko.wavetask
    VERSION 1.0
)

# -------------------------------------------------
# 5. Propiedades y Enlaces (Linker)
# -------------------------------------------------
set_target_properties(wavetask PROPERTIES
    OUTPUT_NAME "wavetaskplugin"
    PREFIX "lib"
)

target_include_directories(wavetask PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(wavetask
    PRIVATE
        Qt6::Core Qt6::DBus Qt6::Qml Qt6::Quick Qt6::Widgets
        KF6::CoreAddons KF6::I18n KF6::Service KF6::WindowSystem
        KF6::ConfigCore
        KF6::ConfigWidgets
        KF6::Notifications
        KF6::KIOCore KF6::KIOGui KF6::KIOFileWidgets KF6::Bookmarks
        Plasma::Plasma Plasma::Activities Plasma::ActivitiesStats
        PW::LibTaskManager PW::LibNotificationManager
        KSysGuard::ProcessCore
)

# -------------------------------------------------
# 6. Instalación
# -------------------------------------------------
install(TARGETS wavetask DESTINATION ${KDE_INSTALL_QMLDIR}/org/vicko/wavetask)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/wavetask.qmltypes
    DESTINATION ${KDE_INSTALL_QMLDIR}/org/vicko/wavetask
)
