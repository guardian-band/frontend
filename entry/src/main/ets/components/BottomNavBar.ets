import { router, promptAction } from '@kit.ArkUI';

@Component
export struct BottomNavBar {
  @Prop activeTab: string = 'home';
  @StorageLink('userRole') userRole: string = 'patient';

  build() {
    Row() {
      // Home Tab
      Column() {
        Image($r('app.media.dashboard'))
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 4 })
        Text('Home')
          .fontSize(13)
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
          router.pushUrl({ url: 'pages/HomePage' }, (err) => {
            if (err) {
              promptAction.showToast({ message: `Routing Error: ${err.message}` })
              console.error(`Routing to HomePage failed: ${err.code} - ${err.message}`)
            }
          });
        }
      })

      // Meds Tab (navigates to the medications page)
      if (this.userRole === 'patient') {
        Column() {
          Image($r('app.media.medicine'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 4 })
          Text('Meds')
            .fontSize(13)
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
            router.pushUrl({ url: 'pages/MedsPage' }, (err) => {
              if (err) {
                promptAction.showToast({ message: `Routing Error: ${err.message}` })
                console.error(`Routing to MedsPage failed: ${err.code} - ${err.message}`)
              }
            });
          }
        })
      }

      // Patients Tab (Doctor role only)
      if (this.userRole === 'doctor') {
        Column() {
          Image($r('app.media.patient'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 4 })
          Text('Patients')
            .fontSize(13)
            .fontWeight(this.activeTab === 'patients' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.activeTab === 'patients' ? '#003D9B' : '#737685')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.activeTab === 'patients' ? '#E8EEFF' : Color.Transparent)
        .borderRadius(16)
        .height('100%')
        .onClick(() => {
          if (this.activeTab !== 'patients') {
            router.pushUrl({ url: 'pages/PatientsPage' }, (err) => {
              if (err) {
                promptAction.showToast({ message: `Routing Error: ${err.message}` })
                console.error(`Routing to PatientsPage failed: ${err.code} - ${err.message}`)
              }
            });
          }
        })
      }

      // SOS Tab
      Column() {
        Image($r('app.media.sos'))
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 4 })
        Text('SOS')
          .fontSize(13)
          .fontWeight(this.activeTab === 'sos' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'sos' ? '#8C0013' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.activeTab === 'sos' ? '#FFEBEA' : Color.Transparent)
      .borderRadius(16)
      .height('100%')
      .onClick(() => {
        if (this.activeTab !== 'sos') {
          router.pushUrl({ url: 'pages/SOSPage' }, (err) => {
            if (err) {
              promptAction.showToast({ message: `Routing Error: ${err.message}` })
              console.error(`Routing to SOSPage failed: ${err.code} - ${err.message}`)
            }
          });
        }
      })

      // Profile Tab
      Column() {
        Image($r('app.media.profile'))
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 4 })
        Text('Profile')
          .fontSize(13)
          .fontWeight(this.activeTab === 'profile' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === 'profile' ? '#003D9B' : '#737685')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.activeTab === 'profile' ? '#E8EEFF' : Color.Transparent)
      .borderRadius(16)
      .height('100%')
      .onClick(() => {
        if (this.activeTab !== 'profile') {
          router.pushUrl({ url: 'pages/ProfilePage' }, (err) => {
            if (err) {
              promptAction.showToast({ message: `Routing Error: ${err.message}` })
              console.error(`Routing to ProfilePage failed: ${err.code} - ${err.message}`)
            }
          });
        }
      })
    }
    .width('100%')
    .height(88)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 32, topRight: 32 })
    .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.05)', offsetY: -5 })
    .padding({ left: 12, right: 12, bottom: 10, top: 10 })
  }
}