find_package(Qt6 REQUIRED COMPONENTS Test)
find_package(PlasmaQuick REQUIRED)
find_package(KF6Config REQUIRED)

set(test_data "${CMAKE_CURRENT_BINARY_DIR}/data")
set(test_applets "${test_data}/plasma/plasmoids")
file(MAKE_DIRECTORY "${test_applets}")
file(CREATE_LINK "${CMAKE_SOURCE_DIR}/widget-containment"
    "${test_applets}/org.vicko.wavetask.widgets" SYMBOLIC)
file(CREATE_LINK "${CMAKE_SOURCE_DIR}/package"
    "${test_applets}/org.vicko.wavetask" SYMBOLIC)
file(CREATE_LINK "${CMAKE_CURRENT_SOURCE_DIR}/fixtures/test-widget"
    "${test_applets}/org.vicko.wavetask.testwidget" SYMBOLIC)

set(test_imports "${CMAKE_CURRENT_BINARY_DIR}/imports")
file(MAKE_DIRECTORY "${test_imports}/org/vicko/wavetask")
file(CREATE_LINK "${CMAKE_BINARY_DIR}/plugin/qmldir"
    "${test_imports}/org/vicko/wavetask/qmldir" SYMBOLIC)
file(CREATE_LINK "${CMAKE_BINARY_DIR}/bin/libwavetaskplugin.so"
    "${test_imports}/org/vicko/wavetask/libwavetaskplugin.so" SYMBOLIC)

add_executable(widgethosttest widgethosttest.cpp
    "${CMAKE_SOURCE_DIR}/plugin/widgethost.cpp"
    "${CMAKE_SOURCE_DIR}/plugin/widgethost.h"
    "${CMAKE_BINARY_DIR}/plugin/log_settings.cpp")
target_include_directories(widgethosttest PRIVATE
    "${CMAKE_SOURCE_DIR}/plugin" "${CMAKE_BINARY_DIR}/plugin")
target_link_libraries(widgethosttest PRIVATE Qt6::Test Qt6::Quick
    Plasma::Plasma Plasma::PlasmaQuick KF6::ConfigCore KF6::ConfigQml KF6::I18n)
add_test(NAME widgethost COMMAND widgethosttest)
set_tests_properties(widgethost PROPERTIES ENVIRONMENT
    "QT_QPA_PLATFORM=offscreen;XDG_DATA_DIRS=${test_data}:/usr/local/share:/usr/share;QML_IMPORT_PATH=${test_imports};DBUS_SESSION_BUS_ADDRESS=unix:path=${CMAKE_CURRENT_BINARY_DIR}/no-session-bus"
    TIMEOUT 60)

find_program(QMLTESTRUNNER NAMES qmltestrunner qmltestrunner6
    HINTS "${QT6_INSTALL_PREFIX}/lib/qt6/bin" /usr/lib/qt6/bin /usr/lib64/qt6/bin)
if(QMLTESTRUNNER)
    add_test(NAME qmlcompatibility
        COMMAND "${QMLTESTRUNNER}" -import "${test_imports}" -input "${CMAKE_CURRENT_SOURCE_DIR}")
    set_tests_properties(qmlcompatibility PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;DBUS_SESSION_BUS_ADDRESS=unix:path=${CMAKE_CURRENT_BINARY_DIR}/no-session-bus"
        TIMEOUT 60)
endif()
