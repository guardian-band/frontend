import { router, promptAction } from '@kit.ArkUI';
import { ApiService, PatientProfile, CriticalFacts } from '../services/ApiService';
import { SessionStore, LocalUserProfile } from '../services/SessionStore';
import { ApiConfig } from '../services/ApiConfig';
import { ProfileRepository, UiMedicalProfile } from '../services/ProfileRepository';
import { AccountRepository } from '../services/AccountRepository';

interface DoctorProfile {
  hospital: string;
  specialty: string;
  email: string;
  isVerified: boolean;
}

@Entry
@Component
struct ProfileSetupPage {
  @State role: string = 'patient';
  
  // Patient fields
  @State birthDate: string = '';
  @State selectedGender: string = 'Male';
  @State heightCm: string = '';
  @State weightKg: string = '';
  @State bloodType: string = 'A+';
  @State chronicDiseases: string[] = [];
  @State allergies: string = '';
  @State pacemaker: boolean = false;
  @State hearingAid: boolean = false;
  /** Serial printed on the band. Empty means no band is paired. */
  @State bandIdentifier: string = '';
  @State isDiseasesExpanded: boolean = false;
  @State otherChronicDisease: string = '';
  
  // Family fields
  @State email: string = '';
  /** Email format error shown under the field. Empty means no error. */
  @State emailError: string = '';
  @State canGoBack: boolean = false;

  // Doctor fields
  @State doctorHospital: string = '';
  @State doctorEmail: string = '';
  @State doctorEmailError: string = '';
  @State verificationCode: string = '';
  @State isCodeSent: boolean = false;
  @State isDoctorVerified: boolean = false;
  @State doctorSpecialty: string = 'General Medicine';
  @State otherDoctorSpecialty: string = '';
  @State isSpecialtyExpanded: boolean = false;

  private scroller: Scroller = new Scroller();
  
