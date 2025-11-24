// entry/src/main/ets/components/map/MapCanvas.ets

import web_webview from '@ohos.web.webview';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { MapConstants, MapPosition } from '../../services/map/MapConfig';
import { TileCacheService } from '../../services/map/TileCacheService';
import { createWebResourceResponse } from '../../services/map/WebShim';

interface MapState {
  type: string;
  zoom: number;
  lat: number;
  lng: number;
}

@Component
export struct MapCanvas {
  controller: web_webview.WebviewController = new web_webview.WebviewController();

  private cacheService: TileCacheService | null = null;

  @State currentZoom: number = 16;
  @State isSettingsOpen: boolean = false;

  aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext;
    this.cacheService = new TileCacheService(context);
  }

  /**
   * 跳转到预设位置（良乡 / 中关村等）
   */
  goToLocation(pos: MapPosition) {
    const zoom: number = 16; // 先固定 16，有需要可以根据 pos.scale 做映射
    this.controller.runJavaScript(`flyToPosition(${pos.x}, ${pos.y}, ${zoom})`);
    this.currentZoom = zoom;
  }

  /**
   * 通过 Slider 控制地图缩放
   */
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
          Text("×")
            .fontSize(20)
            .fontColor(Color.Black)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.isSettingsOpen = false)
      }
      .width('100%')
      .padding({ bottom: 20 })

      Row() {
        Text("1.0")
          .fontSize(12)
          .fontColor(Color.Gray)

        Slider({
          value: this.currentZoom,
          min: 1,
          max: 19,
          step: 0.1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .trackColor('#E0E0E0')
          .selectedColor('#6200EE')
          .onChange((value: number, mode: SliderChangeMode) => {
            this.currentZoom = value;
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
              this.setMapZoom(value);
            }
          })

        Text("19.0")
          .fontSize(12)
          .fontColor(Color.Gray)
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
        .zoomAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
        .onControllerAttached(() => {
          this.controller.setCustomUserAgent("BIT101 " + this.controller.getUserAgent());
        })
        // 🔥 核心逻辑：拦截 + 缓存
        .onInterceptRequest((event) => {
          if (!event) {
            return null;
          }

          const url: string = event.request.getRequestUrl();

          // 只拦截我们自己的瓦片服务
          if (url.includes('/tile/')) {

            const localPath = this.cacheService?.getLocalPath(url);

            if (localPath) {
              console.info('[Map] HIT local: ' + localPath);
              try {
                const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
                return createWebResourceResponse(file.fd);
              } catch (error) {
                const e = error as object;
                console.error('[Map] Read Error: ' + JSON.stringify(e));
                return null;
              }
            } else {
              console.info('[Map] MISS (Downloading): ' + url);
              this.cacheService?.downloadAndCache(url);
              return null;
            }
          }
          return null;
        })
        .onConsole((event) => {
          const msg: string = event?.message.getMessage() || "";
          if (msg.startsWith("FromJS:")) {
            try {
              const jsonStr: string = msg.replace("FromJS:", "");
              const state = JSON.parse(jsonStr) as MapState;
              if (state.type === 'map_state') {
                this.currentZoom = state.zoom;
              }
            } catch (_e) {
              // 忽略解析错误
            }
            return true;
          }
          return false;
        })
        .width('100%')
        .height('100%')

      Column({ space: 15 }) {
        // 设置按钮
        Button({ type: ButtonType.Circle }) {
          Text("设")
            .fontColor(Color.White)
            .fontSize(16)
        }
        .width(50)
        .height(50)
        .backgroundColor('#6200EE')
        .bindSheet($$this.isSettingsOpen, this.SettingsPanel(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          backgroundColor: Color.White
        })
        .onClick(() => this.isSettingsOpen = true)

        // 良乡
        Button({ type: ButtonType.Circle }) {
          Text("乡")
            .fontColor(Color.White)
            .fontSize(16)
        }
        .width(50)
        .height(50)
        .backgroundColor('#03DAC6')
        .onClick(() => this.goToLocation(MapConstants.LiangXiang))

        // 中关村
        Button({ type: ButtonType.Circle }) {
          Text("村")
            .fontColor(Color.White)
            .fontSize(16)
        }
        .width(50)
        .height(50)
        .backgroundColor('#018786')
        .onClick(() => this.goToLocation(MapConstants.ZhongGuanCun))
      }
      .padding({ right: 20, bottom: 50 })
    }
    .width('100%')
    .height('100%')
  }
}
