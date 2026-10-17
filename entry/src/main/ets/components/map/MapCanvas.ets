import { normalizeMapViewport, normalizeMapZoom, mapViewportScript } from '../../services/map/MapSettingsModel';
import { getTileCache } from '../../services/map/TileCachePlatform';
import { tileKey } from '../../services/map/TileCacheService';
// entry/src/main/ets/components/map/MapCanvas.ets
import web_webview from '@ohos.web.webview';
import { common } from '@kit.AbilityKit';
import { MapConstants, MapPosition } from '../../services/map/MapConfig';
import { Logger } from '../../utils/Logger';

// 持久化存储 Key
PersistentStorage.persistProp('last_map_x', MapConstants.LiangXiang.x);
PersistentStorage.persistProp('last_map_y', MapConstants.LiangXiang.y);
PersistentStorage.persistProp('last_map_zoom', 16);

interface MapState {
  type: string;
  zoom: number;
  x: number;
  y: number;
}

@Component
export struct MapCanvas {
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  private logger = new Logger('MapCanvas');

  // 自动从存储中读取上次的位置
  @StorageLink('last_map_x') lastX: number = MapConstants.LiangXiang.x;
  @StorageLink('last_map_y') lastY: number = MapConstants.LiangXiang.y;
  @StorageLink('last_map_zoom') lastZoom: number = 16;

  private ready: boolean = false;
  private restoreViewport: string = '';
  private readonly context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  @State currentZoom: number = 16;
  @State isSettingsOpen: boolean = false;

  aboutToAppear() {
    const viewport = normalizeMapViewport({ x: this.lastX, y: this.lastY, zoom: this.lastZoom });
    this.lastX = viewport.x; this.lastY = viewport.y; this.lastZoom = viewport.zoom;
    this.currentZoom = viewport.zoom;
    this.restoreViewport = mapViewportScript(viewport);
  }

  async goToLocation(pos: MapPosition): Promise<void> {
    if (!this.ready) return;
    try {
      await this.controller.runJavaScript(mapViewportScript({ x: pos.x, y: pos.y, zoom: 16 }));
    } catch (error) { this.logger.error('Move map failed', error); }
  }

  async setMapZoom(zoom: number): Promise<void> {
    if (!this.ready) return;
    try {
      await this.controller.runJavaScript('setZoom(' + normalizeMapZoom(zoom) + ')');
    } catch (error) { this.logger.error('Change map zoom failed', error); }
  }

  @Builder SettingsPanel() {
    Column() {
      Row() {
        Text(`地图缩放级别: ${this.currentZoom.toFixed(1)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button({ type: ButtonType.Circle }) {
          Text("×").fontSize(20).fontColor($r('sys.color.font_primary'))
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.isSettingsOpen = false)
      }
      .width('100%')
      .padding({ bottom: 20 })

      Text('改变地图显示范围；近期瓦片缓存保留 7 天，最多 10 MB')
        .fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ bottom: 8 })
      Row() {
        Text("1.0").fontSize(12).fontColor(Color.Gray)
        Slider({
          value: this.currentZoom,
          min: 1,
          max: 19,
          step: 0.1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.currentZoom = value;
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
              this.setMapZoom(value);
            }
          })
        Text("19.0").fontSize(12).fontColor(Color.Gray)
      }
    }
    .padding(20)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .width('100%')
    .constraintSize({ minHeight: 180 })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Web({
        src: $rawfile('map.html'),
        controller: this.controller
      })
        .domStorageAccess(true)
        .databaseAccess(true)
        .imageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.None)
        .zoomAccess(true)
        .cacheMode(CacheMode.None)
        .onPageBegin(() => { this.ready = false; })
        .onControllerAttached(() => {
          this.controller.setCustomUserAgent("BIT101 " + this.controller.getUserAgent());
        })
        .onPageEnd(() => {
          this.controller.runJavaScript(this.restoreViewport)
            .then(() => { this.ready = true; })
            .catch((error: Error) => { this.logger.error('Restore map viewport failed', error); });
        })
        .onInterceptRequest((event) => {
          if (!event || event.request.getRequestMethod() !== 'GET' || !tileKey(event.request.getRequestUrl())) return null;
          const response = new WebResourceResponse();
          response.setResponseIsReady(false);
          getTileCache(this.context).get(event.request.getRequestUrl()).then((data: ArrayBuffer) => {
            response.setResponseData(data);
            response.setResponseMimeType('image/png');
            response.setResponseCode(200); response.setReasonMessage('OK');
          }).catch(() => {
            response.setResponseData('');
            response.setResponseCode(503); response.setReasonMessage('Tile unavailable');
          }).finally(() => { response.setResponseIsReady(true); });
          return response;
        })
        .onConsole((event) => {
          const msg = event?.message.getMessage() || "";

          // ---------------------------------------------------------
          // 1. 优先处理地图通信逻辑（保持原有逻辑不变）
          // ---------------------------------------------------------
          if (msg.startsWith("FromJS:")) {
            try {
              const jsonStr = msg.replace("FromJS:", "");
              const state = JSON.parse(jsonStr) as MapState;
              if (state.type === 'map_state' && this.ready) {
                const viewport = normalizeMapViewport(state);
                this.currentZoom = viewport.zoom;
                this.lastX = viewport.x; this.lastY = viewport.y; this.lastZoom = viewport.zoom;
                this.restoreViewport = mapViewportScript(viewport);
              }
            } catch (e) {
              // 建议这里也打印一下，万一 JSON 解析失败能看见
              this.logger.error('解析地图状态失败:', e);
            }
            // 返回 true 表示“即使拦截了，不再通过系统默认方式打印”，保持控制台干净
            return true;
          }

          // ---------------------------------------------------------
          // 2. 新增：转发网页普通日志到你的 Logger
          // ---------------------------------------------------------
          // 这样你搜 Tag "BIT101" 时，也能看到网页内部的报错或打印
          // 还可以根据 level 判断是调用 info 还是 error
          const level = event?.message.getMessageLevel();

          if (level === 3) { // 3 代表 Error 级别
            this.logger.error('[Web]', msg);
          } else {
            this.logger.info('[Web]', msg);
          }

          // 返回 false 表示允许系统默认打印（双重保险），
          // 或者返回 true 表示完全接管（Log 面板只有你的 BIT101_MapCanvas）
          return true;
        })
        .width('100%')
        .height('100%')

      Column({ space: 15 }) {
        Button({ type: ButtonType.Circle }) {
          Text("设").fontColor(Color.White).fontSize(16)
        }
        .width(50).height(50).backgroundColor('#6200EE')
        .bindSheet($$this.isSettingsOpen, this.SettingsPanel(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          backgroundColor: $r('sys.color.ohos_id_color_background')
        })
        .onClick(() => this.isSettingsOpen = true)

        Button({ type: ButtonType.Circle }) {
          Text("乡").fontColor(Color.White).fontSize(16)
        }
        .width(50).height(50).backgroundColor('#03DAC6')
        .onClick(() => this.goToLocation(MapConstants.LiangXiang))

        Button({ type: ButtonType.Circle }) {
          Text("村").fontColor(Color.White).fontSize(16)
        }
        .width(50).height(50).backgroundColor('#018786')
        .onClick(() => this.goToLocation(MapConstants.ZhongGuanCun))
      }
      .padding({ right: 20, bottom: 50 })
    }
    .width('100%')
    .height('100%')
  }
}
