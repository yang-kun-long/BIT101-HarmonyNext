// 统一存放应用级路径；带日志，避免多实例/路径不一致
export interface AbilityCtx {
  filesDir?: string;
  cacheDir?: string;
  tempDir?: string;
}

let _ability: AbilityCtx | undefined;

export function setAbilityContext(ctx: AbilityCtx): void {
  _ability = ctx;
  console.info('[AppEnv] setAbilityContext', JSON.stringify({
    filesDir: ctx.filesDir, cacheDir: ctx.cacheDir, tempDir: ctx.tempDir
  }));
}

export function getAbilityContext(): AbilityCtx | undefined {
  console.info('[AppEnv] getAbilityContext called, has=', _ability ? 'yes' : 'no');
  if (_ability) {
    console.info('[AppEnv] current ctx', JSON.stringify({
      filesDir: _ability.filesDir, cacheDir: _ability.cacheDir, tempDir: _ability.tempDir
    }));
  }
  return _ability;
}
