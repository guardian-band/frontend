import { router, promptAction } from '@kit.ArkUI';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';
import { SafetyAnalysisCard, AnalysisResult } from '../components/SafetyAnalysisCard';
import { cameraPicker, camera } from '@kit.CameraKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ApiService, MedicationCatalogItem, MedicationResponse, UploadedDocument, TakenResponse } from '../services/ApiService';
import { SessionStore } from '../services/SessionStore';

export interface MedicalProfile {
  gender?: string;
  birthDate?: string;
  height?: number;
  weight?: number;
  bloodType?: string;
  diseases?: string[];
  otherChronicDisease?: string;
  allergies?: string;
  pacemaker?: boolean;
  hearingAid?: boolean;
}

interface MedTime {
  slot: string; // 'Morning', 'Afternoon', 'Evening'
  specificTime: string; // e.g., '08:00' or '' (empty if optional)
  taken: boolean; // Tracks if the dose was taken today
}

interface MedicationItem {
  id: string;
  /** Backend plan id. Empty means the plan lives on this device only. */
  serverId: string;
  name: string;
  totalPills: number; // Stock-based tracking
  durationDays: number; // How many days to use
  mealTiming: string; // 'Before Meal', 'During Meal', 'After Meal', 'Any Time'
  times: Array<MedTime>;
  days: Array<string>;
}

interface DashboardMedItem {
  id: string;
  name: string;
  dosage: string;
  time: string;
  taken: boolean;
}

@Entry
@Component
struct MedsPage {
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('dashboardMeds') dashboardMeds: Array<DashboardMedItem> = [];
  private scroller: Scroller = new Scroller();
  private modalScroller: Scroller = new Scroller();

  @StorageLink('medications') medications: Array<MedicationItem> = [];
  @StorageLink('medicalProfile') medicalProfile: MedicalProfile | undefined = undefined;
  // MOCK STATE FOR AI BODY ANALYSIS
  @State currentAnalysisIndex: number = 0;
  private mockAnalyses: AnalysisResult[] = [
    {
      overallStatus: 'medium',
      message: 'Moderate risk of stomach irritation detected. Please review the details below.',
      organs: [
        { 
          organId: 'stomach', 
          riskLevel: 'low',
          culpritMeds: ['Aspirin', 'Ibuprofen'],
          detailMessage: 'Taking these two medications together can increase stomach acid and lead to mild irritation. It is strongly advised to take them after a full meal and drink plenty of water.'
        }
      ]
    }
  ];
  @State currentAnalysis: AnalysisResult = this.mockAnalyses[0];

  aboutToAppear() {
    if (this.userRole !== 'patient') {
      promptAction.showToast({ message: 'Access Denied: Only patients have access to the Meds page.' });
      router.replaceUrl({ url: 'pages/HomePage' });
      return;
    }
    this.loadMedicationCatalog();
    this.loadServerMedications();
  }

