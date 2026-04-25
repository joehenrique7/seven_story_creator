import 'dart:io';

import 'package:flutter/material.dart';

import 'capture/models/story_media.dart';
import 'capture/story_capture_page.dart';
import 'editor/story_editor_page.dart';

/// Main entry point for the story creation flow.
///
/// Call [StoryCreator.open] to launch capture → edit → export in sequence.
/// Returns the exported [File] when the user taps "Concluir", or null if
/// they cancel at any step.
///
/// ```dart
/// final file = await StoryCreator.open(context);
/// if (file != null) {
///   // save and publish
/// }
/// ```
class StoryCreator {
  StoryCreator._();

  /// Pushes [StoryCapturePage], then [StoryEditorPage], and returns the
  /// exported [File], or null if the user cancels.
  ///
  /// Set [forRoot] to `true` to use the root navigator — useful when the app
  /// uses nested navigators (e.g. bottom navigation) and you want the story
  /// screens to cover the entire display.
  static Future<File?> open(BuildContext context, {bool forRoot = false}) async {
    final nav = Navigator.of(context, rootNavigator: forRoot);

    final media = await nav.push<StoryMedia?>(
      MaterialPageRoute(builder: (_) => const StoryCapturePage()),
    );
    if (media == null) return null;

    // ignore: use_build_context_synchronously
    if (!context.mounted) return null;

    final file = await Navigator.of(context, rootNavigator: forRoot).push<File?>(
      MaterialPageRoute(builder: (_) => StoryEditorPage(media: media)),
    );
    return file;
  }
}
