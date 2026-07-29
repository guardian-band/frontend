import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';

@Entry
@Component
struct HomePage {
  @State protectedResponse: string = 'Tap test below to verify authentication.';
  @State isLoading: boolean = false;
  @StorageProp('token') token: string = '';

  build() {
    Stack() {
      // Ambient Background Hologram Blurs
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
        .position({ x: '40%', y: '65%' })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 300,
          colors: [
            ['rgba(107, 255, 143, 0.4)', 0.0],
            ['rgba(107, 255, 143, 0.0)', 1.0]
          ]
        })

      Column() {
        // 1. Dashboard Header
        Row() {
          Column() {
            Text('GuardianBand')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 4 })

            Row() {
              Row()
                .width(8)
                .height(8)
                .backgroundColor('#31C48D')
                .borderRadius(4)
                .margin({ right: 6 })
              Text('Connected to Server')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#434654')
            }
          }
          .alignItems(HorizontalAlign.Start)

          // Avatar placeholder
          Row() {
            Text('🛡️')
              .fontSize(22)
          }
          .width(48)
          .height(48)
          .backgroundColor('rgba(0, 61, 155, 0.08)')
          .borderRadius(24)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ top: 30, bottom: 20 })

        // 2. Main Welcome Card
        Column() {
          Text('Welcome Home!')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Text('Your GuardianBand profile is active. Sensorial vitals, step triggers, and clinical metrics are securely linked to your profile.')
            .fontSize(14)
            .fontColor('#434654')
            .lineHeight(20)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(24)
        .backgroundColor(Color.White)
        .borderRadius(28)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.03)', offsetX: 0, offsetY: 4 })
        .margin({ bottom: 20 })

        // 3. API Test Connection Card
        Column() {
          Text('Security Status & API Verification')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          // Token display info
          Row() {
            Text('JWT Status:')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .margin({ right: 6 })

            Text(this.token ? 'Loaded in Storage ✅' : 'No Token Found ❌')
              .fontSize(13)
              .fontColor(this.token ? '#006E2F' : '#8C0013')
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .margin({ bottom: 12 })

          // Response Area
          Column() {
            Text('Server Response:')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#737685')
              .margin({ bottom: 4 })
              .alignSelf(ItemAlign.Start)

            Text(this.protectedResponse)
              .fontSize(14)
              .fontColor('#191C1D')
              .fontWeight(FontWeight.Medium)
              .lineHeight(18)
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F3F4F5')
          .borderRadius(16)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
          .margin({ bottom: 16 })

          // Test Button
          Button() {
            Row() {
              if (this.isLoading) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(Color.White)
                  .margin({ right: 8 })
              }
              Text(this.isLoading ? 'Testing...' : 'Test Protected Connection')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
          }
          .width('100%')
          .height(48)
          .backgroundColor(this.token ? '#003D9B' : '#737685')
          .borderRadius(12)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.isLoading = true;
            this.protectedResponse = 'Contacting server...';

            ApiService.get('/api/protected', this.token)
              .then((res: string) => {
                this.protectedResponse = res;
                promptAction.showToast({ message: 'Authentication verified!' });
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
