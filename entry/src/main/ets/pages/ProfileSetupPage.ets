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
  @State email: string = '';
  @State canGoBack: boolean = false;
  @State doctorHospital: string = '';
  @State doctorEmail: string = '';
  @State verificationCode: string = '';
  @State isCodeSent: boolean = false;
  @State isDoctorVerified: boolean = false;
  @State doctorSpecialty: string = 'General Medicine';
  @State otherDoctorSpecialty: string = '';
  @State isSpecialtyExpanded: boolean = false;

  private scroller: Scroller = new Scroller();
  private diseaseOptions: string[] = ['Hypertension', 'Diabetes', 'Asthma', 'Heart Failure', "Alzheimer's", 'Other'];
  private bloodTypes: string[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];
  private specialtyOptions: string[] = ['General Medicine', 'Cardiology', 'Neurology', 'Geriatrics', 'Pediatrics', 'Other'];

  aboutToAppear() {
    const params = router.getParams() as Record<string, string | boolean>;
    if (params) {
      if (params.role) this.role = params.role as string;
      if (params.canGoBack) this.canGoBack = params.canGoBack as boolean;
    }
  }

  build() {
    Stack() {
      // Background gradients
      Row().width(500).height(500).position({ x: -200, y: -200 }).radialGradient({
        center: ['50%', '50%'], radius: 250, colors: [['rgba(218, 226, 255, 0.5)', 0.0], ['rgba(218, 226, 255, 0.0)', 1.0]]
      })

      Scroll(this.scroller) {
        Column() {
          // Header
          Column() {
            Text('GuardianBand')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 8, top: 20 })
          }.width('100%').margin({ bottom: 24 })

          Column() {
            Text(this.role === 'patient' ? 'Create Health Profile' : 'Profile Details')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 20 })

            if (this.role === 'patient') {
              // Patient Fields
              Button('Complete Profile')
                .width('100%')
                .height(56)
                .backgroundColor('#003D9B')
                .borderRadius(16)
                .onClick(() => {
                  let token = AppStorage.get<string>('token') || '';
                  if (token) {
                    // EXPLICIT TYPE DEFINITION TO AVOID COMPILER ERRORS
                    let profilePayload: PatientProfile = {
                      birthDate: this.birthDate,
                      bloodType: this.bloodType,
                      criticalFacts: {
                        "allergies": this.allergies ? [this.allergies] : [],
                        "chronicConditions": this.chronicDiseases || []
                      } as Record<string, string[]>,
                      timezone: "Europe/Istanbul"
                    };

                    ApiService.putProfile(token, profilePayload)
                      .catch((err: Error) => console.error("Profile sync error", err.message));
                  }

                  AppStorage.setOrCreate('medicalProfile', {
                    birthDate: this.birthDate,
                    gender: this.selectedGender,
                    height: this.heightCm,
                    weight: this.weightKg,
                    bloodType: this.bloodType,
                    diseases: this.chronicDiseases
                  });

                  promptAction.showToast({ message: 'Profile completed successfully!' });
                  router.pushUrl({ url: 'pages/HomePage' });
                })
            }
          }
          .padding(24)
          .backgroundColor('rgba(255, 255, 255, 0.85)')
          .borderRadius(32)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
  }
}