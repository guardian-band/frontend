import { router, promptAction } from '@kit.ArkUI';
import { ApiService, ApiError, AuthResult } from '../services/ApiService';
import { SessionStore, LocalUserProfile } from '../services/SessionStore';
import { ProfileRepository } from '../services/ProfileRepository';

@Entry
@Component
struct LoginPage {
  @State identifier: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;

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

      // Content Container
      Column() {
        Blank() // Dynamic spacer for centering layout

        // 1. Branding Header
        Column() {
          Image($r('app.media.logo_blank'))
            .width(70)
            .height(70)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 16 })

          Text('GuardianBand')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .margin({ bottom: 8 })

          Text('Compassionate monitoring and safety for your loved ones.')
            .fontSize(15)
            .fontColor('#434654')
            .textAlign(TextAlign.Center)
            .width('85%')
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 32 })

        // 2. Login Form Card (Glassmorphism look)
        Column() {
          // Phone Number Input
          Column() {
            Text('Phone Number')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 8 })

            Row() {
              Image($r('app.media.phone'))
                .width(20)
                .height(20)
                .margin({ left: 16, right: 8 })

              TextInput({ placeholder: '+905551234567', text: this.identifier })
                .type(InputType.PhoneNumber)
                .placeholderColor('rgba(115, 118, 133, 0.5)')
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .height('100%')
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.identifier = value;
                })
            }
            .width('100%')
            .height(60)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)
            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Password Input
          Column() {
            Text('Password')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#434654')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 8 })

            Row() {
              Image($r('app.media.password'))
                .width(20)
                .height(20)
                .margin({ left: 16, right: 8 })

              TextInput({ placeholder: '••••••••', text: this.password })
                .type(InputType.Password)
                .placeholderColor('rgba(115, 118, 133, 0.5)')
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .height('100%')
                .layoutWeight(1)
                .showPasswordIcon(true) // Uses the system's built-in interactive eye icon
                .onChange((value: string) => {
                  this.password = value;
                })
            }
            .width('100%')
            .height(60)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)
            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // Login Button
          Button() {
            Row() {
              Text(this.isLoading ? 'Logging in...' : 'Login')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ right: 8 })
              if (!this.isLoading) {
                Text('➔')
                  .fontSize(18)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
              }
            }
          }
          .width('100%')
          .height(60)
          .backgroundColor('#003D9B')
          .borderRadius(16)
          .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
          .onClick(() => {
            if (this.isLoading) return;
            if (!this.identifier || !this.password) {
              promptAction.showToast({ message: 'Phone number and password are required.' })
            } else {
              this.isLoading = true;
              const normalizedPhone: string = ApiService.normalizePhone(this.identifier);
              ApiService.login(normalizedPhone, this.password)
                .then((auth: AuthResult) => {
                  // The token is now persisted by SessionStore.
                  // userId stays empty until the backend adds it (backend request BT-01).
                  const uid: string = auth.userId !== undefined ? auth.userId : '(not sent by backend)';
                  console.info(`[API] POST /api/login - OK, userId=${uid}`);

                  AppStorage.setOrCreate('userPhone', normalizedPhone)
                  AppStorage.setOrCreate('isJustRegistered', false)
                  promptAction.showToast({ message: 'Signed in successfully.' })

                  // This account's device-stored client-side profile: role,
                  // family email, doctor details. Kept per user (keyed by phone
                  // number), so another account's setup on the same device does
                  // not affect it.
                  const local: LocalUserProfile = SessionStore.getLocalProfile(normalizedPhone);
                  const roleForUser: string = local.role;

                  // RESTORE the family/doctor profile. It has no backend home;
                  // it used to be wiped on every sign-in, so setup was asked again.
                  //
                  // Restored whenever the data exists on this account, NOT only
                  // when 'doctor' happens to be the current primary role: since
                  // ProfilePage's role switcher lets a patient also configure a
                  // Doctor profile as a secondary role, gating this on the
                  // primary role wiped a fully-configured doctor profile back to
                  // empty on every sign-in for anyone whose primary role wasn't
                  // doctor - so it kept asking to set it up again. The family
                  // email restore below never had this bug; it already checks
                  // whether the data exists, not which role is active.
                  if (local.doctorEmail.length > 0) {
                    AppStorage.setOrCreate('doctorProfile', {
                      hospital: local.doctorHospital,
                      specialty: local.doctorSpecialty,
                      email: local.doctorEmail,
                      isVerified: local.doctorVerified
                    })
                  } else {
                    AppStorage.setOrCreate('doctorProfile',
                      { hospital: '', specialty: '', email: '', isVerified: false })
                  }
                  if (local.email.length > 0) {
                    AppStorage.setOrCreate('userEmail', local.email)
                  }

                  // Having a profile is a hard prerequisite: every patient-scoped
                  // table in the backend (SOS, emergency contacts, medications,
                  // invitations) has an FK to patient_profiles(user_id). Without a
                  // profile those endpoints return 500/403.
                  //
                  // The backend has no notion of roles, so we use the presence of a
                  // profile as a role hint:
                  //   profile FOUND   -> patient, go straight to the home screen
                  //   profile MISSING -> could be a doctor, or a patient whose setup
                  //                      was interrupted; let them pick a role
                  // Load the FULL profile (name, height, weight, gender, conditions).
                  // Just checking for existence was not enough: nothing was written
                  // into AppStorage, so the fields looked empty after signing in.
                  return ProfileRepository.load()
                    .then(() => {
                      // Profile exists. Use the stored role if there is one;
                      // otherwise a patient profile implies this is a patient.
                      const role: string = roleForUser.length > 0 ? roleForUser : 'patient';
                      AppStorage.setOrCreate('userRole', role)
                      console.info(`[Login] Rol: ${role} -> HomePage`);
                      router.replaceUrl({ url: 'pages/HomePage' })
                    })
                    .catch((profileErr: Error) => {
                      const status: number = profileErr instanceof ApiError ? (profileErr as ApiError).status : -1;
                      if (status === 404) {
                        // No patient profile. If a role is stored (doctor/family)
                        // go straight to that dashboard; otherwise pick a role.
                        if (roleForUser.length > 0) {
                          AppStorage.setOrCreate('userRole', roleForUser)
                          console.info(`[Login] No profile but role is stored: ${roleForUser} -> HomePage`);
                          router.replaceUrl({ url: 'pages/HomePage' })
                        } else {
                          promptAction.showToast({ message: 'Complete your setup to continue.' })
                          router.replaceUrl({ url: 'pages/SelectRolePage' })
                        }
                      } else {
                        // A network/server error does not mean the profile is missing.
                        console.warn(`[API] GET /api/profile check failed (status=${status}): ${profileErr.message}`);
                        AppStorage.setOrCreate('userRole', roleForUser.length > 0 ? roleForUser : 'patient')
                        router.replaceUrl({ url: 'pages/HomePage' })
                      }
                    })
                })
                .catch((err: Error) => {
                  // Log the real status code; a hard-coded 401 was misleading when debugging.
                  const status: number = err instanceof ApiError ? (err as ApiError).status : -1;
                  console.error(`[API] POST /api/login - FAILED (status=${status}): ${err.message}`);
                  promptAction.showToast({ message: err.message })
                })
                .finally(() => {
                  this.isLoading = false;
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

        Blank() // Dynamic spacer for centering layout

        // 3. Footer Link (Don't have an account? Create one)
        Row() {
          Text("Don't have an account? ")
            .fontSize(15)
            .fontColor('#434654')

          Text('Create one')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .onClick(() => {
              router.pushUrl({ url: 'pages/RegisterPage' })
            })
        }
        .margin({ bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA') // Base background color under blurs
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}