import web_webview from '@ohos.web.webview';
import { common } from '@kit.AbilityKit';
import { MapConstants, MapPosition } from '../../services/map/MapConfig';

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
            console.info(`[Map] Restoring position: ${this.lastX}, ${this.lastY}, ${this.lastZoom}`);
            this.controller.runJavaScript(`flyToPosition(${this.lastX}, ${this.lastY}, ${this.lastZoom})`);
          }, 200); // 稍微给一点时间让Leaflet初始化
        })
        .onConsole((event) => {
          const msg = event?.message.getMessage() || "";
          if (msg.startsWith("FromJS:")) {
            try {
              const jsonStr = msg.replace("FromJS:", "");
              const state = JSON.parse(jsonStr) as MapState;
              if (state.type === 'map_state') {
                // 收到 HTML 传来的新坐标，存入本地
                this.currentZoom = state.zoom;
                this.lastX = state.x;
                this.lastY = state.y;
                this.lastZoom = state.zoom;
              }
            } catch (e) {
              // ignore
            }
            return true;
          }
          return false;
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