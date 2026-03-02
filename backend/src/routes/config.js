/**
 * 系统配置 API 路由
 */
import { Router } from 'express';
import { getLLMConfig, updateLLMConfig } from '../services/llmService.js';
import toolRegistry from '../tools/index.js';

const router = Router();

/**
 * GET /api/config/llm - 获取 LLM 配置
 */
router.get('/llm', (req, res) => {
  const config = getLLMConfig();
  res.json({ success: true, data: config });
});

/**
 * PUT /api/config/llm - 更新 LLM 配置
 * Body: { provider: "deepseek", deepseek: { apiKey: "xxx", model: "deepseek-chat" } }
 */
router.put('/llm', (req, res) => {
  try {
    const newConfig = req.body;

    // 验证 API key
    const provider = newConfig.provider || 'deepseek';
    const providerConfig = newConfig[provider];

    if (!providerConfig?.apiKey || providerConfig.apiKey.trim() === '') {
      return res.status(400).json({
        success: false,
        error: `${provider} 的 apiKey 不能为空`
      });
    }

    if (providerConfig.apiKey.startsWith('your_')) {
      return res.status(400).json({
        success: false,
        error: `${provider} 的 apiKey 仍为示例值，请输入真实的 API Key`
      });
    }

    const updated = updateLLMConfig(newConfig);
    res.json({ success: true, data: getLLMConfig(), message: `LLM 配置已更新为 ${provider}` });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/config/tools - 获取工具列表
 */
router.get('/tools', (req, res) => {
  const tools = toolRegistry.getAllTools();
  res.json({ success: true, data: tools });
});

/**
 * PUT /api/config/tools/:id - 启用/禁用工具
 * Body: { enabled: true }
 */
router.put('/tools/:id', (req, res) => {
  const { id } = req.params;
  const { enabled } = req.body;
  const success = toolRegistry.setToolEnabled(id, enabled);
  if (success) {
    res.json({ success: true, message: `工具 ${id} 已${enabled ? '启用' : '禁用'}` });
  } else {
    res.status(404).json({ error: '工具不存在' });
  }
});

export default router;
