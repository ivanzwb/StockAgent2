import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isLoading;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(context),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('正在分析...'),
                      ],
                    )
                  : SelectableText(
                      message,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}
