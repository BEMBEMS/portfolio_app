import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../providers/theme_provider.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isMine = message.isMine;
    final bubbleColor = isMine
        ? Colors.deepPurpleAccent
        : (theme.isDarkMode ? const Color(0xFF1C1C1C) : Colors.white);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                message.senderName!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.accentColor,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 5),
                bottomRight: Radius.circular(isMine ? 5 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMine ? Colors.deepPurpleAccent : Colors.black)
                      .withValues(alpha: isMine ? 0.25 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: isMine ? Colors.white : theme.textColor,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              message.timeLabel,
              style: TextStyle(fontSize: 10.5, color: theme.mutedTextColor),
            ),
          ),
        ],
      ),
    );
  }
}
