import { router } from '@kit.ArkUI';

@Entry
@Component
struct WelcomePage {
  build() {
    Stack() {
      // Background Hologram/Ambient Blurs (Balanced Brand Navy & Red)
      Row()
        .width(500)
        .height(500)
        .position({ x: -200, y: -200 })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 250,
          colors: [
            ['rgba(0, 61, 155, 0.20)', 0.0],
            ['rgba(0, 61, 155, 0.0)', 1.0]
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
            ['rgba(227, 27, 35, 0.18)', 0.0],
            ['rgba(227, 27, 35, 0.0)', 1.0]
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
            ['rgba(0, 61, 155, 0.10)', 0.0],
            ['rgba(0, 61, 155, 0.0)', 1.0]
          ]
        })

      // Main Content Layer
      Column() {
        Blank() // Pushes logo and welcome content down towards the buttons

        // 1. Centered Logo Section
        Row() {
          Image($r('app.media.logo'))
            .width(230)
            .height(230)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        // 2. Welcome Message Section
        Column() {
          // Headline
          Text('Welcome to\nGuardianBand')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .textAlign(TextAlign.Center)
            .lineHeight(40)
            .margin({ bottom: 18 })

          // Subtitle
          Text('Monitor your health, stay connected, and receive AI-powered healthcare assistance.')
            .fontSize(15)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .width('88%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 12 })

        Blank() // Flexible space between welcome content and action buttons

        // 3. Action Buttons Section
        Column() {
          // Login Button
          Button('Login')
            .width('100%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0, 61, 155, 0.25)', offsetX: 0, offsetY: 5 })
            .margin({ bottom: 16 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' })
            })

          // Create Account Button
          Button('Create Account')
            .width('100%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .backgroundColor(Color.White)
            .borderRadius(16)
            .border({ width: 2, color: '#C3C6D6', style: BorderStyle.Solid })
            .margin({ bottom: 24 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/RegisterPage' })
            })

          // Privacy and Terms Note
          Text() {
            Span('By continuing, you agree to our ')
              .fontSize(12)
              .fontColor('#737685')
            Span('Terms of Service')
              .fontSize(12)
              .fontColor('#003D9B')
              .decoration({ type: TextDecorationType.Underline, color: '#003D9B' })
            Span(' and ')
              .fontSize(12)
              .fontColor('#737685')
            Span('Privacy Policy')
              .fontSize(12)
              .fontColor('#003D9B')
              .decoration({ type: TextDecorationType.Underline, color: '#003D9B' })
            Span('.')
              .fontSize(12)
              .fontColor('#737685')
          }
          .textAlign(TextAlign.Center)
          .width('90%')
        }
        .width('100%')
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