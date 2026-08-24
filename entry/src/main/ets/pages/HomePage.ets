// HomePage.ets
import { router, promptAction } from '@kit.ArkUI';
import { ApiService, ApiError, ClinicianPatient, MonitoringRelationship, EmergencyAccessSession, EmergencyMedicalCard, EmergencyMedication, VitalsResponse } from '../services/ApiService';
import { SessionStore } from '../services/SessionStore';
import { AccountRepository } from '../services/AccountRepository';
import { QrPayload, QrKind, QrContent, DisplayFormat } from '../services/QrPayload';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CoachMarkOverlay } from '../components/CoachMarkOverlay';
import { TutorialManager } from '../utils/TutorialManager';

interface ScannedPatientVitals {
  heartRate?: string;
  oxygen?: string;
  /**
   * Son olcumun ISO zaman damgasi.
   * Bu alan eskiden `location` adiniydi ve UI'da "Last Location" olarak
   * gosteriliyordu; ancak icine hep olcum ZAMANI yaziliyordu. Acil tibbi
   * kartta (EmergencyMedicalCard) konum alani yok, bu yuzden ad duzeltildi.
   */
  recordedAt?: string;
}

interface ScannedPatient {
  id: string;
  name: string;
  email: string;
  bloodType: string;
  allergies: string;
  diseases: Array<string>;
  otherChronicDisease?: string;
  medications?: Array<string>;
  vitals?: ScannedPatientVitals;
  /** From criticalFacts.gender - the backend already sends this today. */
  gender?: string;
  /** Computed from EmergencyMedicalCard.birthDate. */
  age?: string;
}

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

/** A patient the current user (doctor or family member) is allowed to monitor. */
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

// Interface for chart coordinates to satisfy ArkTS strict typing
interface ChartPoint {
  x: number;
  y: number;
}

// Helper function to format diseases list as an array and replace 'Other' with custom typed disease name
function getFormattedDiseasesArray(diseases?: Array<string>, otherDisease?: string): string[] {
  let listToUse: string[] = diseases || [];

  if (listToUse.length === 0) {
    let profile = AppStorage.get<Record<string, Object>>('medicalProfile');
    if (profile) {
      let pDiseases = profile['diseases'] as string[] | undefined;
      let pOther = profile['otherChronicDisease'] as string | undefined;
      if (pDiseases && pDiseases.length > 0) {
        listToUse = pDiseases;
      }
      if (!otherDisease && pOther) {
        otherDisease = pOther;
      }
    }
  }

  if (listToUse.length === 0) {
    return [];
  }

  let result: string[] = [];
  for (let i = 0; i < listToUse.length; i++) {
    let item = listToUse[i];
    if (item === 'Other') {
      if (otherDisease && otherDisease.trim().length > 0) {
        result.push(otherDisease.trim());
      }
    } else if (item && item.trim().length > 0) {
      result.push(item.trim());
    }
  }

  return result;
}

// Helper function to format diseases list and replace 'Other' with custom typed disease name
function formatDiseasesList(diseases?: Array<string>, otherDisease?: string): string {
  let listToUse: string[] = diseases || [];

  if (listToUse.length === 0) {
    let profile = AppStorage.get<Record<string, Object>>('medicalProfile');
    if (profile) {
      let pDiseases = profile['diseases'] as string[] | undefined;
      let pOther = profile['otherChronicDisease'] as string | undefined;
      if (pDiseases && pDiseases.length > 0) {
        listToUse = pDiseases;
      }
      if (!otherDisease && pOther) {
        otherDisease = pOther;
      }
    }
  }

  if (listToUse.length === 0) {
    return 'None';
  }

  let result: string[] = [];
  for (let i = 0; i < listToUse.length; i++) {
    let item = listToUse[i];
    if (item === 'Other') {
      if (otherDisease && otherDisease.trim().length > 0) {
        result.push(otherDisease.trim());
      }
    } else if (item && item.trim().length > 0) {
      result.push(item.trim());
    }
  }

  return result.length > 0 ? result.join(', ') : 'None';
}

// Helper function for Emergency Vitals active medications list
function getActiveMedicationsList(medsList?: Array<string>): string[] {
  if (medsList && medsList.length > 0) {
    return medsList;
  }
  let stored: MedicationItem[] = AppStorage.get<MedicationItem[]>('dashboardMeds') || [];
  if (stored && stored.length > 0) {
    let uniqueNames: string[] = [];
    for (let i = 0; i < stored.length; i++) {
      let medName: string = stored[i].name;
      if (medName && !uniqueNames.includes(medName)) {
        uniqueNames.push(medName);
      }
    }
    if (uniqueNames.length > 0) {
      return uniqueNames;
    }
  }
  return [];
}

// Helper function for Emergency Vitals active medications
function getActiveMedicationsText(medsList?: Array<string>): string {
  if (medsList && medsList.length > 0) {
    return medsList.join(', ');
  }
  let stored: MedicationItem[] = AppStorage.get<MedicationItem[]>('dashboardMeds') || [];
  if (stored && stored.length > 0) {
    let uniqueNames: string[] = [];
    for (let i = 0; i < stored.length; i++) {
      let medName: string = stored[i].name;
      if (medName && !uniqueNames.includes(medName)) {
        uniqueNames.push(medName);
      }
    }
    if (uniqueNames.length > 0) {
      return uniqueNames.join(', ');
    }
  }
  return 'None';
}

