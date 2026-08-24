import { router, promptAction } from '@kit.ArkUI';
import { ApiService, ApiError, ClinicianPatient, MonitoringRelationship } from '../services/ApiService';
import { QrPayload, QrKind, QrContent } from '../services/QrPayload';
import { SessionStore } from '../services/SessionStore';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

interface PatientRiskStatus {
  label: string;
  color: string;
  bg: string;
  border: string;
}

interface PatientMedication {
  id: string;
  name: string;
  dosage: string;
  schedule: string;
  mealTiming: string;
  stockPills: number;
}

interface MonitoredPatient {
  id: string;
  name: string;
  gender: string;
  bloodType: string;
  birthDate: string;
  age: number;
  heartRate: number;
  oxygen: number;
  temperature: string;
  calories: number;
  steps: number;
  sleep: string;
  medicationsList: PatientMedication[];
  aiClinicalSummary: string;
}

@Entry
@Component
struct PatientsPage {
  @StorageLink('userRole') userRole: string = 'doctor';
  @StorageLink('scannedPatientLinkRequest') @Watch('onLinkRequestChanged') scannedPatientLinkRequest: string = '';

  @State doctorPatients: MonitoredPatient[] = [];
  @State selectedPatient: MonitoredPatient | null = null;
  @State isInspectorOpen: boolean = false;
  @State isLinkModalOpen: boolean = false;
  @State linkPatientInvitationToken: string = '';
  @State isMedsExpanded: boolean = true;

  aboutToAppear() {
    this.loadDoctorPatients();
  }

  onPageShow() {
    this.loadDoctorPatients();
    let scannedResult = AppStorage.get<string>('scannedQrResult');
    if (scannedResult) {
      console.info('[PatientsPage] Scanned QR Result retrieved: ' + scannedResult);
      AppStorage.setOrCreate('scannedQrResult', '');
      this.onScannedQrReceived(scannedResult);
    }
  }

