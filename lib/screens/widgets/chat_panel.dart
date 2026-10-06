import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../models/peer_device.dart';
import '../../providers/mesh_provider.dart';
import '../../providers/theme_provider.dart';
import 'chat_bubble.dart';
import 'emoji_picker_panel.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojis = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _toggleEmojis() {
    setState(() => _showEmojis = !_showEmojis);
    if (_showEmojis) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid && selection.baseOffset <= text.length
        ? selection.baseOffset
        : text.length;
    final end = selection.isValid && selection.extentOffset <= text.length
        ? selection.extentOffset
        : start;

    _controller.value = TextEditingValue(
      text: '${text.substring(0, start)}$emoji${text.substring(end)}',
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _send(MeshProvider mesh) {
    if (_controller.text.trim().isEmpty) return;
    mesh.sendMessage(_controller.text);
    _controller.clear();
    if (_showEmojis) {
      setState(() => _showEmojis = false);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();
    final theme = Provider.of<ThemeProvider>(context);
    final peer = mesh.activePeer;
    final messages = mesh.activeMessages;
    final canChat = peer != null;
    final canSend = canChat && _controller.text.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.textColor.withValues(alpha: 0.12),
            theme.textColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBar(peer: peer),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: canChat
                ? _buildFeed(messages, theme)
                : _EmptyChatState(theme: theme),
          ),
          if (_showEmojis && canChat)
            EmojiPickerPanel(onEmojiSelected: _insertEmoji),
          _buildInputBar(
            mesh: mesh,
            peer: peer,
            canChat: canChat,
            canSend: canSend,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(List<ChatMessage> messages, ThemeProvider theme) {
    if (messages.isEmpty) {
      return _EmptyConversationHint(theme: theme);
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return ChatBubble(message: messages[messages.length - 1 - index]);
      },
    );
  }

  Widget _buildInputBar({
    required MeshProvider mesh,
    required PeerDevice? peer,
    required bool canChat,
    required bool canSend,
    required ThemeProvider theme,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.borderColor),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: canChat,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(mesh),
                style: TextStyle(fontSize: 14.5, color: theme.textColor),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: peer == null
                      ? 'Connect a device to start chatting'
                      : 'Message ${peer.name}…',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.mutedTextColor,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _showEmojis ? 'Hide emoji picker' : 'Emoji picker',
            onPressed: canChat ? _toggleEmojis : null,
            icon: Icon(
              _showEmojis
                  ? Icons.keyboard_outlined
                  : Icons.emoji_emotions_outlined,
              color: _showEmojis ? theme.accentColor : theme.mutedTextColor,
            ),
          ),
          const SizedBox(width: 4),
          _SendButton(enabled: canSend, onPressed: () => _send(mesh)),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [Colors.deepPurpleAccent, Colors.deepPurple],
              )
            : null,
        color: enabled ? null : theme.textColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: IconButton(
        tooltip: 'Send',
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(
          Icons.send_rounded,
          size: 20,
          color: enabled ? Colors.white : theme.mutedTextColor,
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.peer});

  final PeerDevice? peer;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final connected = peer != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                  : Colors.deepPurpleAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              connected ? Icons.forum_rounded : Icons.forum_outlined,
              size: 18,
              color: connected
                  ? const Color(0xFF4CAF50)
                  : Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer?.name ?? 'No active chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? 'Connected — messages stay on this local mesh'
                      : 'Select a connected device below to start chatting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.theme});

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering_rounded,
                color: Colors.deepPurpleAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No conversation yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Make this device Visible, scan for peers and\nconnect to open an offline chat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: theme.mutedTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversationHint extends StatelessWidget {
  const _EmptyConversationHint({required this.theme});

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Say hello 👋 — messages are delivered\n'
          'over the local mesh, no internet needed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: theme.mutedTextColor),
        ),
      ),
    );
  }
}