// Helper function for the Emergency Vitals header subtitle: "Age 74 · Female",
// only age, only gender, or a fallback when the backend has sent neither yet.
function formatDemographics(age?: string, gender?: string): string {
  const parts: string[] = [];
  if (age !== undefined && age.length > 0) {
    parts.push(`Age ${age}`);
  }
  if (gender !== undefined && gender.length > 0) {
    parts.push(gender);
  }
  return parts.length > 0 ? parts.join(' · ') : 'Age and gender not shared';
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
  @StorageLink('isGraphModalOpen') isGraphModalOpen: boolean = false;
  @State isDoctorVerificationModalOpen: boolean = false;
  @State enteredVerificationCode: string = '';
  @State isScannedPatientModalOpen: boolean = false;
  @State isEmergencyMedsExpanded: boolean = true;
  @State isChronicDiseasesExpanded: boolean = true;
  @State scannedPatientInfo: ScannedPatient = {
    id: '',
    name: '',
    email: '',
    bloodType: '',
    allergies: '',
    diseases: []
  };

  @State isQrModalOpen: boolean = false;
  @State isQrScanning: boolean = false;
  @State showTelemetryResult: boolean = false;
  @State scanProgress: number = 0;
  private scanIntervalId: number = -1;

  @StorageLink('isTutorialActive') isTutorialActive: boolean = false;
  @StorageLink('currentTutorialStep') currentTutorialStep: number = 0;

  async aboutToAppear() {
    if (this.userRole === 'patient') {
      const isJustRegistered = AppStorage.get<boolean>('isJustRegistered') || false;
      if (isJustRegistered) {
        TutorialManager.initializeTutorial(getContext(this));
        AppStorage.setOrCreate('isJustRegistered', false);
      }
    }
    
    if (this.userRole === 'doctor' && !this.doctorProfile.isVerified) {
      setTimeout(() => {
        this.isDoctorVerificationModalOpen = true;
        promptAction.showToast({ message: 'Verification code automatically sent to your professional email address!' });
      }, 500);
    }
  }

  async startQrScanner() {
    try {
      router.pushUrl({ url: 'pages/CameraPage' });
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
    this.isQrModalOpen = false;
    this.showTelemetryResult = false;
    // This animated screen is not a real scanner; it used to show a made-up
    // patient here. Now it routes to the real camera.
    router.pushUrl({ url: 'pages/CameraPage' });
  }

  closeQrScanner() {
    clearInterval(this.scanIntervalId);
    this.isQrModalOpen = false;
    this.showTelemetryResult = false;
  }

  onPageShow() {
    let scannedResult = AppStorage.get<string>('scannedQrResult');
    if (scannedResult) {
      console.info('[HomePage] Scanned QR Result retrieved: ' + scannedResult);

      let isWatchScan = AppStorage.get<boolean>('doctorIsWatchScan') || false;

      // The QR payload is now typed (GB1:LINK: / GB1:EMG:). Which endpoint to
      // call is decided from the code itself, not the scanning context - a token
      // sent to the wrong endpoint used to get a 400 from the backend.
      const parsed: QrContent = QrPayload.decode(scannedResult);
      AppStorage.setOrCreate('scannedQrResult', '');

      if (parsed.kind === QrKind.LEGACY_JSON) {
        promptAction.showToast({ message: QrPayload.legacyMessage() });
        return;
      }

      if (parsed.kind === QrKind.LINK) {
        AppStorage.setOrCreate('doctorIsWatchScan', false);
        AppStorage.setOrCreate('scannedPatientLinkRequest', parsed.token);
        return;
      }
      if (parsed.kind === QrKind.EMERGENCY) {
        AppStorage.setOrCreate('doctorIsWatchScan', false);
        this.loadEmergencyMedicalCard(parsed.token);
        return;
      }

      // Untagged code: an old QR or manual entry. Decide from the scan context.
      if (this.userRole === 'doctor' && !isWatchScan) {
        AppStorage.setOrCreate('scannedPatientLinkRequest', parsed.token);
      } else {
        AppStorage.setOrCreate('doctorIsWatchScan', false);
        this.loadEmergencyMedicalCard(parsed.token);
      }
    }
  }

  /**
   * POST /api/emergency-access/redeem sonra GET .../medical-card
   *
   * This used to read plain-text JSON out of the QR and, failing that, show a
   * made-up patient. The data now comes from the server and every access is
   * written to the backend's audit log.
   */
  async loadEmergencyMedicalCard(accessToken: string): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'You need to sign in to use emergency access.' });
      return;
    }
    promptAction.showToast({ message: 'Verifying emergency access...' });
    try {
      const session: EmergencyAccessSession = await ApiService.redeemEmergencyToken(accessToken.trim());
      const card: EmergencyMedicalCard = await ApiService.getEmergencyMedicalCard(session.sessionId);
      console.info(`[API] Emergency medical card retrieved, sessionId=${session.sessionId}`);

      const allergyList: string[] = card.criticalFacts.allergies !== undefined ? card.criticalFacts.allergies : [];
      const conditionList: string[] = card.criticalFacts.chronicConditions !== undefined
        ? card.criticalFacts.chronicConditions : [];

      let vitalsView: ScannedPatientVitals = {
        heartRate: 'No data',
        oxygen: 'No data',
        recordedAt: ''
      };
      if (card.latestVitals !== undefined) {
        vitalsView = {
          heartRate: `${card.latestVitals.heartRate} bpm`,
          oxygen: `${card.latestVitals.bloodOxygen}%`,
          recordedAt: card.latestVitals.recordedAt
        };
      }

      this.scannedPatientInfo = {
        id: session.sessionId,
        // The card carries the patient's identity; the fallback only covers a
        // profile that was never filled in.
        name: card.displayName !== undefined && card.displayName.length > 0
          ? card.displayName : 'Unknown patient',
        email: '',
        bloodType: card.bloodType || 'Unknown',
        allergies: allergyList.length > 0 ? allergyList.join(', ') : 'No known allergies',
        diseases: conditionList,
        medications: card.medications.map((m: EmergencyMedication) =>
          `${m.name} ${m.strength} — ${m.instructions}`),
        vitals: vitalsView,
        gender: card.criticalFacts.gender !== undefined ? card.criticalFacts.gender : '',
        age: DisplayFormat.age(card.birthDate)
      };
      this.isScannedPatientModalOpen = true;
    } catch (err) {
      console.error(`[API] Emergency access failed: ${(err as Error).message}`);
      promptAction.showToast({ message: `Emergency access failed: ${(err as Error).message}` });
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
            ['rgba(0, 61, 155, 0.20)', 0.0],
            ['rgba(0, 61, 155, 0.0)', 1.0]
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
            ['rgba(227, 27, 35, 0.18)', 0.0],
            ['rgba(227, 27, 35, 0.0)', 1.0]
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
      .padding({ bottom: 80 })
      .enableScrollInteraction(!this.isGraphModalOpen)

      BottomNavBar({ activeTab: 'home' })
        .zIndex(1)

      if (this.isTutorialActive && this.currentTutorialStep === 1) {
        CoachMarkOverlay({
          targetId: 'tab_meds',
          title: 'Manage Your Medications',
          description: 'Tap the Meds tab to manage your daily medications, set reminders, and track your health routine.',
          stepIndex: 1,
          totalSteps: 4
        })
      }

      // Full-Screen Vitals Graph Modal (zIndex 200 - covers ENTIRE screen including status bar & navbar)
      if (this.isGraphModalOpen) {
        VitalsGraphModal()
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(200)
      }

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

                  AppStorage.setOrCreate('doctorProfile', {
                    hospital: this.doctorProfile.hospital,
                    specialty: this.doctorProfile.specialty,
                    email: this.doctorProfile.email,
                    isVerified: true
                  });

                  // AppStorage lives IN MEMORY; the verified flag also goes to
                  // the account (`PUT /api/account`), otherwise the verification
                  // modal opens again on every sign-in - and on every device.
                  AccountRepository.savePatch({
                    doctorVerified: true,
                    doctorHospital: this.doctorProfile.hospital,
                    doctorSpecialty: this.doctorProfile.specialty,
                    doctorEmail: this.doctorProfile.email
                  }).catch((err: Error) => console.warn(`[AccountRepository] Could not persist verification: ${err.message}`));

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
                  Image($r('app.media.cancel'))
                    .width(20)
                    .height(20)
                    .objectFit(ImageFit.Contain)
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
                  Image($r('app.media.cancel'))
                    .width(20)
                    .height(20)
                    .objectFit(ImageFit.Contain)
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

                  // Active Medications
                  Row() {
                    Text('Active Medications')
                      .fontSize(14)
                      .fontColor('#737685')
                    Blank()
                    Text(getActiveMedicationsText())
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#003D9B')
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

      // Centered Pop-up Modal for Scanned Patient Details (List style)
      if (this.isScannedPatientModalOpen) {
        Stack() {
          // Dark background overlay
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.6)')
            .onClick(() => {
              this.isScannedPatientModalOpen = false;
            })

          // Modal Card
          Column() {
            // Header
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
              
              Image($r('app.media.cancel'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  this.isScannedPatientModalOpen = false;
                })
            }
            .width('100%')
            .margin({ bottom: 20 })

            // Highlight Header Info Card
            Row() {
              Row() {
                Text(this.scannedPatientInfo.name ? this.scannedPatientInfo.name.substring(0, 2).toUpperCase() : 'PT')
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
                Text(this.scannedPatientInfo.name || 'Unknown Patient')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .margin({ bottom: 2 })

                Text(formatDemographics(this.scannedPatientInfo.age, this.scannedPatientInfo.gender))
                  .fontSize(12)
                  .fontColor('#737685')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .margin({ bottom: 20 })

            // List Details
            Column() {
              // Blood Type Row
              Row() {
                Text('Blood Type')
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)
                Text(this.scannedPatientInfo.bloodType || 'Not Specified')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Allergies Row
              Row() {
                Text('Allergies')
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)
                Text(this.scannedPatientInfo.allergies || 'None')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Chronic Conditions Collapsible Section
              Column() {
                Row() {
                  Text(`Chronic Conditions (${getFormattedDiseasesArray(this.scannedPatientInfo.diseases, this.scannedPatientInfo.otherChronicDisease).length})`)
                    .fontSize(14)
                    .fontColor('#737685')
                    .layoutWeight(1)

                  Text(this.isChronicDiseasesExpanded ? '▲' : '▼')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  this.isChronicDiseasesExpanded = !this.isChronicDiseasesExpanded;
                })

                if (this.isChronicDiseasesExpanded) {
                  Column({ space: 4 }) {
                    if (getFormattedDiseasesArray(this.scannedPatientInfo.diseases, this.scannedPatientInfo.otherChronicDisease).length === 0) {
                      Row() {
                        Blank()
                        Text('None')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#191C1D')
                      }
                      .width('100%')
                      .padding({ bottom: 8 })
                    } else {
                      ForEach(getFormattedDiseasesArray(this.scannedPatientInfo.diseases, this.scannedPatientInfo.otherChronicDisease), (diseaseName: string) => {
                        Row() {
                          Blank()
                          Text(diseaseName)
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#BA1A1A')
                        }
                        .width('100%')
                        .padding({ top: 2, bottom: 4 })
                      })
                    }
                  }
                  .width('100%')
                  .margin({ bottom: 8 })
                }
              }
              .width('100%')
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Active Medications Collapsible Section
              Column() {
                Row() {
                  Text(`Active Prescriptions (${getActiveMedicationsList(this.scannedPatientInfo.medications).length})`)
                    .fontSize(14)
                    .fontColor('#737685')
                    .layoutWeight(1)

                  Text(this.isEmergencyMedsExpanded ? '▲' : '▼')
                    .fontSize(12)
                    .fontColor('#737685')
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  this.isEmergencyMedsExpanded = !this.isEmergencyMedsExpanded;
                })

                if (this.isEmergencyMedsExpanded) {
                  Column({ space: 4 }) {
                    if (getActiveMedicationsList(this.scannedPatientInfo.medications).length === 0) {
                      Row() {
                        Blank()
                        Text('None')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#191C1D')
                      }
                      .width('100%')
                      .padding({ bottom: 8 })
                    } else {
                      ForEach(getActiveMedicationsList(this.scannedPatientInfo.medications), (medName: string) => {
                        Row() {
                          Blank()
                          Text(medName)
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#191C1D')
                        }
                        .width('100%')
                        .padding({ top: 2, bottom: 4 })
                      })
                    }
                  }
                  .width('100%')
                  .margin({ bottom: 8 })
                }
              }
              .width('100%')
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Heart Rate Row
              Row() {
                Text('Heart Rate')
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)
                Text(this.scannedPatientInfo.vitals?.heartRate || '72 bpm')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.scannedPatientInfo.vitals?.heartRate && this.scannedPatientInfo.vitals.heartRate.includes('High') ? '#BA1A1A' : '#003D9B')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Oxygen Saturation Row
              Row() {
                Text('Oxygen Saturation')
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)
                Text(this.scannedPatientInfo.vitals?.oxygen || '98%')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.scannedPatientInfo.vitals?.oxygen && this.scannedPatientInfo.vitals.oxygen.includes('Low') ? '#854E00' : '#006E2F')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

              // Son olcum zamani.
              // ONCEDEN "Last Location" yaziyordu ama icine olcum ZAMANI
              // konuyordu; ekranda ham ISO damgasi gorunuyordu. Acil tibbi
              // kartta konum alani YOK (EmergencyMedicalCard semasinda yok),
              // bu yuzden etiket gercege uygun hale getirildi.
              Row() {
                Text('Last Reading')
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)
                Text(DisplayFormat.dateTime(this.scannedPatientInfo.vitals?.recordedAt))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor(Color.White)
            .borderRadius(16)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
            .margin({ bottom: 24 })

            // Actions Row
            Row() {
              Button('Call Emergency', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(44)
                .backgroundColor('rgba(186, 26, 26, 0.08)')
                .fontColor('#BA1A1A')
                .fontWeight(FontWeight.Bold)
                .borderRadius(12)
                .margin({ right: 12 })
                .onClick(() => {
                  promptAction.showToast({ message: 'Calling emergency contacts...' });
                })

              Button('Dismiss', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#003D9B')
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
                .borderRadius(12)
                .onClick(() => {
                  this.isScannedPatientModalOpen = false;
                })
            }
            .width('100%')
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
        .zIndex(150)
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
  /** Single-flight guard so vitals requests do not pile up in the 2s loop. */
  private vitalsInFlight: boolean = false;

  // --- REAL-TIME TELEMETRY HISTORY LISTS FOR LIVE CHARTS ---
  @StorageLink('heartRateHistory') heartRateHistory: number[] = [70, 72, 71, 73, 72, 70, 72];
  @StorageLink('oxygenHistory') oxygenHistory: number[] = [97, 98, 98, 97, 99, 98, 98];

  // --- MODAL GRAPH STATES ---
  @StorageLink('isGraphModalOpen') isGraphModalOpen: boolean = false;
  @StorageLink('selectedMetric') selectedMetric: string = 'Heart Rate';
  @StorageLink('selectedValue') selectedValue: number = 72;

  private chartCanvasController: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  openLiveChartModal(metricName: string, currentVal: number) {
    AppStorage.setOrCreate('selectedMetric', metricName);
    AppStorage.setOrCreate('selectedValue', currentVal);
    AppStorage.setOrCreate('isGraphModalOpen', true);
  }

  aboutToAppear() {
    this.seedFromLastReading();
    this.startSensorSimulation();
  }

  /**
   * GET /api/vitals/{userId}/latest for the signed-in patient.
   *
   * The simulation used to always restart from the hard-coded 72 bpm / 98%,
   * so every app launch threw away the last reading the server had. The login
   * response carries the patient's own userId (`AuthResponse.userId`), so the
   * last stored packet can be read back and used as the starting point.
   */
  async seedFromLastReading(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const latest: VitalsResponse = await ApiService.getMyVitalsLatest();
      if (latest.heartRate > 0) {
        this.currentHeartRate = latest.heartRate;
      }
      if (latest.bloodOxygen > 0) {
        this.currentOxygen = latest.bloodOxygen;
      }
      console.info(`[API] GET /api/vitals/{userId}/latest - OK, ${latest.heartRate} bpm / ${latest.bloodOxygen}%`);
    } catch (err) {
      // 404 = no reading recorded yet. Expected on a new account; the
      // simulation just starts from its defaults.
      console.warn(`[API] GET /api/vitals/{userId}/latest - failed: ${(err as Error).message}`);
    }
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  /**
   * The paired band's serial, or '' when none is set.
   *
   * Read fresh from the profile on every send rather than cached once: the
   * patient can pair a band from the setup screen while this dashboard is
   * alive, and a cached empty value would keep the readings anonymous
   * afterwards.
   */
  private pairedBandSerial(): string {
    const profile = AppStorage.get<Record<string, Object>>('medicalProfile');
    if (profile === undefined) {
      return '';
    }
    const serial = profile.bandIdentifier;
    return typeof serial === 'string' ? serial as string : '';
  }

  startSensorSimulation() {
    this.timerId = setInterval(() => {
      let hrDelta = Math.floor(Math.random() * 5) - 2;
      this.currentHeartRate = Math.max(60, Math.min(100, this.currentHeartRate + hrDelta));

      let o2Delta = Math.floor(Math.random() * 3) - 1;
      this.currentOxygen = Math.max(95, Math.min(100, this.currentOxygen + o2Delta));

      this.currentSteps += Math.floor(Math.random() * 3);
      this.currentCalories += Math.floor(Math.random() * 2);

      let newHrHist = [...this.heartRateHistory, this.currentHeartRate];
      if (newHrHist.length > 15) {
        newHrHist.shift();
      }
      this.heartRateHistory = newHrHist;

      let newO2Hist = [...this.oxygenHistory, this.currentOxygen];
      if (newO2Hist.length > 15) {
        newO2Hist.shift();
      }
      this.oxygenHistory = newO2Hist;

      // Send the reading to the backend. Single-flight guard: no new request is
      // started while one is in flight, otherwise the 2s loop piled them up.
      if (SessionStore.isAuthenticated() && !this.vitalsInFlight) {
        this.vitalsInFlight = true;
        // deviceSn carries the paired band's serial, or nothing at all.
        // vitals.go compares it against the patient's registered
        // band_identifier and answers 403 on a mismatch, so a guessed value
        // would break the upload outright - see `pairedBandSerial`.
        ApiService.sendVitals(this.currentHeartRate, this.currentOxygen, this.pairedBandSerial())
          .catch((err: Error) => console.error(`[API] POST /api/vitals - FAILED: ${err.message}`))
          .finally(() => {
            this.vitalsInFlight = false;
          });
      }

      if (this.isGraphModalOpen) {
        if (this.selectedMetric === 'Heart Rate') {
          AppStorage.setOrCreate('selectedValue', this.currentHeartRate);
        } else if (this.selectedMetric === 'Oxygen') {
          AppStorage.setOrCreate('selectedValue', this.currentOxygen);
        }
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
        AppHeader({ title: 'GuardianBand Home', onCameraClick: () => { this.onQrScanClick(); } })
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

        // My Emergency Access QR - shortcut to the code shown to responders in
        // an emergency. Opens ProfilePage's QR modal directly in Emergency
        // Access mode so it does not need a second tap once there.
        Button() {
          Text('My Emergency Access QR')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .height(52)
        .backgroundColor('#BA1A1A')
        .borderRadius(16)
        .shadow({ radius: 10, color: 'rgba(186, 26, 26, 0.25)', offsetX: 0, offsetY: 4 })
        .margin({ bottom: 20 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/ProfilePage', params: { openEmergencyQr: true } });
        })

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



        Row() {
          Text('Live Vitals & Activity')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .layoutWeight(1)

          Row() {
            Circle({ width: 7, height: 7 }).fill('#006E2F').margin({ right: 6 })
            Text('Sensors Active')
              .fontSize(11)
              .fontColor('#006E2F')
              .fontWeight(FontWeight.Bold)
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#E6F9ED')
          .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ left: 4, right: 4, bottom: 12 })

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
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      }
      .width('100%')
    }
    .width('100%')
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

  // Real linked patients (GET /api/monitoring/patients), replacing the old
  // hard-coded "Father"/"Mother" mock. Same data source and shape as
  // DoctorDashboardView.doctorPatients - the backend does not distinguish
  // family from clinician relationships when listing who a member can monitor.
  @State linkedPatients: MonitoredPatient[] = [];
  @State selectedPatientId: string = '';

  @State showDropdown: boolean = false;
  @StorageLink('profilePicture') profilePicture: string = '';

  // Scan & link a patient's QR invitation - same mechanism as DoctorDashboardView.
  // A family member redeeming a LINK QR creates a MonitoringRelationship the
  // same way a doctor does; the backend does not distinguish by role.
  @StorageLink('scannedPatientLinkRequest') @Watch('onLinkRequestChanged') scannedPatientLinkRequest: string = '';
  @State isLinkModalOpen: boolean = false;
  @State linkPatientInvitationToken: string = '';

  async scanPatientQr() {
    try {
      router.pushUrl({ url: 'pages/CameraPage' });
    } catch (e) {
      promptAction.showToast({ message: 'Simulator Mode: Opening manual entry form...' });
      this.isLinkModalOpen = true;
    }
  }

  /** POST /api/patient-link-invitations/redeem - the same flow doctors use. */
  async onLinkRequestChanged() {
    if (!this.scannedPatientLinkRequest) return;
    let scanned = this.scannedPatientLinkRequest;
    AppStorage.setOrCreate('scannedPatientLinkRequest', '');

    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'No active session. Please sign in.' });
      return;
    }

    const parsed: QrContent = QrPayload.decode(scanned);
    if (parsed.kind === QrKind.EMERGENCY) {
      promptAction.showToast({ message: QrPayload.wrongKindMessage(QrKind.LINK) });
      return;
    }
    if (parsed.kind === QrKind.LEGACY_JSON) {
      promptAction.showToast({ message: QrPayload.legacyMessage() });
      return;
    }

    promptAction.showToast({ message: 'Verifying invitation code...' });

    try {
      const relationship: MonitoringRelationship = await ApiService.redeemLinkInvitation(parsed.token);
      console.info(`[API] POST /api/patient-link-invitations/redeem - OK, patientId=${relationship.patientId}`);
      promptAction.showToast({ message: 'Patient added to your list.' });
      await this.loadFamilyPatients();
    } catch (e) {
      const status: number = e instanceof ApiError ? (e as ApiError).status : -1;
      console.error(`[API] Could not redeem invitation (status=${status}): ${(e as Error).message}`);
      if (status >= 500) {
        promptAction.showToast({
          message: 'Server error: patient linking is currently unavailable. The code is valid; the problem is on the server.'
        });
      } else {
        promptAction.showToast({ message: `Could not link: ${(e as Error).message}` });
      }
    }
  }

  /**
   * GET /api/monitoring/patients - the exact same endpoint and shape
   * DoctorDashboardView uses. The backend has no notion of "family" vs
   * "clinician" here; it just returns everyone this account has an active
   * can-monitor relationship with.
   */
  async loadFamilyPatients() {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const backendPatients: ClinicianPatient[] = await ApiService.getMonitoredPatients();
      console.info(`[API] GET /api/monitoring/patients - OK, ${backendPatients.length} patient(s)`);

      const list: MonitoredPatient[] = [];
      for (const bp of backendPatients) {
        let heart: number = 0;
        let oxy: number = 0;
        try {
          const vitals = await ApiService.getVitalsLatest(bp.patientId);
          if (vitals.heartRate) {
            heart = vitals.heartRate;
          }
          if (vitals.bloodOxygen) {
            oxy = vitals.bloodOxygen;
          }
        } catch (e) {
          // 404 = no readings for this patient yet. Expected.
          console.info(`[API] No vitals yet for ${bp.patientId}`);
        }

        list.push({
          id: bp.id,
          name: bp.name && bp.name.length > 0 ? bp.name : 'Unnamed Patient',
          // gender / calories / sleep / meds / location have no backend
          // counterpart for a monitored patient; left empty rather than
          // filled with fake values.
          gender: '',
          bloodType: bp.bloodType || '',
          heartRate: heart,
          oxygen: oxy,
          calories: 0,
          sleep: '',
          meds: '',
          location: ''
        });
      }
      this.linkedPatients = list;
      if (list.length > 0 && !list.some((p: MonitoredPatient) => p.id === this.selectedPatientId)) {
        // Nothing selected yet, or the previous selection is no longer in the
        // list (e.g. the relationship was revoked) - fall back to the first.
        this.selectedPatientId = list[0].id;
      }
    } catch (err) {
      console.error(`[API] GET /api/monitoring/patients - FAILED: ${(err as Error).message}`);
    }
  }

  /** Currently selected patient, or undefined if none is linked yet. */
  getSelectedPatient(): MonitoredPatient | undefined {
    return this.linkedPatients.find((p: MonitoredPatient) => p.id === this.selectedPatientId);
  }

  /** GET /api/vitals/{userId}/latest result, formatted for display; '--' when there is none yet. */
  displayHeartRate(): string {
    const p = this.getSelectedPatient();
    return p !== undefined && p.heartRate > 0 ? `${p.heartRate}` : '--';
  }

  displayOxygen(): string {
    const p = this.getSelectedPatient();
    return p !== undefined && p.oxygen > 0 ? `${p.oxygen}` : '--';
  }

  /**
   * A short factual line based on the latest reading actually on file - no
   * fabricated "everything is fine" narrative like the old mock text.
   */
  getHealthSummaryText(): string {
    const p = this.getSelectedPatient();
    if (p === undefined) {
      return 'No data available yet.';
    }
    if (p.heartRate > 0 && p.oxygen > 0) {
      return `Latest reading: ${p.heartRate} bpm heart rate, ${p.oxygen}% blood oxygen.`;
    }
    return `${p.name} has not synced any readings yet.`;
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

  aboutToAppear() {
    this.loadFamilyPatients();
  }

  build() {
    Stack() {
    Column() {
      AppHeader({ title: 'GuardianBand Home', onCameraClick: () => { this.onQrScanClick(); } })
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

      // Match Patient via QR - same "Link" invitation mechanism as the doctor
      // dashboard (POST /api/patient-link-invitations/redeem).
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

            Text("Scan your patient's Link QR code from their profile to add them to your list.")
              .fontSize(12)
              .fontColor('#737685')
              .lineHeight(16)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Button('Scan & Link Patient', { type: ButtonType.Normal })
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
      .margin({ bottom: 20 })

      if (this.linkedPatients.length === 0) {
        // Empty state - nobody linked yet. The "Match Patient QR Code" card
        // above is the call to action; no point showing a wall of dashes for
        // vitals that do not exist yet.
        Column() {
          Image($r('app.media.patient'))
            .width(56)
            .height(56)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 16 })
          Text('No Patients Linked Yet')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })
          Text('Scan the Link QR code from your patient\'s profile to see their health information here.')
            .fontSize(13)
            .fontColor('#737685')
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .width('80%')
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .alignItems(HorizontalAlign.Center)
      } else {

      // 2. Monitoring Profile Title Section
      Row() {
        Column() {
          Text('MONITORING PROFILE')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#737685')
            .margin({ bottom: 4 })

          Row() {
            Text(this.getSelectedPatient() !== undefined ? `${this.getSelectedPatient()!.name}'s Health` : 'Health')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ right: 8 })

            if (this.linkedPatients.length > 1) {
              Text('▼')
                .fontSize(16)
                .fontColor('#003D9B')
            }
          }
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (this.linkedPatients.length > 1) {
              this.showDropdown = !this.showDropdown;
            }
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

      // Dropdown Overlay Menu - one row per real linked patient.
      if (this.showDropdown) {
        Column() {
          ForEach(this.linkedPatients, (patient: MonitoredPatient) => {
            Row() {
              Row() {
                Text(this.getInitials(patient.name))
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .width(28)
              .height(28)
              .borderRadius(14)
              .backgroundColor(patient.id === this.selectedPatientId ? '#006E2F' : '#854E00')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 10 })

              Text(patient.name)
                .fontSize(15)
                .fontWeight(patient.id === this.selectedPatientId ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(patient.id === this.selectedPatientId ? '#003D9B' : '#191C1D')

              Blank()

              if (patient.id === this.selectedPatientId) {
                Image($r('app.media.like'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 12, left: 16, right: 16 })
            .onClick(() => {
              this.selectedPatientId = patient.id;
              this.showDropdown = false;
            })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })
          }, (patient: MonitoredPatient) => patient.id)
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

          Text(this.getHealthSummaryText())
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
              Text(this.displayHeartRate())
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

            Text(this.displayHeartRate() === '--' ? 'No Data' : 'Normal Range')
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
              Text(this.displayOxygen())
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

            Text(this.displayOxygen() === '--' ? 'No Data' : 'Healthy')
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
              Text('No Data')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text('Not tracked yet')
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
              Text('No Data')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ bottom: 4 })

            Text('Not tracked yet')
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
          Text('Not tracked yet')
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
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 5. Medication Status - no backend endpoint exposes another patient's
      // medications to a monitoring family member/doctor (only the patient's
      // own token can call GET /api/medications), so this stays an honest
      // placeholder rather than fabricated drug names and times.
      Column() {
        Row() {
          Image($r('app.media.drugs'))
            .width(25)
            .height(25)
            .objectFit(ImageFit.Contain)
            .margin({ right: 12 })

          Text('Medication Status')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 12 })

        Text('Medication tracking for linked patients is not available yet.')
          .fontSize(13)
          .fontColor('#737685')
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 6. Last Known Location - no backend endpoint tracks a patient's
      // ongoing location (SOS incidents carry a one-off lat/lng at trigger
      // time, but there is no continuous location API), so this is an honest
      // placeholder instead of a fabricated map and coordinates.
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

        Text('Location sharing is not available yet.')
          .fontSize(13)
          .fontColor('#737685')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // 7. Recent Activity - no backend activity-feed endpoint exists yet,
      // so this stays an honest empty state instead of a fabricated feed.
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

        Text('No recent activity to show yet.')
          .fontSize(13)
          .fontColor('#737685')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      } // end of else (linkedPatients.length > 0)
    }
    .width('100%')

    // Manual Patient Link Modal (Simulator Mode fallback) - same fallback as
    // the doctor dashboard, for when the camera cannot be opened.
    if (this.isLinkModalOpen) {
      Column() {
        Column() {
          Text('Link Patient with Invitation Code')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 16 })

          Text('The patient opens "My QR Code" in their profile and shows it to you. Scan it or enter it manually. The code is valid for 15 minutes and can be used once.')
            .fontSize(12)
            .fontColor('#737685')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })
          TextInput({ placeholder: 'Davet kodu', text: this.linkPatientInvitationToken })
            .width('100%')
            .height(48)
            .margin({ bottom: 20 })
            .onChange((val: string) => this.linkPatientInvitationToken = val)

          Row() {
            Button('Cancel', { type: ButtonType.Normal })
              .width(100)
              .height(44)
              .backgroundColor(Color.Transparent)
              .fontColor('#737685')
              .onClick(() => {
                this.isLinkModalOpen = false;
                this.linkPatientInvitationToken = '';
              })

            Blank()

            Button('Link Patient', { type: ButtonType.Normal })
              .width(130)
              .height(44)
              .backgroundColor('#003D9B')
              .fontColor(Color.White)
              .borderRadius(8)
              .onClick(async () => {
                if (!this.linkPatientInvitationToken) {
                  promptAction.showToast({ message: 'Enter the invitation code from the patient.' });
                  return;
                }
                if (!SessionStore.isAuthenticated()) {
                  promptAction.showToast({ message: 'No active session. Please sign in.' });
                  return;
                }
                try {
                  await ApiService.redeemLinkInvitation(QrPayload.decode(this.linkPatientInvitationToken).token);
                  promptAction.showToast({ message: 'Patient added to your list.' });
                  this.isLinkModalOpen = false;
                  this.linkPatientInvitationToken = '';
                } catch (e) {
                  promptAction.showToast({ message: `Could not link: ${(e as Error).message}` });
                }
              })
          }.width('100%')
        }.width('90%')
        .padding(24)
        .backgroundColor(Color.White)
        .borderRadius(24)
        .shadow({ radius: 24, color: 'rgba(0,0,0,0.15)' })
      }.width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.4)')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .position({ x: 0, y: 0 })
    }
    }
  }
}

