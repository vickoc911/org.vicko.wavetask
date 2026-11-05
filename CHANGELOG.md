# Changelog

Registro das melhorias recentes de 2026-11-05. Este documento nao substitui o
historico completo do Git e nao atribui uma nova versao ao projeto.

## 1. Resumo das mudancas

- Adicionado editor de entradas com lancadores, comandos manuais, espacadores e separadores.
- Adicionada reordenacao por puxadores visiveis, previa flutuante e indicador de insercao.
- Organizadas as abas de configuracao como Appearance, Entries e Behavior.
- Adicionadas importacao multipla de `.desktop` e recepcao de arquivos no editor.
- Mantido o arraste de `.desktop` para a dock ativa, com prioridade para URLs sobre metadados de widgets.
- Corrigida a abertura de `.desktop` locais fora do catalogo, inclusive com espacos e Unicode.
- Adicionado controle de tamanho do Cairo Penguin entre 25% e 300%, com padrao de 100%.
- Removidos os menus de adicao/gerenciamento de widgets e o aceite de novos widgets na dock.
- Preservados o carregamento e a remocao pelo menu do proprio widget para instancias antigas.
- Corrigida a compatibilidade dos badges e do filtro de areas de trabalho nas APIs do Plasma.
- Adicionados testes de interface, layout, persistencia, lancamento e tamanho do Cairo.
- Documentados dependencias, limpeza, build, instalacao e uso das novas configuracoes.

## 2. Detalhes das funcionalidades e commits

### Referencia do conjunto de alteracoes

As mudancas funcionais acima foram reunidas no commit
[`06fae31` — Add WidgetHost and associated tests for WaveTask](https://github.com/vickoc911/org.vicko.wavetask/commit/06fae313c340783a891d419ca2bbf0315424fbde).
Apesar do titulo destacar o WidgetHost, o diff inclui tambem o editor de entradas,
o feedback de arraste, as correcoes de lancadores, o controle do Cairo e a
documentacao inicial. Nao existem commits separados para cada funcionalidade
desse conjunto.

### Editor de entradas e feedback visual

- Nova aba **Entries**, localizada entre **Appearance** e **Behavior**.
- Aplicativos ja fixados sao incluidos automaticamente na lista.
- Puxadores com cursor de mao permitem reorganizar a lista; botoes de
  subir/descer oferecem um caminho alternativo.
- Durante o arraste, a linha original fica atenuada, uma previa acompanha o
  ponteiro e uma linha colorida mostra a posicao de insercao.
- A ordem muda ao soltar; o editor tambem faz rolagem automatica nas bordas.
- Espacadores reservam espaco vazio; separadores desenham uma linha discreta.
  Ambos permitem ajustar o tamanho de 1 a 256 pixels.
- Comandos manuais possuem nome, comando e icone configuraveis, com edicao e
  remocao posteriores. Argumentos entre aspas sao aceitos; operadores e
  substituicoes de shell nao sao interpretados.
- **Aplicar** salva a configuracao. Cancelar as configuracoes nao altera a dock.
- O layout salvo prevalece sobre a ordenacao da aba Behavior e o arraste direto
  dos botoes de tarefas. Janelas nao fixadas aparecem depois das entradas.
- Entradas manuais sao botoes independentes; arquivos `.desktop` continuam sendo
  o caminho para integracao normal com janelas e agrupamento.

### Arquivos `.desktop` e dock ativa

- O editor importa um ou varios arquivos pelo seletor ou por arraste para a lista.
- O arraste diretamente para a dock ativa continua fixando aplicativos sem abrir
  as configuracoes. Novos lancadores aparecem no final do layout configurado.
- Arrastes contendo URLs nao sao rejeitados apenas por tambem anunciarem o
  formato de widget Plasma; o aceite do drop de URLs e explicito.
- Lancadores locais sao lidos diretamente com KService e executados pelo KIO,
  sem exigir registro no catalogo de aplicativos.
- Caminhos com espacos e Unicode sao suportados. As verificacoes de confianca e
  permissoes do KIO continuam valendo.

### Tamanho do Cairo Penguin

- **Appearance → Cairo Penguin size (%)** permite ajustar o tamanho de 25% a 300%.
- O padrao de 100% preserva o tamanho anterior, equivalente a dois tercos do
  tamanho dos icones da dock.
- O controle so fica habilitado quando o Cairo esta ativado.
- O tamanho acompanha as alteracoes da configuracao e do tamanho dos icones.
- Continua restrito a docks horizontais; tamanhos maiores podem exigir um painel
  mais alto para evitar cortes na animacao.

### Transicao dos widgets para entradas nativas

- Retirados os menus para adicionar widgets, o seletor de adicao e o menu
  **Manage embedded widgets...**.
- Desativada a incorporacao de novos widgets por arraste na WaveTask.
- Preservados widgets existentes, suas configuracoes e o containment interno
  para compatibilidade; nao ha exclusao automatica dessas instancias.
- No modo de edicao do Plasma, o menu de clique direito do proprio widget ainda
  permite configurar, mover ou remover uma instancia antiga.
- Os novos espacadores e separadores do editor sao itens nativos da dock, nao
  widgets Plasma, e participam do calculo de espaco e zoom nas duas orientacoes.

### Compatibilidade, testes e instalacao

- Badge local evita depender de `Kirigami.Badge`, ausente em algumas versoes.
- Bindings selecionam as propriedades disponiveis para filtragem por area de
  trabalho; as acoes usam a API de desktop compativel com a versao instalada.
- Testes cobrem carregamento QML, ordem e persistencia das entradas, puxadores,
  previa e indicador de insercao, salvar/cancelar, importacao, comandos manuais,
  dimensoes do Cairo e deslocamento real dos icones em layouts horizontal e vertical.
- Testes do WidgetHost preservam cobertura de instancias antigas e restauracao
  do containment. Fixtures de execucao utilizam `/usr/bin/true`.
- A instalacao continua incluindo o plugin compilado e os pacotes QML. E preciso
  sair e entrar novamente na sessao para recarregar uma biblioteca ja carregada
  pelo `plasmashell`; WaveTask nao e um executavel independente.
- O [guia de instalacao](INSTALL.md) inclui dependencias para Kubuntu/Ubuntu e
  Fedora, limpeza, build, testes opcionais e instalacao. O [README](README.md)
  descreve os fluxos de uso e suas limitacoes.

O build e as tres suites CTest passaram durante a implementacao. Os testes
automatizados nao equivalem a uma validacao visual completa na sessao Plasma
do usuario.
