// entry/src/main/ets/services/map/TileCacheService.ts

import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
// 如果没有引入 BusinessError / HttpResponse，可以不加类型，直接用 (err, data) => { ... }

export class TileCacheService {
  private cacheDir: string;

  constructor(context: common.UIAbilityContext) {
    this.cacheDir = context.cacheDir + '/map_tiles';
    try {
      // 先试着 access 一下
      fileIo.accessSync(this.cacheDir);
    } catch (_e) {
      // 不存在就创建
      try {
        fileIo.mkdirSync(this.cacheDir);
        console.info('[TileCache] mkdir: ' + this.cacheDir);
      } catch (e2) {
        console.error('[TileCache] mkdir failed: ' + JSON.stringify(e2));
      }
    }
  }
  private exists(path: string): boolean {
    try {
      fileIo.accessSync(path);
      return true;
    } catch (_e) {
      return false;
    }
  }




  getFileName(url: string): string {
    const parts = url.split('/');
    if (parts.length >= 3) {
      const z = parts[parts.length - 3];
      const x = parts[parts.length - 2];
      const y = parts[parts.length - 1];
      return `tile_${z}_${x}_${y}`;
    }
    return 'temp_' + new Date().getTime();
  }

  getLocalPath(url: string): string | null {
    const fileName = this.getFileName(url);
    const filePath = `${this.cacheDir}/${fileName}`;

    if (!this.exists(filePath)) {
      return null;
    }

    try {
      const stat = fileIo.statSync(filePath);
      if (stat.size > 0) {
        console.info(`[TileCache] HIT: ${fileName}, size=${stat.size}`);
        return filePath;
      } else {
        fileIo.unlinkSync(filePath);
        return null;
      }
    } catch (e) {
      console.error('[TileCache] stat/unlink error: ' + JSON.stringify(e));
      return null;
    }
  }



  downloadAndCache(url: string) {
    const fileName = this.getFileName(url);
    const filePath = `${this.cacheDir}/${fileName}`;

    if (this.exists(filePath)) {
      try {
        const stat = fileIo.statSync(filePath);
        if (stat.size > 0) {
          console.info(`[TileCache] SKIP download, already cached: ${fileName}`);
          return;
        } else {
          fileIo.unlinkSync(filePath);
        }
      } catch (e) {
        console.error('[TileCache] pre-check stat/unlink error: ' + JSON.stringify(e));
      }
    }

    const req = http.createHttp();
    req.request(
      url,
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      },
      (err, data) => {
        try {
          if (!err && data && data.responseCode === 200) {
            const result = data.result as ArrayBuffer; // 直接强转，不再用 instanceof

            if (result && result.byteLength > 0) {
              const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
              fileIo.writeSync(file.fd, result);
              fileIo.closeSync(file);

              const stat = fileIo.statSync(filePath);
              console.info(
                `[TileCache] Downloaded & Saved: ${fileName}, size=${stat.size}`
              );
            } else {
              console.error(
                `[TileCache] Empty result for url=${url}, responseCode=${data.responseCode}`
              );
            }
          } else {
            console.error(
              `[TileCache] Http error for ${url}: err=${JSON.stringify(err)}, code=${data?.responseCode}`
            );
          }
        } catch (e) {
          console.error('[TileCache] Write error: ' + JSON.stringify(e));
        } finally {
          req.destroy();
        }
      }
    );
  }
}