// ----------------------------------------------------
// DOCTOR DASHBOARD VIEW
// ----------------------------------------------------
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

  @State doctorPatients: MonitoredPatient[] = [];
  @State selectedPatient: MonitoredPatient | null = null;
  @State isInspectorOpen: boolean = false;
  onQrScanClick: () => void = () => {};
  @StorageLink('profilePicture') profilePicture: string = '';
  @StorageLink('scannedPatientLinkRequest') @Watch('onLinkRequestChanged') scannedPatientLinkRequest: string = '';
  @StorageLink('doctorWatchScanResult') @Watch('onWatchScanResultChanged') doctorWatchScanResult: string = '';

  @State isLinkModalOpen: boolean = false;
  @State linkPatientInvitationToken: string = '';
  @State isDoctorWatchPopupOpen: boolean = false;
  @State isEmergencyMedsExpanded: boolean = true;
  @State isChronicDiseasesExpanded: boolean = true;
  @State doctorWatchPatientInfo: ScannedPatient = {
    id: '', name: '', email: '', bloodType: '', allergies: '', diseases: []
  };

  aboutToAppear() {
    this.loadDoctorPatients();
  }

  /** GET /api/monitoring/patients — eski /api/clinician/patients yolu backend'de yoktu. */
  async loadDoctorPatients() {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const backendPatients: ClinicianPatient[] = await ApiService.getMonitoredPatients();
      console.info(`[API] GET /api/monitoring/patients - OK, ${backendPatients.length} hasta`);

      const list: MonitoredPatient[] = [];
      for (const bp of backendPatients) {
        let heart: number = 0;
        let oxy: number = 0;
        try {
          const vitals = await ApiService.getVitalsLatest(bp.patientId);
          if (vitals.heartRate) {
            heart = vitals.heartRate;
          }
          if (vitals.bloodOxygen) {
            oxy = vitals.bloodOxygen;
          }
        } catch (e) {
          // 404 = no readings for this patient yet. Expected.
          console.info(`[API] No vitals yet for ${bp.patientId}`);
        }

        list.push({
          id: bp.id,
          name: bp.name && bp.name.length > 0 ? bp.name : 'Unnamed Patient',
          // gender / calories / sleep / meds / location have no backend
          // counterpart; left empty rather than filled with fake values.
          gender: '',
          bloodType: bp.bloodType || '',
          heartRate: heart,
          oxygen: oxy,
          calories: 0,
          sleep: '',
          meds: '',
          location: ''
        });
      }
      this.doctorPatients = list;
    } catch (err) {
      console.error(`[API] GET /api/monitoring/patients - FAILED: ${(err as Error).message}`);
    }
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

  async onWatchScanResultChanged() {
    if (!this.doctorWatchScanResult) return;
    let scanned = this.doctorWatchScanResult;
    AppStorage.setOrCreate('doctorWatchScanResult', '');
    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'You need to sign in to use emergency access.' });
      return;
    }

    // The watch/band scan also carries an emergency access token; data comes
    // from the server.
    try {
      const parsedWatch: QrContent = QrPayload.decode(scanned);
      if (parsedWatch.kind === QrKind.LINK) {
        promptAction.showToast({ message: QrPayload.wrongKindMessage(QrKind.EMERGENCY) });
        return;
      }
      if (parsedWatch.kind === QrKind.LEGACY_JSON) {
        promptAction.showToast({ message: QrPayload.legacyMessage() });
        return;
      }
      const session: EmergencyAccessSession = await ApiService.redeemEmergencyToken(parsedWatch.token);
      const card: EmergencyMedicalCard = await ApiService.getEmergencyMedicalCard(session.sessionId);
      console.info(`[API] Watch scan - medical card retrieved, sessionId=${session.sessionId}`);

      const allergyList: string[] = card.criticalFacts.allergies !== undefined ? card.criticalFacts.allergies : [];
      const conditionList: string[] = card.criticalFacts.chronicConditions !== undefined
        ? card.criticalFacts.chronicConditions : [];

      let vitalsView: ScannedPatientVitals = {
        heartRate: 'No data',
        oxygen: 'No data',
        recordedAt: ''
      };
      if (card.latestVitals !== undefined) {
        vitalsView = {
          heartRate: `${card.latestVitals.heartRate} bpm`,
          oxygen: `${card.latestVitals.bloodOxygen}%`,
          recordedAt: card.latestVitals.recordedAt
        };
      }

      this.doctorWatchPatientInfo = {
        id: session.sessionId,
        // Used to be the fixed label 'Emergency Medical Card', because the card
        // carried no identity. It does now, so the responder sees who they are
        // looking at.
        name: card.displayName !== undefined && card.displayName.length > 0
          ? card.displayName : 'Unknown patient',
        email: '',
        bloodType: card.bloodType || 'Unknown',
        allergies: allergyList.length > 0 ? allergyList.join(', ') : 'No known allergies',
        diseases: conditionList,
        medications: card.medications.map((m: EmergencyMedication) =>
          `${m.name} ${m.strength} — ${m.instructions}`),
        vitals: vitalsView,
        gender: card.criticalFacts.gender !== undefined ? card.criticalFacts.gender : '',
        age: DisplayFormat.age(card.birthDate)
      };
      this.isDoctorWatchPopupOpen = true;
    } catch (err) {
      console.error(`[API] Watch scan failed: ${(err as Error).message}`);
      promptAction.showToast({ message: `Emergency access failed: ${(err as Error).message}` });
    }
  }

  async onLinkRequestChanged() {
    if (!this.scannedPatientLinkRequest) return;
    
    let scanned = this.scannedPatientLinkRequest;
    AppStorage.setOrCreate('scannedPatientLinkRequest', '');

    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'No active session. Please sign in.' });
      return;
    }

    const parsed: QrContent = QrPayload.decode(scanned);
    if (parsed.kind === QrKind.EMERGENCY) {
      promptAction.showToast({ message: QrPayload.wrongKindMessage(QrKind.LINK) });
      return;
    }
    if (parsed.kind === QrKind.LEGACY_JSON) {
      promptAction.showToast({ message: QrPayload.legacyMessage() });
      return;
    }

    promptAction.showToast({ message: 'Verifying invitation code...' });

    try {
      const relationship: MonitoringRelationship = await ApiService.redeemLinkInvitation(parsed.token);
      console.info(`[API] POST /api/patient-link-invitations/redeem - OK, patientId=${relationship.patientId}`);
      await this.loadDoctorPatients();
      promptAction.showToast({ message: 'Hasta listenize eklendi.' });
    } catch (e) {
      const status: number = e instanceof ApiError ? (e as ApiError).status : -1;
      console.error(`[API] Could not redeem invitation (status=${status}): ${(e as Error).message}`);
      if (status >= 500) {
        // Known server-side bug (BT-05): the redeem query fails because openGauss
        // does not support `ON CONFLICT`. Neither the QR nor the code is wrong.
        promptAction.showToast({
          message: 'Server error: patient linking is currently unavailable. The code is valid; the problem is on the server.'
        });
      } else {
        promptAction.showToast({ message: `Could not link: ${(e as Error).message}` });
      }
    }
  }

  async scanWatchQr() {
    AppStorage.setOrCreate('doctorIsWatchScan', true);
    try {
      router.pushUrl({ url: 'pages/CameraPage' });
    } catch (e) {
      // If the camera fails to open, report it instead of showing a fake patient.
      AppStorage.setOrCreate('doctorIsWatchScan', false);
      console.error(`[HomePage] Could not open camera: ${(e as Error).message}`);
      promptAction.showToast({ message: 'Could not open the camera. You will need to enter the emergency code manually.' });
    }
  }

  async scanPatientQr() {
    try {
      router.pushUrl({ url: 'pages/CameraPage' });
    } catch (e) {
      promptAction.showToast({ message: 'Simulator Mode: Opening manual entry form...' });
      this.isLinkModalOpen = true;
    }
  }

  build() {
    Stack() {
      Column() {
        // --- DOCTOR PORTAL DASHBOARD MAIN VIEW ---
        
        AppHeader({ title: 'GuardianBand Home', onCameraClick: () => { this.scanPatientQr(); } })
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
              this.scanWatchQr();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(0, 61, 155, 0.2)', style: BorderStyle.Solid })
        .margin({ bottom: 24 })

        // Action Card: Match Patient via QR
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

      }
      .width('100%')

    // Emergency Watch Scanner patient info popup (doctor role)
    if (this.isDoctorWatchPopupOpen) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.6)')
          .onClick(() => { this.isDoctorWatchPopupOpen = false; })

        Column() {
          Row() {
            Image($r('app.media.alert'))
              .width(24).height(24).margin({ right: 8 })
            Text('Emergency Patient Vitals')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#BA1A1A')
            Blank()
            Image($r('app.media.cancel'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .onClick(() => { this.isDoctorWatchPopupOpen = false; })
          }
          .width('100%').margin({ bottom: 20 })

          Row() {
            Row() {
              Text(this.doctorWatchPatientInfo.name ? this.doctorWatchPatientInfo.name.substring(0, 2).toUpperCase() : 'PT')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }
            .width(44).height(44).borderRadius(22).backgroundColor('#BA1A1A')
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center).margin({ right: 12 })

            Column() {
              Text(this.doctorWatchPatientInfo.name || 'Unknown Patient')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#191C1D').margin({ bottom: 2 })
              Text(`Oturum: ${DisplayFormat.shortId(this.doctorWatchPatientInfo.id)}`)
                .fontSize(12).fontColor('#737685')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%').padding(12).backgroundColor('#FFEBEA').borderRadius(16).margin({ bottom: 20 })

          Column() {
            Row() {
              Text('Blood Type').fontSize(14).fontColor('#737685').layoutWeight(1)
              Text(this.doctorWatchPatientInfo.bloodType || 'N/A')
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#191C1D')
            }
            .width('100%').padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            Row() {
              Text('Allergies').fontSize(14).fontColor('#737685').layoutWeight(1)
              Text(this.doctorWatchPatientInfo.allergies || 'None')
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#191C1D')
            }
            .width('100%').padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            // Chronic Conditions Collapsible Section
            Column() {
              Row() {
                Text(`Chronic Conditions (${getFormattedDiseasesArray(this.doctorWatchPatientInfo.diseases, this.doctorWatchPatientInfo.otherChronicDisease).length})`)
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)

                Text(this.isChronicDiseasesExpanded ? '▲' : '▼')
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .onClick(() => {
                this.isChronicDiseasesExpanded = !this.isChronicDiseasesExpanded;
              })

              if (this.isChronicDiseasesExpanded) {
                Column({ space: 4 }) {
                  if (getFormattedDiseasesArray(this.doctorWatchPatientInfo.diseases, this.doctorWatchPatientInfo.otherChronicDisease).length === 0) {
                    Row() {
                      Blank()
                      Text('None')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                    }
                    .width('100%')
                    .padding({ bottom: 8 })
                  } else {
                    ForEach(getFormattedDiseasesArray(this.doctorWatchPatientInfo.diseases, this.doctorWatchPatientInfo.otherChronicDisease), (diseaseName: string) => {
                      Row() {
                        Blank()
                        Text(diseaseName)
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#BA1A1A')
                      }
                      .width('100%')
                      .padding({ top: 2, bottom: 4 })
                    })
                  }
                }
                .width('100%')
                .margin({ bottom: 8 })
              }
            }
            .width('100%')
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            // Active Medications Collapsible Section
            Column() {
              Row() {
                Text(`Active Prescriptions (${getActiveMedicationsList(this.doctorWatchPatientInfo.medications).length})`)
                  .fontSize(14)
                  .fontColor('#737685')
                  .layoutWeight(1)

                Text(this.isEmergencyMedsExpanded ? '▲' : '▼')
                  .fontSize(12)
                  .fontColor('#737685')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .onClick(() => {
                this.isEmergencyMedsExpanded = !this.isEmergencyMedsExpanded;
              })

              if (this.isEmergencyMedsExpanded) {
                Column({ space: 4 }) {
                  if (getActiveMedicationsList(this.doctorWatchPatientInfo.medications).length === 0) {
                    Row() {
                      Blank()
                      Text('None')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                    }
                    .width('100%')
                    .padding({ bottom: 8 })
                  } else {
                    ForEach(getActiveMedicationsList(this.doctorWatchPatientInfo.medications), (medName: string) => {
                      Row() {
                        Blank()
                        Text(medName)
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#191C1D')
                      }
                      .width('100%')
                      .padding({ top: 2, bottom: 4 })
                    })
                  }
                }
                .width('100%')
                .margin({ bottom: 8 })
              }
            }
            .width('100%')
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            Row() {
              Text('Heart Rate').fontSize(14).fontColor('#737685').layoutWeight(1)
              Text(this.doctorWatchPatientInfo.vitals?.heartRate || '72 bpm')
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.doctorWatchPatientInfo.vitals?.heartRate &&
                  this.doctorWatchPatientInfo.vitals.heartRate.includes('High') ? '#BA1A1A' : '#003D9B')
            }
            .width('100%').padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            Row() {
              Text('Oxygen Saturation').fontSize(14).fontColor('#737685').layoutWeight(1)
              Text(this.doctorWatchPatientInfo.vitals?.oxygen || '98%')
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.doctorWatchPatientInfo.vitals?.oxygen &&
                  this.doctorWatchPatientInfo.vitals.oxygen.includes('Low') ? '#854E00' : '#006E2F')
            }
            .width('100%').padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)' })

            Row() {
              Text('Last Reading').fontSize(14).fontColor('#737685').layoutWeight(1)
              Text(DisplayFormat.dateTime(this.doctorWatchPatientInfo.vitals?.recordedAt))
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#191C1D').textAlign(TextAlign.End)
            }
            .width('100%').padding({ top: 12, bottom: 12 })
          }
          .width('100%').padding({ left: 16, right: 16 })
          .backgroundColor(Color.White).borderRadius(16)
          .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' }).margin({ bottom: 24 })

          Row() {
            Button('Call Emergency', { type: ButtonType.Normal })
              .layoutWeight(1).height(44)
              .backgroundColor('rgba(186, 26, 26, 0.08)').fontColor('#BA1A1A')
              .fontWeight(FontWeight.Bold).borderRadius(12).margin({ right: 12 })
              .onClick(() => { promptAction.showToast({ message: 'Calling emergency contacts...' }); })

            Button('Dismiss', { type: ButtonType.Normal })
              .layoutWeight(1).height(44)
              .backgroundColor('#003D9B').fontColor(Color.White)
              .fontWeight(FontWeight.Bold).borderRadius(12)
              .onClick(() => { this.isDoctorWatchPopupOpen = false; })
          }
          .width('100%')
        }
        .width('90%').padding(24).backgroundColor(Color.White)
        .borderRadius(24).shadow({ radius: 16, color: 'rgba(0,0,0,0.15)', offsetY: 8 }).zIndex(20)
      }
      .width('100%').height('100%').position({ x: 0, y: 0 }).zIndex(150)
    }

    if (this.isLinkModalOpen) {
        Column() {
          Column() {
            Text('Link Patient with Invitation Code')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 16 })

            Text('The patient opens "My QR Code" in their profile and shows it to you. Scan it or enter it manually. The code is valid for 15 minutes and can be used once.')
              .fontSize(12)
              .fontColor('#737685')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })
            TextInput({ placeholder: 'Davet kodu', text: this.linkPatientInvitationToken })
              .width('100%')
              .height(48)
              .margin({ bottom: 20 })
              .onChange((val: string) => this.linkPatientInvitationToken = val)

            Row() {
              Button('Cancel', { type: ButtonType.Normal })
                .width(100)
                .height(44)
                .backgroundColor(Color.Transparent)
                .fontColor('#737685')
                .onClick(() => {
                  this.isLinkModalOpen = false;
                  this.linkPatientInvitationToken = '';
                })

              Blank()

              Button('Link Patient', { type: ButtonType.Normal })
                .width(130)
                .height(44)
                .backgroundColor('#003D9B')
                .fontColor(Color.White)
                .borderRadius(8)
                .onClick(async () => {
                  if (!this.linkPatientInvitationToken) {
                    promptAction.showToast({ message: 'Enter the invitation code from the patient.' });
                    return;
                  }
                  if (!SessionStore.isAuthenticated()) {
                    promptAction.showToast({ message: 'No active session. Please sign in.' });
                    return;
                  }
                  try {
                    await ApiService.redeemLinkInvitation(QrPayload.decode(this.linkPatientInvitationToken).token);
                    promptAction.showToast({ message: 'Hasta listenize eklendi.' });
                    this.isLinkModalOpen = false;
                    this.linkPatientInvitationToken = '';
                    await this.loadDoctorPatients();
                  } catch (e) {
                    promptAction.showToast({ message: `Could not link: ${(e as Error).message}` });
                  }
                })
            }.width('100%')
          }.width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 24, color: 'rgba(0,0,0,0.15)' })
        }.width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: 0 })
      }
    }.width('100%')
  }
}

