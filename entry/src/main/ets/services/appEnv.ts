// entry/src/main/ets/services/appEnv.ts
// 统一存放应用级路径；带日志，避免多实例/路径不一致
// 不依赖 SDK 的命名类型，避免打包期类型冲突
import { Logger } from '../utils/Logger';
const logger = new Logger('AppEnv');
/** 轻量上下文：只关注我们需要的字段 */
export interface LiteContext {
  filesDir?: string
  getFilesDir?: () => string
}

/** Ability 上下文里我们会缓存的一些目录 */
export interface AbilityCtx {
  filesDir?: string
  cacheDir?: string
  tempDir?: string
}

let _ability: AbilityCtx | undefined

/**
 * 返回应用 files 目录（优先使用传入 ctx，其次使用缓存的 Ability 上下文，最后保守兜底）
 * 说明：
 * - ArkTS 检查要求避免 any/unknown，这里只使用显式接口字段
 * - 不使用 SDK 命名导入，规避 “only refers to a type” 类错误
 */
export function appFilesDir(ctx?: LiteContext | AbilityCtx): string {
  let fromArg: string | undefined

  if (ctx) {
    // 显式按 LiteContext 分支判断，避免在 AbilityCtx 上访问 getFilesDir
    const maybeLite = ctx as LiteContext
    if (typeof maybeLite.getFilesDir === 'function') {
      const v = maybeLite.getFilesDir()
      if (v) fromArg = String(v)
    }
    if (!fromArg && ctx.filesDir) {
      fromArg = String(ctx.filesDir)
    }
  }

  const fromCache = _ability?.filesDir ? String(_ability.filesDir) : undefined
  const fallback = '/data/storage/el2/base/files'
  const out = fromArg || fromCache || fallback

  logger.debug('appFilesDir ->', out);
  return out
}

/** 设置 Ability 上下文（在 EntryAbility.onCreate 等生命周期里调用一次） */
export function setAbilityContext(ctx: AbilityCtx): void {
  _ability = ctx
  logger.info('setAbilityContext', {
    filesDir: ctx.filesDir,
    cacheDir: ctx.cacheDir,
    tempDir: ctx.tempDir
  });
}

/** 读取已缓存的 Ability 上下文（可能为 undefined） */
export function getAbilityContext(): AbilityCtx | undefined {
  const has = _ability ? 'yes' : 'no'
  logger.debug('getAbilityContext called, has =', has);
  if (_ability) {
    logger.debug('current ctx', {
      filesDir: _ability.filesDir,
      cacheDir: _ability.cacheDir,
      tempDir: _ability.tempDir
    });
  }
  return _ability
}
