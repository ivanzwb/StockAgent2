import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '../../.env') });

const config = {
  // 服务器配置
  server: {
    port: parseInt(process.env.PORT || '3000'),
    host: process.env.HOST || '0.0.0.0',
  },

  // LLM 配置
  llm: {
    provider: process.env.LLM_PROVIDER || 'deepseek',
    deepseek: {
      apiKey: process.env.DEEPSEEK_API_KEY || '',
      baseUrl: process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com',
      model: process.env.DEEPSEEK_MODEL || 'deepseek-chat',
    },
    openai: {
      apiKey: process.env.OPENAI_API_KEY || '',
      baseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
      model: process.env.OPENAI_MODEL || 'gpt-4o',
    },
    custom: {
      apiKey: process.env.CUSTOM_API_KEY || '',
      baseUrl: process.env.CUSTOM_BASE_URL || 'http://localhost:11434/v1',
      model: process.env.CUSTOM_MODEL || 'qwen2.5',
    },
  },

  // 监控配置
  monitor: {
    intervalMinutes: parseInt(process.env.MONITOR_INTERVAL_MINUTES || '30'),
    quantIntervalMinutes: parseInt(process.env.QUANT_INTERVAL_MINUTES || '5'),
  },

  // 数据库配置
  db: {
    path: join(__dirname, '../../data/lancedb'),
  },
};

export default config;
