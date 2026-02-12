/// 板块推荐器 - Feature 3: 推荐板块和板块内优质股票
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import '../config/app_config.dart';
import '../skills/skill_manager.dart';

class SectorRecommender {
  final SkillManager _skillManager = SkillManager();

  /// 板块推荐分析
  Future<String> recommend(String userQuery) async {
    final llm = ChatOpenAI(
      apiKey: AppConfig.apiKey,
      baseUrl: AppConfig.effectiveApiBase,
      defaultOptions: ChatOpenAIOptions(
        model: AppConfig.modelName,
        temperature: AppConfig.temperature,
        maxTokens: AppConfig.maxTokens,
      ),
    );

    final tools = _skillManager.getAllTools();

    final systemMessage = SystemChatMessagePromptTemplate.fromTemplate('''
你是一个专业的A股板块分析师。用户会请求板块推荐，你需要：

1. 使用 get_sector_list 工具获取行业板块或概念板块列表
2. 找到涨幅靠前的热门板块
3. 使用 get_sector_stocks 获取热门板块中的成分股
4. 可选：对推荐的个股使用 get_stock_quote 和 get_technical_indicators 进一步分析
5. 给出综合推荐

回复格式：
🔥 **热门板块推荐**

**板块1: xxx板块** (涨幅: +x.xx%)
推荐理由: ...
推荐个股:
  - 股票A(代码): 当前价xx, 涨幅+x%
  - 股票B(代码): 当前价xx, 涨幅+x%

**板块2: xxx板块** (涨幅: +x.xx%)
...

⚠️ **风险提示：** 板块轮动较快，以上推荐仅供参考...
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
      maxIterations: 10,
    );

    try {
      final result = await executor.invoke({'input': userQuery});
      return result['output'] as String;
    } catch (e) {
      return '板块分析出错: $e';
    }
  }
}
