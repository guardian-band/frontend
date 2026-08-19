import { router } from '@kit.ArkUI';

@Component
export struct AppHeader {
  @Prop title: string = '';
  onCameraClick: () => void = () => {};

  build() {
    Row() {
      // Logo Button (Clickable to Profile Page)
      Image($r('app.media.logo_blank'))
        .width(42)
        .height(42)
        .objectFit(ImageFit.Contain)
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