  /** GET /api/medication-catalog - the catalog used to be a hard-coded array. */
  async loadMedicationCatalog(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const items: MedicationCatalogItem[] = await ApiService.getMedicationCatalog();
      if (items.length > 0) {
        this.catalogItems = items;
        this.allMeds = items.map((i: MedicationCatalogItem) =>
          i.strength && i.strength.length > 0 ? `${i.name} ${i.strength}` : i.name);
        this.selectedMedName = this.allMeds[0];
        console.info(`[API] GET /api/medication-catalog - OK, ${items.length} entries`);
      }
    } catch (err) {
      // If the catalog fails, fall back to the local list so the screen still works.
      console.warn(`[API] GET /api/medication-catalog - failed: ${(err as Error).message}`);
    }
  }

  /** GET /api/medications - mirrors server plans into the local list. */
  async loadServerMedications(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const plans: MedicationResponse[] = await ApiService.getMedications();
      console.info(`[API] GET /api/medications - OK, ${plans.length} plan`);
      for (const plan of plans) {
        const existing = this.medications.find((m: MedicationItem) => m.serverId === plan.id);
        if (existing === undefined) {
          this.medications.push({
            id: plan.id,
            serverId: plan.id,
            name: plan.strength && plan.strength.length > 0 ? `${plan.name} ${plan.strength}` : plan.name,
            totalPills: 0,
            durationDays: 0,
            mealTiming: plan.instructions || 'Any Time',
            times: this.slotsFromFrequency(plan.frequencyHours),
            days: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
          });
        }
      }
      this.medications = [...this.medications];
    } catch (err) {
      console.warn(`[API] GET /api/medications - failed: ${(err as Error).message}`);
    }
  }

  /** Maps the backend frequencyHours value onto the UI meal slots. */
  private slotsFromFrequency(frequencyHours: number): Array<MedTime> {
    if (frequencyHours === 24) {
      return [{ slot: 'Morning', specificTime: '', taken: false }];
    }
    if (frequencyHours === 12) {
      return [
        { slot: 'Morning', specificTime: '', taken: false },
        { slot: 'Evening', specificTime: '', taken: false }
      ];
    }
    return [
      { slot: 'Morning', specificTime: '', taken: false },
      { slot: 'Afternoon', specificTime: '', taken: false },
      { slot: 'Evening', specificTime: '', taken: false }
    ];
  }

  /**
   * Maps the UI meal slots onto the backend frequencyHours value.
   *
   * CAREFUL - known model mismatch (BLG-007):
   * The backend accepts only 6, 12 or 24 hours. Once a day -> 24 and twice a day
   * -> 12 are correct. Three times a day is ~8 hours, which is NOT in the
   * backend's set. Rounding it to 6 would mean four doses a day - a dosing
   * error - so it is deliberately not done; the plan is kept on the device only
   * and the user is warned.
   *
   * @returns the hour value when it can be mapped, otherwise 0
   */
  private frequencyFromSlots(slotCount: number): number {
    if (slotCount === 1) {
      return 24;
    }
    if (slotCount === 2) {
      return 12;
    }
    return 0;
  }

  // Modal and Search States
  @State isModalOpen: boolean = false;
  @State searchQuery: string = '';
  @State isDropdownOpen: boolean = false;
  // The catalog comes from the backend; this list is the offline fallback.
  @State allMeds: Array<string> = ['Benical Cold', 'Flagyl 500 mg', 'Apranax Forte', 'Piyeloseptyl'];
  @State catalogItems: MedicationCatalogItem[] = [];
  @State lastPrescriptionDocId: string = '';
  @State selectedMedName: string = 'Benical Cold';

  // Duration State (Days)
  @State durationDays: number = 7;

  // Stock-based Tracking State (Total Pills)
  @State totalPills: number = 20;

  // Meal Timing State (before / after eating)
  @State mealTiming: string = 'Any Time';
  private mealOptions: Array<string> = ['Before Meal', 'During Meal', 'After Meal', 'Any Time'];
  @State medWarning: string = '';

  // Day Selection States (M, T, W, T, F, S, S)
  private weekDays: Array<string> = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  @State selectedDays: boolean[] = [true, true, true, true, true, true, true];

  // Optional Time States
  @State isMorningSelected: boolean = false;
  @State isAfternoonSelected: boolean = false;
  @State isEveningSelected: boolean = false;
  @State morningTime: string = '';
  @State afternoonTime: string = '';
  @State eveningTime: string = '';

  // Restricted Time Data for Picker
  private morningHours: string[] = ['06', '07', '08', '09', '10', '11'];
  private afternoonHours: string[] = ['12', '13', '14', '15', '16', '17'];
  private eveningHours: string[] = ['18', '19', '20', '21', '22', '23'];
  private minutesList: string[] = ['00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55'];

  // Custom Time Picker Dialog
  showCustomTimePicker(slot: 'morning' | 'afternoon' | 'evening') {
    let hours = slot === 'morning' ? this.morningHours : slot === 'afternoon' ? this.afternoonHours : this.eveningHours;

    TextPickerDialog.show({
      range: [hours, this.minutesList],
      selected: [0, 0],
      onAccept: (value: TextPickerResult) => {
        if (Array.isArray(value.value) && value.value.length === 2) {
          const formattedTime = `${value.value[0]}:${value.value[1]}`;
          if (slot === 'morning') {
            this.morningTime = formattedTime;
            this.isMorningSelected = true;
          } else if (slot === 'afternoon') {
            this.afternoonTime = formattedTime;
            this.isAfternoonSelected = true;
          } else {
            this.eveningTime = formattedTime;
            this.isEveningSelected = true;
          }
        }
      }
    });
  }

  /**
   * Medication deletion.
   *
   * PLATFORM LIMITATION - there is no `DELETE /api/medications/{id}` on the
   * backend yet (see BACKEND_REQUESTS.md #2). For a plan that is synced to the
   * server (`serverId` set), removing it only from this local list used to look
   * like it worked - until `loadServerMedications()` re-fetched `GET
   * /api/medications` on the next visit and added it right back, because the
   * server still has it as `active`. Worse: the plan would also keep showing up
   * as an active medication on the Emergency Medical Card, even though the
   * patient believed it was removed - a real safety mismatch, not just a UI
   * glitch. So a synced plan is left alone until the backend adds real
   * deletion; only device-only plans (BLG-007: 3-doses-a-day plans that never
   * reached the server) can be removed today.
   */
  deleteMedication(id: string) {
    const target = this.medications.find(med => med.id === id);
    if (target !== undefined && target.serverId.length > 0) {
      promptAction.showToast({
        message: 'Deleting a saved medication is not supported by the server yet. This has been reported to the backend team.'
      });
      return;
    }
    this.medications = this.medications.filter(med => med.id !== id);
    this.dashboardMeds = this.dashboardMeds.filter(med => !med.id.startsWith(id));
    promptAction.showToast({ message: 'Medication removed successfully' });
  }

  // Toggle dose taken status and update stock
  toggleDoseTaken(medId: string, slot: string) {
    const medIndex = this.medications.findIndex(m => m.id === medId);
    if (medIndex !== -1) {
      const timeIndex = this.medications[medIndex].times.findIndex(t => t.slot === slot);
      if (timeIndex !== -1) {
        const isCurrentlyTaken = this.medications[medIndex].times[timeIndex].taken;

        // Toggle the taken status
        this.medications[medIndex].times[timeIndex].taken = !isCurrentlyTaken;

        // Also update dashboardMeds in AppStorage
        const dashIndex = this.dashboardMeds.findIndex(m => m.id === `${medId}_${slot}`);
        if (dashIndex !== -1) {
          this.dashboardMeds[dashIndex].taken = !isCurrentlyTaken;
          this.dashboardMeds = [...this.dashboardMeds];
        }

        // Adjust stock automatically
        if (!isCurrentlyTaken) {
          this.medications[medIndex].totalPills = Math.max(0, this.medications[medIndex].totalPills - 1);
        } else {
          this.medications[medIndex].totalPills += 1;
        }

        // Force UI update by splicing the array
        this.medications.splice(medIndex, 1, this.medications[medIndex]);

        if (!isCurrentlyTaken) {
          // POST /api/medications/{id}/taken — dozu sunucuya da bildir.
          const serverId: string = this.medications[medIndex].serverId;
          if (serverId.length > 0 && SessionStore.isAuthenticated()) {
            ApiService.takeMedicationDose(serverId)
              .then((taken: TakenResponse) => {
                console.info(`[API] POST /api/medications/${serverId}/taken - OK, next: ${taken.nextScheduledFor}`);
                promptAction.showToast({ message: 'Dose recorded and synced with the server.' });
              })
              .catch((err: Error) => {
                console.error(`[API] Doz kaydedilemedi: ${err.message}`);
                promptAction.showToast({ message: `Could not record the dose on the server: ${err.message}` });
              });
          } else {
            promptAction.showToast({ message: 'Marked as taken. Stock updated.' });
          }
        }
      }
    }
  }

  // Real OCR Camera Scanning Function using Vision Kit
  async performRealOCRScan() {
    const context = getContext(this) as common.UIAbilityContext;

    try {
      promptAction.showToast({ message: 'Opening camera...' });

      // Launch Camera Picker and take a photo
      let pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };

      let pickerResult = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);

      if (pickerResult && pickerResult.resultUri) {
        promptAction.showToast({ message: 'Processing label, please wait...' });

        // Archive the prescription photo. The returned document id is no longer
        // discarded: it is attached to the new plan as prescriptionDocumentId.
        if (SessionStore.isAuthenticated()) {
          ApiService.uploadDocument(
            pickerResult.resultUri,
            'prescription',
            'Scanned Prescription - ' + new Date().toLocaleTimeString()
          )
            .then((doc: UploadedDocument) => {
              this.lastPrescriptionDocId = doc.id;
              console.info(`[API] POST /api/documents - OK id=${doc.id}`);
            })
            .catch((err: Error) => {
              // Do not swallow this: the user must know the prescription was not archived.
              console.error(`[API] POST /api/documents - FAILED: ${err.message}`);
              promptAction.showToast({ message: `Could not upload prescription: ${err.message}` });
            });
        }

        // Read the image and convert it to a PixelMap
        let file = fileIo.openSync(pickerResult.resultUri, fileIo.OpenMode.READ_ONLY);
        let imageSource = image.createImageSource(file.fd);
        let pixelMap = await imageSource.createPixelMap();

        // Recognize text using Core Vision Kit
        let visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
        let textResult = await textRecognition.recognizeText(visionInfo);

        // Extract and parse the recognized text
        let extractedText = textResult.value;
        this.parsePharmacyLabel(extractedText);

        fileIo.closeSync(file);
      }
    } catch (error) {
      console.error('OCR Error:', error);
      promptAction.showToast({ message: 'Scan failed or cancelled.' });
    }
  }

  // Calculates the difference in days between two date strings (Format: DD.MM.YYYY)
  calculateDurationFromDates(startDateStr: string, endDateStr: string): number {
    const startParts = startDateStr.split('.');
    const endParts = endDateStr.split('.');

    // Ensure we have exactly 3 parts (Day, Month, Year)
    if (startParts.length !== 3 || endParts.length !== 3) return 7;

    const startDate = new Date(`${startParts[2]}-${startParts[1]}-${startParts[0]}`);
    const endDate = new Date(`${endParts[2]}-${endParts[1]}-${endParts[0]}`);

    const diffInMs = endDate.getTime() - startDate.getTime();
    const diffInDays = Math.ceil(diffInMs / (1000 * 60 * 60 * 24));

    return diffInDays > 0 ? diffInDays : 7;
  }

  // Parses the raw text extracted from the OCR Vision Kit
  // NOTE: the keywords below are intentionally Turkish. They match text printed
  // on Turkish pharmacy labels, so they are OCR input data - not UI copy.
  // Translating them would break label recognition.
  parsePharmacyLabel(rawText: string) {
    const upperText = rawText.toLocaleUpperCase('tr-TR');

    // 1. Parse Meal Timing
    if (upperText.includes('AÇ VEYA TOK')) {
      this.mealTiming = 'Any Time';
    } else if (upperText.includes('YEMEĞİN ORTASINDA') || upperText.includes('YEMEKLE BERABER')) {
      this.mealTiming = 'During Meal';
    } else if (upperText.includes('TOK') || upperText.includes('YEMEKTEN SONRA')) {
      this.mealTiming = 'After Meal';
    } else if (upperText.includes('AÇ')) {
      this.mealTiming = 'Before Meal';
    }

    // 2. Parse Schedule
    if (upperText.includes('SABAH')) {
      this.isMorningSelected = true;
    }
    if (upperText.includes('ÖĞLE')) {
      this.isAfternoonSelected = true;
    }
    if (upperText.includes('AKŞAM')) {
      this.isEveningSelected = true;
    }

    // 3. Parse Strict Intervals (Optional)
    if (upperText.includes('12 SAAT ARA İLE')) {
      this.morningTime = '08:00';
      this.eveningTime = '20:00';
    }

    // 4. Parse Warnings
    const warningMatch = upperText.match(/UYARI\s*[:;-]?\s*(.*)/);

    if (warningMatch && warningMatch[1]) {
      this.medWarning = warningMatch[1].trim();

      promptAction.showDialog({
        title: '⚠️ Medication Warning',
        message: this.medWarning,
        buttons: [
          {
            text: 'I Understand',
            color: '#BA1A1A'
          }
        ]
      });
    }

    // 5. Parse Dates to Calculate Duration (DD.MM.YYYY)
    const datePattern = /(\d{2}\.\d{2}\.\d{4})/g;
    const foundDates = upperText.match(datePattern);

    if (foundDates && foundDates.length >= 2) {
      // If both Start and End dates are found
      const startDate = foundDates[0];
      const endDate = foundDates[1];
      this.durationDays = this.calculateDurationFromDates(startDate, endDate);
    } else if (foundDates && foundDates.length === 1) {
      // If only one date is found (assuming it's the end date)
      const today = new Date();
      const dd = String(today.getDate()).padStart(2, '0');
      const mm = String(today.getMonth() + 1).padStart(2, '0'); // January is 0!
      const yyyy = today.getFullYear();
      const todayStr = `${dd}.${mm}.${yyyy}`;

      const endDate = foundDates[0];
      this.durationDays = this.calculateDurationFromDates(todayStr, endDate);
    }

    promptAction.showToast({ message: 'Label scanned and applied successfully!' });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F8F9FB')

      // Main Content Container
      Column() {
        AppHeader({ title: 'Medication Schedule' })
          .margin({ bottom: 12 })

        // --------------------------------

        Scroll(this.scroller) {
          Column() {
            // Empty State
            if (this.medications.length === 0) {
              Column() {
                Text('No medications added yet.')
                  .fontSize(15)
                  .fontColor('#8F92A1')
              }
              .width('100%')
              .height(250)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .border({ width: 1, color: '#EBECEF' })
              .margin({ bottom: 12 })
            } else {
              // Medication List
              Column() {
                ForEach(this.medications, (item: MedicationItem) => {
                  Column() {
                    Row() {
                      Column() {
                        Text(item.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1A1C21')

                        // Display Duration and Meal Timing
                        Text(`Duration: ${item.durationDays} Days • ${item.mealTiming}`)
                          .fontSize(13)
                          .fontColor('#8F92A1')
                          .margin({ top: 4 })

                        // Display Stock Remaining
                        Text(`Stock: ${item.totalPills} pills remaining`)
                          .fontSize(12)
                          .fontColor(item.totalPills <= 5 ? '#BA1A1A' : '#006E2F')
                          .margin({ top: 4 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      // Delete Button
                      Image($r('app.media.cancel'))
                        .width(24)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .margin({ left: 8 })
                        .onClick(() => {
                          this.deleteMedication(item.id);
                        })
                    }
                    .width('100%')
                    .margin({ bottom: 12 })

                    // Days Badges
                    Row() {
                      Text('Days: ')
                        .fontSize(12)
                        .fontColor('#8F92A1')
                      Text(item.days.length === 7 ? 'Every Day' : item.days.join(', '))
                        .fontSize(12)
                        .fontColor('#1A1C21')
                        .fontWeight(FontWeight.Medium)
                    }
                    .width('100%')
                    .margin({ bottom: 12 })

                    // Interactive Time Badges (Tick to mark as taken)
                    Row() {
                      ForEach(item.times, (timeObj: MedTime) => {
                        Row() {
                          Image(timeObj.taken ? $r('app.media.check') : $r('app.media.hourglass'))
                            .width(14)
                            .height(14)
                            .margin({ right: 4 })

                          Text(`${timeObj.slot}${timeObj.specificTime ? ' (' + timeObj.specificTime + ')' : ''}`)
                            .fontSize(12)
                            .fontColor(timeObj.taken ? '#006E2F' : '#003D9B')
                            .decoration({ type: timeObj.taken ? TextDecorationType.LineThrough : TextDecorationType.None })
                        }
                        .backgroundColor(timeObj.taken ? '#E6F9ED' : '#F0F4FF')
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .borderRadius(8)
                        .margin({ right: 8 })
                        .onClick(() => {
                          this.toggleDoseTaken(item.id, timeObj.slot);
                        })
                      })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor(Color.White)
                  .borderRadius(16)
                  .border({ width: 1, color: '#EBECEF' })
                  .margin({ bottom: 12 })
                })
              }
              .width('100%')
            }

            // --- Safety (Side Effect Analysis) Section (Now positioned below Medication List) ---
            SafetyAnalysisCard({ 
              analysisResult: this.currentAnalysis, 
              userGender: (this.medicalProfile?.gender || 'Female').toLowerCase() 
            })
              .margin({ left: 12, right: 12, top: 4, bottom: 12 })

            Blank().height(120)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 20 })

      // Floating Action Button (+)
      Button() {
        Text('+')
          .fontSize(50)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width(60)
      .height(60)
      .backgroundColor('#003D9B')
      .borderRadius(28)
      .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetY: 4 })
      .position({ x: '78%', y: '78%' })
      .zIndex(2)
      .onClick(() => {
        this.isModalOpen = true;
      })

      // MODAL OVERLAY
      if (this.isModalOpen) {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.isModalOpen = false;
              this.isDropdownOpen = false;
            })

          Column() {
            Scroll(this.modalScroller) {
              Column() {
                Row() {
                  Text('Add Medication')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1C21')

                  Blank()

                  // Real Camera / OCR Scan Button
                  Button({ type: ButtonType.Normal }) {
                    Row() {
                      Image($r('app.media.camera'))
                        .width(18)
                        .height(18)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })

                      Text('Scan Label')
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }
                  }
                  .backgroundColor('#E8EEFF')
                  .height(36)
                  .padding({ left: 14, right: 14 })
                  .borderRadius(18)
                  .border({ width: 1, color: 'rgba(0, 61, 155, 0.3)', style: BorderStyle.Solid, radius: 18 })
                  .onClick(() => {
                    this.performRealOCRScan();
                  })
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 1. Medication Search
                Text('Medication Name')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                  .margin({ bottom: 6 })
                  .alignSelf(ItemAlign.Start)

                Stack({ alignContent: Alignment.TopStart }) {
                  // Custom Dropdown Trigger (Row + Text instead of TextInput to prevent keyboard opening)
                  Row() {
                    Text(this.searchQuery || 'Select medication...')
                      .fontSize(14)
                      .fontColor(this.searchQuery ? '#1A1C21' : 'rgba(115, 118, 133, 0.5)')
                      .layoutWeight(1)

                    Text('▼')
                      .fontSize(10)
                      .fontColor('#737685')
                  }
                  .height(44)
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(Color.White)
                  .border({ width: 1, color: '#EBECEF', style: BorderStyle.Solid })
                  .borderRadius(8)
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => {
                    this.isDropdownOpen = !this.isDropdownOpen;
                  })

                  if (this.isDropdownOpen) {
                    Column() {
                      List() {
                        ForEach(
                          this.allMeds,
                          (filteredMed: string) => {
                            ListItem() {
                              Text(filteredMed)
                                .fontSize(14)
                                .fontColor('#1A1C21')
                                .width('100%')
                                .padding(12)
                                .backgroundColor(this.selectedMedName === filteredMed ? '#F8F9FB' : Color.Transparent)
                            }
                            .onClick(() => {
                              this.selectedMedName = filteredMed;
                              this.searchQuery = filteredMed;
                              this.isDropdownOpen = false;
                            })
                          }
                        )
                      }
                      .width('100%')
                      .height(110)
                    }
                    .width('100%')
                    .backgroundColor(Color.White)
                    .borderRadius(8)
                    .border({ width: 1, color: '#EBECEF' })
                    .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
                    .margin({ top: 48 })
                    .zIndex(5)
                  }
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 2. Duration (Days to Use)
                Text('Duration (Days)')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                  .margin({ bottom: 6 })
                  .alignSelf(ItemAlign.Start)

                Row() {
                  // - Button
                  Text('−')
                    .width(40)
                    .height(40)
                    .backgroundColor('#E8EEFF')
                    .fontColor('#003D9B')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)
                    .onClick(() => { if (this.durationDays > 1) this.durationDays--; })

                  Text(`${this.durationDays} Days`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1C21')
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)

                  // + Button
                  Text('+')
                    .width(40)
                    .height(40)
                    .backgroundColor('#E8EEFF')
                    .fontColor('#003D9B')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)
                    .onClick(() => { this.durationDays++; })
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 3. Stock Tracking (Total Pills in Box)
                Text('Total Pills in Box (Stock)')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                  .margin({ bottom: 6 })
                  .alignSelf(ItemAlign.Start)

                Row() {
                  // - Button
                  Text('−')
                    .width(40)
                    .height(40)
                    .backgroundColor('#E8EEFF')
                    .fontColor('#003D9B')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)
                    .onClick(() => { if (this.totalPills > 1) this.totalPills--; })

                  Text(`${this.totalPills} Pills`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1C21')
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)

                  // + Button
                  Text('+')
                    .width(40)
                    .height(40)
                    .backgroundColor('#E8EEFF')
                    .fontColor('#003D9B')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)
                    .onClick(() => { this.totalPills++; })
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 4. Meal Timing (before / after eating)
                Text('Meal Timing')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                  .margin({ bottom: 6 })
                  .alignSelf(ItemAlign.Start)

                Row() {
                  ForEach(this.mealOptions, (option: string) => {
                    Text(option)
                      .layoutWeight(1)
                      .height(36)
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .textAlign(TextAlign.Center)
                      .fontColor(this.mealTiming === option ? Color.White : '#1A1C21')
                      .backgroundColor(this.mealTiming === option ? '#003D9B' : '#F8F9FB')
                      .borderRadius(8)
                      .margin({ right: 4, left: 4 })
                      .onClick(() => {
                        this.mealTiming = option;
                      })
                  })
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 5. Days Selection
                Row() {
                  Text('Select Days')
                    .fontSize(13)
                    .fontColor('#8F92A1')
                  Blank()
                  Text(this.selectedDays.includes(false) ? 'Select All' : 'Clear')
                    .fontSize(12)
                    .fontColor('#003D9B')
                    .onClick(() => {
                      const hasFalse = this.selectedDays.includes(false);
                      this.selectedDays = [hasFalse, hasFalse, hasFalse, hasFalse, hasFalse, hasFalse, hasFalse];
                    })
                }
                .width('100%')
                .margin({ bottom: 12 })

                Row() {
                  ForEach(this.weekDays, (day: string, index: number) => {
                    Text(day)
                      .width(32)
                      .height(32)
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.selectedDays[index] ? Color.White : '#8F92A1')
                      .backgroundColor(this.selectedDays[index] ? '#003D9B' : '#F8F9FB')
                      .borderRadius(16)
                      .textAlign(TextAlign.Center)
                      .border({ width: 1, color: this.selectedDays[index] ? '#003D9B' : '#EBECEF' })
                      .onClick(() => {
                        let temp = [...this.selectedDays];
                        temp[index] = !temp[index];
                        this.selectedDays = temp;
                      })
                  })
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ bottom: 24 })

                // 6. Flexible Schedule Selection
                Text('Schedule (Time is Optional)')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)

                Column() {
                  // Morning Flexible Option
                  Row() {
                    Checkbox()
                      .select(this.isMorningSelected)
                      .selectedColor('#003D9B')
                      .onChange((value: boolean) => { this.isMorningSelected = value; })
                    Text('Morning')
                      .fontSize(14)
                      .fontColor('#1A1C21')
                      .margin({ left: 8 })

                    Blank()

                    if (this.isMorningSelected) {
                      Button(this.morningTime ? this.morningTime : 'Set specific time')
                        .fontSize(12)
                        .backgroundColor(this.morningTime ? '#F0F4FF' : '#F8F9FB')
                        .fontColor(this.morningTime ? '#003D9B' : '#8F92A1')
                        .height(30)
                        .onClick(() => { this.showCustomTimePicker('morning'); })
                    }
                  }
                  .width('100%')
                  .height(44)

                  // Afternoon Flexible Option
                  Row() {
                    Checkbox()
                      .select(this.isAfternoonSelected)
                      .selectedColor('#003D9B')
                      .onChange((value: boolean) => { this.isAfternoonSelected = value; })
                    Text('Afternoon')
                      .fontSize(14)
                      .fontColor('#1A1C21')
                      .margin({ left: 8 })

                    Blank()

                    if (this.isAfternoonSelected) {
                      Button(this.afternoonTime ? this.afternoonTime : 'Set specific time')
                        .fontSize(12)
                        .backgroundColor(this.afternoonTime ? '#F0F4FF' : '#F8F9FB')
                        .fontColor(this.afternoonTime ? '#003D9B' : '#8F92A1')
                        .height(30)
                        .onClick(() => { this.showCustomTimePicker('afternoon'); })
                    }
                  }
                  .width('100%')
                  .height(44)

                  // Evening Flexible Option
                  Row() {
                    Checkbox()
                      .select(this.isEveningSelected)
                      .selectedColor('#003D9B')
                      .onChange((value: boolean) => { this.isEveningSelected = value; })
                    Text('Evening')
                      .fontSize(14)
                      .fontColor('#1A1C21')
                      .margin({ left: 8 })

                    Blank()

                    if (this.isEveningSelected) {
                      Button(this.eveningTime ? this.eveningTime : 'Set specific time')
                        .fontSize(12)
                        .backgroundColor(this.eveningTime ? '#F0F4FF' : '#F8F9FB')
                        .fontColor(this.eveningTime ? '#003D9B' : '#8F92A1')
                        .height(30)
                        .onClick(() => { this.showCustomTimePicker('evening'); })
                    }
                  }
                  .width('100%')
                  .height(44)
                }
                .width('100%')
                .margin({ bottom: 20 })

                // 7. Actions
                Row() {
                  Button('Cancel', { type: ButtonType.Normal })
                    .layoutWeight(1)
                    .height(44)
                    .backgroundColor(Color.Transparent)
                    .fontColor('#003D9B')
                    .border({ width: 1, color: '#003D9B', radius: 8 })
                    .borderRadius(8)
                    .margin({ right: 12 })
                    .onClick(() => {
                      this.isModalOpen = false;
                    })

                  Button('Save', { type: ButtonType.Normal })
                    .layoutWeight(1)
                    .height(44)
                    .backgroundColor('#003D9B')
                    .fontColor(Color.White)
                    .borderRadius(8)
                    .onClick(() => {
                      let chosenTimes: Array<MedTime> = [];

                      if (this.isMorningSelected) {
                        chosenTimes.push({ slot: 'Morning', specificTime: this.morningTime, taken: false });
                      }
                      if (this.isAfternoonSelected) {
                        chosenTimes.push({ slot: 'Afternoon', specificTime: this.afternoonTime, taken: false });
                      }
                      if (this.isEveningSelected) {
                        chosenTimes.push({ slot: 'Evening', specificTime: this.eveningTime, taken: false });
                      }

                      if (chosenTimes.length === 0) {
                        promptAction.showToast({ message: 'Please select at least one time slot' });
                        return;
                      }

                      if (!this.selectedDays.includes(true)) {
                        promptAction.showToast({ message: 'Please select at least one day' });
                        return;
                      }

                      let activeDays = this.weekDays.filter((day, index) => this.selectedDays[index]);
                      let baseId = Date.now().toString();

                      const newItem: MedicationItem = {
                        id: baseId,
                        serverId: '',
                        name: this.selectedMedName,
                        durationDays: this.durationDays,
                        totalPills: this.totalPills,
                        mealTiming: this.mealTiming,
                        times: chosenTimes,
                        days: activeDays
                      };
                      this.medications.push(newItem);

                      // POST /api/medications - also write the plan to the backend.
                      const frequencyHours: number = this.frequencyFromSlots(chosenTimes.length);
                      if (frequencyHours === 0) {
                        // Deliberate: three doses a day cannot be mapped safely onto
                        // the backend's {6,12,24} set. See BLG-007.
                        promptAction.showToast({
                          message: 'Three doses per day is not supported by the server yet; the plan was saved on this device only.'
                        });
                      } else if (SessionStore.isAuthenticated()) {
                        const catalogEntry = this.catalogItems.find((c: MedicationCatalogItem) =>
                          this.selectedMedName.startsWith(c.name));
                        ApiService.createMedicationPlan({
                          name: catalogEntry !== undefined ? catalogEntry.name : this.selectedMedName,
                          strength: catalogEntry !== undefined ? catalogEntry.strength : '',
                          instructions: this.mealTiming,
                          frequencyHours: frequencyHours,
                          prescriptionDocumentId: this.lastPrescriptionDocId.length > 0
                            ? this.lastPrescriptionDocId : undefined
                        })
                          .then((created: MedicationResponse) => {
                            newItem.serverId = created.id;
                            this.medications = [...this.medications];
                            this.lastPrescriptionDocId = '';
                            console.info(`[API] POST /api/medications - OK id=${created.id}`);
                          })
                          .catch((err: Error) => {
                            console.error(`[API] POST /api/medications - FAILED: ${err.message}`);
                            promptAction.showToast({ message: `Could not save the plan to the server: ${err.message}` });
                          });
                      }

                      // Add to dashboardMeds (AppStorage) for Patient Dashboard
                      chosenTimes.forEach((time) => {
                        this.dashboardMeds.push({
                          id: `${baseId}_${time.slot}`,
                          name: this.selectedMedName,
                          dosage: `1 Pill • ${this.mealTiming}`,
                          time: time.specificTime ? time.specificTime : time.slot,
                          taken: false
                        });
                      });
                      this.dashboardMeds = [...this.dashboardMeds];

                      // Reset fields
                      this.isMorningSelected = false;
                      this.isAfternoonSelected = false;
                      this.isEveningSelected = false;
                      this.morningTime = '';
                      this.afternoonTime = '';
                      this.eveningTime = '';
                      this.searchQuery = '';
                      this.isDropdownOpen = false;
                      this.isModalOpen = false;
                      this.selectedDays = [true, true, true, true, true, true, true];
                      this.totalPills = 20;
                      this.durationDays = 7;
                      this.mealTiming = 'Any Time';

                      promptAction.showToast({ message: 'Medication added successfully!' });
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(24)
            }
            .scrollBar(BarState.Off)
            .width('92%')
            .height('85%')
            .backgroundColor(Color.White)
            .borderRadius(24)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .zIndex(10)
      }

      BottomNavBar({ activeTab: 'meds' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}