  private diseaseOptions: string[] = ['Hypertension', 'Diabetes', 'Asthma', 'Heart Failure', 'Alzheimer\'s', 'Other'];
  // CAREFUL: use the letter "O", not the digit "0". The backend
  // (profile.go validBloodTypes) accepts only A+/A-/B+/B-/AB+/AB-/O+/O-;
  // a digit zero returned 400.
  private bloodTypes: string[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  private specialtyOptions: string[] = ['General Medicine', 'Cardiology', 'Neurology', 'Geriatrics', 'Pediatrics', 'Other'];

  aboutToAppear() {
    const params = router.getParams() as Record<string, string | boolean>;
    if (params) {
      if (params.role) {
        this.role = params.role as string;
      }
      if (params.canGoBack) {
        this.canGoBack = params.canGoBack as boolean;
      }
    }
    this.prefillFromExistingProfile();
  }

  /**
   * Fills the form with the existing profile.
   *
   * This screen is used for both first-time setup and editing. Opening it to
   * edit used to show every field blank, so pressing save OVERWROTE the server
   * profile with empty values. The form now opens pre-filled.
   */
  private prefillFromExistingProfile(): void {
    const existing = AppStorage.get<UiMedicalProfile>('medicalProfile');
    if (existing !== undefined) {
      this.birthDate = existing.birthDate ? existing.birthDate : this.birthDate;
      this.selectedGender = existing.gender ? existing.gender : this.selectedGender;
      this.heightCm = existing.height ? existing.height : this.heightCm;
      this.weightKg = existing.weight ? existing.weight : this.weightKg;
      this.bloodType = existing.bloodType ? existing.bloodType : this.bloodType;
      this.chronicDiseases = existing.diseases ? existing.diseases : this.chronicDiseases;
      this.allergies = existing.allergies ? existing.allergies : this.allergies;
      this.pacemaker = existing.pacemaker;
      this.hearingAid = existing.hearingAid;
      this.bandIdentifier = existing.bandIdentifier ? existing.bandIdentifier : this.bandIdentifier;
    }

    const savedEmail = AppStorage.get<string>('userEmail');
    if (savedEmail !== undefined && savedEmail.length > 0) {
      this.email = savedEmail;
    }
    const savedDoctor = AppStorage.get<DoctorProfile>('doctorProfile');
    if (savedDoctor !== undefined) {
      this.doctorHospital = savedDoctor.hospital ? savedDoctor.hospital : this.doctorHospital;
      this.doctorEmail = savedDoctor.email ? savedDoctor.email : this.doctorEmail;
      this.doctorSpecialty = savedDoctor.specialty ? savedDoctor.specialty : this.doctorSpecialty;
    }

    // AppStorage is in memory and is empty after a restart. The per-user record
    // in the persistent store is the real source.
    const local: LocalUserProfile = SessionStore.getLocalProfile(SessionStore.getPhone());
    if (local.email.length > 0 && this.email.length === 0) {
      this.email = local.email;
    }
    if (local.doctorHospital.length > 0 && this.doctorHospital.length === 0) {
      this.doctorHospital = local.doctorHospital;
    }
    if (local.doctorEmail.length > 0 && this.doctorEmail.length === 0) {
      this.doctorEmail = local.doctorEmail;
    }
    if (local.doctorSpecialty.length > 0) {
      this.doctorSpecialty = local.doctorSpecialty;
    }

    // The server copy may be newer than the local one; refresh quietly.
    if (SessionStore.isAuthenticated()) {
      ProfileRepository.load()
        .then((fresh: UiMedicalProfile) => {
          this.birthDate = fresh.birthDate ? fresh.birthDate : this.birthDate;
          this.selectedGender = fresh.gender ? fresh.gender : this.selectedGender;
          this.heightCm = fresh.height ? fresh.height : this.heightCm;
          this.weightKg = fresh.weight ? fresh.weight : this.weightKg;
          this.bloodType = fresh.bloodType ? fresh.bloodType : this.bloodType;
          this.chronicDiseases = fresh.diseases.length > 0 ? fresh.diseases : this.chronicDiseases;
          this.allergies = fresh.allergies ? fresh.allergies : this.allergies;
          this.pacemaker = fresh.pacemaker;
          this.hearingAid = fresh.hearingAid;
          this.bandIdentifier = fresh.bandIdentifier ? fresh.bandIdentifier : this.bandIdentifier;
        })
        .catch((err: Error) => {
          // 404 = no profile yet, first-time setup. Expected.
          console.info(`[ProfileSetupPage] Existing profile not loaded: ${err.message}`);
        });
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
          // 1. Header
          Stack({ alignContent: Alignment.TopStart }) {
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

              Text('Complete your profile to continue.')
                .fontSize(15)
                .fontColor('#434654')
                .textAlign(TextAlign.Center)
            }
            .alignItems(HorizontalAlign.Center)
            .width('100%')

            if (this.canGoBack) {
              Row() {
                Image($r('app.media.backward'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
              }
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor('#E8EEFF')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .position({ x: 0, y: 15 })
              .zIndex(20)
              .onClick(() => {
                try {
                  router.back();
                } catch (e) {
                  router.pushUrl({ url: 'pages/ProfilePage' });
                }
              })
            }
          }
          .width('100%')
          .margin({ bottom: 24 })

          // 2. Profile Setup Card
          Column() {
            // Title
            Column() {
              Text(this.role === 'patient' ? 'Create Health Profile' : 'Profile Details')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 6 })

              Text(this.role === 'patient' ? 'Please enter your medical details for closer monitoring.' : 'Please enter your email address to complete your account.')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#434654')
                .margin({ bottom: 20 })}.alignItems(HorizontalAlign.Start)
            .width('100%')

            if (this.role === 'patient') {
              // PATIENT FORM FIELDS

              // Birth Date Input
              Column() {
                Text('Birth Date')
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
                    .margin({ right: 16 })}.width('100%')
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
                        // The contract expects `format: date`: YYYY-MM-DD, zero padded.
                        const mm: string = `${value.month + 1}`.padStart(2, '0');
                        const dd: string = `${value.day}`.padStart(2, '0');
                        this.birthDate = `${value.year}-${mm}-${dd}`;
                      }
                    }
                  })
                })}.width('100%')
              .margin({ bottom: 16 })

              // Gender Segmented Select
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
                      .fontColor(this.selectedGender === 'Male' ? Color.White : '#434654')}.layoutWeight(1)
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
                      .fontColor(this.selectedGender === 'Female' ? Color.White : '#434654')}.layoutWeight(1)
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
                      .fontColor(this.selectedGender === 'Other' ? Color.White : '#434654')}.layoutWeight(1)
                  .height(44)
                  .backgroundColor(this.selectedGender === 'Other' ? '#003D9B' : '#FFFFFF')
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .border({ width: this.selectedGender === 'Other' ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                  .onClick(() => {
                    this.selectedGender = 'Other';
                  })}.width('100%')}.width('100%')
              .margin({ bottom: 16 })

              // Height and Weight Row
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
                      })}.width('100%')
                  .height(56)
                  .backgroundColor('#F3F4F5')
                  .borderRadius(16)
                  .alignItems(VerticalAlign.Center)
                  .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.layoutWeight(1)
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
                      })}.width('100%')
                  .height(56)
                  .backgroundColor('#F3F4F5')
                  .borderRadius(16)
                  .alignItems(VerticalAlign.Center)
                  .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.layoutWeight(1)}.width('100%')
              .margin({ bottom: 16 })

              // Blood Type Selection (Custom Grid)
              Column() {
                Text('Blood Type')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  ForEach(this.bloodTypes, (type: string) => {
                    Button() {
                      Text(type)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.bloodType === type ? Color.White : '#434654')}.width('23%')
                    .height(40)
                    .padding(0)
                    .margin({ bottom: 8 })
                    .backgroundColor(this.bloodType === type ? '#003D9B' : '#FFFFFF')
                    .borderRadius(12)
                    .border({ width: this.bloodType === type ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                    .onClick(() => {
                      this.bloodType = type;
                    })
                  })}.width('100%')}.width('100%')
              .margin({ bottom: 16 })
              // Chronic Diseases Selection (Collapsible checklist)
              Column() {
                Text('Chronic Diseases')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                // Header / Expand-Collapse click bar
                Row() {
                  Row() {
                    Image($r('app.media.stethoscope'))
                      .width(24)
                      .height(24)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    
                    Text(this.chronicDiseases.length > 0 ? this.chronicDiseases.join(', ') : 'None selected')
                      .fontSize(16)
                      .fontColor(this.chronicDiseases.length > 0 ? '#191C1D' : 'rgba(115, 118, 133, 0.5)')
                      .fontWeight(this.chronicDiseases.length > 0 ? FontWeight.Medium : FontWeight.Normal)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)}.layoutWeight(1)
                  .alignItems(VerticalAlign.Center)
                  
                  Text(this.isDiseasesExpanded ? '▲' : '▼')
                    .fontSize(12)
                    .fontColor('#737685')
                    .margin({ left: 8 })}.width('100%')
                .height(56)
                .padding({ left: 16, right: 16 })
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.SpaceBetween)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
                .onClick(() => {
                  this.isDiseasesExpanded = !this.isDiseasesExpanded;
                })

                // Dropdown content list
                if (this.isDiseasesExpanded) {
                  Column() {
                    ForEach(this.diseaseOptions, (disease: string) => {
                      Row() {
                        // Checkbox custom container
                        Row() {
                          if (this.chronicDiseases.includes(disease)) {
                            Text('✓')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(Color.White)
                          }}.width(20)
                        .height(20)
                        .borderRadius(6)
                        .border({ width: 1, color: '#C3C6D6', style: BorderStyle.Solid })
                        .backgroundColor(this.chronicDiseases.includes(disease) ? '#003D9B' : Color.Transparent)
                        .alignItems(VerticalAlign.Center)
                        .justifyContent(FlexAlign.Center)
                        .margin({ right: 12 })

                        Text(disease)
                          .fontSize(15)
                          .fontColor('#191C1D')
                          .fontWeight(FontWeight.Medium)}.width('100%')
                      .height(48)
                      .padding({ left: 16, right: 16 })
                      .alignItems(VerticalAlign.Center)
                      .onClick(() => {
                        if (this.chronicDiseases.includes(disease)) {
                          this.chronicDiseases = this.chronicDiseases.filter(d => d !== disease);
                        } else {
                          this.chronicDiseases = [...this.chronicDiseases, disease];
                        }
                      })
                    })}.width('100%')
                  .margin({ top: 8 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(16)
                  .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
                  .padding({ top: 4, bottom: 4 })
                }

                // Conditionally display details input when "Other" option is checked
                if (this.chronicDiseases.includes('Other')) {
                  Column() {
                    Text('Specify Other Disease')
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#434654')
                      .alignSelf(ItemAlign.Start)
                      .margin({ left: 4, top: 12, bottom: 8 })

                    Row() {
                      Image($r('app.media.pencil'))
                        .width(24)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .margin({ left: 16, right: 8 })

                      TextInput({ placeholder: 'Specify other chronic disease', text: this.otherChronicDisease })
                        .placeholderColor('rgba(115, 118, 133, 0.5)')
                        .fontSize(15)
                        .backgroundColor(Color.Transparent)
                        .height('100%')
                        .layoutWeight(1)
                        .onChange((value: string) => {
                          this.otherChronicDisease = value;
                        })}.width('100%')
                    .height(56)
                    .backgroundColor('#F3F4F5')
                    .borderRadius(16)
                    .alignItems(VerticalAlign.Center)
                    .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
                }}.width('100%')
              .margin({ bottom: 16 })

              // Allergies (Text input)
              Column() {
                Text('Allergies')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                Row() {
                  Image($r('app.media.alert'))
                    .width(24)
                    .height(24)
                    .objectFit(ImageFit.Contain)
                    .margin({ left: 16, right: 8 })

                  TextInput({ placeholder: 'e.g. Penicillin, pollen, food or specific drugs...', text: this.allergies })
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(16)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.allergies = value;
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
              .margin({ bottom: 16 })

              // Medical Devices (Toggles)
              Column() {
                Text('Medical Devices')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 12 })

                // Pacemaker switch
                Row() {
                  Row() {
                    Image($r('app.media.pacemaker'))
                      .width(28)
                      .height(28)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Pacemaker')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#191C1D')
                  }
                  
                  Toggle({ type: ToggleType.Switch, isOn: this.pacemaker })
                    .selectedColor('#003D9B')
                    .onChange((isOn: boolean) => {
                      this.pacemaker = isOn;
                    })}.width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .alignItems(VerticalAlign.Center)
                .margin({ bottom: 12 })

                // Hearing Aid switch
                Row() {
                  Row() {
                    Image($r('app.media.hearingaid'))
                      .width(28)
                      .height(28)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Hearing Aid')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#191C1D')
                  }
                  
                  Toggle({ type: ToggleType.Switch, isOn: this.hearingAid })
                    .selectedColor('#003D9B')
                    .onChange((isOn: boolean) => {
                      this.hearingAid = isOn;
                    })}.width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .alignItems(VerticalAlign.Center)}.width('100%')
              .margin({ bottom: 24 })

              // GuardianBand serial. The backend checks readings against this
              // value and rejects a mismatch with 403, so the app only stamps a
              // serial onto readings once the patient has entered one here.
              Column() {
                Text('GuardianBand Serial (optional)')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                TextInput({ text: this.bandIdentifier, placeholder: 'e.g. GB-12345' })
                  .width('100%')
                  .height(52)
                  .fontSize(16)
                  .backgroundColor('#F0F4F8')
                  .borderRadius(12)
                  .padding({ left: 16, right: 16 })
                  .onChange((value: string) => {
                    this.bandIdentifier = value;
                  })

                Text('Leave empty if you have not paired a band yet.')
                  .fontSize(12)
                  .fontColor('#737685')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, top: 6 })
              }
              .width('100%')
              .margin({ bottom: 24 })

            } else if (this.role === 'doctor') {
              // DOCTOR FORM FIELDS

              // Hospital / Clinic Input
              Column() {
                Text('Hospital / Clinic Name')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4, bottom: 8 })

                Row() {
                  Image($r('app.media.place'))
                    .width(20)
                    .height(20)
                    .margin({ left: 16, right: 8 })

                  TextInput({ placeholder: 'e.g. City General Hospital', text: this.doctorHospital })
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(16)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.doctorHospital = value;
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
              .margin({ bottom: 20 })

              // Doctor Email Address Input
              Column() {
                Text('Doctor Email Address')
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

                  TextInput({ placeholder: 'doctor@hospital.com', text: this.doctorEmail })
                    .type(InputType.Email)
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(16)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.doctorEmail = value;
                      // Clear the error as the user keeps typing so the warning
                      // disappears as soon as the address becomes valid.
                      if (this.doctorEmailError.length > 0 && ApiService.isValidEmail(value)) {
                        this.doctorEmailError = '';
                      }
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({
                  width: 1,
                  color: this.doctorEmailError.length > 0 ? '#BA1A1A' : 'rgba(0, 61, 155, 0.1)',
                  style: BorderStyle.Solid
                })

                if (this.doctorEmailError.length > 0) {
                  Text(this.doctorEmailError)
                    .fontSize(12)
                    .fontColor('#BA1A1A')
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 4, top: 6 })
                }}.width('100%')
              .margin({ bottom: 20 })

              // Specialized Area Select Pills Grid (Collapsible/Accordion Menu)
              Column() {
                // Collapsible Header Row
                Row() {
                  Image($r('app.media.doctor'))
                    .width(20)
                    .height(20)
                    .margin({ right: 8 })

                  Column() {
                    Text('Specialized Area / Department')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#434654')
                      .margin({ bottom: 2 })

                    Text(this.doctorSpecialty === 'Other' && this.otherDoctorSpecialty ? this.otherDoctorSpecialty : this.doctorSpecialty)
                      .fontSize(12)
                      .fontColor('#003D9B')
                      .fontWeight(FontWeight.Medium)}.alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(this.isSpecialtyExpanded ? '▲' : '▼')
                    .fontSize(12)
                    .fontColor('#737685')
                    .margin({ right: 8 })}.width('100%')
                .padding(14)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.15)', style: BorderStyle.Solid })
                .onClick(() => {
                  this.isSpecialtyExpanded = !this.isSpecialtyExpanded;
                })

                // Expanded Section showing the pills
                if (this.isSpecialtyExpanded) {
                  Column() {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.specialtyOptions, (spec: string) => {
                        Row() {
                          Text(spec)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(this.doctorSpecialty === spec ? Color.White : '#434654')}.padding({ left: 16, right: 16, top: 10, bottom: 10 })
                        .margin(4)
                        .backgroundColor(this.doctorSpecialty === spec ? '#003D9B' : '#FFFFFF')
                        .borderRadius(20)
                        .border({ width: this.doctorSpecialty === spec ? 0 : 1, color: '#C3C6D6', style: BorderStyle.Solid })
                        .onClick(() => {
                          this.doctorSpecialty = spec;
                          if (spec !== 'Other') {
                            this.isSpecialtyExpanded = false;
                          }
                        })
                      }, (item: string) => item)}.width('100%')}.width('100%')
                  .padding({ top: 12, bottom: 4 })
                }

                // Custom Specialty Input (if "Other" is chosen)
                if (this.doctorSpecialty === 'Other') {
                  Column() {
                    Text('Specify Specialty')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#434654')
                      .alignSelf(ItemAlign.Start)
                      .margin({ left: 4, bottom: 6 })

                    Row() {
                      Image($r('app.media.pencil'))
                        .width(18)
                        .height(18)
                        .margin({ left: 16, right: 8 })

                      TextInput({ placeholder: 'e.g. Cardiothoracic Surgery', text: this.otherDoctorSpecialty })
                        .placeholderColor('rgba(115, 118, 133, 0.5)')
                        .fontSize(15)
                        .backgroundColor(Color.Transparent)
                        .height('100%')
                        .layoutWeight(1)
                        .onChange((value: string) => {
                          this.otherDoctorSpecialty = value;
                        })}.width('100%')
                    .height(48)
                    .backgroundColor('#F3F4F5')
                    .borderRadius(12)
                    .alignItems(VerticalAlign.Center)
                    .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
                  .margin({ top: 16 })
                }}.width('100%')
              .margin({ bottom: 24 })

            } else {
              // FAMILY MEMBER FORM FIELDS

              // Email Input
              Column() {
                Text('Email Address')
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

                  TextInput({ placeholder: 'e.g. name@example.com', text: this.email })
                    .type(InputType.Email)
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(16)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.email = value;
                      if (this.emailError.length > 0 && ApiService.isValidEmail(value)) {
                        this.emailError = '';
                      }
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({
                  width: 1,
                  color: this.emailError.length > 0 ? '#BA1A1A' : 'rgba(0, 61, 155, 0.1)',
                  style: BorderStyle.Solid
                })

                if (this.emailError.length > 0) {
                  Text(this.emailError)
                    .fontSize(12)
                    .fontColor('#BA1A1A')
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 4, top: 6 })
                }}.width('100%')
              .margin({ bottom: 24 })
            }

            // Complete Button
            Button() {
              Row() {
                Text('Complete Profile')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .margin({ right: 8 })
                Text('➔')
                  .fontSize(18)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
              }}.width('100%')
            .height(56)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
            .onClick(() => {
              if (this.role === 'patient') {
                if (!this.birthDate || !this.heightCm || !this.weightKg) {
                  promptAction.showToast({ message: 'Please fill in your height, weight, and birth date.' });
                  return;
                }
                
                // Log Patient Profile Data
                console.log("\n==================================================");
                console.log("[PROFILE SAVED] PATIENT MEDICAL DATA:");
                console.log(`- Birth Date: ${this.birthDate}`);
                console.log(`- Gender: ${this.selectedGender}`);
                console.log(`- Height: ${this.heightCm} cm`);
                console.log(`- Weight: ${this.weightKg} kg`);
                console.log(`- Blood Type: ${this.bloodType}`);
                console.log(`- Chronic Diseases: ${this.chronicDiseases.join(', ')}`);
                if (this.chronicDiseases.includes('Other')) {
                  console.log(`  - Other Disease Description: ${this.otherChronicDisease}`);
                }
                console.log(`- Allergies: ${this.allergies || 'None'}`);
                console.log(`- Pacemaker: ${this.pacemaker ? 'Yes' : 'No'}`);
                console.log(`- Hearing Aid: ${this.hearingAid ? 'Yes' : 'No'}`);
                console.log("==================================================\n");
                
                // Map chronicDiseases to replace 'Other' with custom typed disease name
                let finalDiseases: string[] = this.chronicDiseases.map((d: string) => {
                  if (d === 'Other') {
                    return this.otherChronicDisease ? this.otherChronicDisease.trim() : '';
                  }
                  return d;
                }).filter((d: string) => d.length > 0);

                // Store in AppStorage for local frontend use
                AppStorage.setOrCreate('medicalProfile', {
                  birthDate: this.birthDate,
                  gender: this.selectedGender,
                  height: this.heightCm,
                  weight: this.weightKg,
                  bloodType: this.bloodType,
                  diseases: finalDiseases,
                  otherChronicDisease: this.otherChronicDisease,
                  allergies: this.allergies,
                  pacemaker: this.pacemaker,
                  hearingAid: this.hearingAid,
                  bandIdentifier: this.bandIdentifier.trim()
                });

                if (SessionStore.isAuthenticated()) {
                  // Allergies can be entered comma-separated; parse them instead of
                  // squashing everything into a single array element.
                  const allergyList: string[] = this.allergies
                    ? this.allergies.split(',').map((a: string) => a.trim()).filter((a: string) => a.length > 0)
                    : [];

                  // Details that matter in an emergency, such as pacemaker and
                  // hearing aid, used to go nowhere; they now travel in criticalFacts.
                  const facts: CriticalFacts = {
                    allergies: allergyList,
                    chronicConditions: finalDiseases,
                    pacemaker: this.pacemaker,
                    hearingAid: this.hearingAid,
                    gender: this.selectedGender,
                    heightCm: Number(this.heightCm),
                    weightKg: Number(this.weightKg)
                  };

                  const profilePayload: PatientProfile = {
                    displayName: AppStorage.get<string>('fullName'),
                    birthDate: this.birthDate,
                    bloodType: this.bloodType,
                    criticalFacts: facts,
                    timezone: ApiConfig.deviceTimezone(),
                    // Sent even when empty: PUT is a full replace, so omitting
                    // it would unpair a band the patient set up earlier.
                    bandIdentifier: this.bandIdentifier.trim()
                  };

                  ApiService.putProfile(profilePayload)
                    .then(() => {
                      console.info('[API] PUT /api/profile - OK');
                      promptAction.showToast({ message: 'Profile saved.' });
                    })
                    .catch((err: Error) => {
                      // This error used to be swallowed silently, which is why the
                      // blood type mismatch stayed invisible for so long.
                      console.error(`[API] PUT /api/profile - FAILED: ${err.message}`);
                      promptAction.showToast({ message: `Could not save profile: ${err.message}` });
                    });
                } else {
                  promptAction.showToast({ message: 'No active session; the profile was saved on this device only.' });
                }
              } else if (this.role === 'doctor') {
                if (!this.doctorHospital || !this.doctorEmail) {
                  promptAction.showToast({ message: 'Hospital name and email address are required.' });
                  return;
                }
                if (!ApiService.isValidEmail(this.doctorEmail)) {
                  this.doctorEmailError = 'Enter a valid email address. Example: name.surname@hospital.com';
                  promptAction.showToast({ message: this.doctorEmailError });
                  return;
                }
                this.doctorEmailError = '';
                this.doctorEmail = ApiService.normalizeEmail(this.doctorEmail);
                if (this.doctorSpecialty === 'Other' && !this.otherDoctorSpecialty) {
                  promptAction.showToast({ message: 'Please specify your specialized area.' });
                  return;
                }

                const finalSpecialty = this.doctorSpecialty === 'Other' ? this.otherDoctorSpecialty : this.doctorSpecialty;

                // Log Doctor Profile Data
                console.log("\n==================================================");
                console.log(`[PROFILE SAVED] DOCTOR DATA:`);
                console.log(`- Hospital: ${this.doctorHospital}`);
                console.log(`- Email: ${this.doctorEmail}`);
                console.log(`- Specialty: ${finalSpecialty}`);
                console.log("==================================================\n");

                // Store in AppStorage for local frontend use - initially NOT verified
                const docProfileData: DoctorProfile = {
                  hospital: this.doctorHospital,
                  specialty: finalSpecialty,
                  email: this.doctorEmail,
                  isVerified: false
                };
                AppStorage.setOrCreate('doctorProfile', docProfileData);
              } else {
                if (!this.email) {
                  promptAction.showToast({ message: 'Email address is required.' });
                  return;
                }
                if (!ApiService.isValidEmail(this.email)) {
                  this.emailError = 'Enter a valid email address. Example: name.surname@example.com';
                  promptAction.showToast({ message: this.emailError });
                  return;
                }
                this.emailError = '';
                this.email = ApiService.normalizeEmail(this.email);

                // Log Family Profile Data
                console.log("\n==================================================");
                console.log(`[PROFILE SAVED] FAMILY DATA:`);
                console.log(`- Email: ${this.email}`);
                console.log("==================================================\n");
                
                // Store in AppStorage for local frontend use
                AppStorage.setOrCreate('userEmail', this.email);
              }

              AppStorage.setOrCreate('userRole', this.role);

              // Persist the role AND the family/doctor profile fields through
              // `PUT /api/account`, so they survive a reinstall or a sign-in on
              // another device. They used to be written to the device only,
              // which meant setup was requested all over again elsewhere.
              //
              // The saved `role` is only updated when this is the FIRST,
              // primary-role setup reached from SelectRolePage (canGoBack is
              // unset there). When this page is reached from ProfilePage's role
              // switcher (canGoBack: true) to configure an ADDITIONAL role, the
              // account's primary role must not silently change - otherwise
              // trying out "Doctor" once permanently redirected every future
              // login to the doctor dashboard instead of the role picked at
              // registration. Leaving `role` out of the patch keeps the stored
              // one; AccountRepository merges the rest on top of it.
              AccountRepository.savePatch({
                role: this.canGoBack ? undefined : this.role,
                email: this.role === 'family' ? this.email : undefined,
                doctorHospital: this.role === 'doctor' ? this.doctorHospital : undefined,
                doctorSpecialty: this.role === 'doctor'
                  ? (this.doctorSpecialty === 'Other' ? this.otherDoctorSpecialty : this.doctorSpecialty)
                  : undefined,
                doctorEmail: this.role === 'doctor' ? this.doctorEmail : undefined
              }).catch((err: Error) => console.warn(`[AccountRepository] Could not save the account role: ${err.message}`));

              promptAction.showToast({ message: 'Profile completed successfully!' });
              router.pushUrl({ url: 'pages/HomePage' });
            })}.width('100%')
          .padding(24)
          .backgroundColor('rgba(255, 255, 255, 0.85)')
          .borderRadius(32)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
          .shadow({ radius: 15, color: 'rgba(0, 61, 155, 0.08)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 20 })}.width('100%')}.scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })}.width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}