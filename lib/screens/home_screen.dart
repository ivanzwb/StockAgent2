import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/chat_bubble.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const _tabLabels = ['股票分析', '股票监控', '板块推荐'];
  static const _tabIcons = [
    Icons.analytics_outlined,
    Icons.monitor_heart_outlined,
    Icons.category_outlined,
  ];
  static const _hints = [
    '输入股票名称或代码，如"分析浦发银行"...',
    '输入"监控600000"或"查看任务列表"...',
    '输入"推荐热门板块"或"推荐概念板块"...',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(AppState appState) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    appState.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        _scrollToBottom();
        return Scaffold(
          appBar: AppBar(
            title: const Text('炒股助理'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '清除聊天记录',
                onPressed: () => _showClearConfirm(context, appState),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 聊天消息列表
              Expanded(
                child: appState.currentMessages.isEmpty
                    ? _buildWelcome(appState.currentTab)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: appState.currentMessages.length,
                        itemBuilder: (context, index) {
                          final msg = appState.currentMessages[index];
                          return ChatBubble(
                            message: msg.content,
                            isUser: msg.role == 'user',
                            isLoading: msg.isLoading,
                          );
                        },
                      ),
              ),

              // 输入区域
              _buildInputArea(appState),
            ],
          ),

          // 底部导航
          bottomNavigationBar: NavigationBar(
            selectedIndex: appState.currentTab,
            onDestinationSelected: appState.setCurrentTab,
            destinations: List.generate(3, (i) {
              return NavigationDestination(
                icon: Icon(_tabIcons[i]),
                selectedIcon: Icon(
                  _tabIcons[i],
                ),
                label: _tabLabels[i],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildWelcome(int tab) {
    final titles = ['📊 股票分析', '👀 股票监控', '🔥 板块推荐'];
    final descs = [
      '输入股票名称或代码，AI分析师会为你分析技术面和基本面，给出买入/卖出/持有建议。\n\n'
          '示例:\n• "分析浦发银行"\n• "600000怎么样"\n• "贵州茅台能买吗"',
      '添加股票到监控列表，AI会定期检查并推送交易建议。\n\n'
          '示例:\n• "监控600000"\n• "帮我盯着贵州茅台，低于1800提醒"\n• "查看任务列表"',
      '获取热门板块推荐和板块内个股分析。\n\n'
          '示例:\n• "推荐热门行业板块"\n• "推荐概念板块"\n• "半导体板块有哪些好股票"',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titles[tab],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              descs[tab],
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(180),
                    height: 1.8,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: _hints[appState.currentTab],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(appState),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: appState.isProcessing
                  ? null
                  : () => _sendMessage(appState),
              child: appState.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirm(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除聊天记录'),
        content: Text('确定要清除"${_tabLabels[appState.currentTab]}"的聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              appState.clearChat();
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
