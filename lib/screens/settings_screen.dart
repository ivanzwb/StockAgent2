import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../skills/skill_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _apiBaseController = TextEditingController();
  final _modelController = TextEditingController();
  String _provider = 'deepseek';
  double _temperature = 0.7;
  final _skillManager = SkillManager();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _provider = AppConfig.llmProvider;
    _apiKeyController.text = AppConfig.apiKey;
    _apiBaseController.text = AppConfig.apiBase ?? '';
    _modelController.text = AppConfig.modelName;
    _temperature = AppConfig.temperature;
  }

  Future<void> _saveSettings() async {
    AppConfig.llmProvider = _provider;
    AppConfig.apiKey = _apiKeyController.text.trim();
    AppConfig.apiBase = _apiBaseController.text.trim().isEmpty
        ? null
        : _apiBaseController.text.trim();
    AppConfig.modelName = _modelController.text.trim();
    AppConfig.temperature = _temperature;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiBaseController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LLM配置
          _buildSectionHeader('LLM 配置'),
          const SizedBox(height: 8),
          _buildProviderSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
              hintText: '输入你的API Key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiBaseController,
            decoration: InputDecoration(
              labelText: 'API Base URL (可选)',
              border: const OutlineInputBorder(),
              hintText: _provider == 'deepseek'
                  ? 'https://api.deepseek.com/v1'
                  : 'https://api.openai.com/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: '模型名称',
              border: const OutlineInputBorder(),
              hintText: _provider == 'deepseek'
                  ? 'deepseek-chat'
                  : 'gpt-4o-mini',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('温度 (Temperature): '),
              Expanded(
                child: Slider(
                  value: _temperature,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _temperature = v),
                ),
              ),
              Text(_temperature.toStringAsFixed(1)),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),

          // 技能管理
          _buildSectionHeader('技能管理'),
          const SizedBox(height: 8),
          ..._buildSkillToggles(),

          const SizedBox(height: 24),
          const Divider(),

          // 关于
          _buildSectionHeader('关于'),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('炒股助理 v1.0'),
            subtitle: Text('基于Flutter + LangChain.dart\n'
                '数据来源: 新浪财经 / 东方财富\n'
                '免责声明: 仅供学习参考，不构成投资建议'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildProviderSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'deepseek',
          label: Text('DeepSeek'),
          icon: Icon(Icons.auto_awesome),
        ),
        ButtonSegment(
          value: 'openai',
          label: Text('OpenAI'),
          icon: Icon(Icons.cloud),
        ),
        ButtonSegment(
          value: 'custom',
          label: Text('自定义'),
          icon: Icon(Icons.settings),
        ),
      ],
      selected: {_provider},
      onSelectionChanged: (selected) {
        setState(() {
          _provider = selected.first;
          if (_provider == 'deepseek') {
            _modelController.text = 'deepseek-chat';
            _apiBaseController.text = '';
          } else if (_provider == 'openai') {
            _modelController.text = 'gpt-4o-mini';
            _apiBaseController.text = '';
          }
        });
      },
    );
  }

  List<Widget> _buildSkillToggles() {
    final skills = _skillManager.getAllSkillsInfo();
    return skills.map((skill) {
      return SwitchListTile(
        title: Text(skill['name'] as String),
        subtitle: Text(skill['description'] as String),
        value: skill['enabled'] as bool,
        onChanged: (enabled) {
          setState(() {
            if (enabled) {
              _skillManager.enableSkill(skill['name'] as String);
            } else {
              _skillManager.disableSkill(skill['name'] as String);
            }
          });
        },
      );
    }).toList();
  }
}
