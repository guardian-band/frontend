import { customScan, scanBarcode, scanCore } from '@kit.ScanKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct CameraPage {
  private xcomponentController: XComponentController = new XComponentController();
  @State surfaceId: string = '';
  @State isPermissionGranted: boolean = false;
  @State statusMessage: string = 'Initializing camera...';
  @State isCameraActive: boolean = false;
  @State scanProgress: number = 0;
  private scanIntervalId: number = -1;

  aboutToAppear() {
    this.requestCameraPermission();
  }

  aboutToDisappear() {
    this.releaseCamera();
  }

  // Request runtime permission
  requestCameraPermission() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      
      this.statusMessage = 'Requesting camera permission...';
      
      atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA'])
        .then((result) => {
          if (result && result.authResults && result.authResults.length > 0 && result.authResults[0] === 0) {
            console.info('[CameraPage] Permission granted successfully.');
            this.isPermissionGranted = true;
            this.statusMessage = 'Permission granted. Preparing camera...';
            if (this.surfaceId) {
              this.initCamera();
            }
          } else {
            console.warn('[CameraPage] Camera permission was denied by the user.');
            this.isPermissionGranted = false;
            this.statusMessage = 'Camera permission denied. Grant permission in settings.';
            promptAction.showToast({ message: 'Camera permission denied. Please grant permission in settings.' });
          }
        })
        .catch((err: BusinessError) => {
          console.error('[CameraPage] Permission request failed: ' + JSON.stringify(err));
          this.statusMessage = 'Permission request error.';
        });
    } catch (e) {
      console.error('[CameraPage] Exception during permission request: ' + JSON.stringify(e));
      this.statusMessage = 'Failed to initialize permissions.';
    }
  }

  // Start laser line scanning animation
  startLaserAnimation() {
    this.stopLaserAnimation();
    this.scanIntervalId = setInterval(() => {
      this.scanProgress = (this.scanProgress + 2) % 100;
    }, 30);
  }

  // Stop laser animation
  stopLaserAnimation() {
    if (this.scanIntervalId !== -1) {
      clearInterval(this.scanIntervalId);
      this.scanIntervalId = -1;
    }
  }

  // Initialize Scan Kit and start scanning preview session
  async initCamera() {
    if (!this.isPermissionGranted) {
      console.warn('[CameraPage] initCamera called but permission not granted yet');
      return;
    }
    if (!this.surfaceId) {
      console.warn('[CameraPage] initCamera called but surfaceId not set yet');
      return;
    }

    await this.releaseCamera();

    try {
      this.statusMessage = 'Preparing scanner engine...';
      
      // Initialize scan options
      let options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false
      };
      
      customScan.init(options);
      
      // Prepare ViewControl matching emulator standard camera sizing
      let viewControl: customScan.ViewControl = {
        width: 1080,
        height: 1920,
        surfaceId: this.surfaceId
      };
      
      this.statusMessage = 'Camera live feed active';
      this.isCameraActive = true;
      this.startLaserAnimation();
      
      // Start customized scan
      customScan.start(viewControl)
        .then((result: Array<scanBarcode.ScanResult>) => {
          if (result && result.length > 0) {
            let qrCodeValue = result[0].originalValue;
            console.info('[CameraPage] QR Code scanned successfully: ' + qrCodeValue);
            
            // Store scanned result in AppStorage
            AppStorage.setOrCreate('scannedQrResult', qrCodeValue);
            
            promptAction.showToast({ message: 'QR Code Scanned!' });
            
            // Return to previous page
            this.navigateBack();
          }
        })
        .catch((err: BusinessError) => {
          console.error('[CameraPage] customScan.start failed: ' + err.message);
          this.statusMessage = `Error: ${err.message}`;
          this.isCameraActive = false;
          this.stopLaserAnimation();
        });
        
    } catch (err) {
      let error = err as Error;
      console.error('[CameraPage] Scan Kit initialization failed: ' + error.message);
      this.statusMessage = `Error: ${error.message}`;
      this.isCameraActive = false;
      this.stopLaserAnimation();
    }
  }

  // Stop session & clean up resources
  async releaseCamera() {
    this.stopLaserAnimation();
    try {
      this.isCameraActive = false;
      await customScan.stop();
      await customScan.release();
      console.info('[CameraPage] Scanner resources released successfully.');
    } catch (err) {
      let error = err as Error;
      console.error('[CameraPage] releaseCamera failed: ' + error.message);
    }
  }

  // Safely go back to the previous page
  async navigateBack() {
    await this.releaseCamera();
    try {
      router.back();
    } catch (e) {
      router.replaceUrl({ url: 'pages/WelcomePage' });
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. Light Ambient Background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F8F9FA')

      // 2. Main Page Layout Container
      Column() {
        // TOP HEADER BAR (Clean light design)
        Row() {
          Column() {
            Text('GuardianBand QR Scanner')
               .fontSize(22)
               .fontWeight(FontWeight.Bold)
               .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // "Go back" button
          Button('Go Back')
            .height(38)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#003D9B')
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.25)', offsetY: 2 })
            .onClick(() => {
              this.navigateBack();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 44, bottom: 20 })
        .backgroundColor(Color.White)
        .border({ width: { bottom: 1 }, color: '#E2E8F0' })

        // PREVIEW AREA CONTAINER
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            // Live Feed Surface via XComponent
            XComponent({
              id: 'camera_preview_xcomponent',
              type: XComponentType.SURFACE,
              controller: this.xcomponentController
            })
              .onLoad(() => {
                console.info('[CameraPage] XComponent loaded successfully.');
                this.surfaceId = this.xcomponentController.getXComponentSurfaceId();
                if (this.isPermissionGranted) {
                  this.initCamera();
                }
              })
              .width('100%')
              .height('100%')
              .borderRadius(24)

            // Scanning Target Box & Laser Line Overlay (Uses brand blue #003D9B instead of green)
            if (this.isCameraActive) {
              Stack({ alignContent: Alignment.Center }) {
                // Dimmed surrounding background overlay cutout simulated by absolute layout
                Column()
                  .width('100%')
                  .height('100%')
                  .backgroundColor('rgba(15, 23, 42, 0.4)')
                  .borderRadius(24)

                // Laser scanning box & text
                Column() {
                  Stack({ alignContent: Alignment.Top }) {
                    // Scanning square box
                    Column()
                      .width(280)
                      .height(280)
                      .border({ width: 2, color: '#003D9B', radius: 24, style: BorderStyle.Dashed })
                      .backgroundColor('rgba(0, 61, 155, 0.05)')

                    // Scanning Laser line animation
                    Row()
                      .width(240)
                      .height(3)
                      .backgroundColor('#003D9B')
                      .margin({ top: `${this.scanProgress}%` })
                      .shadow({ radius: 8, color: '#003D9B' })
                  }
                  .width(280)
                  .height(280)

                  Text('Position the smartwatch QR code inside the frame')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .margin({ top: 24 })
                    .shadow({ radius: 4, color: 'black' })
                }
              }
              .width('100%')
              .height('100%')
            }

            // Warning Overlay if permission not granted
            if (!this.isPermissionGranted) {
              Column() {
                Text('Camera Access Required')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .margin({ bottom: 12 })
                
                Text('Please grant camera permission to test the live scanner preview.')
                  .fontSize(13)
                  .fontColor('#64748B')
                  .textAlign(TextAlign.Center)
                  .width('80%')
                  .margin({ bottom: 24 })
                
                Button('Request Permission')
                  .width(140)
                  .height(44)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor('#003D9B')
                  .borderRadius(12)
                  .onClick(() => {
                    this.requestCameraPermission();
                  })
              }
              .width('100%')
              .height('100%')
              .backgroundColor('#F8F9FA')
              .justifyContent(FlexAlign.Center)
              .borderRadius(24)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .borderRadius(24)
          .border({ width: 1, color: '#E2E8F0' })
          .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.05)', offsetY: 4 })
          .backgroundColor(Color.White)
        }
        .padding({ left: 24, right: 24, top: 20, bottom: 20 })
        .layoutWeight(1)

        // BOTTOM CONTROLS PANEL
        Row() {
          Blank()
          
          Text('Automatic QR Code Scanner')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')
          
          Blank()
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 44 })
        .backgroundColor(Color.White)
        .border({ width: { top: 1 }, color: '#E2E8F0' })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
