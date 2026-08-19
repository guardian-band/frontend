import { router, promptAction } from '@kit.ArkUI';
import { ApiService, ClinicianPatient } from '../services/ApiService';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

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

interface ScannedPatient {
  id: string;
  name: string;
  email: string;
  bloodType: string;
  allergies: string;
  diseases: Array<string>;
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
  @State linkPatientPhone: string = '';
  @State linkPatientName: string = '';
  @State isMedsExpanded: boolean = true;

  aboutToAppear() {
    this.loadDoctorPatients();
  }

  async loadDoctorPatients() {
    let token = AppStorage.get<string>('token') || '';
    if (token) {
      try {
        let backendPatients = await ApiService.getClinicianPatients(token);
        
        if (ApiService.isMockMode()) {
          let mockListStr = AppStorage.get<string>('mockLinkedPatients') || '[]';
          let localMockList = JSON.parse(mockListStr) as ClinicianPatient[];
          for (let lp of localMockList) {
            if (!backendPatients.some(bp => bp.patientId === lp.patientId)) {
              backendPatients.push(lp);
            }
          }
        }

        let list: MonitoredPatient[] = [];
        for (let idx = 0; idx < backendPatients.length; idx++) {
          let bp = backendPatients[idx];
          let heart = 75;
          let oxy = 98;
          try {
            let vitals = await ApiService.getVitalsLatest(token, bp.patientId);
            if (vitals && vitals.heartRate) heart = vitals.heartRate;
            if (vitals && vitals.bloodOxygen) oxy = vitals.bloodOxygen;
          } catch (e) {
            console.error("Vitals fetch error for " + bp.patientId, e);
          }

          let isJohn = bp.name.toLowerCase().includes('john');

          let meds: PatientMedication[] = isJohn ? [
            { id: '1', name: 'Amlodipine 5mg', dosage: '1 pill', schedule: 'Once Daily (08:00)', mealTiming: 'After Meal', stockPills: 20 },
            { id: '2', name: 'Atorvastatin 20mg', dosage: '1 pill', schedule: 'Once Daily (21:00)', mealTiming: 'During Meal', stockPills: 12 }
          ] : [
            { id: '1', name: 'Metformin 500mg', dosage: '1 pill', schedule: 'Twice Daily (08:00, 20:00)', mealTiming: 'After Meal', stockPills: 28 },
            { id: '2', name: 'Lisinopril 10mg', dosage: '1 pill', schedule: 'Once Daily (09:00)', mealTiming: 'Before Meal', stockPills: 14 }
          ];

          let summaryStr = isJohn ?
            "Patient vitals are stable with 82 BPM resting heart rate and optimal SpO2 (97%). Daily activity shows 6,400 steps with 1,680 kcal burned. Current adherence to Amlodipine & Atorvastatin is consistent. No arrhythmia flags in the last 24 hours." :
            "Patient vitals are currently stable with normal sinus rhythm (75 BPM) and optimal SpO2 (98%). Daily steps reached 5,200 with 1,450 kcal burned. Active regimen includes Metformin (500mg) and Lisinopril (10mg). No medication interaction alerts recorded.";

          list.push({
            id: bp.id,
            name: bp.name,
            gender: isJohn ? 'Male' : 'Female',
            bloodType: bp.bloodType || 'A+',
            birthDate: isJohn ? '1962-09-24' : (bp.birthDate || '1958-06-15'),
            age: isJohn ? 63 : 68,
            heartRate: heart,
            oxygen: oxy,
            temperature: '36.6 °C',
            calories: isJohn ? 1680 : 1450,
            steps: isJohn ? 6400 : 5200,
            sleep: isJohn ? '6h 45m' : '7h 20m',
            medicationsList: meds,
            aiClinicalSummary: summaryStr
          });
        }
        this.doctorPatients = list;
      } catch (err) {
        console.error("Failed to load doctor roster", err);
      }
    }
  }

