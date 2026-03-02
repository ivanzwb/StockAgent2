/**
 * LLM 服务 - 管理 LLM 连接和调用
 */
import { ChatOpenAI } from '@langchain/openai';
import config from '../config/index.js';
import { getLLMConfigFromDB } from './dbService.js';

let currentLLM = null;
let currentConfig = null;
let cachedDBConfig = null;

/**
 * 初始化 LLM 配置（应用启动时调用）
 */
export async function initLLMConfig() {
  try {
    const dbConfig = await getLLMConfigFromDB();
    if (dbConfig && dbConfig.provider) {
      console.log(`从数据库加载 LLM 配置: ${dbConfig.provider}`);
      // 更新内存配置（但不保存回数据库）
      Object.assign(config.llm, dbConfig);
      return; // 成功从数据库加载，返回
    }
  } catch (error) {
    console.warn('从数据库加载 LLM 配置失败:', error.message);
  }
  // 如果没有数据库配置，使用环境配置
  console.log(`使用环境变量配置 LLM: ${config.llm.provider}`);
}

/**
 * 获取或创建 LLM 实例
 */
export async function getLLM(overrideConfig = null) {
  let llmConfig = overrideConfig;

  // 如果没有提供覆盖配置，尝试从数据库读取
  if (!llmConfig) {
    // 先检查缓存的数据库配置
    if (cachedDBConfig && cachedDBConfig.expiry > Date.now()) {
      llmConfig = cachedDBConfig.config;
    } else {
      // 尝试从数据库读取
      try {
        const dbConfig = await getLLMConfigFromDB();
        if (dbConfig && dbConfig.provider) {
          cachedDBConfig = { config: dbConfig, expiry: Date.now() + 60000 }; // 缓存 1 分钟
          llmConfig = dbConfig;
        }
      } catch (error) {
        console.warn('从数据库读取 LLM 配置失败:', error.message);
      }
    }
    // 如果数据库没有配置，使用环境配置
    if (!llmConfig) {
      llmConfig = config.llm;
    }
  }

  const provider = llmConfig?.provider || 'deepseek';
  const providerConfig = llmConfig?.[provider];

  if (!providerConfig) {
    throw new Error(`LLM 配置缺失: 未找到 ${provider} 配置`);
  }

  if (!providerConfig.apiKey || providerConfig.apiKey.trim() === '' || providerConfig.apiKey.startsWith('your_')) {
    throw new Error(`LLM 配置缺失: ${provider} 的 apiKey 未配置或无效`);
  }

  // 如果配置没变，返回现有实例
  const configKey = JSON.stringify({ provider, ...providerConfig });
  if (currentLLM && currentConfig === configKey) {
    return currentLLM;
  }

  currentLLM = new ChatOpenAI({
    apiKey: providerConfig.apiKey,
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
export async function updateLLMConfig(newConfig) {
  Object.assign(config.llm, newConfig);
  currentLLM = null;
  currentConfig = null;
  cachedDBConfig = null; // 清除缓存

  // 保存到数据库
  try {
    const { saveLLMConfig } = await import('./dbService.js');
    await saveLLMConfig(newConfig);
  } catch (error) {
    console.error('保存 LLM 配置到数据库失败:', error.message);
    // 不抛出异常，内存配置已更新
  }

  return config.llm;
}

/**
 * 获取当前 LLM 配置（优先从数据库读取）
 */
export async function getLLMConfig() {
  try {
    const dbConfig = await getLLMConfigFromDB();

    const merged = {
      provider: dbConfig?.provider ?? config.llm.provider,
      deepseek: { ...(config.llm.deepseek || {}), ...(dbConfig?.deepseek || {}) },
      openai: { ...(config.llm.openai || {}), ...(dbConfig?.openai || {}) },
      custom: { ...(config.llm.custom || {}), ...(dbConfig?.custom || {}) },
    };

    return {
      provider: merged.provider,
      deepseek: { ...merged.deepseek, apiKey: merged.deepseek.apiKey ? '***' : '' },
      openai: { ...merged.openai, apiKey: merged.openai.apiKey ? '***' : '' },
      custom: { ...merged.custom, apiKey: merged.custom.apiKey ? '***' : '' },
    };
  } catch (error) {
    console.warn('从数据库读取 LLM 配置失败（getLLMConfig）:', error.message);
    return {
      provider: config.llm.provider,
      deepseek: { ...config.llm.deepseek, apiKey: config.llm.deepseek.apiKey ? '***' : '' },
      openai: { ...config.llm.openai, apiKey: config.llm.openai.apiKey ? '***' : '' },
      custom: { ...config.llm.custom, apiKey: config.llm.custom.apiKey ? '***' : '' },
    };
  }
}

export default { getLLM, updateLLMConfig, getLLMConfig, initLLMConfig };