@Component
struct VitalsGraphModal {
  @StorageLink('isGraphModalOpen') isGraphModalOpen: boolean = false;
  @StorageLink('selectedMetric') selectedMetric: string = 'Heart Rate';
  @StorageLink('selectedValue') selectedValue: number = 72;
  @StorageLink('heartRateHistory') heartRateHistory: number[] = [70, 72, 71, 73, 72, 70, 72];
  @StorageLink('oxygenHistory') oxygenHistory: number[] = [97, 98, 98, 97, 99, 98, 98];

  private chartCanvasController: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  getVitalsStatusText(): string {
    let val = Number(this.selectedValue);
    if (this.selectedMetric === 'Heart Rate') {
      if (val >= 60 && val <= 100) return 'Normal Range';
      if (val > 100) return 'High';
      return 'Low';
    } else {
      if (val >= 95) return 'Normal Range';
      return 'Low';
    }
  }

  getVitalsStatusColor(): string {
    let val = Number(this.selectedValue);
    if (this.selectedMetric === 'Heart Rate') {
      if (val >= 60 && val <= 100) return '#006E2F';
      if (val > 100) return '#BA1A1A';
      return '#854E00';
    } else {
      if (val >= 95) return '#006E2F';
      return '#BA1A1A';
    }
  }

