import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

interface MedTime {
  slot: string;
  specificTime: string;
  taken: boolean;
}

interface FullMedicationItem {
  id: string;
  name: string;
  durationDays: number;
  totalPills: number;
  mealTiming: string;
  times: Array<MedTime>;
  days: Array<string>;
}

// Data model interface for medical profile
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

// Interface for dynamic emergency contacts (Syncs with SOS Page)
interface EmergencyContact {
  id: string;
  fullName: string;
  phone: string;
  relation: string;
}

@CustomDialog
struct AddContactDialog {
  controller?: CustomDialogController;
  @State firstName: string = '';
  @State lastName: string = '';
  @State phoneNumber: string = '';
  @State relation: string = '';

  onAdd: (name: string, phone: string, relation: string) => void = () => {};

  build() {
    Column() {
      Text('Add Emergency Contact')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 16 })

      Button('Select from Contacts')
        .backgroundColor('rgba(0, 61, 155, 0.08)')
        .fontColor('#003D9B')
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .height(44)
        .borderRadius(12)
        .margin({ bottom: 16 })
        .onClick(() => {
          promptAction.showActionMenu({
            title: 'Select Contact',
            showInSubWindow: false,
            buttons: [
              { text: 'Alice Green (+90 555 111 2233)', color: '#003D9B' },
              { text: 'Bob Smith (+90 555 444 5566)', color: '#003D9B' },
              { text: 'Charlie Brown (+90 555 777 8899)', color: '#003D9B' }
            ]
          }).then((data) => {
            if (data.index === 0) {
              this.firstName = 'Alice';
              this.lastName = 'Green';
              this.phoneNumber = '+905551112233';
              this.relation = 'Mother';
            } else if (data.index === 1) {
              this.firstName = 'Bob';
              this.lastName = 'Smith';
              this.phoneNumber = '+905554445566';
              this.relation = 'Father';
            } else if (data.index === 2) {
              this.firstName = 'Charlie';
              this.lastName = 'Brown';
              this.phoneNumber = '+905557778899';
              this.relation = 'Brother';
            }
            promptAction.showToast({ message: 'Contact selected!' });
          }).catch((err: Error) => {
            console.error("ActionMenu error", err.message);
          });
        })

