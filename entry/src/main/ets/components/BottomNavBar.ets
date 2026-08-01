import { router } from '@kit.ArkUI';

@Component
export struct BottomNavBar {
  @Prop activeTab: string = 'home';

  build() {
    Row() {
      // Home Tab
      Column() {
        Text('🏡').fontSize(24).margin({ bottom: 4 })
        Text('Home')
          .fontSize(12)
          .fontWeight(this.activeTab === 'home' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'home' ? '#003D9B' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.activeTab === 'home' ? '#E8EEFF' : Color.Transparent)
      .borderRadius(16)
      .height('100%')
      .onClick(() => {
        if (this.activeTab !== 'home') {
          router.pushUrl({ url: 'pages/HomePage' });
        }
      })

      // Meds Tab (İlaç Sayfasına Geçiş Yapar!)
      Column() {
        Text('💊').fontSize(24).margin({ bottom: 4 })
        Text('Meds')
          .fontSize(12)
          .fontWeight(this.activeTab === 'meds' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'meds' ? '#003D9B' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.activeTab === 'meds' ? '#E8EEFF' : Color.Transparent)
      .borderRadius(16)
      .height('100%')
      .onClick(() => {
        if (this.activeTab !== 'meds') {
          router.pushUrl({ url: 'pages/MedsPage' });
        }
      })

      // SOS Tab
      Column() {
        Text('⚠️').fontSize(24).margin({ bottom: 4 })
        Text('SOS')
          .fontSize(12)
          .fontWeight(this.activeTab === 'sos' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'sos' ? '#8C0013' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .height('100%')

      // Profile Tab
      Column() {
        Text('👤').fontSize(24).margin({ bottom: 4 })
        Text('Profile')
          .fontSize(12)
          .fontWeight(this.activeTab === 'profile' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'profile' ? '#003D9B' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .height('100%')
    }
    .width('100%')
    .height(80)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 32, topRight: 32 })
    .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.05)', offsetY: -5 })
    .padding({ left: 12, right: 12, bottom: 10, top: 10 })
  }
}