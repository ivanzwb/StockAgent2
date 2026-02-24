/**
 * LLM 服务 - 管理 LLM 连接和调用
 */
import { ChatOpenAI } from '@langchain/openai';
import config from '../config/index.js';

let currentLLM = null;
let currentConfig = null;

/**
 * 获取或创建 LLM 实例
 */
export function getLLM(overrideConfig = null) {
  const llmConfig = overrideConfig || config.llm;
  const provider = llmConfig.provider || 'deepseek';
  const providerConfig = llmConfig[provider];

  if (!providerConfig || !providerConfig.apiKey) {
    throw new Error(`LLM 配置缺失: ${provider}`);
  }

  // 如果配置没变，返回现有实例
  const configKey = JSON.stringify({ provider, ...providerConfig });
  if (currentLLM && currentConfig === configKey) {
    return currentLLM;
  }

  currentLLM = new ChatOpenAI({
    openAIApiKey: providerConfig.apiKey,
    modelName: providerConfig.model,
    configuration: {
      baseURL: providerConfig.baseUrl,
    },
    temperature: 0.3,
    maxTokens: 4096,
  });

  currentConfig = configKey;
  return currentLLM;
}

/**
 * 更新 LLM 配置
 */
export function updateLLMConfig(newConfig) {
  Object.assign(config.llm, newConfig);
  currentLLM = null;
  currentConfig = null;
  return config.llm;
}

/**
 * 获取当前 LLM 配置
 */
export function getLLMConfig() {
  return {
    provider: config.llm.provider,
    deepseek: { ...config.llm.deepseek, apiKey: config.llm.deepseek.apiKey ? '***' : '' },
    openai: { ...config.llm.openai, apiKey: config.llm.openai.apiKey ? '***' : '' },
    custom: { ...config.llm.custom, apiKey: config.llm.custom.apiKey ? '***' : '' },
  };
}

export default { getLLM, updateLLMConfig, getLLMConfig };
