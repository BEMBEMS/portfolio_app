import '../utils/formatters.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.senderName,
  });

  final String id;
  final String text;
  final bool isMine;
  final DateTime timestamp;
  final String? senderName;

  String get timeLabel => formatTime(timestamp);
}
