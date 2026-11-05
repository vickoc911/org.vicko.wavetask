# Compilar e instalar o WaveTask

Este guia descreve a compilacao a partir do codigo-fonte em sistemas com KDE
Plasma 6. Os comandos de pacotes abaixo cobrem Kubuntu/Ubuntu e Fedora. A versao
do Plasma e as bibliotecas de desenvolvimento instaladas precisam ser
compativeis entre si.

O [CHANGELOG.md](CHANGELOG.md) registra as mudancas em duas secoes: resumo de
uma linha por mudanca e detalhes das funcionalidades com referencias aos commits.

## Kubuntu e Ubuntu

Instale as ferramentas de compilacao e as dependencias de desenvolvimento:

```sh
sudo apt update
sudo apt install build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  qml6-module-qtquick-dialogs \
  libkf6coreaddons-dev libkf6i18n-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6configwidgets-dev \
  libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev \
  libkf6globalaccel-dev libkf6xmlgui-dev \
  libplasma-dev libplasmaactivities-dev libplasmaactivitiesstats-dev \
  libksysguard-dev kwin-dev plasma-workspace-dev
```

## Fedora

```sh
sudo dnf install gcc-c++ cmake extra-cmake-modules \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kservice-devel \
  kf6-kwindowsystem-devel kf6-kconfig-devel kf6-kconfigwidgets-devel \
  kf6-knotifications-devel kf6-kio-devel kf6-kglobalaccel-devel \
  kf6-kxmlgui-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  plasma-workspace-devel libksysguard-devel kwin-devel
```

## Limpar e compilar

Na raiz do repositorio, remova a pasta de build anterior se quiser iniciar uma
configuracao limpa. Este comando apaga somente a pasta local `build/`:

```sh
rm -rf build
```

Configure e compile em modo Release:

```sh
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build build --parallel "$(nproc)"
```

Para validar os QML, opcionalmente rode:

```sh
cmake --build build --target all_qmllint
```

O alvo acima verifica apenas o modulo C++/QML gerado, nao toda a interface do
applet. Para testar o editor, o arraste pelos puxadores, a ordem das entradas,
o deslocamento dos icones nas duas orientacoes, o tamanho do Cairo e os widgets
antigos, habilite os
testes e execute:

```sh
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --parallel "$(nproc)"
ctest --test-dir build --output-on-failure
```

Os testes requerem Qt Test e `qmltestrunner` do Qt 6. No Kubuntu/Ubuntu, instale
`qml6-module-qttest qt6-declarative-dev-tools`. O CTest usa o plugin recem-compilado
e pacotes de teste locais, sem precisar instalar como root. O teste de launcher
usa um arquivo local que executa somente `/usr/bin/true`.

## Instalar

Instale nos caminhos de sistema configurados pelo KDE:

```sh
sudo cmake --install build
```

Esse comando instala tambem o containment interno `org.vicko.wavetask.widgets`,
mantido para carregar/remover widgets incorporados anteriormente. Nao copie apenas a
biblioteca do plugin.

Depois, saia e entre novamente na sessao Plasma para garantir que o shell carregue
a versao instalada do plugin. Em seguida, adicione o painel WaveTask pelo modo
de edicao do Plasma. O README contem as instrucoes para configurar o painel.

## Tamanho do Cairo

Na aba **Appearance**, a opcao **Cairo Penguin size (%)** ajusta o tamanho do
Cairo de 25% a 300%, quando ele esta habilitado. O padrao de 100% preserva o
tamanho anterior: dois tercos do tamanho dos icones. Clique em **Aplicar** para
salvar; o controle fica desabilitado enquanto o Cairo estiver desligado.
Para tamanhos grandes, aumente a
altura do painel se a animacao ficar cortada. O Cairo continua disponivel apenas
na dock horizontal.

## Editor de entradas: ordem, espacadores e separadores

1. Abra as configuracoes da WaveTask e entre na aba **Entries** (Entradas).
   Ela fica depois de **Appearance** e antes de **Behavior**.
   Os aplicativos ja fixados aparecem automaticamente.
2. Arraste o puxador visivel de uma linha para outra para reorganizar. Os
   botoes de subir/descer tambem estao disponiveis. Durante o arraste, uma
   previa acompanha o ponteiro e uma linha destaca a posicao de insercao.
3. Use **Spacer** para espaco vazio ou **Separator** para uma linha discreta.
   Ajuste o espaco reservado de 1 a 256 pixels na propria linha.
4. Use **Manual entry** para informar nome, comando e icone (nome do tema ou
   caminho de imagem). O comando aceita argumentos entre aspas, mas nao
   operadores de shell, pipes ou substituicoes. O botao de editar altera esses
   dados depois.
5. Use **Import .desktop** para selecionar um ou varios arquivos, ou arraste
   arquivos `.desktop` para a lista. Caminhos locais com espacos e Unicode
   tambem sao aceitos; nao precisam estar no catalogo de aplicativos.
6. O botao de lixeira remove a entrada. Clique em **Aplicar** para salvar.
   Cancelar as configuracoes nao modifica a dock.

Tambem continua sendo possivel arrastar arquivos `.desktop` diretamente para a
dock ativa para fixar aplicativos, sem abrir as configuracoes. Com um layout
salvo, novas entradas aparecem no final da lista e podem ser reorganizadas no
editor. Somente o arraste para incorporar widgets Plasma foi desativado.

A ordem salva no editor prevalece sobre a ordenacao da aba Behavior e o arraste
direto dos botoes de tarefas. Janelas nao fixadas aparecem depois das entradas.
Espacadores e separadores reservam espaco horizontal/vertical, inclusive durante
o zoom, sem criar widgets Plasma.

Entradas manuais sao botoes de execucao independentes. Para a integracao normal
com janelas, agrupamento e menus de aplicativos, prefira arquivos `.desktop`.

## Remover widgets antigos

Os menus de adicao de widgets e o aceite de arraste para incorpora-los foram
retirados, assim como o menu **Manage embedded widgets...**. Widgets ja existentes
nao sao apagados. Para remove-los, desbloqueie os widgets no modo de edicao do
Plasma e clique com o botao direito no proprio widget, depois **Remove widget**.

## Resolver problemas de configuracao

Se o CMake nao encontrar uma biblioteca, confirme que os pacotes de
desenvolvimento correspondem a versao do Plasma instalada. Para reconfigurar do
zero, remova `build/` e repita os comandos de compilacao acima.

Launchers `.desktop` locais podem ficar fora de `~/.local/share/applications/`;
a dock le o arquivo diretamente. O KIO continua verificando a confianca e as
permissoes do launcher. Somente para arquivos que voce conhece e confia, marque
o arquivo como executavel nas propriedades do gerenciador de arquivos.
