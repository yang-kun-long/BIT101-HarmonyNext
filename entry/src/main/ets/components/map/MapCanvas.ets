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

  @State currentZoom: number = 16;
  @State isSettingsOpen: boolean = false;

  aboutToAppear() {
    this.currentZoom = this.lastZoom;
  }

  goToLocation(pos: MapPosition) {
    const zoom = 16;
    this.controller.runJavaScript(`flyToPosition(${pos.x}, ${pos.y}, ${zoom})`);
    this.currentZoom = zoom;
  }

  setMapZoom(zoom: number) {
    this.controller.runJavaScript(`setZoom(${zoom})`);
  }

  @Builder SettingsPanel() {
    Column() {
      Row() {
        Text(`缩放倍率: ${this.currentZoom.toFixed(1)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button({ type: ButtonType.Circle }) {
          Text("×").fontSize(20).fontColor(Color.Black)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.isSettingsOpen = false)
      }
      .width('100%')
      .padding({ bottom: 20 })

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
    .backgroundColor(Color.White)
    .width('100%')
    .height(150)
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
        .mixedMode(MixedMode.All)
        .zoomAccess(true)
        .cacheMode(CacheMode.Default)
        .onControllerAttached(() => {
          this.controller.setCustomUserAgent("BIT101 " + this.controller.getUserAgent());
        })
        .onPageEnd(() => {
          // 🔥 页面加载完毕，立即恢复上次位置
          // 这里不再需要注入 JS，因为 html 里已经写好了监听逻辑
          setTimeout(() => {
            this.logger.info('Restoring position:', this.lastX, this.lastY, this.lastZoom);
            this.controller.runJavaScript(`flyToPosition(${this.lastX}, ${this.lastY}, ${this.lastZoom})`);
          }, 200); // 稍微给一点时间让Leaflet初始化
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
              if (state.type === 'map_state') {
                this.currentZoom = state.zoom;
                this.lastX = state.x;
                this.lastY = state.y;
                this.lastZoom = state.zoom;
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
          backgroundColor: Color.White
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