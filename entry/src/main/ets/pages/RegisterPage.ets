import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';

@Entry
@Component
struct RegisterPage {
  // Input fields state
  @State fullName: string = '';
  @State phone: string = '';
  @State password: string = '';
  @State selectedRole: string = 'patient';

  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params.role) {
      this.selectedRole = params.role;
    }
  }

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

      // Main Scrollable Area
      Scroll(this.scroller) {
        Column() {
          // 1. Branding Header
          Column() {
            Image($r('app.media.logo_blank'))
              .width(70)
              .height(70)
              .objectFit(ImageFit.Contain)
              .margin({ top: 20, bottom: 16 })

            Text('GuardianBand')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 8 })

            Text('Compassionate reliability for your loved ones.')
              .fontSize(15)
              .fontColor('#434654')
              .textAlign(TextAlign.Center)
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 24 })

          // 2. Create Account Card
          Column() {
            // Title
            Column() {
              Text('Create Account')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 6 })

              Text('Start your journey toward safer care today.')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#434654')
                .margin({ bottom: 16 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // Full Name Input
            Column() {
              Text('Full Name')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Image($r('app.media.name'))
                  .width(20)
                  .height(20)
                  .margin({ left: 16, right: 8 })

                TextInput({ placeholder: 'John Doe', text: this.fullName })
                  .placeholderColor('rgba(115, 118, 133, 0.5)')
                  .fontSize(16)
                  .backgroundColor(Color.Transparent)
                  .height('100%')
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.fullName = value;
                  })
              }
              .width('100%')
              .height(56)
              .backgroundColor('#F3F4F5')
              .borderRadius(16)
              .alignItems(VerticalAlign.Center)
              .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Phone Number Input
            Column() {
              Text('Phone Number')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Image($r('app.media.phone'))
                  .width(20)
                  .height(20)
                  .margin({ left: 16, right: 8 })

                TextInput({ placeholder: '+90 (555) 000 0000', text: this.phone })
                  .type(InputType.PhoneNumber)
                  .placeholderColor('rgba(115, 118, 133, 0.5)')
                  .fontSize(16)
                  .backgroundColor(Color.Transparent)
                  .height('100%')
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.phone = value;
                  })
              }
              .width('100%')
              .height(56)
              .backgroundColor('#F3F4F5')
              .borderRadius(16)
              .alignItems(VerticalAlign.Center)
              .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Password Input
            Column() {
              Text('Password')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Image($r('app.media.password'))
                  .width(23)
                  .height(23)
                  .margin({ left: 16, right: 8 })

                TextInput({ placeholder: '••••••••', text: this.password })
                  .type(InputType.Password)
                  .placeholderColor('rgba(115, 118, 133, 0.5)')
                  .fontSize(16)
                  .backgroundColor(Color.Transparent)
                  .height('100%')
                  .layoutWeight(1)
                  .showPasswordIcon(true)
                  .onChange((value: string) => {
                    this.password = value;
                  })
              }
              .width('100%')
              .height(56)
              .backgroundColor('#F3F4F5')
              .borderRadius(16)
              .alignItems(VerticalAlign.Center)
              .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 24 })

            // Continue Button
            Button() {
              Row() {
                Text('Continue')
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
            .height(56)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
            .onClick(() => {
              if (!this.fullName || !this.phone || !this.password) {
                promptAction.showToast({ message: 'Please fill in all fields' })
              } else {

                ApiService.register(this.phone, this.password)
                  .then(() => {
                    // BAŞARILI KAYIT ÇIKTISI
                    console.log("\n==================================================");
                    console.log("[API EXECUTION] POST /api/register - CREATED: Resource was successfully registered or created. (Code: 201)");
                    console.log("==================================================\n");

                    // Auto-login after successful registration to retrieve the JWT token
                    return ApiService.login(this.phone, this.password);
                  })
                  .then((token: string) => {
                    // BAŞARILI GİRİŞ ÇIKTISI
                    console.log("\n==================================================");
                    console.log("[API EXECUTION] POST /api/login - SUCCESS: Operation completed successfully. (Code: 200)");
                    console.log("==================================================\n");

                    AppStorage.setOrCreate('token', token);
                    AppStorage.setOrCreate('fullName', this.fullName);
                    AppStorage.setOrCreate('userPhone', this.phone);
                    AppStorage.setOrCreate('userRole', 'patient');
                    AppStorage.setOrCreate('doctorProfile', { hospital: '', specialty: '', email: '', isVerified: false });
                    promptAction.showToast({ message: 'Registered and logged in successfully!' })
                    router.pushUrl({ url: 'pages/SelectRolePage' })
                  })
                  .catch((err: Error) => {
                    // HATALI KAYIT ÇIKTISI
                    console.log("\n==================================================");
                    console.log("[API EXECUTION] POST /api/register - BAD REQUEST: Registration failed. (Code: 400)");
                    console.log("==================================================\n");

                    promptAction.showToast({ message: `Registration Failed: ${err.message}` })
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
          .margin({ bottom: 20 })

          // 3. Footer Link (Already have an account? Log in)
          Row() {
            Text('Already have an account? ')
              .fontSize(15)
              .fontColor('#434654')

            Text('Log in')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .onClick(() => {
                router.pushUrl({ url: 'pages/LoginPage' })
              })
          }
          .margin({ bottom: 20 })

          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 20 })
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA') // Base background color under blurs
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}