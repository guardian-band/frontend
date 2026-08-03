import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

interface MedicalProfile {
  birthDate: string;
  gender: string;
  height: string;
  weight: string;
  bloodType: string;
  diseases: string[];
  otherChronicDisease: string;
  allergies: string;
  pacemaker: boolean;
  hearingAid: boolean;
}

@Entry
@Component
struct ProfilePage {
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'John Doe';
  @StorageLink('profilePicture') profilePicture: string = '';

  @StorageLink('medicalProfile') medicalProfile: MedicalProfile = {
    birthDate: '',
    gender: '',
    height: '',
    weight: '',
    bloodType: '',
    diseases: [],
    otherChronicDisease: '',
    allergies: '',
    pacemaker: false,
    hearingAid: false
  };

  private scroller: Scroller = new Scroller();

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  changeProfilePicture() {
    try {
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      photoPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
          this.profilePicture = photoSelectResult.photoUris[0];
          promptAction.showToast({ message: 'Profile picture updated from gallery!' });
        }
      }).catch((err: Error) => {
        console.error(`PhotoPicker select failed: ${err.message}`);
        promptAction.showToast({ message: 'Photo selection cancelled.' });
      });
    } catch (err) {
      const error = err as Error;
      console.error(`PhotoPicker failed to open: ${error.message}`);
      promptAction.showToast({ message: 'Failed to open photo picker on this device.' });
    }
  }

  getAge(birthDateStr: string): number {
    if (!birthDateStr) return 0;
    try {
      const parts = birthDateStr.split('-');
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const currentYear = new Date().getFullYear();
        return currentYear - year;
      }
    } catch (e) {
      // ignore
    }
    return 0;
  }

  formatBirthDate(birthDateStr: string): string {
    if (!birthDateStr) return 'Not Set';
    try {
      const parts = birthDateStr.split('-');
      if (parts.length === 3) {
        const year = parts[0];
        const monthNum = parseInt(parts[1]);
        const day = parts[2];
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        if (monthNum >= 1 && monthNum <= 12) {
          return `${months[monthNum - 1]} ${day}, ${year}`;
        }
      }
    } catch (e) {
      // ignore
    }
    return birthDateStr;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background Hologram/Ambient Blurs (0.5 opacity for consistency)
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
        .position({ x: '30%', y: '60%' })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 300,
          colors: [
            ['rgba(107, 255, 143, 0.5)', 0.0],
            ['rgba(107, 255, 143, 0.0)', 1.0]
          ]
        })

      // Main Content Wrapped in a Scroll
      Scroll(this.scroller) {
        Column() {
          // 1. Header
          Row() {
            Row() {
              Text('💙')
                .fontSize(18)
                .margin({ right: 8 })
              Text('GuardianBand')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Setup Prompt Banner (If profile is not completed)
          if (this.medicalProfile.birthDate === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Profile is not set up. Tap here to complete it.')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
                .layoutWeight(1)
              Text('➔')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/ProfileSetupPage' });
            })
          }

          // 2. Profile Main Header Card
          Column() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if (this.profilePicture === '') {
                Row() {
                  Text(this.getInitials(this.fullName))
                    .fontSize(32)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width(100)
                .height(100)
                .borderRadius(50)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .border({ width: 3, color: '#FFFFFF', style: BorderStyle.Solid })
              } else {
                Image(this.profilePicture)
                  .width(100)
                  .height(100)
                  .borderRadius(50)
                  .objectFit(ImageFit.Cover)
                  .border({ width: 3, color: '#FFFFFF', style: BorderStyle.Solid })
              }
            }
            .width(100)
            .height(100)
            .margin({ bottom: 16 })
            .onClick(() => {
              this.changeProfilePicture();
            })

            // Patient Name
            Text(this.fullName)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 6 })

            // DOB and Age
            Row() {
              Image($r('app.media.dob'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })
              Text(this.medicalProfile.birthDate ? `${this.formatBirthDate(this.medicalProfile.birthDate)} (${this.getAge(this.medicalProfile.birthDate)} Years Old)` : 'Birth Date & Age: Not Set')
                .fontSize(14)
                .fontColor('#737685')
            }
            .margin({ bottom: 16 })
            .justifyContent(FlexAlign.Center)

            // Interactive Badges (Blood Type, Allergies, Primary Disease)
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              // Blood Badge
              if (this.medicalProfile.bloodType) {
                Row() {
                  Image($r('app.media.blood'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text(`Blood: ${this.medicalProfile.bloodType}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#BA1A1A')
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#FFEBEA')
                .borderRadius(16)
                .margin(4)
              }

              // Allergy Badge
              if (this.medicalProfile.allergies) {
                Row() {
                  Image($r('app.media.alert'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text(`Allergy: ${this.medicalProfile.allergies}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#854E00')
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#FFF4E5')
                .borderRadius(16)
                .margin(4)
              }

              // Diseases Badges
              ForEach(this.medicalProfile.diseases, (disease: string) => {
                Row() {
                  Image($r('app.media.stethoscope'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text(disease === 'Other' && this.medicalProfile.otherChronicDisease ? this.medicalProfile.otherChronicDisease : disease)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#434654')
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .margin(4)
              })

              // Fallback text if nothing is set up yet
              if (!this.medicalProfile.bloodType && !this.medicalProfile.allergies && this.medicalProfile.diseases.length === 0) {
                Text('No medical parameters registered')
                  .fontSize(13)
                  .fontColor('#737685')
                  .fontStyle(FontStyle.Italic)
                  .margin(4)
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(24)
          .backgroundColor('rgba(255, 255, 255, 0.85)')
          .borderRadius(28)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
          .shadow({ radius: 12, color: 'rgba(0, 61, 155, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 20 })

          // 3. AI Emergency Summary Box
          Column() {
            Row() {
              Image($r('app.media.summary'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('AI Emergency Summary')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
            .width('100%')
            .margin({ bottom: 8 })

            Text(this.medicalProfile.diseases.length > 0 ?
              `"Patient has a history of ${this.medicalProfile.diseases.join(', ')}. Based on current environmental sensors and activity logs, patient is likely stable but requires monitoring."` :
              `"No recorded chronic diseases. Based on current profile setup, patient is stable. Vitals logs will appear here when active."`
            )
              .fontSize(13)
              .fontColor('#003D9B')
              .lineHeight(20)
              .fontStyle(FontStyle.Italic)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#E8EEFF')
          .borderRadius(20)
          .margin({ bottom: 20 })

          // 4. Physical Info & Devices Card (Setup information)
          Column() {
            Text('Physical & Devices')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 12 })

            Column() {
              // Height
              Row() {
                Row() {
                  Image($r('app.media.ruler'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                  Text('Height')
                    .fontSize(14)
                    .fontColor('#737685')
                }
                Blank()
                Text(`${this.medicalProfile.height} cm`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

              // Weight
              Row() {
                Row() {
                  Image($r('app.media.scale'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                  Text('Weight')
                    .fontSize(14)
                    .fontColor('#737685')
                }
                Blank()
                Text(`${this.medicalProfile.weight} kg`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

              // Pacemaker
              Row() {
                Row() {
                  Image($r('app.media.pacemaker'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                  Text('Pacemaker')
                    .fontSize(14)
                    .fontColor('#737685')
                }
                Blank()
                Text(this.medicalProfile.pacemaker ? 'Active' : 'None')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.medicalProfile.pacemaker ? '#006E2F' : '#737685')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

              // Hearing Aid
              Row() {
                Row() {
                  Image($r('app.media.hearingaid'))
                    .width(18)
                    .height(18)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                  Text('Hearing Aid')
                    .fontSize(14)
                    .fontColor('#737685')
                }
                Blank()
                Text(this.medicalProfile.hearingAid ? 'Active' : 'None')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.medicalProfile.hearingAid ? '#006E2F' : '#737685')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // 5. Current Medications
          Column() {
            Text('Current Medications')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 12 })

            Column() {
              // Med 1
              Row() {
                Column() {
                  Text('Metformin')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                    .margin({ bottom: 4 })
                  Text('500mg, Twice Daily')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Row() {
                  Image($r('app.media.like'))
                    .width(14)
                    .height(14)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text('Last: 08:30 AM')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#006E2F')
                }
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor('#E6F9ED')
                .borderRadius(8)
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

              // Med 2
              Row() {
                Column() {
                  Text('Lisinopril')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                    .margin({ bottom: 4 })
                  Text('10mg, Morning')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Row() {
                  Image($r('app.media.like'))
                    .width(14)
                    .height(14)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text('Last: 08:30 AM')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#006E2F')
                }
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor('#E6F9ED')
                .borderRadius(8)
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // 6. Emergency Contacts
          Column() {
            Text('Emergency Contacts')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 12 })

            Column() {
              // Contact 1
              Row() {
                // Profile Initials Circle Avatar (Left Side)
                Row() {
                  Text(this.getInitials('Sarah Chen'))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width(40)
                .height(40)
                .borderRadius(20)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ right: 12 })

                Column() {
                  Text('Sarah Chen')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                    .margin({ bottom: 4 })
                  Text('Daughter / Primary')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Row() {
                  Image($r('app.media.phone'))
                    .width(16)
                    .height(16)
                    .objectFit(ImageFit.Contain)
                }
                .width(36)
                .height(36)
                .borderRadius(18)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  promptAction.showToast({ message: 'Calling Sarah Chen...' });
                })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

              // Contact 2
              Row() {
                // Profile Initials Circle Avatar (Left Side)
                Row() {
                  Text(this.getInitials('Dr. James Miller'))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width(40)
                .height(40)
                .borderRadius(20)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ right: 12 })

                Column() {
                  Text('Dr. James Miller')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                    .margin({ bottom: 4 })
                  Text('Cardiologist')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Row() {
                  Image($r('app.media.phone'))
                    .width(16)
                    .height(16)
                    .objectFit(ImageFit.Contain)
                }
                .width(36)
                .height(36)
                .borderRadius(18)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  promptAction.showToast({ message: 'Calling Dr. James Miller...' });
                })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          }
          .width('100%')

          // Sign Out Button (moved from home page)
          Button('Sign Out')
            .width('100%')
            .height(56)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#8C0013')
            .backgroundColor('rgba(140, 0, 19, 0.08)')
            .borderRadius(16)
            .margin({ top: 24, bottom: 20 })
            .onClick(() => {
              AppStorage.setOrCreate('token', '');
              AppStorage.setOrCreate('fullName', '');
              AppStorage.setOrCreate('profilePicture', '');
              AppStorage.setOrCreate('userRole', 'patient');
              AppStorage.setOrCreate('medicalProfile', {
                birthDate: '',
                gender: '',
                height: '',
                weight: '',
                bloodType: '',
                diseases: [],
                otherChronicDisease: '',
                allergies: '',
                pacemaker: false,
                hearingAid: false
              });
              promptAction.showToast({ message: 'Signed out successfully' });
              router.clear();
              router.replaceUrl({ url: 'pages/WelcomePage' });
            })

          // Spacing for BottomNavBar
          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // Reusable Navigation Bar Component (Profile is active)
      BottomNavBar({ activeTab: 'profile' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
