# seven_story_creator

Flutter package para criação de stories no estilo Instagram: captura ou seleciona mídia da galeria, edita com textos, adesivos e desenho livre, aplica filtros de cor, e exporta para um arquivo comprimido pronto para salvar e publicar.

## Features

- **Captura** — câmera fullscreen com foto e vídeo (pressão longa para gravar, barra de progresso, flash, câmera frontal/traseira)
- **Galeria** — selecionar foto ou vídeo existente
- **Editor** — canvas em camadas com:
  - Textos (cor, tamanho, fonte, sombra, alinhamento) — arrastar, escalar, rotar, duplo toque para editar
  - Adesivos emoji — arrastar, escalar, rotar
  - Desenho livre (cor, espessura)
  - Histórico de undo (30 passos)
- **Filtros** — brilho, contraste e saturação via `ColorFiltered`
- **Preview** — `StoryPreviewWidget` read-only em 9:16 com auto-play de vídeo
- **Export** — foto comprimida para `.webp` (todos os overlays compostos na imagem); vídeo comprimido para `.mp4`

## Instalação

```yaml
dependencies:
  seven_story_creator:
    path: ../seven_story_creator  # ajuste para o seu path ou pub server
```

## Permissões

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>A câmera é usada para capturar stories.</string>
<key>NSMicrophoneUsageDescription</key>
<string>O microfone é usado para gravar vídeos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>A galeria é usada para selecionar mídia para stories.</string>
```

---

## Como usar

### Forma recomendada — fluxo completo em uma linha

`StoryCreator.open()` gerencia tudo: abre a câmera, ao capturar/selecionar uma mídia abre automaticamente o editor, e quando o usuário tocar em **Concluir** devolve o `File` exportado. Retorna `null` se o usuário cancelar em qualquer etapa.

```dart
import 'package:seven_story_creator/seven_story_creator.dart';

Future<void> _criarStory(BuildContext context) async {
  final File? file = await StoryCreator.open(context);

  if (file == null) return; // usuário cancelou

  // Aqui você salva e publica
  await uploadStory(file);
}
```

É só isso. O package cuida de toda a navegação, edição e exportação.

#### Usando `forRoot: true` (navegador raiz)

Se o app usa navegadores aninhados — por exemplo um `BottomNavigationBar` ou `NavigationShell` — as telas do story seriam empilhadas dentro do tab atual e não cobririam a barra de navegação. Passe `forRoot: true` para usar o navegador raiz e exibir o story em tela cheia:

```dart
final File? file = await StoryCreator.open(context, forRoot: true);
```

---

### Fluxo manual (opcional)

Se precisar controlar cada etapa individualmente:

#### 1 — Capturar mídia

```dart
final StoryMedia? media = await Navigator.of(context).push<StoryMedia?>(
  MaterialPageRoute(builder: (_) => const StoryCapturePage()),
);
if (media == null) return; // cancelou
```

#### 2 — Editar e exportar

```dart
final File? file = await Navigator.of(context).push<File?>(
  MaterialPageRoute(builder: (_) => StoryEditorPage(media: media)),
);
if (file == null) return; // cancelou
```

#### 3 — Usar o arquivo

```dart
await uploadStory(file);
```

---

### Editor — gestos na canvas

| Gesto | Ação |
|---|---|
| Toque em elemento | Seleciona |
| Arrastar | Move |
| Pinch (dois dedos) | Escala e rotaciona |
| Duplo toque em texto | Abre editor de texto |
| Pressão longa | Remove elemento |

### Editor — barra de ferramentas

| Botão | Função |
|---|---|
| **Texto** | Abre editor de texto; confirme para adicionar na canvas |
| **Adesivo** | Abre seletor de emojis |
| **Desenhar** | Ativa modo pincel (toque novamente para desativar) |
| **Filtro** | Exibe sliders de brilho, contraste e saturação |
| **Desfazer** (↩) | Desfaz a última ação |
| **Concluir** | Exporta e retorna o arquivo |

---

### Preview read-only

Use `StoryPreviewWidget` para exibir um story já publicado (por exemplo durante a reprodução):

```dart
StoryPreviewWidget(
  media: media,
  elements: elements,   // List<StoryElement>
  brightness: 0.1,
  contrast: 1.2,
  saturation: 1.1,
)
```

---

### Controle avançado dos elementos (opcional)

Se precisar adicionar ou manipular elementos programaticamente:

```dart
final controller = StoryEditorController();

// Texto
controller.addText(TextElement(
  id: const Uuid().v4(),
  position: const Offset(0.3, 0.2), // fracional 0.0–1.0
  text: 'Bom jogo!',
  color: Colors.white,
  fontSize: 32,
  hasShadow: true,
));

// Adesivo
controller.addSticker(StickerElement(
  id: const Uuid().v4(),
  position: const Offset(0.5, 0.5),
  emoji: '🏆',
));

// Desfazer
controller.undo();
```

---

## API

| Classe | Descrição |
|---|---|
| `StoryCreator` | Entry point — `open(context, {forRoot})` executa o fluxo completo e retorna `File?`; `forRoot: true` usa o navegador raiz |
| `StoryCapturePage` | Tela de captura; retorna `StoryMedia?` |
| `StoryEditorPage` | Tela de edição; recebe `StoryMedia`, retorna `File?` |
| `StoryMedia` | Contém o `File`, `StoryType` (photo/video), duração e thumbnail |
| `StoryEditorController` | `ChangeNotifier` que gerencia elementos e histórico de undo |
| `TextElement` | Elemento de texto com cor, fonte, sombra e alinhamento |
| `StickerElement` | Adesivo emoji |
| `DrawingElement` | Traço de desenho livre |
| `StoryPreviewWidget` | Preview read-only 9:16 com suporte a filtros e auto-play de vídeo |
| `StoryExportService` | Comprime e salva story + sidecar JSON com os elementos |

## Dependências

| Package | Função |
|---|---|
| `camerawesome` | Captura de câmera |
| `photo_manager` | Acesso à galeria |
| `video_player` | Preview de vídeo |
| `ffmpeg_kit_flutter_new` | Compressão de vídeo |
| `flutter_image_compress` | Compressão de imagem para WebP |
| `path_provider` | Diretório de saída |
| `uuid` | Geração de IDs dos elementos |
