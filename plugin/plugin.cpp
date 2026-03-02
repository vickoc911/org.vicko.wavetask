#include <QtQml/QQmlExtensionPlugin>

class org_vicko_wavetaskPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        // Qt6 gestionará el registro automático de Backend y Item
        // basándose en el archivo .qmltypes generado.
    }
};

#include "plugin.moc"
