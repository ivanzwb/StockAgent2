import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// 设置页面 - LLM 配置 & 工具管理
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverHostController = TextEditingController(text: 'localhost');
  final _serverPortController = TextEditingController(text: '3000');
  bool _useSsl = false;
  String _selectedProvider = 'deepseek';

  // DeepSeek
  final _dsApiKeyController = TextEditingController();
  final _dsBaseUrlController =
      TextEditingController(text: 'https://api.deepseek.com');
  final _dsModelController = TextEditingController(text: 'deepseek-chat');

  // OpenAI
  final _oaiApiKeyController = TextEditingController();
  final _oaiBaseUrlController =
      TextEditingController(text: 'https://api.openai.com/v1');
  final _oaiModelController = TextEditingController(text: 'gpt-4o');

  // Custom
  final _customApiKeyController = TextEditingController();
  final _customBaseUrlController =
      TextEditingController(text: 'http://localhost:11434/v1');
  final _customModelController = TextEditingController(text: 'qwen2.5');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    final state = context.read<AppState>();
    await state.loadConfig();

    if (state.llmConfig != null) {
      setState(() {
        _selectedProvider = state.llmConfig!.provider;
        _dsBaseUrlController.text = state.llmConfig!.deepseek['baseUrl'] ?? '';
        _dsModelController.text = state.llmConfig!.deepseek['model'] ?? '';
        _oaiBaseUrlController.text = state.llmConfig!.openai['baseUrl'] ?? '';
        _oaiModelController.text = state.llmConfig!.openai['model'] ?? '';
        _customBaseUrlController.text =
            state.llmConfig!.custom['baseUrl'] ?? '';
        _customModelController.text = state.llmConfig!.custom['model'] ?? '';
      });
    }
  }

  Future<void> _saveConfig() async {
    final config = {
      'provider': _selectedProvider,
      'deepseek': {
        'apiKey': _dsApiKeyController.text,
        'baseUrl': _dsBaseUrlController.text,
        'model': _dsModelController.text,
      },
      'openai': {
        'apiKey': _oaiApiKeyController.text,
        'baseUrl': _oaiBaseUrlController.text,
        'model': _oaiModelController.text,
      },
      'custom': {
        'apiKey': _customApiKeyController.text,
        'baseUrl': _customBaseUrlController.text,
        'model': _customModelController.text,
      },
    };

    await context.read<AppState>().saveLLMConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('配置已保存')),
      );
    }
  }

  @override
  void dispose() {
    _serverHostController.dispose();
    _serverPortController.dispose();
    _dsApiKeyController.dispose();
    _dsBaseUrlController.dispose();
    _dsModelController.dispose();
    _oaiApiKeyController.dispose();
    _oaiBaseUrlController.dispose();
    _oaiModelController.dispose();
    _customApiKeyController.dispose();
    _customBaseUrlController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
// 服务器连接
          _buildSection('服务器连接', [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _serverHostController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'frp.freefrp.net',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _serverPortController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '3000',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('使用 SSL (HTTPS/WSS)'),
              value: _useSsl,
              onChanged: (v) => setState(() => _useSsl = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Consumer<AppState>(
                  builder: (context, state, _) {
                    return Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                state.isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.isConnected ? '已连接' : '未连接',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final host = _serverHostController.text.trim();
                    final port = _serverPortController.text.trim();
                    final useSsl = _useSsl;
                    context.read<AppState>().updateServerUrl(
                        host, int.tryParse(port) ?? 80, useSsl);
                  },
                  child: const Text('连接'),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // LLM 配置
          _buildSection('LLM 配置', [
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(labelText: '选择 LLM 提供商'),
              items: const [
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                DropdownMenuItem(value: 'custom', child: Text('自定义')),
              ],
              onChanged: (v) => setState(() => _selectedProvider = v!),
            ),
            const SizedBox(height: 16),
            if (_selectedProvider == 'deepseek')
              ..._buildProviderFields(
                _dsApiKeyController,
                _dsBaseUrlController,
                _dsModelController,
                'DeepSeek',
              ),
            if (_selectedProvider == 'openai')
              ..._buildProviderFields(
                _oaiApiKeyController,
                _oaiBaseUrlController,
                _oaiModelController,
                'OpenAI',
              ),
            if (_selectedProvider == 'custom')
              ..._buildProviderFields(
                _customApiKeyController,
                _customBaseUrlController,
                _customModelController,
                '自定义',
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saveConfig,
              child: const Text('保存 LLM 配置'),
            ),
          ]),

          const SizedBox(height: 24),

          // 工具管理
          _buildSection('工具技能管理', [
            Consumer<AppState>(
              builder: (context, state, _) {
                if (state.tools.isEmpty) {
                  return Text('暂无工具数据',
                      style: TextStyle(color: AppTheme.textSecondary));
                }

                return Column(
                  children: state.tools.map((tool) {
                    return SwitchListTile(
                      title: Text(tool.name),
                      subtitle: Text(tool.description,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      value: tool.enabled,
                      onChanged: (v) {
                        context.read<AppState>().toggleTool(tool.id, v);
                      },
                      secondary: Chip(
                        label:
                            Text(tool.category, style: TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildProviderFields(
    TextEditingController apiKey,
    TextEditingController baseUrl,
    TextEditingController model,
    String name,
  ) {
    return [
      TextField(
        controller: apiKey,
        decoration: InputDecoration(labelText: '$name API Key'),
        obscureText: true,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: baseUrl,
        decoration: InputDecoration(labelText: '$name Base URL'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: model,
        decoration: InputDecoration(labelText: '$name 模型'),
      ),
    ];
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
