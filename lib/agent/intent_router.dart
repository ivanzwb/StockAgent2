/// 意图路由 - 判断用户意图属于哪个功能
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import '../config/app_config.dart';

enum UserIntent {
  stockAnalysis, // 分析某只股票
  stockMonitor, // 监控某只股票
  sectorRecommend, // 板块推荐
  generalChat, // 普通聊天
}

class IntentRouter {
  /// 使用LLM判断用户意图
  static Future<UserIntent> classifyIntent(String userMessage) async {
    final llm = ChatOpenAI(
      apiKey: AppConfig.apiKey,
      baseUrl: AppConfig.effectiveApiBase,
      defaultOptions: ChatOpenAIOptions(
        model: AppConfig.modelName,
        temperature: 0,
        maxTokens: 100,
      ),
    );

    final prompt = ChatPromptTemplate.fromTemplate('''
你是一个意图分类器。根据用户的消息，判断其意图属于以下哪个类别：

1. stock_analysis - 用户想分析某只股票（问股票怎么样、能不能买、分析一下等）
2. stock_monitor - 用户想监控某只股票（帮我盯着、监控、提醒我等）
3. sector_recommend - 用户想要板块推荐（推荐板块、哪个行业好、热门板块等）
4. general_chat - 其他普通聊天

只回复类别名称，不要其他文字。

用户消息: {message}
''');

    final chain = prompt | llm | const StringOutputParser();

    try {
      final result = await chain.invoke({'message': userMessage});
      final text = result.toString().trim().toLowerCase();

      if (text.contains('stock_analysis') || text.contains('分析')) {
        return UserIntent.stockAnalysis;
      } else if (text.contains('stock_monitor') || text.contains('监控')) {
        return UserIntent.stockMonitor;
      } else if (text.contains('sector_recommend') || text.contains('板块')) {
        return UserIntent.sectorRecommend;
      }
      return UserIntent.generalChat;
    } catch (e) {
      // 基于关键词的回退方案
      return _fallbackClassify(userMessage);
    }
  }

  static UserIntent _fallbackClassify(String message) {
    final msg = message.toLowerCase();
    final monitorKeywords = ['监控', '盯着', '提醒', '监视', '帮我看', '自动买', '自动卖'];
    final sectorKeywords = ['板块', '行业', '概念', '推荐板块', '热门', '哪个行业'];
    final analysisKeywords = [
      '分析', '怎么样', '能买吗', '能不能买', '什么价位', '目标价',
      '建议', '走势', '技术面', '基本面', '估值',
    ];

    for (final kw in monitorKeywords) {
      if (msg.contains(kw)) return UserIntent.stockMonitor;
    }
    for (final kw in sectorKeywords) {
      if (msg.contains(kw)) return UserIntent.sectorRecommend;
    }
    for (final kw in analysisKeywords) {
      if (msg.contains(kw)) return UserIntent.stockAnalysis;
    }

    // 如果包含股票代码或看起来像股票请求，默认分析
    final codeRegex = RegExp(r'[036]\d{5}');
    if (codeRegex.hasMatch(msg)) return UserIntent.stockAnalysis;

    return UserIntent.generalChat;
  }
}
