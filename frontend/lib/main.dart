import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'theme/app_theme.dart';
import 'pages/chat/chat_page.dart';
import 'pages/monitor/monitor_page.dart';
import 'pages/sector/sector_page.dart';
import 'pages/quant/quant_page.dart';
import 'pages/settings/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final serverConfig = await AppState.loadServerConfig();
  runApp(StockAgentApp(serverConfig: serverConfig));
}

class StockAgentApp extends StatelessWidget {
  final Map<String, dynamic> serverConfig;

  const StockAgentApp({super.key, required this.serverConfig});

  @override
  Widget build(BuildContext context) {
    final host = serverConfig['host'] as String;
    final port = serverConfig['port'] as int;
    final useSsl = serverConfig['useSsl'] as bool;
    final protocol = useSsl ? 'https' : 'http';
    final wsProtocol = useSsl ? 'wss' : 'ws';
    final baseUrl = '$protocol://$host:$port';
    final wsUrl = '$wsProtocol://$host:$port/ws';

    return ChangeNotifierProvider(
      create: (_) => AppState(
        api: ApiService(baseUrl: baseUrl),
        ws: WebSocketService(wsUrl: wsUrl),
      ),
      child: MaterialApp(
        title: '炒股助理',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}

/// 主页 - 底部导航
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ChatPage(),
    MonitorPage(),
    SectorPage(),
    QuantPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().checkConnection();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = context.read<AppState>();
    if (state == AppLifecycleState.paused) {
      appState.startBackgroundService();
    } else if (state == AppLifecycleState.resumed) {
      appState.stopBackgroundService();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '监控',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: '板块',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph),
            label: '量化',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
