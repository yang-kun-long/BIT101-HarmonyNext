// entry/src/main/ets/debug/DebugCase.ts
import { Logger } from '../utils/Logger';

export abstract class DebugCase {
  // 每个调试用例必须定义自己的名字
  abstract readonly name: string;

  // 核心运行逻辑
  abstract run(): Promise<void>;

  // 实例化 Logger，模块名统一为 "DebugCase"
  // 这样在 Log 面板里搜 "BIT101_DebugCase" 就能看到所有用例的日志
  private logger = new Logger('DebugCase');

  /**
   * 输出 Debug 日志
   * 场景：打印庞大的 API 响应数据、循环里的变量状态
   */
  protected logDebug(...args: unknown[]): void {
    this.logger.debug(`[${this.name}]`, ...args);
  }

  /**
   * 输出 Info 日志
   * 场景：用例开始、关键步骤完成、结果摘要
   */
  protected logInfo(...args: unknown[]): void {
    this.logger.info(`[${this.name}]`, ...args);
  }

  /**
   * 输出 Warn 日志
   * 场景：测试数据不完整、使用了默认值、非预期的轻微异常
   */
  protected logWarn(...args: unknown[]): void {
    this.logger.warn(`[${this.name}]`, ...args);
  }

  /**
   * 输出 Error 日志
   * 场景：断言失败、API 请求报错、流程中断
   */
  protected logError(...args: unknown[]): void {
    this.logger.error(`[${this.name}]`, ...args);
  }

  /**
   * 输出 Fatal 日志
   * 场景：严重的配置错误、环境缺失，导致测试无法进行
   */
  protected logFatal(...args: unknown[]): void {
    this.logger.fatal(`[${this.name}]`, ...args);
  }
}