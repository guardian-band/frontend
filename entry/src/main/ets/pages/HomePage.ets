// HomePage.ets
import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';
import { geoLocationManager } from '@kit.LocationKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface MedicationItem {
  id: string;
  name: string;
  dosage: string;
  time: string;
  taken: boolean;
}

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

// Interface for chart coordinates to satisfy ArkTS strict typing
interface ChartPoint {
  x: number;
  y: number;
}

@Entry
@Component
struct HomePage {
  @StorageLink('token') token: string = '';
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';
  @StorageLink('profilePicture') profilePicture: string = '';
  @StorageLink('doctorProfile') doctorProfile: DoctorProfile = { hospital: '', specialty: '', email: '', isVerified: false };
  @StorageLink('previousRole') previousRole: string = 'patient';
  @State isDoctorVerificationModalOpen: boolean = false;
  @State enteredVerificationCode: string = '';

  @State isQrModalOpen: boolean = false;
  @State isQrScanning: boolean = false;
  @State showTelemetryResult: boolean = false;
  @State scanProgress: number = 0;
  private scanIntervalId: number = -1;

  async startQrScanner() {
    promptAction.showToast({ message: 'Opening camera...', duration: 800 });

    try {
      const context = getContext(this) as common.UIAbilityContext;

      let pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };

      // Launch the real system Camera Picker (matching meds page scanner logic!)
      let pickerResult = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);

