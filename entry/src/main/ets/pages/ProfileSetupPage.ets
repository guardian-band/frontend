import { router, promptAction } from '@kit.ArkUI';
import { ApiService, PatientProfile } from '../services/ApiService';

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
  @State isDiseasesExpanded: boolean = false;
  @State otherChronicDisease: string = '';
  
  // Family fields
  @State email: string = '';
  @State canGoBack: boolean = false;

  // Doctor fields
  @State doctorHospital: string = '';
  @State doctorEmail: string = '';
  @State verificationCode: string = '';
  @State isCodeSent: boolean = false;
  @State isDoctorVerified: boolean = false;
  @State doctorSpecialty: string = 'General Medicine';
  @State otherDoctorSpecialty: string = '';
  @State isSpecialtyExpanded: boolean = false;

  private scroller: Scroller = new Scroller();
  
  private diseaseOptions: string[] = ['Hypertension', 'Diabetes', 'Asthma', 'Heart Failure', 'Alzheimer\'s', 'Other'];
  private bloodTypes: string[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];
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
          // 1. Header
          Stack({ alignContent: Alignment.TopStart }) {
            Column() {
              Text('GuardianBand')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 8, top: 20 })

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
                        this.birthDate = `${value.year}-${value.month + 1}-${value.day}`;
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
                    .placeholderColor('rgba(115, 118, 133, 0.5)')
                    .fontSize(16)
                    .backgroundColor(Color.Transparent)
                    .height('100%')
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.doctorEmail = value;
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
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
                    })}.width('100%')
                .height(56)
                .backgroundColor('#F3F4F5')
                .borderRadius(16)
                .alignItems(VerticalAlign.Center)
                .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })}.width('100%')
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
                  hearingAid: this.hearingAid
                });

                let token = AppStorage.get<string>('token') || '';
                if (token) {
                  let profilePayload: PatientProfile = {
                    birthDate: this.birthDate,
                    bloodType: this.bloodType,
                    criticalFacts: {
                      "allergies": this.allergies ? [this.allergies] : [],
                      "chronicConditions": finalDiseases
                    } as Record<string, string[]>,
                    timezone: "Europe/Istanbul"
                  };

                  ApiService.putProfile(token, profilePayload)
                    .catch((err: Error) => console.error("Profile sync error", err.message));
                }
              } else if (this.role === 'doctor') {
                if (!this.doctorHospital || !this.doctorEmail) {
                  promptAction.showToast({ message: 'Please fill in hospital name and email address.' });
                  return;
                }
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
                  promptAction.showToast({ message: 'Please enter a valid email address.' });
                  return;
                }
                
                // Log Family Profile Data
                console.log("\n==================================================");
                console.log(`[PROFILE SAVED] FAMILY DATA:`);
                console.log(`- Email: ${this.email}`);
                console.log("==================================================\n");
                
                // Store in AppStorage for local frontend use
                AppStorage.setOrCreate('userEmail', this.email);
              }

              AppStorage.setOrCreate('userRole', this.role);
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