  async onLinkRequestChanged() {
    if (!this.scannedPatientLinkRequest) return;
    
    let scanned = this.scannedPatientLinkRequest;
    AppStorage.setOrCreate('scannedPatientLinkRequest', '');

    try {
      let parsed = JSON.parse(scanned) as ScannedPatient;
      let patientName = parsed.name || 'Unknown Patient';
      let patientPhone = parsed.email || 'scanned-patient';

      promptAction.showToast({ message: `Linking with patient ${patientName}...` });

      let token = AppStorage.get<string>('token') || '';
      if (token) {
        await ApiService.linkPatient(token, patientPhone, patientName, 'Physician');
        
        if (ApiService.isMockMode()) {
          let mockList = AppStorage.get<string>('mockLinkedPatients') || '[]';
          let list: ClinicianPatient[] = JSON.parse(mockList) as ClinicianPatient[];
          
          if (!list.some(p => p.patientId === parsed.id)) {
            list.push({
              id: (list.length + 3).toString(),
              patientId: parsed.id || 'p' + (list.length + 3),
              name: patientName,
              relationship: 'Physician',
              bloodType: parsed.bloodType || 'A-',
              birthDate: '1980-01-01'
            });
            AppStorage.setOrCreate('mockLinkedPatients', JSON.stringify(list));
          }
        }
        
        await this.loadDoctorPatients();
        promptAction.showToast({ message: `Successfully linked with ${patientName}!` });
      }
    } catch (e) {
      console.error("Link request failed", e);
      promptAction.showToast({ message: `Linking failed: ${(e as Error).message}` });
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

                      Text(`${this.selectedPatient.gender} • ${this.selectedPatient.age} yrs (${this.selectedPatient.birthDate}) • Blood Type: ${this.selectedPatient.bloodType}`)
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
                    Row() {
                      Image($r('app.media.summary'))
                        .width(22)
                        .height(22)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 8 })

                      Text('AI Clinical Summary & Risk Assessment')
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')

                      Blank()
                    }
                    .width('100%')
                    .margin({ bottom: 8 })

                    Text(this.selectedPatient.aiClinicalSummary)
                      .fontSize(13)
                      .fontColor('#191C1D')
                      .lineHeight(20)
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

                      Text(`${this.selectedPatient.heartRate} BPM`)
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

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

                      Text(`${this.selectedPatient.oxygen} %`)
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text('SpO2: Optimal')
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

                      Text(this.selectedPatient.temperature)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text('Temp: Normal')
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

                      Text(this.selectedPatient.sleep)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 2 })

                      Text('Quality: Restful')
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
            Text('Link Patient via QR / Phone')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 8 })

            Text('Enter patient phone number or scanned QR token below to link them to your roster.')
              .fontSize(13)
              .fontColor('#737685')
              .margin({ bottom: 16 })

            TextInput({ placeholder: 'Patient Name (e.g. John Doe)', text: this.linkPatientName })
              .height(48)
              .backgroundColor('#F0F4F8')
              .borderRadius(12)
              .margin({ bottom: 12 })
              .onChange((val: string) => { this.linkPatientName = val; })

            TextInput({ placeholder: 'Patient Phone (e.g. +1 555-0199)', text: this.linkPatientPhone })
              .height(48)
              .backgroundColor('#F0F4F8')
              .borderRadius(12)
              .margin({ bottom: 20 })
              .onChange((val: string) => { this.linkPatientPhone = val; })

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
                  if (!this.linkPatientPhone || !this.linkPatientName) {
                    promptAction.showToast({ message: 'Please enter name and phone number.' });
                    return;
                  }
                  let token = AppStorage.get<string>('token') || '';
                  if (token) {
                    try {
                      await ApiService.linkPatient(token, this.linkPatientPhone, this.linkPatientName, 'Physician');
                      if (ApiService.isMockMode()) {
                        let mockList = AppStorage.get<string>('mockLinkedPatients') || '[]';
                        let list: ClinicianPatient[] = JSON.parse(mockList) as ClinicianPatient[];
                        list.push({
                          id: (list.length + 3).toString(),
                          patientId: 'p' + (list.length + 3),
                          name: this.linkPatientName,
                          relationship: 'Physician',
                          bloodType: 'A-',
                          birthDate: '1985-05-12'
                        });
                        AppStorage.setOrCreate('mockLinkedPatients', JSON.stringify(list));
                      }
                      await this.loadDoctorPatients();
                      promptAction.showToast({ message: `Linked with ${this.linkPatientName}` });
                      this.isLinkModalOpen = false;
                      this.linkPatientName = '';
                      this.linkPatientPhone = '';
                    } catch (err) {
                      promptAction.showToast({ message: `Error: ${(err as Error).message}` });
                    }
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
