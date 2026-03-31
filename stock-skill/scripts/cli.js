#!/usr/bin/env node
import { searchStock } from './searchStock.js';
import { getStockKline, calculateIndicators } from './kline.js';
import { getStockFundamental, getFinancialSummary } from './fundamental.js';
import { getAllSectors, getConceptSectors, getSectorStocks } from './sectors.js';
import { getStockNews } from './news.js';

const command = process.argv[2];
const args = process.argv.slice(3);

function parseArgs(args) {
  const result = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].slice(2);
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        result[key] = isNaN(next) ? next : Number(next);
        i++;
      } else {
        result[key] = true;
      }
    } else if (args[i].startsWith('-')) {
      const key = args[i].slice(1);
      const next = args[i + 1];
      if (next && !next.startsWith('-')) {
        result[key] = isNaN(next) ? next : Number(next);
        i++;
      }
    }
  }
  return result;
}

async function main() {
  const params = parseArgs(args);

  try {
    switch (command) {
      case 'search': {
        if (!params.keyword && args[0]) {
          params.keyword = args[0];
        }
        if (!params.keyword) {
          console.error('Usage: node cli.js search <keyword>');
          process.exit(1);
        }
        const result = await searchStock({ keyword: params.keyword });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case 'kline': {
        if (!params.code && args[0]) {
          params.code = args[0];
        }
        if (!params.code) {
          console.error('Usage: node cli.js kline <code> [--period daily|weekly|monthly] [--limit 60]');
          process.exit(1);
        }
        const klines = await getStockKline(params.code, params.period || 'daily', params.limit || 60);
        const indicators = calculateIndicators(klines);
        console.log(JSON.stringify({ klines: klines.slice(-20), indicators }, null, 2));
        break;
      }

      case 'fundamental':
      case 'fund': {
        if (!params.code && args[0]) {
          params.code = args[0];
        }
        if (!params.code) {
          console.error('Usage: node cli.js fundamental <code>');
          process.exit(1);
        }
        const fundamental = await getStockFundamental(params.code);
        const financial = await getFinancialSummary(params.code);
        console.log(JSON.stringify({ fundamental, financial }, null, 2));
        break;
      }

      case 'sectors': {
        const result = await getAllSectors();
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case 'concepts': {
        const result = await getConceptSectors();
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case 'sector-stocks': {
        if (!params.code && args[0]) {
          params.code = args[0];
        }
        if (!params.code) {
          console.error('Usage: node cli.js sector-stocks <sectorCode> [--limit 20]');
          process.exit(1);
        }
        const result = await getSectorStocks(params.code, params.limit || 20);
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case 'news': {
        if (!params.code && args[0]) {
          params.code = args[0];
        }
        if (!params.code) {
          console.error('Usage: node cli.js news <code> [--limit 10]');
          process.exit(1);
        }
        const result = await getStockNews({ code: params.code, limit: params.limit || 10 });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case 'help':
      case '--help':
      case '-h': {
        console.log(`
Stock CLI - 股票数据查询工具

Usage:
  node cli.js <command> [options]

Commands:
  search <keyword>          搜索股票
  kline <code>              获取K线数据
  fundamental <code>        获取基本面数据
  sectors                   获取行业板块列表
  concepts                  获取概念板块列表
  sector-stocks <code>      获取板块成分股
  news <code>               获取股票新闻

Options:
  --period <daily|weekly|monthly>  K线周期 (默认: daily)
  --limit <number>                  返回数量 (默认: 根据命令)
  --code <code>                    股票/板块代码
  --keyword <keyword>              搜索关键词

Examples:
  node cli.js search 浦发银行
  node cli.js kline 600000 --period daily --limit 60
  node cli.js fund 600000
  node cli.js sectors
  node cli.js sector-stocks 881001 --limit 10
  node cli.js news 600000 --limit 5
`);
        break;
      }

      default:
        if (!command) {
          console.log('Stock CLI - 股票数据查询工具\n');
          console.log('Usage: node cli.js <command> [options]');
          console.log('Run "node cli.js help" for more information.');
        } else {
          console.error(`Unknown command: ${command}`);
          console.log('Run "node cli.js help" for usage information.');
          process.exit(1);
        }
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
