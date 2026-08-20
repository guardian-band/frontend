import { router, promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SelectRolePage {
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

      // Main Scrollable Content Layer
      Column() {
        // 1. Branding Header Section
        Column() {
          Image($r('app.media.logo_blank'))
            .width(70)
            .height(70)
            .objectFit(ImageFit.Contain)
            .margin({ top: 20, bottom: 12 })

          Text('GuardianBand')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .margin({ bottom: 8 })

          Text('Please select your primary role to customize your safety experience.')
            .fontSize(15)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .width('90%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 24 })

        // 3. Selection Cards List
        Column() {
          // Card 1: Patient
          Row() {
            // Icon
            Row() {
              Image($r('app.media.patient'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
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
            promptAction.showToast({ message: 'Patient role selected! Welcome to GuardianBand.' })
            router.pushUrl({
              url: 'pages/ProfileSetupPage',
              params: { role: 'patient' }
            }, (err) => {
              if (err) {
                promptAction.showToast({ message: `Routing Error: ${err.message}` })
                console.error(`Routing to ProfileSetupPage failed: ${err.code} - ${err.message}`)
              }
            })
          })

          // Card 2: Family Member
          Row() {
            // Icon
            Row() {
              Image($r('app.media.family'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
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
            promptAction.showToast({ message: 'Family Member role selected! Welcome to GuardianBand.' })
            router.pushUrl({
              url: 'pages/ProfileSetupPage',
              params: { role: 'family' }
            }, (err) => {
              if (err) {
                promptAction.showToast({ message: `Routing Error: ${err.message}` })
                console.error(`Routing to ProfileSetupPage failed: ${err.code} - ${err.message}`)
              }
            })
          })

          // Card 3: Doctor
          Row() {
            // Icon
            Row() {
              Image($r('app.media.doctor'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
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
              Text('Doctor')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 4 })
              Text("Monitor your patients' health and perform real-time check-ups.")
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
            promptAction.showToast({ message: 'Doctor role selected! Welcome to GuardianBand.' })
            router.pushUrl({
              url: 'pages/ProfileSetupPage',
              params: { role: 'doctor' }
            }, (err) => {
              if (err) {
                promptAction.showToast({ message: `Routing Error: ${err.message}` })
                console.error(`Routing to ProfileSetupPage failed: ${err.code} - ${err.message}`)
              }
            })
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
