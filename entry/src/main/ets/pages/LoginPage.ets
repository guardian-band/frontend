import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';

@Entry
@Component
struct LoginPage {
  @State identifier: string = '';
  @State password: string = '';
  @State rememberMe: boolean = false;

  build() {
    Stack() {
      // Background Hologram/Ambient Blurs (matching 0.5 opacity)
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
            ['rgba(107, 255, 143, 0.5)', 0.0],
            ['rgba(107, 255, 143, 0.0)', 1.0]
          ]
        })

      Row()
        .width(400)
        .height(400)
        .position({ x: -150, y: '35%' })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 200,
          colors: [
            ['rgba(255, 218, 215, 0.5)', 0.0],
            ['rgba(255, 218, 215, 0.0)', 1.0]
          ]
        })

      // Content Container
      Column() {
        Blank() // Dynamic spacer for centering layout

        // 1. Branding Header
        Column() {
          Row() {
            Text('🛟')
              .fontSize(32)
              .fontColor(Color.White)
          }
          .width(64)
          .height(64)
          .backgroundColor('#003D9B')
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .rotate({ angle: 3 })
          .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 16 })

          Text('GuardianBand')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .margin({ bottom: 8 })

          Text('Compassionate monitoring and safety for your loved ones.')
            .fontSize(15)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .width('85%')
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 32 })

        // 2. Login Form Card (Glassmorphism look)
        Column() {
          // Email or Phone Number Input
          Column() {
            Text('Email or Phone Number')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 8 })

            Row() {
              Image($r('app.media.email'))
                .width(20)
                .height(20)
                .margin({ left: 16, right: 8 })

              TextInput({ placeholder: 'e.g. name@email.com', text: this.identifier })
                .placeholderColor('rgba(115, 118, 133, 0.5)')
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .height('100%')
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.identifier = value;
                })
            }
            .width('100%')
            .height(60)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)
            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Password Input
          Column() {
            Text('Password')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 8 })

            Row() {
              Image($r('app.media.password'))
                .width(20)
                .height(20)
                .margin({ left: 16, right: 8 })

              TextInput({ placeholder: '••••••••', text: this.password })
                .type(InputType.Password)
                .placeholderColor('rgba(115, 118, 133, 0.5)')
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .height('100%')
                .layoutWeight(1)
                .showPasswordIcon(true) // Uses the system's built-in interactive eye icon
                .onChange((value: string) => {
                  this.password = value;
                })
            }
            .width('100%')
            .height(60)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)
            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Remember Me & Forgot Password
          Row() {
            // Remember Me Checkbox
            Row() {
              Checkbox({ name: 'rememberMe' })
                .select(this.rememberMe)
                .onChange((value: boolean) => {
                  this.rememberMe = value;
                })
                .width(20)
                .height(20)
                .margin({ right: 8 })

              Text('Remember Me')
                .fontSize(14)
                .fontColor('#434654')
            }
            .alignItems(VerticalAlign.Center)

            // Forgot Password Link
            Text('Forgot Password?')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .onClick(() => {
                promptAction.showToast({ message: 'Forgot password click handler' })
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 24, left: 4, right: 4 })

          // Login Button
          Button() {
            Row() {
              Text('Login')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ right: 8 })
              Text('➔')
                .fontSize(18)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .height(60)
          .backgroundColor('#003D9B')
          .borderRadius(16)
          .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
          .onClick(() => {
            if (!this.identifier || !this.password) {
              promptAction.showToast({ message: 'Please fill in all fields' })
            } else {
              ApiService.login(this.identifier, this.password)
                .then((token: string) => {
                  AppStorage.setOrCreate('token', token)
                  promptAction.showToast({ message: 'Logged in successfully!' })
                  router.pushUrl({ url: 'pages/HomePage' })
                })
                .catch((err: Error) => {
                  promptAction.showToast({ message: `Login Failed: ${err.message}` })
                })
            }
          })
        }
        .width('100%')
        .padding(24)
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .borderRadius(32)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
        .shadow({ radius: 15, color: 'rgba(0, 61, 155, 0.08)', offsetX: 0, offsetY: 4 })

        Blank() // Dynamic spacer for centering layout

        // 3. Footer Link (Don't have an account? Create one)
        Row() {
          Text("Don't have an account? ")
            .fontSize(15)
            .fontColor('#434654')

          Text('Create one')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .onClick(() => {
              router.pushUrl({ url: 'pages/RegisterPage' })
            })
        }
        .margin({ bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA') // Base background color under blurs
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
