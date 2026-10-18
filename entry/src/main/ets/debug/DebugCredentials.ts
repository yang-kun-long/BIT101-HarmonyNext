import { fileIo } from '@kit.CoreFileKit';

interface DebugCredentials { TEST_USERNAME: string; TEST_PASSWORD: string; }
/** Explicit device-local fixture; no developer secrets are imported into app code. */
export function loadDebugCredentials(): DebugCredentials {
  if (AppStorage.get<boolean>('isDebugBuild') !== true) throw new Error('Debug credentials unavailable in release');
  const filesDir = AppStorage.get<string>('filesDir');
  if (!filesDir) throw new Error('Debug files directory is unavailable');
  const path = filesDir + '/debug-credentials.json';
  if (!fileIo.accessSync(path)) throw new Error('Provide device-local debug-credentials.json before running account debug cases');
  const value: DebugCredentials = JSON.parse(fileIo.readTextSync(path));
  if (!value || typeof value.TEST_USERNAME !== 'string' || typeof value.TEST_PASSWORD !== 'string') throw new Error('Invalid debug credential fixture');
  return value;
}
