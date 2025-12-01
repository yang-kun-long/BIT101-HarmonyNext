import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';

/**
 * A page that allows the user to add a marker to Huawei Map using the MapKit API.
 *
 * If you are using this template to create a custom page, you will need to sign into the
 * AppGallery Connect Console, create a new project, and enable the Map API Permission.
 */
@Entry
@Component
export default struct MapPage2 {
  private mapOptions?: mapCommon.MapOptions;
  private callback?: AsyncCallback<map.MapComponentController>;
  private mapController?: map.MapComponentController;

  aboutToAppear(): void {
    const target: mapCommon.LatLng = {
      latitude: 39.9181,
      longitude: 116.3970193
    };
    const cameraPosition: mapCommon.CameraPosition = {
      target: target,
      zoom: 15
    };
    this.mapOptions = {
      position: cameraPosition
    };
    this.callback = (err: BusinessError | undefined, mapController: map.MapComponentController | undefined) => {
      if (!err) {
        this.mapController = mapController;
        const markerOptions: mapCommon.MarkerOptions = {
          position: {
            latitude: 39.9181,
            longitude: 116.3970193
          }
        };
        this.mapController?.addMarker(markerOptions).catch(() => {
          // handle error
        });
      }
    };
  }

  build() {
    Column() {
      MapComponent({ mapOptions: this.mapOptions, mapCallback: this.callback })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}