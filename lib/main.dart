import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'storage/local_store.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();

  runApp(const StockAgentApp());
}

class StockAgentApp extends StatelessWidget {
  const StockAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: '炒股助理',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
