/// 股票分析顾问 - Feature 1: 分析股票给出买卖建议
import 'dart:convert';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import '../config/app_config.dart';
import '../skills/skill_manager.dart';
import '../skills/stock_info_tool.dart' as stock_info;
import '../skills/technical_tool.dart' as technical;
import '../skills/fundamental_tool.dart' as fundamental;
import '../models/schemas.dart';

class StockAdvisor {
  final SkillManager _skillManager = SkillManager();

  /// 分析股票并给出建议
  Future<String> analyze(String userQuery) async {
    final llm = ChatOpenAI(
      apiKey: AppConfig.apiKey,
      baseUrl: AppConfig.effectiveApiBase,
      defaultOptions: ChatOpenAIOptions(
        model: AppConfig.modelName,
        temperature: AppConfig.temperature,
        maxTokens: AppConfig.maxTokens,
      ),
    );

    final tools = _skillManager.getAnalysisTools();

    final systemMessage = SystemChatMessagePromptTemplate.fromTemplate('''
你是一个专业的A股投资分析师。用户会询问某只股票的情况，你需要：

1. 使用工具获取股票的实时行情、技术指标和基本面数据
2. 综合分析技术面和基本面
3. 给出明确的投资建议（买入/持有/卖出）
4. 说明建议的理由

分析要点：
- 技术面：关注MA趋势、MACD金叉死叉、RSI超买超卖、KDJ指标、布林带位置
- 基本面：关注PE/PB估值、ROE、营收增长、资产负债率
- 综合判断：结合技术面和基本面给出建议

回复格式：
📊 **股票名称 (代码)**
💰 当前价格: xxx | 涨跌幅: xxx%

**技术面分析：**
- MA均线: ...
- MACD: ...
- RSI: ...
- KDJ: ...

**基本面分析：**
- 估值: ...
- 盈利能力: ...

**综合建议：** 🟢买入 / 🟡持有 / 🔴卖出
**理由：** ...
**建议仓位：** ...%
**风险提示：** ...
''');

    final humanMessage =
        HumanChatMessagePromptTemplate.fromTemplate('{input}');

    final prompt = ChatPromptTemplate.fromPromptMessages([
      systemMessage,
      humanMessage,
      const MessagesPlaceholder(variableName: 'agent_scratchpad'),
    ]);

    final agent = ToolsAgent.fromLLMAndTools(llm: llm, tools: tools, prompt: prompt);

    final executor = AgentExecutor(
      agent: agent,
      tools: tools,
      maxIterations: 8,
    );

    try {
      final result = await executor.invoke({'input': userQuery});
      return result['output'] as String;
    } catch (e) {
      return '分析过程出错: $e';
    }
  }

  /// 快速分析（不用Agent，直接调用工具获取数据后让LLM总结）
  Future<AnalysisResult?> quickAnalyze(String stockCode) async {
    try {
      // 并行获取数据
      final results = await Future.wait([
        stock_info.getStockQuoteTool.invoke({'stock': stockCode}),
        technical.getTechnicalIndicatorsTool
            .invoke({'stock_code': stockCode}),
        fundamental.getFundamentalDataTool
            .invoke({'stock_code': stockCode}),
      ]);

      final llm = ChatOpenAI(
        apiKey: AppConfig.apiKey,
        baseUrl: AppConfig.effectiveApiBase,
        defaultOptions: ChatOpenAIOptions(
          model: AppConfig.modelName,
          temperature: 0.3,
          maxTokens: 500,
        ),
      );

      final prompt = ChatPromptTemplate.fromTemplate('''
基于以下股票数据，给出简要的投资建议。只回复JSON格式:
{{"action": "buy/hold/sell", "confidence": 0.0-1.0, "reason": "简要理由", "target_price": 数字或null, "stop_loss": 数字或null}}

股票数据:
{data}
''');

      final chain = prompt | llm | const StringOutputParser();
      final response = await chain.invoke({
        'data': results.join('\n\n'),
      });

      // 解析结果
      final responseStr = response.toString();
      // 提取JSON
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(responseStr);
      if (jsonMatch == null) return null;

      final jsonStr = jsonMatch.group(0)!;
      final json = Map<String, dynamic>.from(
        (await Future.value(
                    const JsonDecoder().convert(jsonStr)))
            as Map,
      );

      return AnalysisResult(
        code: stockCode,
        action: StockAction.values
            .firstWhere((a) => a.name == json['action'],
                orElse: () => StockAction.hold),
        confidence: (json['confidence'] as num).toDouble(),
        reason: json['reason'] as String,
        targetPrice: json['target_price'] != null
            ? (json['target_price'] as num).toDouble()
            : null,
        stopLoss: json['stop_loss'] != null
            ? (json['stop_loss'] as num).toDouble()
            : null,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}