      TextInput({ placeholder: 'First Name', text: this.firstName })
        .onChange((val: string) => this.firstName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Last Name', text: this.lastName })
        .onChange((val: string) => this.lastName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Phone Number', text: this.phoneNumber })
        .type(InputType.PhoneNumber)
        .onChange((val: string) => this.phoneNumber = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Relationship / Title (e.g. Son, Security)', text: this.relation })
        .onChange((val: string) => this.relation = val)
        .margin({ bottom: 24 })
        .backgroundColor('#F3F4F5')

      Row() {
        Button('Cancel')
          .backgroundColor('#F1F2F5')
          .fontColor('#191C1D')
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.controller?.close();
          })

        Button('Save')
          .backgroundColor('#003D9B')
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            if (this.firstName && this.phoneNumber) {
              this.onAdd(`${this.firstName} ${this.lastName}`.trim(), this.phoneNumber, this.relation || 'Emergency Contact');
              this.controller?.close();
            } else {
              promptAction.showToast({ message: 'Name and Phone are required!' });
            }
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

interface DoctorProfile {
  hospital: string;
  specialty: string;
  email: string;
  isVerified: boolean;
}

@Entry
@Component
struct ProfilePage {
  // AppStorage links for user session data
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';
  @StorageLink('profilePicture') profilePicture: string = '';
  @StorageLink('medications') medications: FullMedicationItem[] = [];
  @StorageLink('doctorProfile') doctorProfile: DoctorProfile = { hospital: '', email: '', specialty: '', isVerified: false };

  // Dynamic contacts fetched from SOS Page
  @StorageLink('sosContacts') sosContacts: EmergencyContact[] = [];

  // Link to medical profile data
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

  @StorageLink('userEmail') userEmail: string = '';
  @StorageLink('userPhone') userPhone: string = '';
  @State showRoleSwitcher: boolean = false;
  @State expandedMedId: string = '';
  @State isMyQrModalOpen: boolean = false;
  @StorageLink('selectedFamilyMember') selectedMember: string = 'Father';
  @State showMemberDropdown: boolean = false;

  dialogController: CustomDialogController = new CustomDialogController({
    builder: AddContactDialog({
      onAdd: (name: string, phone: string, relation: string) => {
        if (this.sosContacts.length < 2) {
          this.sosContacts.push({
            id: Date.now().toString(),
            fullName: name,
            phone: phone,
            relation: relation
          });
          this.sosContacts = [...this.sosContacts];
        }
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true
  });

  private scroller: Scroller = new Scroller();

  // Helper function to extract initials for avatar
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

  // Helper to generate a patient ID dynamically based on fullName and email
  getPatientId(): string {
    if (!this.fullName || this.fullName === 'User') {
      return 'GP-8321-2026';
    }
    let code = 0;
    for (let i = 0; i < this.fullName.length; i++) {
      code += this.fullName.charCodeAt(i);
    }
    const num = (code * 17) % 9000 + 1000;
    return `GP-${num}-2026`;
  }

  // Helper to generate a unique QR code value representing patient details
  getQrCodeValue(): string {
    const data: Record<string, string | string[]> = {
      'id': this.getPatientId(),
      'name': this.fullName,
      'email': this.userEmail || '',
      'phone': this.userPhone || '',
      'bloodType': this.medicalProfile.bloodType || 'N/A',
      'allergies': this.medicalProfile.allergies || 'None',
      'diseases': this.medicalProfile.diseases || []
    };
    return JSON.stringify(data);
  }

  // Photo picker function to change profile picture from gallery
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

  // Helper function to calculate age from birth date
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
      // Ignore parsing errors
    }
    return 0;
  }

  // Formatter to display birth date nicely
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
      // Ignore parsing errors
    }
    return birthDateStr;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background Hologram/Ambient Blurs
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

      Scroll(this.scroller) {
        Column() {
          // 1. Header Area
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

          // Setup Prompt Banner
          if (this.userRole === 'patient' && this.medicalProfile.birthDate === '') {
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
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'patient', canGoBack: true }
              });
            })
          } else if (this.userRole === 'family' && this.userEmail === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Email address is not set up. Tap here to complete it.')
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
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: this.userRole, canGoBack: true }
              });
            })
          } else if (this.userRole === 'doctor' && this.doctorProfile.email === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Doctor email profile is not set up. Tap here to complete it.')
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
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'doctor', canGoBack: true }
              });
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

            // User Full Name
            Text(this.fullName)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 8 })

            // Clickable Role Badge with Switch Action (Ends with ⇅)
            Row() {
              Image(this.userRole === 'patient' ? $r('app.media.patient') : 
                (this.userRole === 'doctor' ? $r('app.media.doctor') : $r('app.media.family')))
                .width(16)
                .height(16)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })

              Text(this.userRole === 'patient' ? 'Patient' : 
                (this.userRole === 'doctor' ? 'Doctor' : 'Family Member'))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.userRole === 'patient' ? '#003D9B' : 
                  (this.userRole === 'doctor' ? '#854E00' : '#006E2F'))
                .margin({ right: 6 })

              Text('⇅')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.userRole === 'patient' ? '#003D9B' : 
                  (this.userRole === 'doctor' ? '#854E00' : '#006E2F'))
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.userRole === 'patient' ? '#E8EEFF' : 
              (this.userRole === 'doctor' ? '#FFF4E5' : '#E6F9ED'))
            .borderRadius(16)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.showRoleSwitcher = true;
            })

            // DOB / Email / Hospital display based on role
            if (this.userRole === 'patient') {
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
            } else if (this.userRole === 'doctor') {
              Row() {
                Image($r('app.media.place'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text(this.doctorProfile.hospital ? `${this.doctorProfile.hospital}` : 'Hospital Name: Not Set')
                  .fontSize(14)
                  .fontColor('#737685')
              }
              .margin({ bottom: 16 })
              .justifyContent(FlexAlign.Center)
            } else {
              Row() {
                Image($r('app.media.email'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text(this.userEmail ? this.userEmail : 'Email: Not Set')
                  .fontSize(14)
                  .fontColor('#737685')
              }
              .margin({ bottom: 16 })
              .justifyContent(FlexAlign.Center)
            }

            // Interactive Medical Badges (Blood Type, Allergies, Diseases) - Only for Patient
            if (this.userRole === 'doctor') {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                // Specialty Badge
                if (this.doctorProfile.specialty) {
                  Row() {
                    Image($r('app.media.stethoscope'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Specialty: ${this.doctorProfile.specialty}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#003D9B')
                  }
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#E8EEFF')
                  .borderRadius(16)
                  .margin(4)
                }

                // Verified Email Badge
                if (this.doctorProfile.email) {
                  Row() {
                    Image($r('app.media.email'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Verified Email: ${this.doctorProfile.email}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#006E2F')
                  }
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#E6F9ED')
                  .borderRadius(16)
                  .margin(4)
                }
              }
              .width('95%')
              .margin({ bottom: 10 })
            }

            if (this.userRole === 'patient') {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                // Blood Type Badge
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

                // Chronic Disease Badges
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

                // Fallback text if no medical parameters are registered
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
          }
          .width('100%')
          .padding(24)
          .backgroundColor('rgba(255, 255, 255, 0.85)')
          .borderRadius(28)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
          .shadow({ radius: 12, color: 'rgba(0, 61, 155, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 20 })

          // Conditionally Render Patient Cards
          if (this.userRole === 'patient') {
            // Share Patient QR Code Card
            Row() {
              Row() {
                Image($r('app.media.qr'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
              }
              .width(40)
              .height(40)
              .borderRadius(8)
              .backgroundColor('rgba(0, 110, 47, 0.08)')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('Share Patient QR Code')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#006E2F')
                  .margin({ bottom: 2 })
                Text('Let your doctor scan this code to link with your account.')
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('Show QR', { type: ButtonType.Normal })
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#006E2F')
                .borderRadius(8)
                .height(30)
                .onClick(() => {
                  this.isMyQrModalOpen = true;
                })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(0, 110, 47, 0.2)', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .alignItems(VerticalAlign.Center)



            // 4. Physical Info & Devices Card
            Column() {
              Text('Physical & Devices')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                // Height Info
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

                // Weight Info
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

                // Pacemaker Status
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

                // Hearing Aid Status
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

            // 5. Currently Used Medications
            Column() {
              Text('Active Medications')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                if (this.medications.length > 0) {
                  ForEach(this.medications, (med: FullMedicationItem) => {
                    Column() {
                      Row() {
                        Row() {
                          Image($r('app.media.drugs'))
                            .width(20)
                            .height(20)
                            .objectFit(ImageFit.Contain)
                        }
                        .width(36)
                        .height(36)
                        .borderRadius(10)
                        .backgroundColor('rgba(0, 61, 155, 0.1)')
                        .justifyContent(FlexAlign.Center)
                        .alignItems(VerticalAlign.Center)
                        .margin({ right: 12 })

                        Column() {
                          Text(med.name)
                            .fontSize(15)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#191C1D')
                            .margin({ bottom: 2 })

                          Text(`${med.totalPills} Pills left • ${med.mealTiming}`)
                            .fontSize(12)
                            .fontColor('#737685')
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)

                        Row() {
                          Text(this.expandedMedId === med.id ? 'Hide Detail ▲' : 'Detail ▼')
                            .fontSize(12)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#003D9B')
                        }
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor('#E8EEFF')
                        .borderRadius(6)
                      }
                      .width('100%')
                      .padding({ top: 12, bottom: 12 })
                      .onClick(() => {
                        this.expandedMedId = this.expandedMedId === med.id ? '' : med.id;
                      })

                      if (this.expandedMedId === med.id) {
                        Column() {
                          // 1. Weekly Days active
                          Row() {
                            Text('Active Days:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 8 })

                            Row() {
                              ForEach(['M', 'T', 'W', 'T', 'F', 'S', 'S'], (day: string, idx: number) => {
                                Text(day)
                                  .width(22)
                                  .height(22)
                                  .fontSize(10)
                                  .fontWeight(FontWeight.Bold)
                                  .textAlign(TextAlign.Center)
                                  .borderRadius(11)
                                  .backgroundColor(med.days.includes(day) ? '#003D9B' : '#F3F4F5')
                                  .fontColor(med.days.includes(day) ? Color.White : '#8F92A1')
                                  .margin({ right: 4 })
                              }, (day: string, idx: number) => day + idx.toString())
                            }
                          }
                          .width('100%')
                          .margin({ bottom: 12 })

                          // 2. Schedule times slot detail
                          Row() {
                            Text('Times:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 8 })

                            Flex({ wrap: FlexWrap.Wrap }) {
                              ForEach(med.times, (time: MedTime) => {
                                Row() {
                                  Text(time.slot)
                                    .fontSize(11)
                                    .fontWeight(FontWeight.Bold)
                                    .fontColor('#003D9B')
                                  if (time.specificTime) {
                                    Text(` (${time.specificTime})`)
                                      .fontSize(11)
                                      .fontColor('#737685')
                                  }
                                }
                                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                                .backgroundColor('#F0F4FF')
                                .borderRadius(6)
                                .margin({ right: 6 })
                              }, (time: MedTime) => time.slot)
                            }
                            .layoutWeight(1)
                          }
                          .width('100%')
                          .alignItems(VerticalAlign.Center)
                          .margin({ bottom: 12 })

                          // 3. Treatment Duration and Meal Timing
                          Row() {
                            Text('Treatment Duration:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 6 })

                            Text(`${med.durationDays} Days`)
                              .fontSize(12)
                              .fontColor('#191C1D')

                            Blank().width(16)
                          }
                          .width('100%')
                          .margin({ bottom: 4 })
                        }
                        .width('100%')
                        .padding(12)
                        .backgroundColor('#F8F9FA')
                        .borderRadius(12)
                        .margin({ bottom: 12 })
                        .alignItems(HorizontalAlign.Start)
                      }
                    }
                    .width('100%')
                    .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
                  }, (med: FullMedicationItem) => med.id)
                } else {
                  Column() {
                    Image($r('app.media.confetti'))
                      .width(32)
                      .height(32)
                      .objectFit(ImageFit.Contain)
                      .margin({ bottom: 8 })
                    Text('No medications scheduled.')
                      .fontSize(13)
                      .fontColor('#737685')
                      .fontStyle(FontStyle.Italic)
                  }
                  .width('100%')
                  .padding(16)
                  .alignItems(HorizontalAlign.Center)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 20 })
          }

          // Conditionally Render Family Member Cards
          if (this.userRole === 'family') {
            // Monitored Family Member Card
            Column() {
              Row() {
                Text('Monitored Member')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')

                Blank()

                // Switch Member Button
                Row() {
                  Text(this.selectedMember === 'Father' ? 'Father' : 'Mother')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#003D9B')
                    .margin({ right: 6 })
                  Text('▼')
                    .fontSize(10)
                    .fontColor('#003D9B')
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor('#E8EEFF')
                .borderRadius(10)
                .onClick(() => {
                  this.showMemberDropdown = !this.showMemberDropdown;
                })
              }
              .width('100%')
              .margin({ left: 4, bottom: 12 })

              // Dropdown Menu for choosing Monitored Member
              if (this.showMemberDropdown) {
                Column() {
                  // Option 1: Father
                  Row() {
                    Row() {
                      Text('JD')
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                    }
                    .width(26)
                    .height(26)
                    .borderRadius(13)
                    .backgroundColor('#006E2F')
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .margin({ right: 10 })

                    Text("Father (John Doe)")
                      .fontSize(14)
                      .fontWeight(this.selectedMember === 'Father' ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.selectedMember === 'Father' ? '#003D9B' : '#191C1D')

                    Blank()

                    if (this.selectedMember === 'Father') {
                      Text('✓')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }
                  }
                  .width('100%')
                  .padding(12)
                  .onClick(() => {
                    this.selectedMember = 'Father';
                    this.showMemberDropdown = false;
                  })
                  .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.15)' })

                  // Option 2: Mother
                  Row() {
                    Row() {
                      Text('MD')
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                    }
                    .width(26)
                    .height(26)
                    .borderRadius(13)
                    .backgroundColor('#854E00')
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .margin({ right: 10 })

                    Text("Mother (Mary Doe)")
                      .fontSize(14)
                      .fontWeight(this.selectedMember === 'Mother' ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.selectedMember === 'Mother' ? '#003D9B' : '#191C1D')

                    Blank()

                    if (this.selectedMember === 'Mother') {
                      Text('✓')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }
                  }
                  .width('100%')
                  .padding(12)
                  .onClick(() => {
                    this.selectedMember = 'Mother';
                    this.showMemberDropdown = false;
                  })
                }
                .width('100%')
                .backgroundColor(Color.White)
                .borderRadius(16)
                .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
                .margin({ bottom: 12 })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)' })
              }

              Column() {
                // Header of the monitored person
                Row() {
                  // Avatar with initials
                  Row() {
                    Text(this.selectedMember === 'Father' ? 'JD' : 'MD')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(24)
                  .backgroundColor(this.selectedMember === 'Father' ? '#006E2F' : '#854E00')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .margin({ right: 12 })

                  Column() {
                    Row() {
                      Text(this.selectedMember === 'Father' ? 'John Doe (Father)' : 'Mary Doe (Mother)')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                      // Active green status dot
                      Row()
                        .width(8)
                        .height(8)
                        .backgroundColor(this.selectedMember === 'Father' ? '#006E2F' : '#854E00')
                        .borderRadius(4)
                        .margin({ left: 8 })
                    }
                    .alignItems(VerticalAlign.Center)
                    .margin({ bottom: 4 })

                    Text('Band Connected • Signal Strong')
                      .fontSize(12)
                      .fontColor(this.selectedMember === 'Father' ? '#006E2F' : '#854E00')
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ bottom: 16 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Quick stats
                Row() {
                  Column() {
                    Text('Heart Rate')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.heart'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text(this.selectedMember === 'Father' ? '72 bpm' : '80 bpm')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#BA1A1A')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)

                  Row()
                    .width(1)
                    .height(30)
                    .backgroundColor('rgba(195, 198, 214, 0.3)')

                  Column() {
                    Text('Oxygen Sat.')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.oxygensaturation'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text(this.selectedMember === 'Father' ? '98%' : '99%')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)

                  Row()
                    .width(1)
                    .height(30)
                    .backgroundColor('rgba(195, 198, 214, 0.3)')

                  Column() {
                    Text('Steps Today')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.walking'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text(this.selectedMember === 'Father' ? '4,820' : '6,150')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#006E2F')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }
                .width('100%')
                .padding({ top: 16, bottom: 16 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Actions row
                Row() {
                  Button() {
                    Row() {
                      Image($r('app.media.dashboard'))
                        .width(16)
                        .height(16)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })
                      Text('View Live Health Data')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }
                  }
                  .layoutWeight(1)
                  .height(38)
                  .backgroundColor('rgba(0, 61, 155, 0.06)')
                  .borderRadius(8)
                  .margin({ right: 12 })
                  .onClick(() => {
                    promptAction.showToast({ message: `Opening live dashboard for ${this.selectedMember === 'Father' ? 'John Doe' : 'Mary Doe'}...` });
                    router.pushUrl({ url: 'pages/HomePage' }, (err) => {
                      if (err) {
                        promptAction.showToast({ message: `Routing Error: ${err.message}` });
                        console.error(`Routing to HomePage failed: ${err.code} - ${err.message}`);
                      }
                    });
                  })

                  Button() {
                    Row() {
                      Image($r('app.media.phone'))
                        .width(16)
                        .height(16)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })
                      Text('Call')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#006E2F')
                    }
                  }
                  .width(90)
                  .height(38)
                  .backgroundColor('rgba(0, 110, 47, 0.06)')
                  .borderRadius(8)
                  .onClick(() => {
                    promptAction.showToast({ message: `Calling ${this.selectedMember === 'Father' ? 'John Doe' : 'Mary Doe'}...` });
                  })
                }
                .width('100%')
                .padding({ top: 16 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 20 })
          }

          // Conditionally Render Doctor Cards
          if (this.userRole === 'doctor') {
            Column() {
              Text('Professional Profile')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                // Clinic Row
                Row() {
                  Image($r('app.media.place'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Affiliated Clinic / Hospital')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.hospital || 'Not Configured')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 16 })

                // Specialty Row
                Row() {
                  Image($r('app.media.doctor'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Medical Specialty')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.specialty || 'Not Configured')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 16 })

                // Verification Status Row
                Row() {
                  Image($r('app.media.like'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Account Status')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.isVerified ? 'Verified Medical Professional' : 'Verification Required')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.doctorProfile.isVerified ? '#006E2F' : '#BA1A1A')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 20 })
          }

          // Emergency Contacts - Rendered only for Patients
          if (this.userRole === 'patient') {
            Column() {
              Row() {
                Text('Emergency Contacts')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')

                Blank()

                // Sadece 2 kişiden az eklendiyse Add butonunu gösterir
                if (this.sosContacts.length < 2) {
                  Button('+ Add')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#003D9B')
                    .backgroundColor('#E8EEFF')
                    .height(28)
                    .onClick(() => {
                      this.dialogController.open();
                    })
                }
              }
              .width('100%')
              .margin({ bottom: 12 })
              .padding({ left: 4, right: 4 })

              Column() {
                if (this.sosContacts.length > 0) {
                  ForEach(this.sosContacts, (contact: EmergencyContact, index: number) => {
                    Row() {
                      // Avatar (Left Side)
                      Row() {
                        Text(this.getInitials(contact.fullName))
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

                      // Contact Info
                      Column() {
                        Text(contact.fullName)
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#191C1D')
                          .margin({ bottom: 4 })

                        // Priority Badge and Relation
                        Row() {
                          Text(index === 0 ? '1st to Call' : '2nd to Call')
                            .fontSize(10)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Color.White)
                            .backgroundColor(index === 0 ? '#BA1A1A' : '#854E00')
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4)
                            .margin({ right: 6 })

                          Text(contact.relation)
                            .fontSize(12)
                            .fontColor('#737685')
                        }
                      }
                      .alignItems(HorizontalAlign.Start)

                      Blank()

                      // Remove Button
                      Button('Remove', { type: ButtonType.Normal })
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#BA1A1A')
                        .backgroundColor('rgba(186, 26, 26, 0.08)')
                        .borderRadius(8)
                        .height(28)
                        .onClick(() => {
                          this.sosContacts = this.sosContacts.filter(c => c.id !== contact.id);
                          this.sosContacts = [...this.sosContacts];
                        })
                    }
                    .width('100%')
                    .padding({ top: 12, bottom: 12 })
                    .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
                  }, (contact: EmergencyContact) => contact.id)
                } else {
                  // Fallback screen if no contacts are added
                  Column() {
                    Text('No emergency contacts added yet.')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')
                      .margin({ bottom: 4 })
                    Text('Please use the Add button above to register responders.')
                      .fontSize(12)
                      .fontColor('#737685')
                  }
                  .width('100%')
                  .padding(16)
                  .alignItems(HorizontalAlign.Center)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            }
            .width('100%')
            .margin({ bottom: 20 })
          }

          // Sign Out Button
          Button() {
            Row() {
              Image($r('app.media.logout'))
                .width(20)
                .height(20)
                .margin({ right: 8 })
                .objectFit(ImageFit.Contain)
              Text('Sign Out')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8C0013')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .height(56)
          .backgroundColor('rgba(140, 0, 19, 0.08)')
          .borderRadius(16)
          .margin({ top: 8, bottom: 20 })
          .onClick(() => {
              AppStorage.setOrCreate('token', '');
              AppStorage.setOrCreate('fullName', '');
              AppStorage.setOrCreate('profilePicture', '');
              AppStorage.setOrCreate('userRole', 'patient');
              AppStorage.setOrCreate('userEmail', '');
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

          // Blank space to prevent overlap with BottomNavBar
          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // Bottom Navigation Bar
      BottomNavBar({ activeTab: 'profile' })
        .zIndex(1)

      // Role Switcher Drawer/Card Overlay
      if (this.showRoleSwitcher) {
        // Semi-transparent Overlay Background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.4)')
          .zIndex(10)
          .onClick(() => {
            this.showRoleSwitcher = false;
          })

        // Role Switcher Bottom Sheet Card
        Column() {
          // Drag Handle
          Row()
            .width(40)
            .height(5)
            .backgroundColor('#E1E2E4')
            .borderRadius(3)
            .margin({ bottom: 20 })

          Text('Switch Active Role')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Text('Choose the role you want to act as. If you select a new role, you can set it up instantly.')
            .fontSize(14)
            .fontColor('#737685')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
            .width('90%')

          // Role 1: Patient
          Row() {
            Image($r('app.media.patient'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Patient')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.medicalProfile.birthDate ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.medicalProfile.birthDate ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'patient') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 12 })
          .border({ width: this.userRole === 'patient' ? 2 : 1, color: this.userRole === 'patient' ? '#003D9B' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.medicalProfile.birthDate) {
              this.userRole = 'patient';
              promptAction.showToast({ message: 'Switched to Patient role' });
            } else {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'patient', canGoBack: true }
              });
            }
          })

          // Role 2: Family Member
          Row() {
            Image($r('app.media.family'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Family Member')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.userEmail ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.userEmail ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'family') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 12 })
          .border({ width: this.userRole === 'family' ? 2 : 1, color: this.userRole === 'family' ? '#006E2F' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.userEmail) {
              this.userRole = 'family';
              promptAction.showToast({ message: 'Switched to Family Member role' });
            } else {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'family', canGoBack: true }
              });
            }
          })

          // Role 3: Doctor
          Row() {
            Image($r('app.media.doctor'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Doctor')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.doctorProfile.email ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.doctorProfile.email ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'doctor') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#854E00')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 24 })
          .border({ width: this.userRole === 'doctor' ? 2 : 1, color: this.userRole === 'doctor' ? '#854E00' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.doctorProfile.email) {
              AppStorage.setOrCreate('previousRole', this.userRole);
              this.userRole = 'doctor';
              promptAction.showToast({ message: 'Switched to Doctor role' });
            } else {
              AppStorage.setOrCreate('previousRole', this.userRole);
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'doctor', canGoBack: true }
              });
            }
          })

          // Close Button
          Button('Cancel')
            .width('100%')
            .height(50)
            .backgroundColor('#E1E2E4')
            .fontColor('#191C1D')
            .borderRadius(12)
            .onClick(() => {
              this.showRoleSwitcher = false;
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 30 })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 32, topRight: 32 })
        .zIndex(11)
      }

      // My Patient QR Code Modal Dialog
      if (this.isMyQrModalOpen) {
        Stack() {
          // Semi-transparent background
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.45)')
            .onClick(() => {
              this.isMyQrModalOpen = false;
            })

          Column() {
            Row() {
              Text('My Patient QR Code')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')

              Blank()

              // Close Button
              Row() {
                Image($r('app.media.cancel'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
              }
              .onClick(() => {
                this.isMyQrModalOpen = false;
              })
            }
            .width('100%')
            .margin({ bottom: 20 })

            // Display Dynamic QR Code Container
            Row() {
              QRCode(this.getQrCodeValue())
                .width(180)
                .height(180)
                .color('#003D9B')
            }
            .width(220)
            .height(220)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E8EEFF', style: BorderStyle.Solid })
            .borderRadius(16)
            .margin({ bottom: 16 })

            Text(this.fullName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 4 })

            Text(`Patient ID: ${this.getPatientId()}`)
              .fontSize(12)
              .fontColor('#737685')
              .margin({ bottom: 16 })

            Text('Let your doctor scan this code to link you as their patient for real-time vitals checks.')
              .fontSize(13)
              .fontColor('#434654')
              .textAlign(TextAlign.Center)
              .lineHeight(18)
              .width('90%')
          }
          .width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)' })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }


    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}