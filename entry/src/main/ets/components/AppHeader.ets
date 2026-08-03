import { router } from '@kit.ArkUI';

@Component
export struct AppHeader {
  @Prop title: string = '';

  build() {
    Row() {
      // Profile Avatar Button (Clickable to Profile Page)
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
      .margin({ right: 12 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ProfilePage' });
      })

      // Brand and Page Titles
      Column() {
        Text('GuardianBand')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#003D9B')
          .margin({ bottom: 4 })

        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 0, bottom: 5 })
  }
}