import { router, promptAction } from '@kit.ArkUI';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';
import { SafetyAnalysisCard, AnalysisResult } from '../components/SafetyAnalysisCard';
import { cameraPicker, camera } from '@kit.CameraKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ApiService, ApiError, UnsupportedMedicationsError, MedicationCatalogItem, MedicationResponse,
  UploadedDocument, TakenResponse, MedicationRiskAnalysis, CreateMedicationRequest,
  DocumentCatalog, MedicationIngredient, UnsupportedMedication } from '../services/ApiService';
import { SessionStore } from '../services/SessionStore';
import { RiskAnalysis } from '../services/RiskAnalysis';
import { CoachMarkOverlay } from '../components/CoachMarkOverlay';
import { TutorialManager } from '../utils/TutorialManager';

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
  /**
   * Catalog entry this plan was created from. Empty for a free-text plan.
   * Only plans WITH one can take part in the interaction analysis: the backend
   * reaches a plan's ingredients through this id, and a plan without it makes
   * the analysis answer 422.
   */
  catalogItemId: string;
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

  @StorageLink('isTutorialActive') isTutorialActive: boolean = false;
  @StorageLink('currentTutorialStep') currentTutorialStep: number = 0;

  // --- AI interaction analysis (POST /api/medication-risk-analyses) ----------
  // This card used to render a hard-coded example: a fixed "Aspirin + Ibuprofen
  // irritates the stomach" card that appeared no matter which medications the
  // patient actually took. It now shows what the model returns for THIS
  // patient's own plans.
  @State currentAnalysis: AnalysisResult = {
    overallStatus: 'safe',
    message: 'Add at least two medications to see an interaction analysis.',
    organs: []
  };
  @State isAnalysing: boolean = false;
  /**
   * Why there is no analysis to show, when there is none. Kept separate from
   * `currentAnalysis.message` so an error is never dressed up as a result -
   * "no risk found" and "could not be analysed" must not look the same on a
   * medical screen.
   */
  @State analysisNotice: string = '';

  aboutToAppear() {
    if (this.userRole !== 'patient') {
      promptAction.showToast({ message: 'Access Denied: Only patients have access to the Meds page.' });
      router.replaceUrl({ url: 'pages/HomePage' });
      return;
    }
    this.loadMedicationCatalog();
    this.loadServerMedications().then(() => this.runRiskAnalysis());
  }

  /** GET /api/documents - the patient's archived prescriptions and reports. */
  async loadDocuments(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      this.documents = await ApiService.getDocuments();
      this.documentsLoaded = true;
      console.info(`[API] GET /api/documents - OK, ${this.documents.length} documents`);
    } catch (err) {
      this.documentsLoaded = true;
      console.warn(`[API] GET /api/documents - failed: ${(err as Error).message}`);
      promptAction.showToast({ message: `Documents could not be loaded: ${(err as Error).message}` });
    }
  }

  /**
   * Downloads a document and opens the preview.
   *
   * The content endpoint needs the bearer token, so the file cannot be handed
   * to a viewer as a URL: it is fetched into the app's cache directory first
   * and shown from there.
   */
  async openDocument(doc: DocumentCatalog): Promise<void> {
    if (this.isDownloading) {
      return;
    }
    this.isDownloading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const fileName: string = `${doc.id}${this.extensionFor(doc.contentType)}`;
      this.previewPath = await ApiService.downloadDocumentContent(doc.id, context.cacheDir, fileName);
      this.previewTitle = doc.title;
      this.previewContentType = doc.contentType;
      this.isPreviewOpen = true;
      console.info(`[API] GET /api/documents/${doc.id}/content - OK -> ${this.previewPath}`);
    } catch (err) {
      console.error(`[API] GET /api/documents/${doc.id}/content - FAILED: ${(err as Error).message}`);
      promptAction.showToast({ message: `Document could not be opened: ${(err as Error).message}` });
    } finally {
      this.isDownloading = false;
    }
  }

  /** PUT /api/documents/{id}/content - re-photograph a document in place. */
  async replaceDocument(doc: DocumentCatalog): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      const pickerResult = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);
      if (!pickerResult || !pickerResult.resultUri) {
        return;
      }
      await ApiService.updateDocumentContent(doc.id, pickerResult.resultUri);
      promptAction.showToast({ message: 'Document updated.' });
      // The catalog row carries updatedAt/currentVersionId, both of which just
      // changed on the server.
      await this.loadDocuments();
      console.info(`[API] PUT /api/documents/${doc.id}/content - OK`);
    } catch (err) {
      console.error(`[API] PUT /api/documents/${doc.id}/content - FAILED: ${(err as Error).message}`);
      promptAction.showToast({ message: `Document could not be updated: ${(err as Error).message}` });
    }
  }

  private extensionFor(contentType: string): string {
    if (contentType.includes('pdf')) {
      return '.pdf';
    }
    if (contentType.includes('png')) {
      return '.png';
    }
    return '.jpg';
  }

  private isPreviewImage(): boolean {
    return this.previewContentType.includes('image');
  }

  /** Catalog entry behind a display name ("Parol 500mg"). */
  private findCatalogEntry(displayName: string): MedicationCatalogItem | undefined {
    const exact: MedicationCatalogItem | undefined = this.catalogItems.find((c: MedicationCatalogItem) =>
      (c.strength && c.strength.length > 0 ? `${c.name} ${c.strength}` : c.name) === displayName);
    if (exact !== undefined) {
      return exact;
    }
    return this.catalogItems.find((c: MedicationCatalogItem) => displayName.startsWith(c.name));
  }

  /**
   * Is this plan something the interaction model can actually reason about?
   *
   * Two things have to hold: the plan is linked to a catalog entry, and that
   * entry has at least one ingredient the model was trained on. The second is
   * the one that surprises people - Lipitor is a perfectly good catalog entry,
   * but atorvastatin sits outside the model's drug set, so it can never take
   * part in an analysis. Filtering here lets the patient see a result for the
   * rest of their medications instead of a refusal covering all of them.
   *
   * Returns true when the catalog is not loaded yet: better to ask the server
   * and let the 422 handler sort it out than to silently drop a plan.
   */
  private isAnalysable(med: MedicationItem): boolean {
    if (med.serverId.length === 0) {
      return false;
    }
    if (med.catalogItemId.length === 0 || this.catalogItems.length === 0) {
      return true;
    }
    const entry: MedicationCatalogItem | undefined =
      this.catalogItems.find((c: MedicationCatalogItem) => c.id === med.catalogItemId);
    if (entry === undefined || entry.ingredients === undefined) {
      return true;
    }
    return entry.ingredients.some((i: MedicationIngredient) => i.aiSupported);
  }

  private nameForServerId(serverId: string): string {
    const med: MedicationItem | undefined =
      this.medications.find((m: MedicationItem) => m.serverId === serverId);
    return med !== undefined ? med.name : serverId;
  }

  /** "A", "A and B", "A, B and C" - reads better than a bare comma list. */
  private list(items: string[]): string {
    if (items.length === 0) {
      return '';
    }
    if (items.length === 1) {
      return items[0];
    }
    return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
  }

  /**
   * POST /api/medication-risk-analyses over the patient's synced plans.
   *
   * Only plans that reached the server take part: the analysis works on backend
   * medication ids, so device-only plans are skipped.
   *
   * Medications the model does not cover are left OUT rather than turned into
   * an error. A patient on Lipitor, Parol and Aspirin should still get the
   * Parol + Aspirin result; refusing the whole analysis over the one uncovered
   * drug hid information they were entitled to.
   */
  async runRiskAnalysis(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }

    const analysable: MedicationItem[] = this.medications.filter((m: MedicationItem) => this.isAnalysable(m));
    const skipped: string[] = this.medications
      .filter((m: MedicationItem) => m.serverId.length > 0 && !this.isAnalysable(m))
      .map((m: MedicationItem) => m.name);

    if (analysable.length < 2) {
      this.analysisNotice = '';
      this.currentAnalysis = {
        overallStatus: 'safe',
        message: skipped.length > 0
          ? `The interaction model does not cover ${this.list(skipped)}, so there are not enough medications left to compare. Two covered medications are needed.`
          : 'Add at least two medications to see an interaction analysis.',
        organs: []
      };
      return;
    }

    // The backend refuses more than 10 in one request.
    const ids: string[] = analysable.map((m: MedicationItem) => m.serverId).slice(0, 10);
    await this.requestRiskAnalysis(ids, skipped, true);
  }

  /**
   * One analysis round trip.
   *
   * `mayRetry` allows exactly one second attempt: when the server rejects
   * medications the client had no catalog information for, they are dropped and
   * the rest are analysed. Capped at one retry so a disagreement between client
   * and server can never become a request loop.
   */
  private async requestRiskAnalysis(ids: string[], skipped: string[], mayRetry: boolean): Promise<void> {
    this.isAnalysing = true;
    this.analysisNotice = '';
    try {
      const analysis: MedicationRiskAnalysis = await ApiService.createMedicationRiskAnalysis(ids);
      this.currentAnalysis = RiskAnalysis.toAnalysisResult(analysis);

      const notes: string[] = [];
      if (skipped.length > 0) {
        const one: boolean = skipped.length === 1;
        notes.push(`${this.list(skipped)} ${one ? 'is' : 'are'} not covered by the interaction model, so ${one ? 'it was' : 'they were'} left out.`);
      }
      if (RiskAnalysis.hasReducedConfidence(analysis)) {
        // The model itself flagged the input as weaker than usual; saying so is
        // more honest than showing the same confident-looking card.
        notes.push('The model reported reduced confidence for some pairs. Treat these results as indicative.');
      }
      this.analysisNotice = notes.join(' ');
      console.info(`[API] POST /api/medication-risk-analyses - OK, ${analysis.pairs.length} pairs, ${skipped.length} skipped`);
    } catch (err) {
      if (err instanceof UnsupportedMedicationsError) {
        const rejected: UnsupportedMedication[] = (err as UnsupportedMedicationsError).unsupported;
        const rejectedIds: string[] = rejected.map((u: UnsupportedMedication) => u.medicationId);
        const names: string[] = rejected.map((u: UnsupportedMedication) =>
          u.name !== undefined && u.name.length > 0 ? u.name : this.nameForServerId(u.medicationId));
        const remaining: string[] = ids.filter((id: string) => !rejectedIds.includes(id));

        if (mayRetry && remaining.length >= 2) {
          this.isAnalysing = false;
          await this.requestRiskAnalysis(remaining, skipped.concat(names), false);
          return;
        }
        this.failAnalysis(this.unsupportedMessage(rejected, names));
      } else {
        const apiErr: ApiError | null = err instanceof ApiError ? err as ApiError : null;
        this.failAnalysis(apiErr !== null ? apiErr.message : 'The interaction analysis could not be completed.');
      }
      console.warn(`[API] POST /api/medication-risk-analyses - failed: ${(err as Error).message}`);
    } finally {
      this.isAnalysing = false;
    }
  }

  private failAnalysis(notice: string): void {
    this.currentAnalysis = { overallStatus: 'safe', message: '', organs: [] };
    this.analysisNotice = notice;
  }

  /**
   * Explains a 422 in terms that are actually true for it.
   *
   * The backend answers 422 for two different situations that need opposite
   * advice. A rejected medication that still carries an `ingredient` IS linked
   * to the catalog - the model simply does not cover that drug, and re-adding
   * it would change nothing. Only a rejection with no ingredient at all is a
   * missing catalog link, which the patient can actually fix.
   */
  private unsupportedMessage(rejected: UnsupportedMedication[], names: string[]): string {
    const unlinked: string[] = rejected
      .filter((u: UnsupportedMedication) => u.ingredient === undefined || u.ingredient.length === 0)
      .map((u: UnsupportedMedication) => u.name);

    if (unlinked.length > 0 && unlinked.length === rejected.length) {
      const one: boolean = unlinked.length === 1;
      return `${this.list(unlinked)} ${one ? 'is' : 'are'} not linked to a catalog entry, so ${one ? 'it' : 'they'} cannot be analysed. Re-add ${one ? 'it' : 'them'} by picking from the medication list.`;
    }
    return `The interaction model does not cover ${this.list(names)}, so there are not enough medications left to compare. This is a limit of the model, not a problem with your list.`;
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
            catalogItemId: plan.catalogItemId !== undefined ? plan.catalogItemId : '',
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

  /**
   * Maps the backend frequencyHours value onto the UI meal slots.
   * 24 -> once a day, 12 -> twice, 8 -> three times. 6 (four doses) has no
   * fourth meal slot in this UI, so it also renders as three.
   */
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
   * The backend accepts 6, 8, 12 or 24 hours, so all three meal-slot counts map
   * exactly: once a day -> 24, twice -> 12, three times -> 8. (Three doses a
   * day used to have no safe mapping and such plans stayed on the device only -
   * BLG-007; the 8-hour value closes that gap.)
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
    if (slotCount === 3) {
      return 8;
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

  // --- Archived prescriptions and reports (GET /api/documents) --------------
  // Uploads had no way back: a scanned prescription went to S3 and the patient
  // could never look at it again. These drive the list and the viewer.
  @State documents: DocumentCatalog[] = [];
  @State isDocumentListExpanded: boolean = false;
  @State documentsLoaded: boolean = false;
  /** Local path of the document being previewed, and its content type. */
  @State previewPath: string = '';
  @State previewTitle: string = '';
  @State previewContentType: string = '';
  @State isPreviewOpen: boolean = false;
  @State isDownloading: boolean = false;
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
   * A synced plan (`serverId` set) has to go through
   * `DELETE /api/medications/{id}` first. Removing it only from this local list
   * used to look like it worked - until `loadServerMedications()` re-fetched
   * `GET /api/medications` on the next visit and added it right back, and the
   * plan also kept showing up as an active medication on the Emergency Medical
   * Card. So the local rows are dropped only after the server confirms.
   */
  deleteMedication(id: string) {
    const target = this.medications.find(med => med.id === id);
    const serverId: string = target !== undefined ? target.serverId : '';

    if (serverId.length === 0) {
      // Device-only plan: nothing to delete on the server.
      this.removeMedicationLocally(id);
      promptAction.showToast({ message: 'Medication removed successfully' });
      return;
    }

    ApiService.deleteMedicationPlan(serverId)
      .then(() => {
        this.removeMedicationLocally(id);
        console.info(`[API] DELETE /api/medications/${serverId} - OK`);
        promptAction.showToast({ message: 'Medication removed successfully' });
        // One fewer medication means a different interaction picture; leaving
        // the old card up would show risks for a plan that is gone.
        this.runRiskAnalysis();
      })
      .catch((err: Error) => {
        console.error(`[API] DELETE /api/medications/${serverId} - FAILED: ${err.message}`);
        promptAction.showToast({ message: `Could not remove the medication: ${err.message}` });
      });
  }

  private removeMedicationLocally(id: string) {
    this.medications = this.medications.filter(med => med.id !== id);
    this.dashboardMeds = this.dashboardMeds.filter(med => !med.id.startsWith(id));
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
              if (this.documentsLoaded) {
                // The list is open behind this flow; keep it in step.
                this.loadDocuments();
              }
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
                  .borderRadius(20)
                  .border({ width: 1, color: '#EBECEF' })
                  .margin({ bottom: 12 })
                })
              }
              .width('100%')
            }

            // --- Safety (Side Effect Analysis) Section (Now positioned below Medication List) ---
            if (this.isAnalysing) {
              Row() {
                LoadingProgress()
                  .width(22)
                  .height(22)
                  .color('#003D9B')
                  .margin({ right: 10 })
                Text('Analysing medication interactions...')
                  .fontSize(14)
                  .fontColor('#434654')
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#F0F4FF')
              .borderRadius(20)
              .border({ width: 1, color: '#D0E0FF' })
              .margin({ bottom: 12 })
            }

            // Why there is no result, when there is none. Deliberately NOT
            // rendered inside the analysis card: a failure must not be mistaken
            // for an "all clear".
            if (this.analysisNotice.length > 0) {
              Row() {
                Image($r('app.media.alert'))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 10 })
                Text(this.analysisNotice)
                  .fontSize(13)
                  .fontColor('#854E00')
                  .lineHeight(19)
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding(14)
              .backgroundColor('#FFF4E5')
              .borderRadius(20)
              .border({ width: 1, color: '#F0C27A' })
              .margin({ bottom: 12 })
            }

            if (!this.isAnalysing && this.currentAnalysis.message.length > 0) {
              SafetyAnalysisCard({ 
                analysisResult: this.currentAnalysis, 
                userGender: (this.medicalProfile?.gender || 'Female').toLowerCase() 
              })
                .margin({ bottom: 12 })
            }

            // --- Archived prescriptions and reports -------------------------
            Column() {
              Row() {
                Image($r('app.media.prescription'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 10 })
                Column() {
                  Text('Prescriptions & Reports')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#434654')
                  Text('Documents you have uploaded')
                    .fontSize(12)
                    .fontColor('#737685')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.isDocumentListExpanded ? '▲' : '▼')
                  .fontSize(14)
                  .fontColor('#8F92A1')
              }
              .width('100%')
              .onClick(() => {
                this.isDocumentListExpanded = !this.isDocumentListExpanded;
                if (this.isDocumentListExpanded && !this.documentsLoaded) {
                  this.loadDocuments();
                }
              })

              if (this.isDocumentListExpanded) {
                Divider().color('#EBECEF').margin({ top: 12, bottom: 12 })

                if (this.documents.length === 0) {
                  Text(this.documentsLoaded
                    ? 'No documents yet. Scanning a prescription archives it here.'
                    : 'Loading...')
                    .fontSize(13)
                    .fontColor('#737685')
                    .width('100%')
                } else {
                  Column({ space: 10 }) {
                    ForEach(this.documents, (doc: DocumentCatalog) => {
                      Row() {
                        Column() {
                          Text(doc.title)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .fontColor('#191C1D')
                          Text(`${doc.kind} · ${doc.contentType}`)
                            .fontSize(12)
                            .fontColor('#737685')
                            .margin({ top: 2 })
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)

                        Text('View')
                          .fontSize(12)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#003D9B')
                          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                          .backgroundColor('#F0F4FF')
                          .borderRadius(8)
                          .onClick(() => { this.openDocument(doc); })

                        Text('Replace')
                          .fontSize(12)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#854E00')
                          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                          .backgroundColor('#FFF4E5')
                          .borderRadius(8)
                          .margin({ left: 8 })
                          .onClick(() => { this.replaceDocument(doc); })
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Center)
                    }, (doc: DocumentCatalog) => doc.id)
                  }
                  .width('100%')
                }
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: '#EBECEF' })
            .margin({ bottom: 12 })

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
      .id('btn_add_med')
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
                  .id('btn_scan_label')
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

                      // Resolved up front: the catalog id has to travel with the
                      // plan both locally and to the server, otherwise the plan
                      // can never be analysed for interactions.
                      const catalogEntry: MedicationCatalogItem | undefined =
                        this.findCatalogEntry(this.selectedMedName);

                      const newItem: MedicationItem = {
                        id: baseId,
                        serverId: '',
                        catalogItemId: catalogEntry !== undefined ? catalogEntry.id : '',
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
                        // No meal slot maps onto the backend's {6,8,12,24} set;
                        // the plan stays on this device only.
                        promptAction.showToast({
                          message: 'This dose schedule cannot be saved to the server; the plan was saved on this device only.'
                        });
                      } else if (SessionStore.isAuthenticated()) {
                        const request: CreateMedicationRequest = {
                          // Without this the backend cannot reach the plan's
                          // ingredients, and every later risk analysis that
                          // includes this plan comes back 422.
                          catalogItemId: catalogEntry !== undefined ? catalogEntry.id : undefined,
                          name: catalogEntry !== undefined ? catalogEntry.name : this.selectedMedName,
                          strength: catalogEntry !== undefined ? catalogEntry.strength : '',
                          instructions: this.mealTiming,
                          frequencyHours: frequencyHours,
                          prescriptionDocumentId: this.lastPrescriptionDocId.length > 0
                            ? this.lastPrescriptionDocId : undefined
                        };
                        ApiService.createMedicationPlan(request)
                          .then((created: MedicationResponse) => {
                            newItem.serverId = created.id;
                            if (created.catalogItemId !== undefined) {
                              newItem.catalogItemId = created.catalogItemId;
                            }
                            this.medications = [...this.medications];
                            this.lastPrescriptionDocId = '';
                            console.info(`[API] POST /api/medications - OK id=${created.id}`);
                            // A new plan changes the interaction picture.
                            this.runRiskAnalysis();
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

      // Document preview. Images render in place; anything else (a PDF) is
      // downloaded and its location reported - the app ships no PDF renderer,
      // and pretending otherwise would just show a blank frame.
      if (this.isPreviewOpen) {
        Column() {
          Column() {
            Row() {
              Text(this.previewTitle)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .layoutWeight(1)
              Text('✕')
                .fontSize(18)
                .fontColor('#737685')
                .onClick(() => { this.isPreviewOpen = false; })
            }
            .width('100%')
            .margin({ bottom: 16 })

            if (this.isPreviewImage()) {
              Image(`file://${this.previewPath}`)
                .width('100%')
                .height(380)
                .objectFit(ImageFit.Contain)
                .borderRadius(12)
                .backgroundColor('#F3F4F5')
            } else {
              Column() {
                Text('📄')
                  .fontSize(48)
                  .margin({ bottom: 12 })
                Text('This document was downloaded to your device.')
                  .fontSize(14)
                  .fontColor('#434654')
                  .textAlign(TextAlign.Center)
                Text(this.previewPath)
                  .fontSize(11)
                  .fontColor('#737685')
                  .textAlign(TextAlign.Center)
                  .margin({ top: 8 })
              }
              .width('100%')
              .padding(24)
              .backgroundColor('#F3F4F5')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(24)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .zIndex(11)
      }

      if (this.isDownloading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(Color.White)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .justifyContent(FlexAlign.Center)
        .zIndex(12)
      }

      BottomNavBar({ activeTab: 'meds' })
        .zIndex(1)

      if (this.isTutorialActive && this.currentTutorialStep === 2) {
        CoachMarkOverlay({
          targetId: 'btn_add_med',
          title: 'Add New Medication',
          description: 'Tap the + button to manually add medications or scan your prescription using AI camera.',
          stepIndex: 2,
          totalSteps: 4
        })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}