  getVitalsStatusBg(): string {
    let val = Number(this.selectedValue);
    if (this.selectedMetric === 'Heart Rate') {
      if (val >= 60 && val <= 100) return '#E6F9ED';
      if (val > 100) return '#FFEBEA';
      return '#FFF4E5';
    } else {
      if (val >= 95) return '#E6F9ED';
      return '#FFEBEA';
    }
  }

  drawMinimalistLineChart() {
    const ctx = this.chartCanvasController;
    const width = 300;
    const height = 160;

    ctx.clearRect(0, 0, width, height);

    let isHeart = this.selectedMetric === 'Heart Rate';
    let dataPoints = isHeart ? this.heartRateHistory : this.oxygenHistory;
    if (dataPoints.length === 0) return;

    let minVal = isHeart ? 50 : 90;
    let maxVal = isHeart ? 110 : 100;
    let normalMin = isHeart ? 60 : 95;
    let normalMax = isHeart ? 100 : 100;

    let paddingLeft = 4;
    let paddingRight = 4;
    let paddingTop = 8;
    let paddingBottom = 8;

    let usableWidth = width - paddingLeft - paddingRight;
    let usableHeight = height - paddingTop - paddingBottom;

    let getY = (val: number): number => {
      let clamped = Math.max(minVal, Math.min(maxVal, val));
      let norm = (clamped - minVal) / (maxVal - minVal);
      return (height - paddingBottom) - (norm * usableHeight);
    };

    let normYTop = getY(normalMax);
    let normYBottom = getY(normalMin);
    ctx.fillStyle = 'rgba(0, 110, 47, 0.12)';
    ctx.fillRect(paddingLeft, normYTop, usableWidth, normYBottom - normYTop);

    ctx.strokeStyle = 'rgba(0, 110, 47, 0.35)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(paddingLeft, normYTop);
    ctx.lineTo(paddingLeft + usableWidth, normYTop);
    ctx.moveTo(paddingLeft, normYBottom);
    ctx.lineTo(paddingLeft + usableWidth, normYBottom);
    ctx.stroke();

    let ySteps = isHeart ? [100, 80, 60] : [100, 95, 90];
    ctx.strokeStyle = '#E2E8F0';
    ctx.lineWidth = 1;
    for (let val of ySteps) {
      let yPos = getY(val);
      ctx.beginPath();
      ctx.moveTo(paddingLeft, yPos);
      ctx.lineTo(width - paddingRight, yPos);
      ctx.stroke();
    }

    let stepX = dataPoints.length > 1 ? usableWidth / (dataPoints.length - 1) : usableWidth;
    ctx.strokeStyle = '#003D9B';
    ctx.lineWidth = 3;
    ctx.beginPath();

    let coords: ChartPoint[] = [];
    for (let i = 0; i < dataPoints.length; i++) {
      let x = paddingLeft + (i * stepX);
      let y = getY(dataPoints[i]);
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

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. Full-screen dark overlay covering status bar, navbar, and window
      Row()
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .onClick(() => {
          AppStorage.setOrCreate('isGraphModalOpen', false);
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. White Dialog Card
      Column() {
        // Header: Title & Sleek 32x32 Close Button
        Row() {
          Column() {
            Text(this.selectedMetric === 'Heart Rate' ? 'Heart Rate Trend' : 'Oxygen Saturation Trend')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
            Text('Last 10 minutes live reading')
              .fontSize(12)
              .fontColor('#737685')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button() {
            Image($r('app.media.cancel'))
              .width(16)
              .height(16)
              .objectFit(ImageFit.Contain)
          }
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .backgroundColor('#F1F5F9')
          .onClick(() => {
            AppStorage.setOrCreate('isGraphModalOpen', false);
          })
        }
        .width('100%')
        .margin({ bottom: 16 })

        // 1. Single Main Reading & Status Card
        Row() {
          Column() {
            Text('Latest Reading')
              .fontSize(12)
              .fontColor('#737685')
              .margin({ bottom: 2 })

            Text(`${this.selectedValue} ${this.selectedMetric === 'Heart Rate' ? 'bpm' : '%'}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row() {
            Image($r('app.media.like'))
              .width(16)
              .height(16)
              .objectFit(ImageFit.Contain)
              .margin({ right: 6 })
            Text(this.getVitalsStatusText())
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getVitalsStatusColor())
          }
          .padding({ left: 10, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.getVitalsStatusBg())
          .borderRadius(16)
          .border({ width: 1, color: this.getVitalsStatusColor() })
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#F8F9FF')
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(0, 61, 155, 0.12)' })
        .margin({ bottom: 16 })

        // 2. Chart with Native ArkUI Labels
        Column() {
          Row() {
            Column() {
              Text(this.selectedMetric === 'Heart Rate' ? '100' : '%100')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
                .textAlign(TextAlign.End)
                .width('100%')
                .maxLines(1)

              Blank()

              Text(this.selectedMetric === 'Heart Rate' ? '80' : '%95')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
                .textAlign(TextAlign.End)
                .width('100%')
                .maxLines(1)

              Blank()

              Text(this.selectedMetric === 'Heart Rate' ? '60' : '%90')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
                .textAlign(TextAlign.End)
                .width('100%')
                .maxLines(1)
            }
            .width(36)
            .height(160)
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ right: 3 })

            Canvas(this.chartCanvasController)
              .layoutWeight(1)
              .height(160)
              .backgroundColor('#FFFFFF')
              .onReady(() => {
                this.drawMinimalistLineChart();
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Row() {
            Text('-10 min')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#475569')
            Blank()
            Text('-5 min')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#475569')
            Blank()
            Text('Now')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#475569')
          }
          .width('100%')
          .padding({ left: 31, right: 4 })
          .margin({ top: 6 })
        }
        .width('100%')
        .padding({ left: 8, right: 12, top: 12, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 1.5, color: '#E2E8F0' })
        .margin({ bottom: 12 })

        // 3. Explanation Banner
        Row() {
          Circle({ width: 8, height: 8 }).fill('#006E2F').margin({ right: 8 })
          Text('Green area indicates normal healthy range.')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#434654')
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 4. Confirmation Button
        Button() {
          Row() {
            Image($r('app.media.like'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
              .margin({ right: 8 })
            Text('Done')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(50)
        .backgroundColor('#003D9B')
        .borderRadius(12)
        .shadow({ radius: 6, color: 'rgba(0,61,155,0.2)', offsetY: 3 })
        .onClick(() => {
          AppStorage.setOrCreate('isGraphModalOpen', false);
        })
      }
      .width('90%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(24)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.2)', offsetY: 8 })
      .zIndex(20)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(200)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}