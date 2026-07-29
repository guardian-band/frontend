import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';

@Entry
@Component
struct RegisterPage {
  // Input fields state
  @State fullName: string = '';
  @State email: string = '';
  @State phone: string = '';
  @State birthDate: string = '';
  @State selectedGender: string = 'Male';
  @State heightCm: string = '';
  @State weightKg: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
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

      // Main Scrollable Area
      Scroll(this.scroller) {
        Column() {
          // 1. Branding Header
          Column() {
            Text('GuardianBand')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 8, top: 20 })

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

            // Email Input
            Column() {
              Text('Email')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Image($r('app.media.email'))
                  .width(20)
                  .height(20)
                  .margin({ left: 16, right: 8 })

                TextInput({ placeholder: 'care@example.com', text: this.email })
                  .type(InputType.Email)
                  .placeholderColor('rgba(115, 118, 133, 0.5)')
                  .fontSize(16)
                  .backgroundColor(Color.Transparent)
                  .height('100%')
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.email = value;
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

            // Birth Date Input (Yaş için)
            Column() {
              Text('Birth Date (Age)')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Image($r('app.media.calendar'))
                  .width(20)
                  .height(20)
                  .margin({ left: 16, right: 8 })

                Text(this.birthDate ? this.birthDate : 'Select Birth Date')
                  .fontSize(16)
                  .fontColor(this.birthDate ? '#191C1D' : 'rgba(115, 118, 133, 0.5)')
                  .layoutWeight(1)

                Text('➔')
                  .fontSize(16)
                  .fontColor('#737685')
                  .margin({ right: 16 })
              }
              .width('100%')
              .height(56)
              .backgroundColor('#F3F4F5')
              .borderRadius(16)
              .alignItems(VerticalAlign.Center)
              .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
              .onClick(() => {
                DatePickerDialog.show({
                  start: new Date("1900-1-1"),
                  end: new Date(),
                  selected: this.birthDate ? new Date(this.birthDate) : new Date(),
                  onAccept: (value: DatePickerResult) => {
                    if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
                      this.birthDate = `${value.year}-${value.month + 1}-${value.day}`;
                    }
                  }
                })
              })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Gender Segmented Select (Cinsiyet)
            Column() {
              Text('Gender')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 8 })

              Row() {
                Row() {
                  Text('Male')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.selectedGender === 'Male' ? Color.White : '#434654')
                }
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.selectedGender === 'Male' ? '#003D9B' : '#FFFFFF')
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .border({ width: this.selectedGender === 'Male' ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                .onClick(() => {
                  this.selectedGender = 'Male';
                })
                .margin({ right: 8 })

                Row() {
                  Text('Female')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.selectedGender === 'Female' ? Color.White : '#434654')
                }
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.selectedGender === 'Female' ? '#003D9B' : '#FFFFFF')
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .border({ width: this.selectedGender === 'Female' ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                .onClick(() => {
                  this.selectedGender = 'Female';
                })
                .margin({ right: 8 })

                Row() {
                  Text('Other')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.selectedGender === 'Other' ? Color.White : '#434654')
                }
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.selectedGender === 'Other' ? '#003D9B' : '#FFFFFF')
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .border({ width: this.selectedGender === 'Other' ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                .onClick(() => {
                  this.selectedGender = 'Other';
                })
              }
              .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Height and Weight Row (Boy ve Kilo yan yana)
            Row() {
              // Height Input
              Column() {
                Text('Height (cm)')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                Row() {
                  Image($r('app.media.ruler'))
                    .width(25)
                    .height(25)
                    .margin({ left: 12, right: 6 })

                  TextInput({ placeholder: 'e.g. 180', text: this.heightCm })
                    .type(InputType.Number)
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(15)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .padding({ left: 0, right: 8 })
                    .onChange((value: string) => {
                      this.heightCm = value;
                    })
                }
                .width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
              }
              .layoutWeight(1)
              .margin({ right: 12 })

              // Weight Input
              Column() {
                Text('Weight (kg)')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                Row() {
                  Image($r('app.media.scale'))
                    .width(25)
                    .height(25)
                    .margin({ left: 12, right: 6 })

                  TextInput({ placeholder: 'e.g. 75', text: this.weightKg })
                    .type(InputType.Number)
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(15)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .padding({ left: 0, right: 8 })
                    .onChange((value: string) => {
                      this.weightKg = value;
                    })
                }
                .width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
              }
              .layoutWeight(1)
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
            .margin({ bottom: 16 })

            // Confirm Password Input
            Column() {
              Text('Confirm Password')
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

                TextInput({ placeholder: '••••••••', text: this.confirmPassword })
                  .type(InputType.Password)
                  .placeholderColor('rgba(115, 118, 133, 0.5)')
                  .fontSize(16)
                  .backgroundColor(Color.Transparent)
                  .height('100%')
                  .layoutWeight(1)
                  .showPasswordIcon(true)
                  .onChange((value: string) => {
                    this.confirmPassword = value;
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
              if (!this.fullName || !this.email || !this.phone || !this.birthDate || !this.heightCm || !this.weightKg || !this.password || !this.confirmPassword) {
                promptAction.showToast({ message: 'Please fill in all medical and profile fields' })
              } else if (this.password !== this.confirmPassword) {
                promptAction.showToast({ message: 'Passwords do not match' })
              } else {
                ApiService.post('/api/register', {
                  username: this.email,
                  password: this.password
                })
                .then(() => {
                  promptAction.showToast({ message: 'Profile created successfully!' })
                  router.pushUrl({ url: 'pages/SelectRolePage' })
                })
                .catch((err: Error) => {
                  // ApiService will already toast on HTTP errors, this catches network failures
                });
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

          // 4. Trust Badges
          Row() {
            Row() {
              Text('🛡️')
                .fontSize(16)
                .margin({ right: 6 })
              Text('HIPAA Compliant')
                .fontSize(13)
                .fontColor('#737685')
            }
            .alignItems(VerticalAlign.Center)

            Row()
              .width(1)
              .height(14)
              .backgroundColor('#C3C6D6')
              .margin({ left: 16, right: 16 })

            Row() {
              Text('🔐')
                .fontSize(16)
                .margin({ right: 6 })
              Text('256-bit AES')
                .fontSize(13)
                .fontColor('#737685')
            }
            .alignItems(VerticalAlign.Center)
          }
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
