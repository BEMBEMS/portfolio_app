import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class EmojiPickerPanel extends StatelessWidget {
  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  static const List<String> emojis = <String>[
    '😀', '😄', '😂', '🥲', '😊', '😍', '😎', '🤩',
    '🤔', '😴', '🙃', '😉', '😭', '🥳', '😮', '🤯',
    '👍', '👎', '👏', '🙏', '💪', '🤝', '🙌', '✌️',
    '❤️', '💜', '💙', '💚', '🔥', '✨', '🎉', '🚀',
    '⭐', '🌙', '⚡', '☕', '🎵', '💬', '✅', '📍',
  ];

  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Container(
      height: 148,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: theme.borderColor),
        ),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onEmojiSelected(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}
