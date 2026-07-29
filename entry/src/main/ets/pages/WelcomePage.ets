import { router } from '@kit.ArkUI';

@Entry
@Component
struct WelcomePage {
  build() {
    Stack() {
      // Background Hologram/Ambient Blurs (Using radial gradients to prevent jagged/clipped edges)
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

      // Main Content Layer
      Column() {
        // 1. Header/Brand Section
        Row() {
          Row() {
            Text('<')
              .fontSize(22)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 2 }) // subtle optical alignment
          }
          .width(42)
          .height(42)
          .backgroundColor('#003D9B')
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })

          Text('GuardianBand')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .margin({ left: 10 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 30 })

        Blank() // Pushes welcome content to the vertical center area

        // 2. Welcome Message Section
        Column() {
          // Trusted badge
          Row() {
            Text('Trusted Healthcare Monitoring')
              .fontSize(14)
              .fontColor('#0040A2')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#E8EEFF') // Soft primary tinted background
          .borderRadius(20)
          .border({ width: 1, color: '#B2C5FF', style: BorderStyle.Solid })
          .margin({ bottom: 24 })

          // Headline
          Text('Welcome to\nGuardianBand')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .textAlign(TextAlign.Center)
            .lineHeight(42)
            .margin({ bottom: 16 })

          // Subtitle
          Text('Monitor your health, stay connected, and receive AI-powered healthcare assistance.')
            .fontSize(16)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .lineHeight(24)
            .width('90%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Blank() // Pushes button section to the bottom

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
