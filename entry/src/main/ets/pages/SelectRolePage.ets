import { router, promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SelectRolePage {
  build() {
    Stack() {
      // Background Hologram/Ambient Blurs (matching WelcomePage stops at 0.5 opacity)
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

      // Main Scrollable Content Layer
      Column() {
        // 1. Header Section
        Row() {
          // Left: Brand Logo Icon (Navigates back to WelcomePage on click)
          Row() {
            Text('🛡️')
              .fontSize(20)
              .fontColor(Color.White)
          }
          .width(42)
          .height(42)
          .backgroundColor('#003D9B')
          .borderRadius(21)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .shadow({ radius: 6, color: 'rgba(0, 61, 155, 0.15)', offsetX: 0, offsetY: 3 })
          .onClick(() => {
            router.back()
          })

          // Center: Brand Title
          Text('GuardianBand')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')

          // Right: Placeholder to keep the title perfectly centered
          Row()
            .width(42)
            .height(42)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 30, bottom: 20 })

        // 2. Page Title Section
        Column() {
          Text('Welcome')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Text('Please select your primary role to customize your safety experience.')
            .fontSize(16)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .lineHeight(24)
            .width('95%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 30 })

        // 3. Selection Cards List
        Column() {
          // Card 1: Patient
          Row() {
            // Icon
            Row() {
              Text('🚶')
                .fontSize(24)
            }
            .width(56)
            .height(56)
            .backgroundColor('#E8EEFF')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16 })

            // Content
            Column() {
              Text('Patient')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 4 })
              Text('Monitor your health and receive medication reminders.')
                .fontSize(14)
                .fontColor('#434654')
                .lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 16 })
          .onClick(() => {
            promptAction.showToast({ message: 'Patient role selected! Registration complete.' })
          })

          // Card 2: Family Member
          Row() {
            // Icon
            Row() {
              Text('👥')
                .fontSize(24)
            }
            .width(56)
            .height(56)
            .backgroundColor('#E6F9ED')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16 })

            // Content
            Column() {
              Text('Family Member')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
                .margin({ bottom: 4 })
              Text("Stay informed about your loved one's health and receive emergency alerts.")
                .fontSize(14)
                .fontColor('#434654')
                .lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 16 })
          .onClick(() => {
            promptAction.showToast({ message: 'Family Member role selected! Registration complete.' })
          })

          // Card 3: Emergency Responder
          Row() {
            // Icon
            Row() {
              Text('🩹')
                .fontSize(24)
            }
            .width(56)
            .height(56)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16 })

            // Content
            Column() {
              Text('Emergency Responder')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8C0013')
                .margin({ bottom: 4 })
              Text('Access emergency medical information securely using QR code verification.')
                .fontSize(14)
                .fontColor('#434654')
                .lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 16 })
          .onClick(() => {
            promptAction.showToast({ message: 'Emergency Responder role selected! Registration complete.' })
          })
        }
        .width('100%')
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
