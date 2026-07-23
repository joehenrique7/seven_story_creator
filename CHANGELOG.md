## 0.1.18

* O corte no `StoryTrimmerPage` passou a chamar `EasyVideoEditorPlatform.instance.trimVideo()` direto, no lugar do `VideoEditorBuilder`. O `export()` do builder tem um `catch (_) => null` que escondia o motivo real de qualquer falha no corte.
* `PlatformException` do corte agora é logada com `code` e `message` (no Android isso expõe a mensagem do Media3; no iOS o plugin ainda devolve `null` sem detalhe).
* Log de diagnóstico antes do corte com caminho, existência, tamanho do arquivo e a janela `start`/`end` escolhida.
* Removida a cópia intermediária para um `outputPath` próprio — o nativo já devolve o arquivo num diretório temporário, e o `File.copy` do builder era mais um ponto de falha silenciosa.

> Nota: o corte usa `AVAssetExportPresetHighestQuality`, que re-codifica o vídeo. O Simulador do iOS não tem encoder por hardware, então o corte falha lá e funciona no aparelho.

## 0.1.12

* Melhoria de UX: a permissão de fotos deixou de ser solicitada automaticamente ao abrir a câmera de story. Agora o diálogo do sistema só aparece quando o usuário toca no atalho da galeria. A miniatura da galeria só é pré-carregada quando a permissão já foi concedida (via `GalleryService.hasPermission`, que consulta o estado sem disparar o prompt).

## 0.1.5

* Corrigido: fontes selecionadas no editor agora são aplicadas corretamente no texto — nomes genéricos (`Serif`, `Monospace`) foram substituídos por Google Fonts reais, resolvendo o problema de renderização especialmente no iOS.
* Adicionadas 8 opções de fonte via `google_fonts`: Padrão (sistema), Roboto, Playfair Display, Roboto Mono, Oswald, Pacifico, Dancing Script e Bebas Neue.
* A fonte escolhida agora é renderizada corretamente no editor, no canvas e no preview/exportação.

## 0.1.4

* Sincronizado com a tag do Github

## 0.1.3

* Refatoração do editor de texto: nova barra de ferramentas com seleção de fonte, tamanho, alinhamento e sombra.
* Interface do editor traduzida para português (botões Cancelar/Concluir, dica de digitação).
* Ajuste na lógica de publicação do `StoryEditorPage` (botão Publicar).

## 0.1.2

* Adicionado parâmetro `forRoot` em `StoryCreator.open()` para empilhar as telas no navegador raiz — útil em apps com `BottomNavigationBar` ou `NavigationShell`.

## 0.1.1

* Atualizada descrição do package no `pubspec.yaml`.
* Removidos testes desnecessários.

## 0.1.0

* Arquitetura principal implementada:
  * `StoryCreator.open()` — fluxo completo em uma chamada.
  * `StoryCapturePage` — câmera fullscreen com foto, vídeo (pressão longa), flash e câmera frontal/traseira.
  * `StoryEditorPage` — editor canvas em camadas: textos, adesivos emoji, desenho livre, filtros (brilho/contraste/saturação) e histórico de undo (30 passos).
  * `StoryPreviewWidget` — preview read-only 9:16 com auto-play de vídeo.
  * Exportação: foto → `.webp` com overlays compostos; vídeo → `.mp4` comprimido.
  * `StoryEditorController` — `ChangeNotifier` com `addText`, `addSticker`, `addDrawing`, `removeElement`, `undo`.

## 0.0.1

* Versão inicial do package.
