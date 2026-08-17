import { router, promptAction } from '@kit.ArkUI';
import { ApiService, ClinicianPatient } from '../services/ApiService';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

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
        for (let bp of backendPatients) {
          let heart = 75;
          let oxy = 98;
          try {
            let vitals = await ApiService.getVitalsLatest(token, bp.patientId);
            if (vitals && vitals.heartRate) heart = vitals.heartRate;
            if (vitals && vitals.bloodOxygen) oxy = vitals.bloodOxygen;
          } catch (e) {
            console.error("Vitals fetch error for " + bp.patientId, e);
          }

          list.push({
            id: bp.id,
            name: bp.name,
            gender: 'Male',
            bloodType: bp.bloodType || 'N/A',
            heartRate: heart,
            oxygen: oxy,
            calories: 1450,
            sleep: '7h 15m',
            meds: 'None',
            location: 'Palo Alto • Live'
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
      Scroll() {
        Column() {
          if (!this.isInspectorOpen) {
            // --- PATIENTS ROSTER MAIN VIEW ---
            AppHeader({ title: 'My Linked Patients' })
              .margin({ bottom: 16 })

            // Linked Patients Title
            Text('My Linked Patients')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 4, bottom: 14 })

            if (this.doctorPatients.length === 0) {
              Column() {
                Text('No linked patients found.')
                  .fontSize(14)
                  .fontColor('#737685')
                  .margin({ top: 20, bottom: 20 })
              }
              .width('100%')
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
            }
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
            }
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 110 })
      }
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FF')
  }
}
