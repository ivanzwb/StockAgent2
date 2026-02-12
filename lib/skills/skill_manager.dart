/// 技能管理器 - 管理所有LangChain Tools
import 'package:langchain_core/tools.dart';
import 'stock_info_tool.dart';
import 'technical_tool.dart';
import 'fundamental_tool.dart';
import 'sector_tool.dart';

class SkillInfo {
  final String name;
  final String description;
  bool enabled;
  final List<Tool> tools;

  SkillInfo({
    required this.name,
    required this.description,
    this.enabled = true,
    required this.tools,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'enabled': enabled,
      };
}

class SkillManager {
  static final SkillManager _instance = SkillManager._internal();
  factory SkillManager() => _instance;
  SkillManager._internal() {
    _initDefaultSkills();
  }

  final Map<String, SkillInfo> _skills = {};

  void _initDefaultSkills() {
    _skills['stock_info'] = SkillInfo(
      name: 'stock_info',
      description: '获取股票实时行情和K线数据',
      tools: [getStockQuoteTool, getStockKlineTool],
    );
    _skills['technical_analysis'] = SkillInfo(
      name: 'technical_analysis',
      description: '计算股票技术指标（MA、MACD、RSI、KDJ、布林带等）',
      tools: [getTechnicalIndicatorsTool],
    );
    _skills['fundamental_analysis'] = SkillInfo(
      name: 'fundamental_analysis',
      description: '获取股票基本面数据（PE、PB、ROE、市值、营收等）',
      tools: [getFundamentalDataTool],
    );
    _skills['sector_analysis'] = SkillInfo(
      name: 'sector_analysis',
      description: '获取板块列表和板块内股票信息',
      tools: [getSectorListTool, getSectorStocksTool],
    );
  }

  /// 获取所有技能信息
  List<Map<String, dynamic>> getAllSkillsInfo() {
    return _skills.values.map((s) => s.toJson()).toList();
  }

  /// 获取启用的LangChain Tools
  List<Tool> getEnabledTools({List<String>? skillNames}) {
    final tools = <Tool>[];
    for (final entry in _skills.entries) {
      if (!entry.value.enabled) continue;
      if (skillNames != null && !skillNames.contains(entry.key)) continue;
      tools.addAll(entry.value.tools);
    }
    return tools;
  }

  /// 获取分析用工具（排除板块工具）
  List<Tool> getAnalysisTools() {
    return getEnabledTools(skillNames: [
      'stock_info',
      'technical_analysis',
      'fundamental_analysis',
    ]);
  }

  /// 获取全部工具
  List<Tool> getAllTools() {
    return getEnabledTools();
  }

  /// 启用技能
  bool enableSkill(String name) {
    if (_skills.containsKey(name)) {
      _skills[name]!.enabled = true;
      return true;
    }
    return false;
  }

  /// 禁用技能
  bool disableSkill(String name) {
    if (_skills.containsKey(name)) {
      _skills[name]!.enabled = false;
      return true;
    }
    return false;
  }
}