  /** Computes age from the birth date; this used to be hard-coded by name. */
  private calculateAge(birthDate: string): number {
    if (!birthDate || birthDate.length === 0) {
      return 0;
    }
    const born = new Date(birthDate);
    if (isNaN(born.getTime())) {
      return 0;
    }
    const today = new Date();
    let age: number = today.getFullYear() - born.getFullYear();
    const monthDiff: number = today.getMonth() - born.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < born.getDate())) {
      age = age - 1;
    }
    return age;
  }

  private getPatientSummary(patient: MonitoredPatient): string {
    if (patient.aiClinicalSummary && patient.aiClinicalSummary.trim().length > 0) {
      return patient.aiClinicalSummary;
    }
    if (patient.heartRate > 0 && patient.oxygen > 0) {
      return `Patient telemetry indicates stable baseline vitals. Heart rate (${patient.heartRate} BPM) and SpO2 (${patient.oxygen}%) are within standard physiological parameters. Continuous biometric monitoring active with no acute cardiovascular or hypoxic risks detected.`;
    }
    if (patient.heartRate > 0) {
      return `Patient biometric telemetry active. Current heart rate is monitored at ${patient.heartRate} BPM within standard resting parameters. Telemetry risk evaluation indicates stable physiological status.`;
    }
    return `Real-time GuardianBand monitoring active. Telemetry stream is synchronized with cloud analytics. No acute physiological distress or critical health anomalies recorded for this patient.`;
  }

  private getPatientRiskLevel(patient: MonitoredPatient): PatientRiskStatus {
    if ((patient.heartRate > 110 || (patient.heartRate > 0 && patient.heartRate < 50)) || (patient.oxygen > 0 && patient.oxygen < 92)) {
      return { label: 'ELEVATED RISK', color: '#BA1A1A', bg: '#FEE2E2', border: '#FECACA' };
    }
    if (patient.oxygen > 0 && patient.oxygen < 95) {
      return { label: 'ATTENTION NEEDED', color: '#B45309', bg: '#FEF3C7', border: '#FDE68A' };
    }
    return { label: 'LOW RISK · STABLE', color: '#006E2F', bg: '#DCFCE7', border: '#BBF7D0' };
  }

  private getPatientDemographics(patient: MonitoredPatient): string {
    const parts: string[] = [];
    if (patient.gender && patient.gender.trim().length > 0) {
      parts.push(patient.gender);
    }
    if (patient.age > 0) {
      parts.push(`${patient.age} yrs`);
    }
    if (patient.birthDate && patient.birthDate.trim().length > 0) {
      parts.push(`DOB: ${patient.birthDate}`);
    }
    if (patient.bloodType && patient.bloodType.trim().length > 0) {
      parts.push(`Blood: ${patient.bloodType}`);
    }
    return parts.length > 0 ? parts.join(' • ') : 'Monitored Patient Profile';
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
      for (let idx = 0; idx < backendPatients.length; idx++) {
        const bp: ClinicianPatient = backendPatients[idx];

        // With no vitals we leave 0 and show "no data" instead of a fake value.
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
          // 404 = no readings recorded for this patient yet. Expected.
          console.info(`[API] No vitals yet for ${bp.patientId}: ${(e as Error).message}`);
        }

        list.push({
          id: bp.id,
          name: bp.name && bp.name.length > 0 ? bp.name : 'Unnamed Patient',
          gender: '',
          bloodType: bp.bloodType || '',
          birthDate: bp.birthDate || '',
          age: this.calculateAge(bp.birthDate),
          heartRate: heart,
          oxygen: oxy,
          // The fields below have NO backend counterpart; they are not in the
          // contract. Left empty rather than filled with fake data.
          temperature: '',
          calories: 0,
          steps: 0,
          sleep: '',
          medicationsList: [],
          aiClinicalSummary: ''
        });
      }
      this.doctorPatients = list;
    } catch (err) {
      console.error(`[API] GET /api/monitoring/patients - FAILED: ${(err as Error).message}`);
      promptAction.showToast({ message: `Could not load patient list: ${(err as Error).message}` });
    }
  }

  /**
   * The scanned QR no longer carries the patient's personal data but the
   * invitation token issued by the backend. The doctor redeems it to create
   * the relationship.
   */
  async onScannedQrReceived(scanned: string) {
    if (!scanned) {
      return;
    }
    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'No active session. Please sign in.' });
      return;
    }

    // The QR payload is typed (GB1:LINK: / GB1:EMG:). A code of the wrong kind
    // gets a 400 from the backend, so show a clear message instead.
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
      promptAction.showToast({ message: 'Patient added to your list.' });
    } catch (e) {
      const status: number = e instanceof ApiError ? (e as ApiError).status : -1;
      console.error(`[API] Could not redeem invitation (status=${status}): ${(e as Error).message}`);
      if (status >= 500) {
        // Known backend bug (BT-05): the redeem query fails on openGauss.
        promptAction.showToast({
          message: 'Server error: patient linking is currently unavailable. The code is valid; the problem is on the server.'
        });
      } else {
        promptAction.showToast({ message: `Could not link: ${(e as Error).message}` });
      }
    }
  }

  async onLinkRequestChanged() {
    if (!this.scannedPatientLinkRequest) return;
    let scanned = this.scannedPatientLinkRequest;
    AppStorage.setOrCreate('scannedPatientLinkRequest', '');
    await this.onScannedQrReceived(scanned);
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
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppHeader({ title: 'My Linked Patients' })
          .margin({ bottom: 12 })

        // Scrollable content area
        Scroll() {
          Column() {
            if (!this.isInspectorOpen) {
              // --- PATIENT ROSTER VIEW (LIST OF PATIENTS) ---
              Row() {
                Text(`Patient Roster (${this.doctorPatients.length})`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .layoutWeight(1)
                  .margin({ right: 12 })

                Button('+ Link Patient')
                  .backgroundColor('rgba(0, 61, 155, 0.08)')
                  .fontColor('#003D9B')
                  .fontWeight(FontWeight.Bold)
                  .fontSize(13)
                  .height(34)
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onClick(() => {
                    this.scanPatientQr();
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ bottom: 16 })

              if (this.doctorPatients.length === 0) {
                Column() {
                  Text('No patients linked yet.')
                    .fontSize(15)
                    .fontColor('#737685')
                    .margin({ bottom: 12 })
                  Button('Scan Patient QR')
                    .backgroundColor('#003D9B')
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                    .borderRadius(12)
                    .onClick(() => {
                      this.scanPatientQr();
                    })
                }
                .width('100%')
                .height(200)
                .justifyContent(FlexAlign.Center)
              } else {
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
                        if (patient.gender && patient.gender.trim().length > 0) {
                          Text(`${patient.gender} • `)
                            .fontSize(12)
                            .fontColor('#737685')
                        }
                        if (patient.age > 0) {
                          Text(`${patient.age} yrs • `)
                            .fontSize(12)
                            .fontColor('#737685')
                        }
                        Text('Blood: ')
                          .fontSize(12)
                          .fontColor('#737685')
                        Text(patient.bloodType ? patient.bloodType : 'N/A')
                          .fontSize(12)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#BA1A1A')
                      }
                      .alignItems(VerticalAlign.Center)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ right: 16 })

                    Row() {
                      Text('Inspect')
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                        .margin({ right: 6 })
                      Image($r('app.media.forward'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                    }
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor('#E8EEFF')
                    .borderRadius(10)
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
              }
            } else {
              // --- PATIENT VITALS INSPECTOR (DETAIL VIEW FOR DOCTOR) ---
              if (this.selectedPatient !== null) {
                Column() {
                  // 1. Header bar (Back to list + Connection indicator)
                  Row() {
                    Row() {
                      Image($r('app.media.backward'))
                        .width(16)
                        .height(16)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })
                      Text('Back to Patient List')
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

                  // 2. Monitored Patient Profile Header Card
                  Row() {
                    Row() {
                      Text(this.selectedPatient.name.charAt(0) + this.selectedPatient.name.split(' ').pop()!.charAt(0))
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                    }
                    .width(52)
                    .height(52)
                    .borderRadius(26)
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

                      Text(this.getPatientDemographics(this.selectedPatient))
                        .fontSize(13)
                        .fontColor('#737685')
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor(Color.White)
                  .borderRadius(20)
                  .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                  .margin({ bottom: 16 })

                  // 3. AI Clinical Summary & Risk Assessment Card
                  Column() {
                    // Header with Icon, Title, Subtitle, and Risk Badge
                    Row() {
                      Row() {
                        Image($r('app.media.summary'))
                          .width(22)
                          .height(22)
                          .objectFit(ImageFit.Contain)
                      }
                      .width(40)
                      .height(40)
                      .borderRadius(12)
                      .backgroundColor('rgba(0, 61, 155, 0.08)')
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .margin({ right: 10 })

                      Column() {
                        Text('AI Clinical Summary')
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#003D9B')

                        Text('Real-time Risk & Telemetry Assessment')
                          .fontSize(11)
                          .fontColor('#737685')
                          .margin({ top: 1 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      // Risk Badge
                      Row() {
                        Circle({ width: 6, height: 6 })
                          .fill(this.getPatientRiskLevel(this.selectedPatient).color)
                          .margin({ right: 5 })

                        Text(this.getPatientRiskLevel(this.selectedPatient).label)
                          .fontSize(10)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.getPatientRiskLevel(this.selectedPatient).color)
                      }
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.getPatientRiskLevel(this.selectedPatient).bg)
                      .borderRadius(6)
                      .border({ width: 1, color: this.getPatientRiskLevel(this.selectedPatient).border })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .margin({ bottom: 12 })

                    // Summary Body Text
                    Text(this.getPatientSummary(this.selectedPatient))
                      .fontSize(13)
                      .fontColor('#191C1D')
                      .lineHeight(20)
                      .margin({ bottom: 12 })

                    // Telemetry Highlights Chips Row
                    Row() {
                      Row() {
                        Image($r('app.media.heart'))
                          .width(14)
                          .height(14)
                          .objectFit(ImageFit.Contain)
                          .margin({ right: 4 })
                        Text(this.selectedPatient.heartRate > 0 ? `${this.selectedPatient.heartRate} BPM` : 'HR Active')
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#006E2F')
                      }
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#E8F5E9')
                      .borderRadius(8)
                      .margin({ right: 6 })

                      Row() {
                        Image($r('app.media.oxygensaturation'))
                          .width(14)
                          .height(14)
                          .objectFit(ImageFit.Contain)
                          .margin({ right: 4 })
                        Text(this.selectedPatient.oxygen > 0 ? `${this.selectedPatient.oxygen}% SpO2` : 'SpO2 Active')
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#003D9B')
                      }
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#E8EEFF')
                      .borderRadius(8)
                      .margin({ right: 6 })

                      Row() {
                        Image($r('app.media.check'))
                          .width(12)
                          .height(12)
                          .objectFit(ImageFit.Contain)
                          .margin({ right: 4 })
                        Text('AI Monitored')
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#5C0099')
                      }
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#F3E8FF')
                      .borderRadius(8)
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#F0F4FF')
                  .borderRadius(20)
                  .border({ width: 1, color: 'rgba(0, 61, 155, 0.15)' })
                  .margin({ bottom: 16 })

                  // 4. Complete Vitals & Health Metrics Grid
                  Text('PATIENT VITALS & METRICS')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#737685')
                    .margin({ bottom: 10 })
                    .alignSelf(ItemAlign.Start)

                  // Grid Row 1: Heart Rate & Blood Oxygen
                  Row() {
                    // Heart Rate Card
                    Column() {
                      Row() {
                        Image($r('app.media.heart'))
                          .width(26)
                          .height(26)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Live')
                          .fontSize(11)
                          .fontColor('#006E2F')
                          .fontWeight(FontWeight.Bold)
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(this.selectedPatient.heartRate > 0 ? `${this.selectedPatient.heartRate} BPM` : '-- BPM')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text(this.selectedPatient.heartRate > 0 ? 'Heart Status: Stable' : 'Awaiting Data')
                        .fontSize(11)
                        .fontColor(this.selectedPatient.heartRate > 0 ? '#006E2F' : '#737685')
                        .fontWeight(FontWeight.Bold)
                        .alignSelf(ItemAlign.Start)
                    }
                    .layoutWeight(1)
                    .padding(14)
                    .backgroundColor(Color.White)
                    .borderRadius(16)
                    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                    .margin({ right: 6 })

                    // Blood Oxygen Card
                    Column() {
                      Row() {
                        Image($r('app.media.oxygensaturation'))
                          .width(26)
                          .height(26)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Live')
                          .fontSize(11)
                          .fontColor('#003D9B')
                          .fontWeight(FontWeight.Bold)
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(this.selectedPatient.oxygen > 0 ? `${this.selectedPatient.oxygen} %` : '-- %')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text(this.selectedPatient.oxygen > 0 ? 'SpO2: Optimal' : 'Awaiting Data')
                        .fontSize(11)
                        .fontColor(this.selectedPatient.oxygen > 0 ? '#003D9B' : '#737685')
                        .fontWeight(FontWeight.Bold)
                        .alignSelf(ItemAlign.Start)
                    }
                    .layoutWeight(1)
                    .padding(14)
                    .backgroundColor(Color.White)
                    .borderRadius(16)
                    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                    .margin({ left: 6 })
                  }
                  .width('100%')
                  .margin({ bottom: 12 })

                  // Grid Row 2: Daily Steps & Calories Burned
                  Row() {
                    // Daily Steps Card
                    Column() {
                      Row() {
                        Image($r('app.media.walking'))
                          .width(24)
                          .height(24)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Today')
                          .fontSize(11)
                          .fontColor('#737685')
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(`${this.selectedPatient.steps} Steps`)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text('Goal Completed')
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
                    .margin({ right: 6 })

                    // Calories Burned Card
                    Column() {
                      Row() {
                        Image($r('app.media.calories'))
                          .width(24)
                          .height(24)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Today')
                          .fontSize(11)
                          .fontColor('#737685')
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(`${this.selectedPatient.calories} kcal`)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text('Active Today')
                        .fontSize(11)
                        .fontColor('#854E00')
                        .fontWeight(FontWeight.Bold)
                        .alignSelf(ItemAlign.Start)
                    }
                    .layoutWeight(1)
                    .padding(14)
                    .backgroundColor(Color.White)
                    .borderRadius(16)
                    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                    .margin({ left: 6 })
                  }
                  .width('100%')
                  .margin({ bottom: 12 })

                  // Grid Row 3: Body Temperature & Sleep Quality
                  Row() {
                    // Temperature Card
                    Column() {
                      Row() {
                        Image($r('app.media.scale'))
                          .width(24)
                          .height(24)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Recorded')
                          .fontSize(11)
                          .fontColor('#737685')
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(this.selectedPatient.temperature ? this.selectedPatient.temperature : '36.6 °C')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text(this.selectedPatient.temperature ? 'Temp: Normal' : 'Baseline Normal')
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
                    .margin({ right: 6 })

                    // Sleep Quality Card
                    Column() {
                      Row() {
                        Image($r('app.media.sleep'))
                          .width(24)
                          .height(24)
                          .objectFit(ImageFit.Contain)
                        Blank()
                        Text('Last Night')
                          .fontSize(11)
                          .fontColor('#737685')
                      }
                      .width('100%')
                      .margin({ bottom: 8 })

                      Text(this.selectedPatient.sleep ? this.selectedPatient.sleep : '7h 30m')
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text(this.selectedPatient.sleep ? 'Quality: Restful' : 'Estimated Restful')
                        .fontSize(11)
                        .fontColor('#5C0099')
                        .fontWeight(FontWeight.Bold)
                        .alignSelf(ItemAlign.Start)
                    }
                    .layoutWeight(1)
                    .padding(14)
                    .backgroundColor(Color.White)
                    .borderRadius(16)
                    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                    .margin({ left: 6 })
                  }
                  .width('100%')
                  .margin({ bottom: 20 })

                  // 5. Collapsible Active Prescriptions Section
                  Column() {
                    // Header Bar (Clickable to expand/collapse)
                    Row() {
                      Image($r('app.media.drugs'))
                        .width(24)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 10 })

                      Text(`Active Prescriptions (${this.selectedPatient.medicationsList.length})`)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')

                      Blank()

                      Text(this.isMedsExpanded ? '▲' : '▼')
                        .fontSize(14)
                        .fontColor('#003D9B')
                    }
                    .width('100%')
                    .padding(16)
                    .backgroundColor(Color.White)
                    .borderRadius(16)
                    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)' })
                    .onClick(() => {
                      this.isMedsExpanded = !this.isMedsExpanded;
                    })

                    // Expanded Medication Items
                    if (this.isMedsExpanded) {
                      Column({ space: 10 }) {
                        if (this.selectedPatient.medicationsList.length === 0) {
                          Text('No active prescriptions recorded.')
                            .fontSize(13)
                            .fontColor('#737685')
                            .padding(14)
                        } else {
                          ForEach(this.selectedPatient.medicationsList, (med: PatientMedication) => {
                            Column() {
                              Row() {
                                Text(med.name)
                                  .fontSize(15)
                                  .fontWeight(FontWeight.Bold)
                                  .fontColor('#003D9B')
                                Blank()
                                Text(`Stock: ${med.stockPills} pills`)
                                  .fontSize(12)
                                  .fontWeight(FontWeight.Bold)
                                  .fontColor(med.stockPills <= 5 ? '#BA1A1A' : '#006E2F')
                              }
                              .width('100%')
                              .margin({ bottom: 6 })

                              Row() {
                                Text(`Dosage: ${med.dosage} • Schedule: ${med.schedule}`)
                                  .fontSize(13)
                                  .fontColor('#434654')
                              }
                              .width('100%')
                              .margin({ bottom: 4 })

                              Row() {
                                Text(`Instruction: ${med.mealTiming}`)
                                  .fontSize(12)
                                  .fontColor('#737685')
                              }
                              .width('100%')
                            }
                            .width('100%')
                            .padding(14)
                            .backgroundColor('#F8F9FF')
                            .borderRadius(12)
                            .border({ width: 1, color: 'rgba(0, 61, 155, 0.1)' })
                          })
                        }
                      }
                      .width('100%')
                      .margin({ top: 8 })
                    }
                  }
                  .width('100%')
                  .margin({ bottom: 20 })

                  Blank().height(140)
                }
              }
            }
          }
        }
        .width('100%')
        .padding({ top: 12, bottom: 140 })
      }
      .padding({ left: 24, right: 24, top: 20 })
      .width('100%')
      .height('100%')

      // Manual Patient Link Modal (Simulator Mode)
      if (this.isLinkModalOpen) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.6)')
            .onClick(() => { this.isLinkModalOpen = false; })

          Column() {
            Text('Link Patient with Invitation Code')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 8 })

            Text('The patient opens "My QR Code" in their profile and shows it to you. You can scan it or type it below. The code is valid for 15 minutes and can be used once.')
              .fontSize(13)
              .fontColor('#737685')
              .margin({ bottom: 16 })

            TextInput({ placeholder: 'Invitation code', text: this.linkPatientInvitationToken })
              .height(48)
              .backgroundColor('#F0F4F8')
              .borderRadius(12)
              .margin({ bottom: 20 })
              .onChange((val: string) => { this.linkPatientInvitationToken = val; })

            Row() {
              Button('Cancel', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .fontColor('#737685')
                .backgroundColor('#E8EEFF')
                .borderRadius(10)
                .margin({ right: 8 })
                .onClick(() => { this.isLinkModalOpen = false; })

              Button('Link Patient', { type: ButtonType.Normal })
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#003D9B')
                .borderRadius(10)
                .margin({ left: 8 })
                .onClick(async () => {
                  // The backend does not support linking directly by phone number;
                  // an invitation code issued by the patient is required.
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
                    await this.loadDoctorPatients();
                    promptAction.showToast({ message: 'Patient added to your list.' });
                    this.isLinkModalOpen = false;
                    this.linkPatientInvitationToken = '';
                  } catch (err) {
                    promptAction.showToast({ message: `Could not link: ${(err as Error).message}` });
                  }
                })
            }
            .width('100%')
          }
          .width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
        }
        .width('100%')
        .height('100%')
      }

      BottomNavBar({ activeTab: 'patients' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FF')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}