      if (pickerResult && pickerResult.resultUri) {
        promptAction.showToast({ message: 'Processing QR code, please wait...' });
        
        // Simulating QR code decoding from the captured smartwatch photo
        setTimeout(() => {
          this.handleScanSuccess();
        }, 1000);
      }
    } catch (e) {
      // Fallback for emulator environments
      this.launchFallbackScanner();
    }
  }

  launchFallbackScanner() {
    this.isQrModalOpen = true;
    this.showTelemetryResult = false;
    this.scanProgress = 0;

    // Laser animation simulation
    let direction = 1;
    this.scanIntervalId = setInterval(() => {
      this.scanProgress += direction * 5;
      if (this.scanProgress >= 90) {
        direction = -1;
      } else if (this.scanProgress <= 10) {
        direction = 1;
      }
    }, 50);

    // Auto capture after 3.5 seconds of scanning (simulating QR detection)
    setTimeout(() => {
      if (this.isQrModalOpen && !this.showTelemetryResult) {
        this.handleScanSuccess();
      }
    }, 3500);
  }

  handleScanSuccess() {
    clearInterval(this.scanIntervalId);
    this.showTelemetryResult = true;
    promptAction.showToast({ message: 'Vitals telemetry scanned successfully!' });
  }

  closeQrScanner() {
    clearInterval(this.scanIntervalId);
    this.isQrModalOpen = false;
    this.showTelemetryResult = false;
  }

  aboutToAppear() {
    if (this.userRole === 'doctor' && !this.doctorProfile.isVerified) {
      setTimeout(() => {
        this.isDoctorVerificationModalOpen = true;
        promptAction.showToast({ message: 'Verification code automatically sent to your professional email address!' });
      }, 500);
    }
  }

  private scroller: Scroller = new Scroller();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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
          if (this.userRole === 'patient') {
            PatientDashboardView({ fullName: this.fullName, onQrScanClick: () => { this.startQrScanner(); } })
          } else if (this.userRole === 'family') {
            FamilyDashboardView({ fullName: this.fullName, onQrScanClick: () => { this.startQrScanner(); } })
          } else if (this.userRole === 'doctor') {
            DoctorDashboardView({ onQrScanClick: () => { this.startQrScanner(); } })
          }

          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      BottomNavBar({ activeTab: 'home' })
        .zIndex(1)

      // Doctor Verification Overlay Modal
      if (this.isDoctorVerificationModalOpen) {
        Stack() {
          // Dimmed background
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.65)')

          Column() {
            // Alert Image Icon
            Image($r('app.media.alert'))
              .width(56)
              .height(56)
              .objectFit(ImageFit.Contain)
              .margin({ bottom: 20 })

            Text('Doctor Verification Required')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
              .margin({ bottom: 12 })
              .textAlign(TextAlign.Center)

            Text(`A verification code was automatically sent to your medical email address:\n\n${this.doctorProfile.email || 'doctor@hospital.com'}`)
              .fontSize(14)
              .fontColor('#434654')
              .textAlign(TextAlign.Center)
              .lineHeight(20)
              .margin({ bottom: 24 })
              .width('90%')

            // Code Entry Field
            Row() {
              Image($r('app.media.name'))
                .width(20)
                .height(20)
                .margin({ left: 16, right: 8 })

              TextInput({ placeholder: 'Enter 6-digit code (e.g. 123456)', text: this.enteredVerificationCode })
                .placeholderColor('rgba(115, 118, 133, 0.5)')
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .height('100%')
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.enteredVerificationCode = value;
                })
            }
            .width('100%')
            .height(56)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)
            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)', style: BorderStyle.Solid })
            .margin({ bottom: 24 })

            // Action Buttons
            Button('Unlock Doctor Portal', { type: ButtonType.Normal })
              .width('100%')
              .height(48)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#003D9B')
              .borderRadius(12)
              .margin({ bottom: 12 })
              .onClick(() => {
                if (this.enteredVerificationCode === '123456') {
                  this.doctorProfile.isVerified = true;
                  
                  // Persist back to AppStorage
                  AppStorage.setOrCreate('doctorProfile', {
                    hospital: this.doctorProfile.hospital,
                    specialty: this.doctorProfile.specialty,
                    email: this.doctorProfile.email,
                    isVerified: true
                  });

                  this.isDoctorVerificationModalOpen = false;
                  promptAction.showToast({ message: 'Doctor portal unlocked successfully!' });
                } else {
                  promptAction.showToast({ message: 'Invalid verification code. Please enter 123456.' });
                }
              })

            Button('Cancel / Go Back', { type: ButtonType.Normal })
              .width('100%')
              .height(48)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#737685')
              .backgroundColor(Color.Transparent)
              .borderRadius(12)
              .border({ width: 1, color: 'rgba(0, 0, 0, 0.1)', style: BorderStyle.Solid })
              .onClick(() => {
                // Return to their previous working role dashboard (patient or family)
                this.userRole = this.previousRole;
                this.isDoctorVerificationModalOpen = false;
                promptAction.showToast({ message: `Returned to ${this.previousRole} dashboard.` });
              })
          }
          .width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 16, color: 'rgba(0,0,0,0.15)', offsetY: 8 })
          .zIndex(20)
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }

      // QR Code Scanner Overlay Modal
      if (this.isQrModalOpen) {
        Stack() {
          // Dark overlay background
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.6)')
            .onClick(() => {
              this.closeQrScanner();
            })

          Column() {
            if (!this.showTelemetryResult) {
              // SCANNING VIEW
              Column() {
                Row() {
                  Text('Emergency Scan')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                  Blank()
                  Text('✕')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#737685')
                    .onClick(() => {
                      this.closeQrScanner();
                    })
                }
                .width('100%')
                .margin({ bottom: 20 })

                Text("Position the smartwatch QR code inside the frame to scan the patient's latest vitals.")
                  .fontSize(14)
                  .fontColor('#737685')
                  .textAlign(TextAlign.Center)
                  .margin({ bottom: 24 })

                // Animated Scan Frame
                Stack() {
                  // Scanner visual mockup background
                  Column()
                    .width(200)
                    .height(200)
                    .borderRadius(16)
                    .border({ width: 2, color: '#003D9B', style: BorderStyle.Solid })

                  // Scanning laser animation line
                  Row()
                    .width(180)
                    .height(4)
                    .backgroundColor('#003D9B')
                    .shadow({ radius: 8, color: '#003D9B' })
                    .position({ x: 10, y: `${this.scanProgress}%` })
                }
                .width(200)
                .height(200)
                .margin({ bottom: 30 })

                Text('Scanning...')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#003D9B')
              }
              .width('90%')
              .padding(24)
              .backgroundColor(Color.White)
              .borderRadius(24)
              .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)' })
            } else {
              // TELEMETRY RESULT VIEW
              Column() {
                Row() {
                  Image($r('app.media.alert'))
                    .width(24)
                    .height(24)
                    .margin({ right: 8 })
                  Text('Emergency Patient Vitals')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#BA1A1A')
                  Blank()
                  Text('✕')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#737685')
                    .onClick(() => {
                      this.closeQrScanner();
                    })
                }
                .width('100%')
                .margin({ bottom: 20 })

                // Patient Info Card
                Row() {
                  Row() {
                    Text('JD')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor('#BA1A1A')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .margin({ right: 12 })

                  Column() {
                    Text('John Doe (Father)')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')
                      .margin({ bottom: 2 })

                    Text('Age: 68 • Smartwatch Connected')
                      .fontSize(12)
                      .fontColor('#737685')
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#FFEBEA')
                .borderRadius(16)
                .margin({ bottom: 20 })

                // Vitals Details
                Column() {
                  // Heart Rate
                  Row() {
                    Row() {
                      Image($r('app.media.heart'))
                        .width(18)
                        .height(18)
                        .margin({ right: 8 })
                      Text('Heart Rate')
                        .fontSize(14)
                        .fontColor('#737685')
                    }
                    Blank()
                    Text('135 bpm (High!)')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#BA1A1A')
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                  .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                  // Oxygen
                  Row() {
                    Row() {
                      Image($r('app.media.oxygensaturation'))
                        .width(18)
                        .height(18)
                        .margin({ right: 8 })
                      Text('Oxygen Saturation')
                        .fontSize(14)
                        .fontColor('#737685')
                    }
                    Blank()
                    Text('94% (Low Alert)')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#854E00')
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                  .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                  // Last Sync
                  Row() {
                    Row() {
                      Image($r('app.media.place'))
                        .width(18)
                        .height(18)
                        .margin({ right: 8 })
                      Text('Location Address')
                        .fontSize(14)
                        .fontColor('#737685')
                    }
                    Blank()
                    Text('Palo Alto, Live')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#003D9B')
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                }
                .width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor(Color.White)
                .borderRadius(16)
                .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
                .margin({ bottom: 24 })

                // Actions
                Row() {
                  Button('Call Contacts', { type: ButtonType.Normal })
                    .layoutWeight(1)
                    .height(44)
                    .backgroundColor('rgba(186, 26, 26, 0.08)')
                    .fontColor('#BA1A1A')
                    .fontWeight(FontWeight.Bold)
                    .borderRadius(12)
                    .margin({ right: 12 })
                    .onClick(() => {
                      promptAction.showToast({ message: 'Emergency dispatch called.' });
                    })

                  Button('Close', { type: ButtonType.Normal })
                    .layoutWeight(1)
                    .height(44)
                    .backgroundColor('#003D9B')
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                    .borderRadius(12)
                    .onClick(() => {
                      this.closeQrScanner();
                    })
                }
                .width('100%')
              }
              .width('90%')
              .padding(24)
              .backgroundColor(Color.White)
              .borderRadius(24)
              .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)' })
            }
          }
        }
        .width('100%')
        .height('100%')
        .zIndex(20)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

// ----------------------------------------------------
// PATIENT DASHBOARD VIEW
// ----------------------------------------------------
@Component
struct PatientDashboardView {
  @Prop fullName: string;
  onQrScanClick: () => void = () => {};
  @StorageLink('profilePicture') profilePicture: string = '';
  @StorageLink('dashboardMeds') dashboardMeds: MedicationItem[] = [];
  @StorageLink('medications') medications: FullMedicationItem[] = [];


  @State currentHeartRate: number = 72;
  @State currentOxygen: number = 98;
  @State currentSteps: number = 4500;
  @State currentCalories: number = 1450;
  private timerId: number = -1;

  // --- REAL-TIME TELEMETRY HISTORY LISTS FOR LIVE CHARTS ---
  @State heartRateHistory: number[] = [70, 72, 71, 73, 72, 70, 72];
  @State oxygenHistory: number[] = [97, 98, 98, 97, 99, 98, 98];

  // --- MODAL GRAPH STATES ---
  @State isGraphModalOpen: boolean = false;
  @State selectedMetric: string = 'Heart Rate';
  @State selectedValue: number = 72;

  private chartCanvasController: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  openLiveChartModal(metricName: string, currentVal: number) {
    this.selectedMetric = metricName;
    this.selectedValue = currentVal;
    this.isGraphModalOpen = true;
  }

  aboutToAppear() {
    this.startSensorSimulation();
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  startSensorSimulation() {
    this.timerId = setInterval(() => {
      let hrDelta = Math.floor(Math.random() * 5) - 2;
      this.currentHeartRate = Math.max(60, Math.min(100, this.currentHeartRate + hrDelta));

      let o2Delta = Math.floor(Math.random() * 3) - 1;
      this.currentOxygen = Math.max(95, Math.min(100, this.currentOxygen + o2Delta));

      this.currentSteps += Math.floor(Math.random() * 3);
      this.currentCalories += Math.floor(Math.random() * 2);

      this.heartRateHistory.push(this.currentHeartRate);
      if (this.heartRateHistory.length > 15) {
        this.heartRateHistory.shift();
      }

      this.oxygenHistory.push(this.currentOxygen);
      if (this.oxygenHistory.length > 15) {
        this.oxygenHistory.shift();
      }

      if (this.isGraphModalOpen) {
        if (this.selectedMetric === 'Heart Rate') {
          this.selectedValue = this.currentHeartRate;
        } else if (this.selectedMetric === 'Oxygen') {
          this.selectedValue = this.currentOxygen;
        }
        this.drawMinimalistLineChart();
      }
    }, 2000);
  }

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts: string[] = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  getNextPendingMed(): MedicationItem | undefined {
    for (let i = 0; i < this.dashboardMeds.length; i++) {
      if (!this.dashboardMeds[i].taken) {
        return this.dashboardMeds[i];
      }
    }
    return undefined;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppHeader({ title: 'GuardianBand Home' })
          .margin({ bottom: 16 })

        Row() {
          if (this.profilePicture === '') {
            Row() {
              Text(this.getInitials(this.fullName))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(32)
            .height(32)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
            .margin({ right: 10 })
          } else {
            Image(this.profilePicture)
              .width(32)
              .height(32)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
              .margin({ right: 10 })
          }

          Text(`Welcome, ${this.fullName}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')
            .layoutWeight(1)

          Row() {
            Circle({ width: 8, height: 8 }).fill('#006E2F').margin({ right: 6 })
            Text('Sensors Active')
              .fontSize(12)
              .fontColor('#006E2F')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#E6F9ED')
          .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 20 })

        // AI Health Insight Box
        Row() {
          Row()
            .width(4)
            .height(42)
            .backgroundColor('#003D9B')
            .borderRadius(2)
            .margin({ right: 16 })

          Image($r('app.media.idea'))
            .width(32)
            .height(32)
            .objectFit(ImageFit.Contain)
            .margin({ right: 12 })

          Column() {
            Text('AI Health Insight')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 4 })
            Text(`"Your vitals are stable. Heart rate is trending smoothly around ${this.currentHeartRate} bpm. Activity is up 10% today!"`)
              .fontSize(13)
              .fontColor('#434654')
              .lineHeight(18)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#E8EEFF')
        .borderRadius(20)
        .margin({ bottom: 20 })
        .alignItems(VerticalAlign.Center)

        // Emergency Watch Scanner Banner Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.qr'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
            }
            .width(44)
            .height(44)
            .borderRadius(10)
            .backgroundColor('rgba(0, 61, 155, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Emergency Watch Scanner')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 4 })

              Text("Scan patient's smartwatch QR code to quickly retrieve live vitals and emergency contact info.")
                .fontSize(12)
                .fontColor('#737685')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: 12 })

          Button('Scan Smartwatch QR', { type: ButtonType.Normal })
            .width('100%')
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#003D9B')
            .borderRadius(8)
            .onClick(() => {
              this.onQrScanClick();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(0, 61, 155, 0.2)', style: BorderStyle.Solid })
        .margin({ bottom: 20 })



        Text('Live Vitals & Activity')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        // 2x2 Grid for Vital Cards
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          this.HeartRateCard()
          this.OxygenCard()
          this.SleepCard()
          this.CaloriesCard()
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Daily Steps Card
        Row() {
          Row() {
            Image($r('app.media.walking'))
              .width(40)
              .height(40)
              .objectFit(ImageFit.Contain)
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#E6F9ED')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ right: 12 })

          Column() {
            Text('Daily Steps')
              .fontSize(12)
              .fontColor('#737685')
              .margin({ bottom: 2 })
            Text(`${this.currentSteps}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width(100)
              .height(6)
              .backgroundColor('#E8EEFF')
              .borderRadius(3)

            Row()
              .width(75)
              .height(6)
              .backgroundColor('#006E2F')
              .borderRadius(3)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .margin({ bottom: 20 })
        .alignItems(VerticalAlign.Center)

        // Next Medication Card
        Column() {
          if (this.getNextPendingMed() !== undefined) {
            Row() {
              Text('Next Medication')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')

              Blank()

              Text(this.getNextPendingMed()!.time)
                .fontSize(12)
                .fontColor('#737685')
            }
            .width('100%')
            .margin({ bottom: 12 })

            Row() {
              Row() {
                Image($r('app.media.drugs'))
                  .width(32)
                  .height(32)
                  .objectFit(ImageFit.Contain)
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor('#E8EEFF')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text(this.getNextPendingMed()!.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .margin({ bottom: 2 })

                Text(this.getNextPendingMed()!.dosage)
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .margin({ bottom: 12 })

            Button() {
              Row() {
                Image($r('app.media.like'))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text('Mark as Taken')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .height(48)
            .backgroundColor('#003D9B')
            .borderRadius(12)
            .onClick(() => {
              const nextMed = this.getNextPendingMed();
              if (nextMed !== undefined) {
                this.dashboardMeds = this.dashboardMeds.map((med: MedicationItem): MedicationItem => {
                  if (med.id === nextMed.id) {
                    return {
                      id: med.id,
                      name: med.name,
                      dosage: med.dosage,
                      time: med.time,
                      taken: true
                    };
                  }
                  return med;
                });

                // Sync back to medications list in AppStorage to update MedsPage UI and stock
                const parts = nextMed.id.split('_');
                if (parts.length === 2) {
                  const medId = parts[0];
                  const slot = parts[1];
                  const medIndex = this.medications.findIndex((m: FullMedicationItem) => m.id === medId);
                  if (medIndex !== -1) {
                    const timeIndex = this.medications[medIndex].times.findIndex((t: MedTime) => t.slot === slot);
                    if (timeIndex !== -1) {
                      this.medications[medIndex].times[timeIndex].taken = true;
                      // Decrease stock
                      this.medications[medIndex].totalPills = Math.max(0, this.medications[medIndex].totalPills - 1);
                      this.medications.splice(medIndex, 1, this.medications[medIndex]);
                    }
                  }
                }

                promptAction.showToast({ message: `${nextMed.name} marked as taken!` });
              }
            })
          } else {
            Column() {
              Image($r('app.media.confetti'))
                .width(44)
                .height(44)
                .objectFit(ImageFit.Contain)
                .margin({ bottom: 8 })
              Text('No pending medications')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
                .margin({ bottom: 4 })
              Text('Add medications via Meds schedule to track them here.')
                .fontSize(12)
                .fontColor('#737685')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      }
      .width('100%')

      // --- SWEET MINIMALIST REAL-TIME LINE CHART MODAL ---
      if (this.isGraphModalOpen) {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.35)')
            .onClick(() => { this.isGraphModalOpen = false; })

          Column() {
            // Header
            Row() {
              Column() {
                Text(`${this.selectedMetric} Live Trend`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                Text('Real-time session stream')
                  .fontSize(12)
                  .fontColor('#737685')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Button('✕')
                .type(ButtonType.Circle)
                .width(32)
                .height(32)
                .backgroundColor('#F1F2F5')
                .fontColor('#191C1D')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .onClick(() => { this.isGraphModalOpen = false; })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Live Value Pill
            Row() {
              Text('Current Reading: ')
                .fontSize(13)
                .fontColor('#737685')
              Text(`${this.selectedValue} ${this.selectedMetric === 'Heart Rate' ? 'bpm' : '%'}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#E8EEFF')
            .borderRadius(12)
            .margin({ bottom: 16 })

            // --- MINIMALIST CLEAN CANVAS CHART ---
            Canvas(this.chartCanvasController)
              .width('100%')
              .height(180)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .border({ width: 1, color: '#EBECEF' })
              .onReady(() => {
                this.drawMinimalistLineChart();
              })
              .margin({ bottom: 20 })

            // Close Button
            Button('Done')
              .width('100%')
              .height(44)
              .backgroundColor('#003D9B')
              .fontColor(Color.White)
              .borderRadius(12)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .onClick(() => { this.isGraphModalOpen = false; })
          }
          .width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(28)
          .shadow({ radius: 16, color: 'rgba(0,0,0,0.15)', offsetY: 8 })
          .zIndex(20)
        }
        .width('100%')
        .height('100%')
        .zIndex(15)
      }
    }
    .width('100%')
  }

  // Algorithm using explicit ChartPoint interface to satisfy ArkTS type safety
  drawMinimalistLineChart() {
    const ctx = this.chartCanvasController;
    const width = 300;
    const height = 180;

    ctx.clearRect(0, 0, width, height);

    let dataPoints = this.selectedMetric === 'Heart Rate' ? this.heartRateHistory : this.oxygenHistory;
    if (dataPoints.length === 0) return;

    ctx.strokeStyle = '#F1F2F5';
    ctx.lineWidth = 1;
    for (let y = 30; y < height; y += 35) {
      ctx.beginPath();
      ctx.moveTo(15, y);
      ctx.lineTo(width - 15, y);
      ctx.stroke();
    }

    let minVal = Math.min(...dataPoints);
    let maxVal = Math.max(...dataPoints);
    if (minVal === maxVal) {
      minVal -= 5;
      maxVal += 5;
    }

    let paddingX = 25;
    let usableWidth = width - (paddingX * 2);
    let stepX = dataPoints.length > 1 ? usableWidth / (dataPoints.length - 1) : usableWidth;

    ctx.strokeStyle = '#003D9B';
    ctx.lineWidth = 2.5;
    ctx.beginPath();

    let coords: ChartPoint[] = [];

    for (let i = 0; i < dataPoints.length; i++) {
      let x = paddingX + (i * stepX);
      let normalized = (dataPoints[i] - minVal) / (maxVal - minVal);
      let y = height - 30 - (normalized * (height - 60));
      coords.push({ x: x, y: y });

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();

    for (let i = 0; i < coords.length; i++) {
      ctx.fillStyle = '#FFFFFF';
      ctx.strokeStyle = '#003D9B';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(coords[i].x, coords[i].y, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  }

  @Builder HeartRateCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.heart'))
            .width(30)
            .height(30)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFEBEA')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Heart Rate')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentHeartRate} bpm`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#BA1A1A').margin({ right: 4 })
        Text('Normal')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#BA1A1A')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
    .onClick(() => { this.openLiveChartModal('Heart Rate', this.currentHeartRate); })
  }

  @Builder OxygenCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.oxygensaturation'))
            .width(40)
            .height(40)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#E8EEFF')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Oxygen (SpO2)')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentOxygen} %`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#003D9B').margin({ right: 4 })
        Text('Healthy')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#003D9B')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
    .onClick(() => { this.openLiveChartModal('Oxygen', this.currentOxygen); })
  }

  @Builder SleepCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.sleep'))
            .width(31)
            .height(31)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#F3E8FF')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Sleep Quality')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text('6h 45m')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#5C0099').margin({ right: 4 })
        Text('Restful')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5C0099')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
  }

  @Builder CaloriesCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.calories'))
            .width(40)
            .height(40)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFF4E5')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Calories Burned')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentCalories} kcal`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#854E00').margin({ right: 4 })
        Text('Active')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#854E00')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
  }
}

// ----------------------------------------------------
// FAMILY DASHBOARD VIEW
// ----------------------------------------------------
@Component
struct FamilyDashboardView {
  @Prop fullName: string;
  onQrScanClick: () => void = () => {};
  @StorageLink('dashboardMeds') dashboardMeds: MedicationItem[] = [];
  @State heartRate: number = 72;
  @State oxygen: number = 98;
  @State calories: number = 1450;
  @State mapUrl: string = 'https://static-maps.yandex.ru/1.x/?ll=-122.1697,37.4275&z=16&l=map&size=600,300';
  @State locationLabel: string = 'Home • 5 mins ago';

  @StorageLink('selectedFamilyMember') selectedMember: string = 'Father';
  @State showDropdown: boolean = false;
  private hrIntervalId: number = -1;
  @StorageLink('profilePicture') profilePicture: string = '';

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts: string[] = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  getPatientLocation() {
    if (this.selectedMember === 'Mother') {
      this.mapUrl = 'https://static-maps.yandex.ru/1.x/?ll=-122.4194,37.7749&z=15&l=map&size=600,300';
      this.locationLabel = 'San Francisco • Live';
      return;
    }

    try {
      let requestInfo: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX
      };
      geoLocationManager.getCurrentLocation(requestInfo).then((location) => {
        if (location && this.selectedMember === 'Father') {
          const lat = location.latitude;
          const lng = location.longitude;
          this.mapUrl = `https://static-maps.yandex.ru/1.x/?ll=${lng.toFixed(5)},${lat.toFixed(5)}&z=16&l=map&size=600,300`;
          this.locationLabel = `Palo Alto • Live`;
        }
      }).catch(() => {
        // Fallback is handled by default values
      });
    } catch (err) {
      // Ignore
    }
  }

  aboutToAppear() {
    this.hrIntervalId = setInterval(() => {
      const baseHR = this.selectedMember === 'Father' ? 72 : 80;
      const baseO2 = this.selectedMember === 'Father' ? 98 : 99;

      // Heart Rate simulation
      const hrVariance = Math.floor(Math.random() * 3) - 1; // -1, 0, 1
      this.heartRate = baseHR + hrVariance;

      // Oxygen simulation
      const o2Variance = Math.floor(Math.random() * 3) - 1; // -1, 0, 1
      this.oxygen = Math.max(95, Math.min(100, baseO2 + o2Variance));

      // Calories simulation
      this.calories += Math.floor(Math.random() * 2);
    }, 3000);

    this.getPatientLocation();
  }

  aboutToDisappear() {
    if (this.hrIntervalId !== -1) {
      clearInterval(this.hrIntervalId);
    }
  }

  build() {
    Column() {
      AppHeader({ title: 'GuardianBand Home' })
        .margin({ bottom: 16 })

      Row() {
        if (this.profilePicture === '') {
          Row() {
            Text(this.getInitials(this.fullName))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(32)
          .height(32)
          .backgroundColor('#003D9B')
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
          .margin({ right: 10 })
        } else {
          Image(this.profilePicture)
            .width(32)
            .height(32)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
            .margin({ right: 10 })
        }

        Text(`Welcome, ${this.fullName}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 20 })

      // Emergency Watch Scanner Banner Card
      Column() {
        Row() {
          Row() {
            Image($r('app.media.qr'))
              .width(26)
              .height(26)
              .objectFit(ImageFit.Contain)
          }
          .width(44)
          .height(44)
          .borderRadius(10)
          .backgroundColor('rgba(0, 61, 155, 0.08)')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ right: 12 })

          Column() {
            Text('Emergency Watch Scanner')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 4 })

            Text("Scan patient's smartwatch QR code to quickly retrieve live vitals and emergency contact info.")
              .fontSize(12)
              .fontColor('#737685')
              .lineHeight(16)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Button('Scan Smartwatch QR', { type: ButtonType.Normal })
          .width('100%')
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#003D9B')
          .borderRadius(8)
          .onClick(() => {
            this.onQrScanClick();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(0, 61, 155, 0.2)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 2. Monitoring Profile Title Section
      Row() {
        Column() {
          Text('MONITORING PROFILE')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#737685')
            .margin({ bottom: 4 })

          Row() {
            Text(this.selectedMember === 'Father' ? "Father's Health" : "Mother's Health")
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ right: 8 })

            Text('▼')
              .fontSize(16)
              .fontColor('#003D9B')
          }
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.showDropdown = !this.showDropdown;
          })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row() {
          // Green dot + Live Text
          Row()
            .width(8)
            .height(8)
            .backgroundColor('#006E2F')
            .borderRadius(4)
            .margin({ right: 6 })

          Text('Live')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#006E2F')
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .margin({ bottom: 20 })

      // Dropdown Overlay Menu
      if (this.showDropdown) {
        Column() {
          // Option 1: Father
          Row() {
            Row() {
              Text('JD')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor('#006E2F')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 10 })

            Text("Father (John Doe)")
              .fontSize(15)
              .fontWeight(this.selectedMember === 'Father' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedMember === 'Father' ? '#003D9B' : '#191C1D')

            Blank()

            if (this.selectedMember === 'Father') {
              Image($r('app.media.like'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
          }
          .width('100%')
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .onClick(() => {
            this.selectedMember = 'Father';
            this.showDropdown = false;
            this.heartRate = 72;
            this.oxygen = 98;
            this.calories = 1450;
            this.getPatientLocation();
          })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

          // Option 2: Mother
          Row() {
            Row() {
              Text('MD')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor('#854E00')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 10 })

            Text("Mother (Mary Doe)")
              .fontSize(15)
              .fontWeight(this.selectedMember === 'Mother' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedMember === 'Mother' ? '#003D9B' : '#191C1D')

            Blank()

            if (this.selectedMember === 'Mother') {
              Image($r('app.media.like'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
          }
          .width('100%')
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .onClick(() => {
            this.selectedMember = 'Mother';
            this.showDropdown = false;
            this.heartRate = 80;
            this.oxygen = 99;
            this.calories = 1200;
            this.getPatientLocation();
          })
        }
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 4 })
        .margin({ bottom: 16 })
      }

      // 3. AI Health Summary (Blue Card)
      Row() {
        Row() {
          Image($r('app.media.idea'))
            .width(26)
            .height(26)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(12)
        .backgroundColor('rgba(255, 255, 255, 0.2)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ right: 16 })

        Column() {
          Text('AI Health Summary')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ bottom: 6 })

          Text(this.selectedMember === 'Father' ? 
            "Father is stable today. Activity is normal, and all meds were taken on time. Irregular heart pattern check passed." : 
            "Mother is active today. Daily steps goal is completed. Her sleep quality last night was excellent, and blood oxygen levels are optimal at 99%.")
            .fontSize(14)
            .fontColor('rgba(255, 255, 255, 0.9)')
            .lineHeight(20)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#0052cc')
      .borderRadius(20)
      .shadow({ radius: 10, color: 'rgba(0, 82, 204, 0.15)', offsetY: 4 })
      .margin({ bottom: 20 })

      // 4. Health Metrics Grid (2x2 Grid)
      Row() {
        // Heart Rate Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.heart'))
                .width(30)
                .height(30)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .borderRadius(10)
            .backgroundColor('rgba(186, 26, 26, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

            Blank()

            Text('Live')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#737685')
          }
          .width('100%')

          Blank()

          Column() {
            Row() {
              Text(this.heartRate.toString())
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
              Text(' BPM')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#737685')
                .margin({ bottom: 2, left: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text('Normal Range')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#006E2F')
              .alignSelf(ItemAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .height(132)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .margin({ right: 8 })

        // Oxygen Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.oxygensaturation'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .borderRadius(10)
            .backgroundColor('rgba(0, 61, 155, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

            Blank()

            Text('Live')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#737685')
          }
          .width('100%')

          Blank()

          Column() {
            Row() {
              Text(this.oxygen.toString())
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
              Text(' %')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#737685')
                .margin({ bottom: 2, left: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text('Healthy')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .alignSelf(ItemAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .height(132)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        // Sleep Quality Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.sleep'))
                .width(31)
                .height(31)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .borderRadius(10)
            .backgroundColor('rgba(92, 0, 153, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

            Blank()

            Text('Last Night')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#737685')
          }
          .width('100%')

          Blank()

          Column() {
            Row() {
              Text(this.selectedMember === 'Father' ? '6h 45m' : '8h 15m')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text(this.selectedMember === 'Father' ? 'Restful' : 'Excellent')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#5C0099')
              .alignSelf(ItemAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .height(132)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .margin({ right: 8 })

        // Calories Burned Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.calories'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
            .borderRadius(10)
            .backgroundColor('rgba(255, 180, 0, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

            Blank()

            Text('Today')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#737685')
          }
          .width('100%')

          Blank()

          Column() {
            Row() {
              Text(this.calories.toString())
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
              Text(' kcal')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#737685')
                .margin({ bottom: 2, left: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text('Active')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#854E00')
              .alignSelf(ItemAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .height(132)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 4b. Steps Card (Full-width row)
      Row() {
        Row() {
          Image($r('app.media.walking'))
            .width(40)
            .height(40)
            .objectFit(ImageFit.Contain)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('rgba(0, 110, 47, 0.1)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text('Daily Steps')
            .fontSize(12)
            .fontColor('#737685')
            .margin({ bottom: 2 })
          Text('4,281 Steps')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width(100)
            .height(6)
            .backgroundColor('#E8EEFF')
            .borderRadius(3)

          Row()
            .width(85)
            .height(6)
            .backgroundColor('#006E2F')
            .borderRadius(3)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 5. Medication Status
      Column() {
        Row() {
          Row() {
            Row() {
              Image($r('app.media.drugs'))
                .width(25)
                .height(25)
                .objectFit(ImageFit.Contain)
            }
            .width(36)
            .height(36)
            .borderRadius(10)
            .backgroundColor('rgba(0, 61, 155, 0.1)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Text(this.dashboardMeds.length > 0 ? 'Medication Tracker' : 'Last Medication')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(VerticalAlign.Center)

          Blank()

          Row() {
            Image($r('app.media.like'))
              .width(14)
              .height(14)
              .margin({ right: 4 })
              .objectFit(ImageFit.Contain)
            Text(this.dashboardMeds.length > 0 ? (this.dashboardMeds[0].taken ? 'Taken' : 'Pending') : 'Taken')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.dashboardMeds.length > 0 ? (this.dashboardMeds[0].taken ? '#006E2F' : '#003D9B') : '#006E2F')
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.dashboardMeds.length > 0 ? (this.dashboardMeds[0].taken ? '#E6F9ED' : '#E8EEFF') : '#E6F9ED')
          .borderRadius(8)
        }
        .width('100%')
        .margin({ bottom: 16 })

        Row() {
          Column() {
            Text(this.selectedMember === 'Father' ? 
              (this.dashboardMeds.length > 0 ? this.dashboardMeds[0].name : 'Atorvastatin (20mg)') : 
              'Metformin (500mg)')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 4 })

            Text(this.selectedMember === 'Father' ? 
              (this.dashboardMeds.length > 0 ? this.dashboardMeds[0].dosage : 'Daily Dosage: Cardiovascular') : 
              'Daily Dosage: Type 2 Diabetes')
              .fontSize(13)
              .fontColor('#737685')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column() {
            Text(this.selectedMember === 'Father' ? 
              (this.dashboardMeds.length > 0 ? 'Scheduled Time' : 'Time Taken') : 
              'Scheduled Time')
              .fontSize(11)
              .fontColor('#737685')
              .margin({ bottom: 4 })

            Text(this.selectedMember === 'Father' ? 
              (this.dashboardMeds.length > 0 ? this.dashboardMeds[0].time : '08:15 AM') : 
              '08:00 AM')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F8F9FA')
        .borderRadius(12)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 6. Last Known Location Map
      Column() {
        Row() {
          Image($r('app.media.place'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .margin({ right: 8 })

          Text('Last Known Location')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Stack() {
          Image(this.mapUrl)
            .width('100%')
            .height(240)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)

          Column() {
            Row() {
              Text(this.locationLabel)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#0052cc', style: BorderStyle.Solid })
            .shadow({ radius: 6, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
            .margin({ bottom: 8 })

            Row() {
              Text('🚶')
                .fontSize(16)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor('#003D9B')
            .border({ width: 3, color: Color.White, style: BorderStyle.Solid })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .shadow({ radius: 8, color: 'rgba(0,61,155,0.3)', offsetY: 4 })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

        }
        .width('100%')
        .height(240)
        .borderRadius(20)
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 7. Recent Activity
      Column() {
        Row() {
          Image($r('app.media.summary'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .margin({ right: 8 })

          Text('Recent Activity')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Column() {
          // Item 1
          Row() {
            Row() {
              Image($r('app.media.like'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor('#E6F9ED')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Row() {
                Text('Morning Meds Logged')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                Blank()
                Text('8:15 AM')
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .width('100%')
              .margin({ bottom: 4 })

              Text('Father manually confirmed morning medication via device.')
                .fontSize(13)
                .fontColor('#737685')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

          // Item 2
          Row() {
            Row() {
              Image($r('app.media.safezone'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor('#E8EEFF')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Row() {
                Text('Safe Zone Entry')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                Blank()
                Text('8:02 AM')
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .width('100%')
              .margin({ bottom: 4 })

              Text("Entered 'Home' geofence after morning backyard walk.")
                .fontSize(13)
                .fontColor('#737685')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
        }
        .width('100%')
      }
      .width('100%')
      .margin({ bottom: 20 })
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// DOCTOR DASHBOARD VIEW
// ----------------------------------------------------
interface MonitoredPatient {
  id: string;
  name: string;
  gender: string;
  bloodType: string;
  heartRate: number;
  oxygen: number;
  calories: number;
  sleep: string;
  meds: string;
  location: string;
}

interface DoctorProfile {
  hospital: string;
  specialty: string;
  email: string;
  isVerified: boolean;
}

@Component
struct DoctorDashboardView {
  @StorageLink('fullName') fullName: string = 'Dr. Alex Care';
  @StorageLink('doctorProfile') doctorProfile: DoctorProfile = {
    hospital: '',
    specialty: '',
    email: '',
    isVerified: false
  };

  @State doctorPatients: MonitoredPatient[] = [
    { id: '1', name: 'John Doe', gender: 'Male', bloodType: 'A+', heartRate: 72, oxygen: 98, calories: 1450, sleep: '6h 45m', meds: 'Atorvastatin (20mg)', location: 'Palo Alto • Live' },
    { id: '2', name: 'Alice Smith', gender: 'Female', bloodType: 'O-', heartRate: 68, oxygen: 99, calories: 1120, sleep: '7h 15m', meds: 'Lisinopril (10mg)', location: 'San Jose • Live' }
  ];

  @State selectedPatient: MonitoredPatient | null = null;
  @State isInspectorOpen: boolean = false;
  onQrScanClick: () => void = () => {};
  @StorageLink('profilePicture') profilePicture: string = '';

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts: string[] = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  async scanPatientQr() {
    promptAction.showToast({ message: 'Opening camera...', duration: 800 });

    try {
      const context = getContext(this) as common.UIAbilityContext;

      let pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };

      // Launch system camera picker (matching OCR Scan label camera picker flow)
      let pickerResult = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);

      if (pickerResult && pickerResult.resultUri) {
        promptAction.showToast({ message: 'Processing QR code, please wait...' });

        // Simulating matching & adding the new patient Bob Johnson
        setTimeout(() => {
          if (this.doctorPatients.findIndex(p => p.id === '3') === -1) {
            this.doctorPatients.push({
              id: '3',
              name: 'Bob Johnson',
              gender: 'Male',
              bloodType: 'O+',
              heartRate: 75,
              oxygen: 98,
              calories: 1320,
              sleep: '6h 50m',
              meds: 'Metoprolol (50mg)',
              location: 'Mountain View • Live'
            });
            promptAction.showToast({ message: 'Successfully matched & linked with Bob Johnson!' });
          } else {
            promptAction.showToast({ message: 'Patient Bob Johnson is already linked.' });
          }
        }, 1200);
      }
    } catch (e) {
      // Fallback: Simulator mode when camera picker cannot launch on emulator environments
      promptAction.showToast({ message: 'Simulator Mode: Loading camera...' });
      setTimeout(() => {
        if (this.doctorPatients.findIndex(p => p.id === '3') === -1) {
          this.doctorPatients.push({
            id: '3',
            name: 'Bob Johnson',
            gender: 'Male',
            bloodType: 'O+',
            heartRate: 75,
            oxygen: 98,
            calories: 1320,
            sleep: '6h 50m',
            meds: 'Metoprolol (50mg)',
            location: 'Mountain View • Live'
          });
          promptAction.showToast({ message: 'Linked with Bob Johnson (Simulator Mode)' });
        } else {
          promptAction.showToast({ message: 'Patient Bob Johnson is already linked.' });
        }
      }, 1500);
    }
  }

  build() {
    Column() {
      if (!this.isInspectorOpen) {
        // --- DOCTOR PORTAL DASHBOARD MAIN VIEW ---
        
        AppHeader({ title: 'GuardianBand Home' })
          .margin({ bottom: 16 })

        Row() {
          if (this.profilePicture === '') {
            Row() {
              Text(this.getInitials(this.fullName))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(32)
            .height(32)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
            .margin({ right: 10 })
          } else {
            Image(this.profilePicture)
              .width(32)
              .height(32)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
              .margin({ right: 10 })
          }

          Text(`Welcome, ${this.fullName}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 20 })

        // Emergency Watch Scanner Banner Card
        Column() {
          Row() {
            Row() {
              Image($r('app.media.qr'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
            }
            .width(44)
            .height(44)
            .borderRadius(10)
            .backgroundColor('rgba(0, 61, 155, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Emergency Watch Scanner')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 4 })

              Text("Scan patient's smartwatch QR code to quickly retrieve live vitals and emergency contact info.")
                .fontSize(12)
                .fontColor('#737685')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: 12 })

          Button('Scan Smartwatch QR', { type: ButtonType.Normal })
            .width('100%')
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#003D9B')
            .borderRadius(8)
            .onClick(() => {
              this.onQrScanClick();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(0, 61, 155, 0.2)', style: BorderStyle.Solid })
        .margin({ bottom: 24 })

        // 2. Action Card: Match Patient via QR
        Column() {
          Row() {
            Row() {
              Image($r('app.media.qr'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
            }
            .width(44)
            .height(44)
            .borderRadius(10)
            .backgroundColor('rgba(0, 61, 155, 0.08)')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Match Patient QR Code')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ bottom: 4 })

              Text("Scan patient's unique QR code to link them to your hospital roster.")
                .fontSize(12)
                .fontColor('#737685')
                .lineHeight(16)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: 12 })

          Button('Scan & Link New Patient', { type: ButtonType.Normal })
            .width('100%')
            .height(38)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#003D9B')
            .borderRadius(8)
            .onClick(() => {
              this.scanPatientQr();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(0, 61, 155, 0.2)', style: BorderStyle.Solid })
        .margin({ bottom: 24 })

        // 3. Patients List Section
        Text('My Linked Patients')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 14 })

        ForEach(this.doctorPatients, (patient: MonitoredPatient) => {
          Row() {
            // Initial/Avatar
            Row() {
              Text(patient.name.charAt(0) + patient.name.split(' ').pop()!.charAt(0))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor(patient.gender === 'Male' ? '#003D9B' : '#5C0099')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 14 })

            Column() {
              Text(patient.name)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })

              Row() {
                Text(`${patient.gender} • Blood Type: `)
                  .fontSize(12)
                  .fontColor('#737685')
                Text(patient.bloodType)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#BA1A1A')
              }
              .alignItems(VerticalAlign.Center)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row() {
              Text('Inspect')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
                .margin({ right: 4 })
              Text('➔')
                .fontSize(12)
                .fontColor('#003D9B')
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(20)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
          .margin({ bottom: 12 })
          .onClick(() => {
            this.selectedPatient = patient;
            this.isInspectorOpen = true;
          })
        }, (item: MonitoredPatient) => item.id)

      } else {
        // --- PATIENT VITALS INSPECTOR (DETAIL VIEW) ---
        if (this.selectedPatient !== null) {
          Column() {
            // Header bar
            Row() {
              Row() {
                Text('⬅ Back to Roster')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#003D9B')
              }
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#E8EEFF')
              .borderRadius(12)
              .onClick(() => {
                this.isInspectorOpen = false;
                this.selectedPatient = null;
              })

              Blank()

              Row() {
                Circle({ width: 6, height: 6 }).fill('#006E2F').margin({ right: 4 })
                Text('Real-time Connection')
                  .fontSize(11)
                  .fontColor('#006E2F')
                  .fontWeight(FontWeight.Medium)
              }
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Monitored Patient Header Card
            Row() {
              Row() {
                Text(this.selectedPatient.name.charAt(0) + this.selectedPatient.name.split(' ').pop()!.charAt(0))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor(this.selectedPatient.gender === 'Male' ? '#003D9B' : '#5C0099')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 14 })

              Column() {
                Text(this.selectedPatient.name)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .margin({ bottom: 4 })

                Text(`Monitored Patient Account • ${this.selectedPatient.gender}`)
                  .fontSize(13)
                  .fontColor('#737685')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 20 })

            // Vitals Stats Grid (Heart Rate & Oxygen)
            Row() {
              // Heart Rate
              Column() {
                Row() {
                  Image($r('app.media.heart'))
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                  Blank()
                  Text('Live')
                    .fontSize(11)
                    .fontColor('#737685')
                }
                .width('100%')
                .margin({ bottom: 14 })

                Text(`${this.selectedPatient.heartRate} BPM`)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })

                Text('Heart Status: Stable')
                  .fontSize(11)
                  .fontColor('#006E2F')
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)
              }
              .layoutWeight(1)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
              .margin({ right: 8 })

              // Blood Oxygen
              Column() {
                Row() {
                  Image($r('app.media.oxygensaturation'))
                    .width(36)
                    .height(36)
                    .objectFit(ImageFit.Contain)
                  Blank()
                  Text('Live')
                    .fontSize(11)
                    .fontColor('#737685')
                }
                .width('100%')
                .margin({ bottom: 6 })

                Text(`${this.selectedPatient.oxygen} %`)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })

                Text('Oxygen Level: Optimal')
                  .fontSize(11)
                  .fontColor('#003D9B')
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)
              }
              .layoutWeight(1)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
              .margin({ left: 8 })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Medication Card
            Row() {
              Row() {
                Image($r('app.media.drugs'))
                  .width(28)
                  .height(28)
                  .objectFit(ImageFit.Contain)
              }
              .width(40)
              .height(40)
              .borderRadius(8)
              .backgroundColor('rgba(0, 61, 155, 0.08)')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('Assigned Medication')
                  .fontSize(11)
                  .fontColor('#737685')
                  .margin({ bottom: 2 })
                Text(this.selectedPatient.meds)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
            .margin({ bottom: 16 })

            // Map Location
            Column() {
              Row() {
                Image($r('app.media.place'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 8 })

                Text('Patient Live Location')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')

                Blank()

                Text(this.selectedPatient.location)
                  .fontSize(11)
                  .fontColor('#737685')
              }
              .width('100%')
              .margin({ bottom: 12 })

              // Display static map placeholder
              Image('https://static-maps.yandex.ru/1.x/?ll=-122.1697,37.4275&z=14&l=map&size=600,240')
                .width('100%')
                .height(130)
                .objectFit(ImageFit.Cover)
                .borderRadius(12)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
            .margin({ bottom: 20 })
          }
          .width('100%')
        }
      }
    }
    .width('100%')
  }
}
