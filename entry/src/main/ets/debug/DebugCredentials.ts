import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

interface DebugCredentials { TEST_USERNAME: string; TEST_PASSWORD: string; }
/** Explicit device-local fixture; no developer secrets are imported into app code. */
export function loadDebugCredentials(): DebugCredentials {
  const context = getContext() as common.UIAbilityContext;
  if (!context.applicationInfo.debug) throw new Error('Debug credentials unavailable in release');
  const path = context.filesDir + '/debug-credentials.json';
  if (!fileIo.accessSync(path)) throw new Error('Provide device-local debug-credentials.json before running account debug cases');
  const value: DebugCredentials = JSON.parse(fileIo.readTextSync(path));
  if (!value || typeof value.TEST_USERNAME !== 'string' || typeof value.TEST_PASSWORD !== 'string') throw new Error('Invalid debug credential fixture');
  return value;
}
