## 0.1.24

* Correção do crash `PlatformException(FLASH_UNSUPPORTED, can't set flash for portrait mode)` no iOS (Crashlytics, issue `02936ace`). Ao virar para a câmera frontal com o flash ligado, o `switchCameraSensor` repassava o modo de flash à frontal, que não tem flash. A frontal agora entra com `FlashMode.none`, o ciclo do flash não é aplicado nela, e as falhas da troca de câmera e do flash deixaram de derrubar o app.

## 0.1.23

* O canvas do editor passou a ser um quadro fixo 9:16 encostado no topo, em vez da tela inteira. Uma imagem 1080×1920 aparece inteira, sem cortar as laterais em telas mais altas que 9:16.
* A foto exportada sai sempre em 1080×1920: o `pixelRatio` da captura é calculado a partir da largura do quadro, no lugar do valor fixo 2.5.

## 0.1.22

* Correção do crash `type 'StoryMedia' is not a subtype of type 'File?' of 'result'` (Crashlytics, issue `eeebe7de`). A captura é assíncrona: um segundo toque no botão resolvia depois que o primeiro já havia fechado a `StoryCapturePage`, e o `pop` caía na rota seguinte — a do editor, tipada `File?`.
* `StoryCapturePage` só devolve o resultado enquanto ainda é a rota do topo (`ModalRoute.isCurrent`) e uma única vez por sessão de captura. Vale também para os dois retornos vindos da galeria (com e sem corte).

## 0.1.19

* A galeria do story deixou de mostrar só o álbum "Recentes". O `GalleryService.fetchAlbums()` não usa mais `onlyAll: true` — devolve todos os álbuns e coleções do aparelho, com "Recentes" sempre em primeiro.
* A bottom sheet da galeria ganhou seletor de álbum no topo (nome do álbum + seta), listando cada coleção com miniatura e contagem de itens.
* Acesso limitado (iOS e Android 14+): quando o usuário liberou só algumas fotos, aparece um aviso com o botão "Gerenciar", que abre o seletor do sistema (`PhotoManager.presentLimited()`) e recarrega a galeria.
* A miniatura da galeria na câmera usa `fetchRecentAlbum()`, que continua consultando só o álbum "Recentes" — sem varrer as coleções do usuário à toa.

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
