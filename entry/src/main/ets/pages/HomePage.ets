import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';

@Entry
@Component
struct HomePage {
  @StorageLink('token') token: string = '';
  @State protectedResponse: string = 'Click button below to load protected data.';
  @State isLoading: boolean = false;

  // Mock patient vital metrics
  @State heartRate: string = '74 bpm';
  @State stepCount: string = '8,432 steps';
  @State batteryLevel: string = '92%';
  @State deviceStatus: string = 'Connected';

  build() {
    Stack() {
      // Background Hologram/Ambient Blurs (0.5 opacity for consistency)
      Row()
        .width(500)
        .height(500)
        .position({ x: -200, y: -200 })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 250,
          colors: [
            ['rgba(218, 226, 255, 0.5)', 0.0],
            ['rgba(218, 226, 255, 0.0)', 1.0]
          ]
        })

      Row()
        .width(600)
        .height(600)
        .position({ x: '30%', y: '60%' })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 300,
          colors: [
            ['rgba(107, 255, 143, 0.5)', 0.0],
            ['rgba(107, 255, 143, 0.0)', 1.0]
          ]
        })

      Column() {
        // 1. Dashboard Header
        Row() {
          Column() {
            Text('Dashboard')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 4 })

            Text('GuardianBand Care')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // Profile Avatar Icon
          Row() {
            Text('👤')
              .fontSize(20)
          }
          .width(44)
          .height(44)
          .backgroundColor('rgba(0, 61, 155, 0.08)')
          .borderRadius(22)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .margin({ top: 20, bottom: 24 })

        // 2. Patient Device Status Card (Premium Glassmorphism)
        Column() {
          Row() {
            Column() {
              Text('Smart Band Status')
                .fontSize(14)
                .fontColor('#737685')
                .margin({ bottom: 4 })
              Text(this.deviceStatus)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Row() {
              Text('🔋')
                .fontSize(16)
                .margin({ right: 4 })
              Text(this.batteryLevel)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
            }
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Divider
          Row()
            .width('100%')
            .height(1)
            .backgroundColor('rgba(195, 198, 214, 0.3)')
            .margin({ bottom: 20 })

          // Vitals Grid
          Row() {
            // Heart Rate
            Column() {
              Text('❤️ Heart Rate')
                .fontSize(13)
                .fontColor('#737685')
                .margin({ bottom: 6 })
              Text(this.heartRate)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            // Steps
            Column() {
              Text('🚶 Daily Steps')
                .fontSize(13)
                .fontColor('#737685')
                .margin({ bottom: 6 })
              Text(this.stepCount)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .borderRadius(28)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
        .shadow({ radius: 12, color: 'rgba(0, 61, 155, 0.04)', offsetX: 0, offsetY: 4 })
        .margin({ bottom: 20 })

        // 3. API Integration Testing Card
        Column() {
          Text('Backend API Integration')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 6 })
            .alignSelf(ItemAlign.Start)

          Text('Tests secure connection to local Docker backend using Bearer token authentication.')
            .fontSize(13)
            .fontColor('#434654')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          // Request Status Response Container
          Column() {
            if (this.isLoading) {
              LoadingProgress()
                .width(40)
                .height(40)
                .color('#003D9B')
            } else {
              Text(this.protectedResponse)
                .fontSize(14)
                .fontColor('#003D9B')
                .textAlign(TextAlign.Start)
                .lineHeight(20)
            }
          }
          .width('100%')
          .height(100)
          .padding(16)
          .backgroundColor('#F3F4F5')
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 16 })

          // Connect API Trigger Button
          Button() {
            Text('Fetch Protected Data')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(48)
          .backgroundColor('#003D9B')
          .borderRadius(12)
          .onClick(() => {
            if (!this.token) {
              this.protectedResponse = 'No auth token found in AppStorage! Please log in first.';
              return;
            }
            this.isLoading = true;
            ApiService.getProtected(this.token)
              .then((result: string) => {
                this.protectedResponse = result;
                this.isLoading = false;
              })
              .catch((err: Error) => {
                this.protectedResponse = `Authentication Failed:\n${err.message}`;
                this.isLoading = false;
              });
          })
        }
        .width('100%')
        .padding(24)
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .borderRadius(28)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
        .shadow({ radius: 12, color: 'rgba(0, 61, 155, 0.04)', offsetX: 0, offsetY: 4 })
        .margin({ bottom: 24 })

        Blank()

        // 4. Sign Out Button
        Button('Sign Out')
          .width('100%')
          .height(56)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#8C0013')
          .backgroundColor('rgba(140, 0, 19, 0.08)')
          .borderRadius(16)
          .margin({ bottom: 20 })
          .onClick(() => {
            AppStorage.setOrCreate('token', '');
            promptAction.showToast({ message: 'Signed out successfully' });
            router.clear();
            router.replaceUrl({ url: 'pages/WelcomePage' });
          })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
