import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { contact } from '@kit.ContactsKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { ApiService, PatientProfile, MonitoringInvitation, EmergencyAccessToken, ClinicianPatient,
  AuditLogEntry } from '../services/ApiService';
import { QrPayload, DisplayFormat } from '../services/QrPayload';
import { SessionStore } from '../services/SessionStore';
import { ContactsRepository, UiEmergencyContact } from '../services/ContactsRepository';
import { ProfileRepository } from '../services/ProfileRepository';
import { AccountRepository } from '../services/AccountRepository';
import { CoachMarkOverlay } from '../components/CoachMarkOverlay';

interface ContactWithDisplayName {
  displayName: string;
}

/** A patient a family member is allowed to monitor, for the "Monitored Member" card. */
interface MonitoredFamilyPatient {
  id: string;
  name: string;
  heartRate: number;
  oxygen: number;
  /** Empty unless the patient consented to share it. */
  phone: string;
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

// Data model interface for medical profile
interface MedicalProfile {
  birthDate: string;
  gender: string;
  height: string;
  weight: string;
  bloodType: string;
  diseases: string[];
  otherChronicDisease: string;
  allergies: string;
  pacemaker: boolean;
  hearingAid: boolean;
}

// Interface for dynamic emergency contacts (Syncs with SOS Page)
interface EmergencyContact {
  id: string;
  fullName: string;
  phone: string;
  relation: string;
}

@CustomDialog
struct AddContactDialog {
  controller?: CustomDialogController;
  @State firstName: string = '';
  @State lastName: string = '';
  @State phoneNumber: string = '';
  @State relation: string = '';

  onAdd: (name: string, phone: string, relation: string) => void = () => {};

  build() {
    Column() {
      Text('Add Emergency Contact')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 16 })

      Button('Select from Contacts')
        .backgroundColor('rgba(0, 61, 155, 0.08)')
        .fontColor('#003D9B')
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .height(44)
        .borderRadius(12)
        .margin({ bottom: 16 })
        .onClick(() => {
          let selectionOptions: contact.ContactSelectionOptions = {
            isMultiSelect: false
          };
          contact.selectContacts(selectionOptions)
            .then((contacts) => {
              if (contacts && contacts.length > 0) {
                let selected = contacts[0];
                let displayName = '';
                if (selected.name) {
                  displayName = selected.name.fullName || '';
                }
                let selectedWithDisplayName = selected as ContactWithDisplayName;
                if (!displayName && selectedWithDisplayName.displayName) {
                  displayName = selectedWithDisplayName.displayName;
                }
                if (!displayName) {
                  displayName = 'Unknown Contact';
                }
                let parts = displayName.trim().split(' ');
                this.firstName = parts[0] || '';
                this.lastName = parts.slice(1).join(' ') || '';

                let phone = '';
                if (selected.phoneNumbers && selected.phoneNumbers.length > 0) {
                  phone = selected.phoneNumbers[0].phoneNumber || '';
                }
                this.phoneNumber = phone.replace(/\s+/g, '');
                this.relation = 'Other';
                promptAction.showToast({ message: 'Contact selected successfully!' });
              } else {
                promptAction.showToast({ message: 'No contact was selected.' });
              }
            })
            .catch((err: Error) => {
              console.error("selectContacts error", err.message);
              promptAction.showToast({ message: 'Could not access device contacts.' });
            });
        })

      TextInput({ placeholder: 'First Name', text: this.firstName })
        .onChange((val: string) => this.firstName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Last Name', text: this.lastName })
        .onChange((val: string) => this.lastName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Phone Number', text: this.phoneNumber })
        .type(InputType.PhoneNumber)
        .onChange((val: string) => this.phoneNumber = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Relationship / Title (e.g. Son, Security)', text: this.relation })
        .onChange((val: string) => this.relation = val)
        .margin({ bottom: 24 })
        .backgroundColor('#F3F4F5')

      Row() {
        Button('Cancel')
          .backgroundColor('#F1F2F5')
          .fontColor('#191C1D')
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.controller?.close();
          })

        Button('Save')
          .backgroundColor('#003D9B')
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            if (this.firstName && this.phoneNumber) {
              this.onAdd(`${this.firstName} ${this.lastName}`.trim(), this.phoneNumber, this.relation || 'Emergency Contact');
              this.controller?.close();
            } else {
              promptAction.showToast({ message: 'Name and Phone are required!' });
            }
          })}.width('100%')}.padding(24)
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

interface DoctorProfile {
  hospital: string;
  specialty: string;
  email: string;
  isVerified: boolean;
}

@Entry
@Component
struct ProfilePage {
  // AppStorage links for user session data
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';
  @StorageLink('profilePicture') profilePicture: string = '';
  @StorageLink('medications') medications: FullMedicationItem[] = [];
  @StorageLink('doctorProfile') doctorProfile: DoctorProfile = { hospital: '', email: '', specialty: '', isVerified: false };

  // Dynamic contacts fetched from SOS Page
  @StorageLink('sosContacts') sosContacts: EmergencyContact[] = [];

  // Link to medical profile data
  @StorageLink('medicalProfile') medicalProfile: MedicalProfile = {
    birthDate: '',
    gender: '',
    height: '',
    weight: '',
    bloodType: '',
    diseases: [],
    otherChronicDisease: '',
    allergies: '',
    pacemaker: false,
    hearingAid: false
  };

  @StorageLink('isTutorialActive') isTutorialActive: boolean = false;
  @StorageLink('currentTutorialStep') currentTutorialStep: number = 0;

  @StorageLink('userEmail') userEmail: string = '';
  @StorageLink('userPhone') userPhone: string = '';
  @State showRoleSwitcher: boolean = false;
  @State expandedMedId: string = '';
  @State isMyQrModalOpen: boolean = false;
  /** GET /api/emergency-access/audit-logs - who opened the emergency card. */
  @State accessLogs: AuditLogEntry[] = [];
  @State isAccessLogExpanded: boolean = false;
  @State accessLogLoaded: boolean = false;
  @State linkInvitationToken: string = '';
  @State linkInvitationExpiresAt: string = '';
  @State isGeneratingQr: boolean = false;
  /** 'link' = monitoring invitation, 'emergency' = emergency access code. */
  @State qrMode: string = 'link';
  /**
   * Who the "Link" QR is for: 'clinician' (Doctor) or 'family' (Family
   * Member). Same QR flow/UI for both - only kind/relationship differ, so the
   * backend records the relationship correctly - reusing one QR for both would
   * mislabel family links as clinician links.
   */
  @State linkTargetKind: string = 'clinician';
  /**
   * Consent to share the patient's phone number with whoever redeems the link
   * QR. Off by default and reset on every switch: sharing a phone number is a
   * decision that must be made deliberately, per invitation, not inherited from
   * the last time the screen was used.
   */
  @State sharePhoneWithMonitor: boolean = false;

  // Real linked patients for the "Monitored Member" card (GET /api/monitoring/patients),
  // replacing the old hard-coded "Father"/"Mother" mock - same data source as
  // HomePage.ets's FamilyDashboardView.
  @State linkedPatients: MonitoredFamilyPatient[] = [];
  @State selectedPatientId: string = '';
  @State showMemberDropdown: boolean = false;

  dialogController: CustomDialogController = new CustomDialogController({
    builder: AddContactDialog({
      onAdd: (name: string, phone: string, relation: string) => {
        if (this.sosContacts.length >= 2) {
          return;
        }
        // The contact is now written to the backend, not just the device:
        // SOS notifications are sent to this list.
        ContactsRepository.add(name, phone, relation, this.sosContacts.length === 0)
          .then((created: UiEmergencyContact) => {
            console.info(`[API] POST /api/emergency-contacts - OK id=${created.id}`);
            promptAction.showToast({ message: 'Emergency contact saved.' });
          })
          .catch((err: Error) => {
            console.error(`[API] POST /api/emergency-contacts - FAILED: ${err.message}`);
            promptAction.showToast({ message: `Could not save contact: ${err.message}` });
          });
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true
  });

  private scroller: Scroller = new Scroller();

  // Helper function to extract initials for avatar
  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  // Helper to generate a patient ID dynamically based on fullName and email
  getPatientId(): string {
    if (!this.fullName || this.fullName === 'User') {
      return 'GP-8321-2026';
    }
    let code = 0;
    for (let i = 0; i < this.fullName.length; i++) {
      code += this.fullName.charCodeAt(i);
    }
    const num = (code * 17) % 9000 + 1000;
    return `GP-${num}-2026`;
  }

  /**
   * QR payload.
   *
   * BEFORE: the patient's name, email, phone, blood type, allergies and
   * conditions were printed into the QR as plain-text JSON - an open medical
   * record with no expiry, no signature, no revocation and no audit trail.
   *
   * NOW: only a short-lived, single-use token issued by the backend is printed.
   * Medical data comes from the server after authorisation is checked.
   */
  getQrCodeValue(): string {
    if (this.linkInvitationToken.length === 0) {
      return 'Generating code...';
    }
    // The payload is printed with a type tag so the scanner knows which endpoint
    // to call. An untagged token produced a 400 in both flows.
    return this.qrMode === 'emergency'
      ? QrPayload.encodeEmergency(this.linkInvitationToken)
      : QrPayload.encodeLink(this.linkInvitationToken);
  }

  /** Requests a new token from the backend for the selected QR kind. */
  generateQrToken(): void {
    if (!SessionStore.isAuthenticated()) {
      promptAction.showToast({ message: 'You need to sign in to generate a QR code.' });
      return;
    }
    this.isGeneratingQr = true;
    this.linkInvitationToken = '';
    this.linkInvitationExpiresAt = '';

    if (this.qrMode === 'emergency') {
      // POST /api/emergency-access/tokens - the code emergency responders scan.
      ApiService.createEmergencyAccessToken()
        .then((access: EmergencyAccessToken) => {
          this.linkInvitationToken = access.token;
          this.linkInvitationExpiresAt = access.expiresAt;
          console.info(`[API] POST /api/emergency-access/tokens - OK, expiresAt=${access.expiresAt}`);
        })
        .catch((err: Error) => {
          console.error(`[API] Could not generate emergency access code: ${err.message}`);
          promptAction.showToast({ message: `Could not generate emergency access code: ${err.message}` });
        })
        .finally(() => {
          this.isGeneratingQr = false;
        });
      return;
    }

    // POST /api/patient-link-invitations - the invitation a doctor or family
    // member scans. kind/relationship follow linkTargetKind so the backend
    // records which kind of relationship this actually is.
    //
    // isEmergencyContact was hard-coded false for both kinds. The backend
    // sends SOS/all-clear alerts to a linked member ONLY when this flag is
    // true (see gb-go-main/api/sos.go createOutboxEntries: it queries
    // patient_relationships WHERE is_emergency_contact = TRUE). So a linked
    // family member - the person you would actually expect to be alerted in
    // an emergency - was silently never notified through this relationship;
    // only the separate, 2-contact-max "Emergency Contacts" list worked. A
    // doctor keeps false: a clinician monitoring relationship is not the same
    // as consenting to receive personal SOS alerts.
    ApiService.createLinkInvitation({
      relationship: this.linkTargetKind === 'family' ? 'Family Member' : 'Physician',
      kind: this.linkTargetKind === 'family' ? 'family' : 'clinician',
      canMonitor: true,
      isEmergencyContact: this.linkTargetKind === 'family',
      // The token is minted now, so the consent has to be decided now: the
      // backend stamps it onto the invitation and it cannot be changed after
      // the code is scanned.
      sharePhoneNumber: this.sharePhoneWithMonitor,
      expiresInSeconds: 900
    })
      .then((invitation: MonitoringInvitation) => {
        this.linkInvitationToken = invitation.token;
        this.linkInvitationExpiresAt = invitation.expiresAt;
        console.info(`[API] POST /api/patient-link-invitations - OK, expiresAt=${invitation.expiresAt}`);
      })
      .catch((err: Error) => {
        console.error(`[API] POST /api/patient-link-invitations - FAILED: ${err.message}`);
        promptAction.showToast({ message: `Could not generate invitation code: ${err.message}` });
      })
      .finally(() => {
        this.isGeneratingQr = false;
      });
  }

  /** Switches the QR kind and requests a new token. */
  switchQrMode(mode: string): void {
    if (this.qrMode === mode) {
      return;
    }
    this.qrMode = mode;
    this.generateQrToken();
  }

  /** Switches who the "Link" QR is for (Doctor/Family) and requests a new token. */
  switchLinkTarget(target: string): void {
    if (this.linkTargetKind === target) {
      return;
    }
    this.linkTargetKind = target;
    // A new recipient is a new decision; carrying the previous consent over
    // would share the number with someone the patient never agreed to.
    this.sharePhoneWithMonitor = false;
    if (this.qrMode === 'link') {
      this.generateQrToken();
    }
  }

  /** Toggles phone sharing and mints a fresh token carrying the new consent. */
  toggleSharePhone(share: boolean): void {
    if (this.sharePhoneWithMonitor === share) {
      return;
    }
    this.sharePhoneWithMonitor = share;
    if (this.qrMode === 'link') {
      // The consent lives inside the token, so the old QR still carries the old
      // answer; it has to be reissued.
      this.generateQrToken();
    }
  }

  /** Refreshes the profile and emergency contacts from the backend on open. */
  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      return;
    }

    // HomePage's "My Emergency Access QR" shortcut routes here with this flag
    // so the modal opens straight into Emergency Access mode instead of
    // requiring an extra tap on the "Emergency Access" pill.
    const params = router.getParams() as Record<string, boolean>;
    if (params && params.openEmergencyQr) {
      this.qrMode = 'emergency';
      this.isMyQrModalOpen = true;
      this.generateQrToken();
    }

    ContactsRepository.refreshQuietly();
    // Role and the doctor/family details live on the account now, so this page
    // shows what the server has rather than whatever this device last cached.
    AccountRepository.refreshQuietly();
    // Restore the FULL profile from the server: name, gender, height, weight,
    // blood type, chronic conditions, allergies, pacemaker, hearing aid.
    // The backend keeps these inside criticalFacts; the mapping lives in one
    // place, ProfileRepository.
    ProfileRepository.refreshQuietly();

    if (this.userRole === 'family') {
      this.loadLinkedPatients();
    }
  }

  /**
   * GET /api/monitoring/patients - same endpoint and shape as
   * HomePage.ets's FamilyDashboardView.loadFamilyPatients(). Feeds the
   * "Monitored Member" card below.
   */
  async loadLinkedPatients(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      const backendPatients: ClinicianPatient[] = await ApiService.getMonitoredPatients();
      const list: MonitoredFamilyPatient[] = [];
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
        }
        list.push({
          id: bp.id,
          name: bp.name && bp.name.length > 0 ? bp.name : 'Unnamed Patient',
          heartRate: heart,
          oxygen: oxy,
          phone: bp.phone !== undefined ? bp.phone : ''
        });
      }
      this.linkedPatients = list;
      if (list.length > 0 && !list.some((p: MonitoredFamilyPatient) => p.id === this.selectedPatientId)) {
        this.selectedPatientId = list[0].id;
      }
    } catch (err) {
      // Surfaced, not just logged: a silent failure leaves an empty roster on
      // screen and reads as "the QR link did not work", when in fact the link
      // succeeded and only this request failed.
      console.error(`[API] GET /api/monitoring/patients - FAILED: ${(err as Error).message}`);
      promptAction.showToast({ message: `Patient list could not be loaded: ${(err as Error).message}` });
    }
  }

  /**
   * Loads the emergency-access audit trail.
   *
   * Fetched on demand rather than on open: it is a privacy log a patient looks
   * at deliberately, and it should not be pulled down on every visit to the
   * profile screen.
   */
  async loadAccessLogs(): Promise<void> {
    if (!SessionStore.isAuthenticated()) {
      return;
    }
    try {
      this.accessLogs = await ApiService.getEmergencyAccessAuditLogs();
      this.accessLogLoaded = true;
      console.info(`[API] GET /api/emergency-access/audit-logs - OK, ${this.accessLogs.length} entries`);
    } catch (err) {
      this.accessLogLoaded = true;
      console.warn(`[API] GET /api/emergency-access/audit-logs - failed: ${(err as Error).message}`);
      promptAction.showToast({ message: `Access history could not be loaded: ${(err as Error).message}` });
    }
  }

  /** Who the responder was, with a readable fallback for an unnamed account. */
  responderLabel(entry: AuditLogEntry): string {
    if (entry.responderName !== undefined && entry.responderName.length > 0) {
      return entry.responderName;
    }
    if (entry.responderPhone !== undefined && entry.responderPhone.length > 0) {
      return entry.responderPhone;
    }
    return `Responder ${DisplayFormat.shortId(entry.responderId)}`;
  }

  getSelectedLinkedPatient(): MonitoredFamilyPatient | undefined {
    return this.linkedPatients.find((p: MonitoredFamilyPatient) => p.id === this.selectedPatientId);
  }

  /**
   * Puts the patient's number on the clipboard.
   *
   * Not a direct dial on purpose: placing a call needs the restricted
   * `ohos.permission.PLACE_CALL`, which this app does not declare and which is
   * not something to add quietly from a feature branch. Copying works with no
   * new permission and still gets the monitor to the number in one tap.
   */
  copyPatientPhone(phone: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, phone);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        promptAction.showToast({ message: `Phone number copied: ${phone}` });
      })
      .catch((err: Error) => {
        console.error(`[Clipboard] Could not copy the number: ${err.message}`);
        promptAction.showToast({ message: phone });
      });
  }

  // Photo picker function to change profile picture from gallery
  changeProfilePicture() {
    try {
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      photoPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
          this.profilePicture = photoSelectResult.photoUris[0];
          promptAction.showToast({ message: 'Profile picture updated from gallery!' });
        }
      }).catch((err: Error) => {
        console.error(`PhotoPicker select failed: ${err.message}`);
        promptAction.showToast({ message: 'Photo selection cancelled.' });
      });
    } catch (err) {
      const error = err as Error;
      console.error(`PhotoPicker failed to open: ${error.message}`);
      promptAction.showToast({ message: 'Failed to open photo picker on this device.' });
    }
  }

  // Helper function to calculate age from birth date
  getAge(birthDateStr: string): number {
    if (!birthDateStr) return 0;
    try {
      const parts = birthDateStr.split('-');
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const currentYear = new Date().getFullYear();
        return currentYear - year;
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 0;
  }

  // Formatter to display birth date nicely
  formatBirthDate(birthDateStr: string): string {
    if (!birthDateStr) return 'Not Set';
    try {
      const parts = birthDateStr.split('-');
      if (parts.length === 3) {
        const year = parts[0];
        const monthNum = parseInt(parts[1]);
        const day = parts[2];
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        if (monthNum >= 1 && monthNum <= 12) {
          return `${months[monthNum - 1]} ${day}, ${year}`;
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return birthDateStr;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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
          // 1. Header Area
          Row() {
            Row() {
              Image($r('app.media.logo_blank'))
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('GuardianBand')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }}.width('100%')
          .margin({ bottom: 20 })

          // Setup Prompt Banner
          if (this.userRole === 'patient' && this.medicalProfile.birthDate === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Profile is not set up. Tap here to complete it.')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
                .layoutWeight(1)
              Text('➔')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')}.width('100%')
            .padding(16)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'patient', canGoBack: true }
              });
            })
          } else if (this.userRole === 'family' && this.userEmail === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Email address is not set up. Tap here to complete it.')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
                .layoutWeight(1)
              Text('➔')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')}.width('100%')
            .padding(16)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: this.userRole, canGoBack: true }
              });
            })
          } else if (this.userRole === 'doctor' && this.doctorProfile.email === '') {
            Row() {
              Image($r('app.media.alert'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })
              Text('Doctor email profile is not set up. Tap here to complete it.')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')
                .layoutWeight(1)
              Text('➔')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#BA1A1A')}.width('100%')
            .padding(16)
            .backgroundColor('#FFEBEA')
            .borderRadius(16)
            .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'doctor', canGoBack: true }
              });
            })
          }

          // 2. Profile Main Header Card
          Column() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if (this.profilePicture === '') {
                Row() {
                  Text(this.getInitials(this.fullName))
                    .fontSize(32)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)}.width(100)
                .height(100)
                .borderRadius(50)
                .backgroundColor('#003D9B')
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .border({ width: 3, color: '#FFFFFF', style: BorderStyle.Solid })
              } else {
                Image(this.profilePicture)
                  .width(100)
                  .height(100)
                  .borderRadius(50)
                  .objectFit(ImageFit.Cover)
                  .border({ width: 3, color: '#FFFFFF', style: BorderStyle.Solid })
              }}.width(100)
            .height(100)
            .margin({ bottom: 16 })
            .onClick(() => {
              this.changeProfilePicture();
            })

            // User Full Name
            Text(this.fullName)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 8 })

            // Clickable Role Badge with Switch Action (Ends with ⇅)
            Row() {
              Image(this.userRole === 'patient' ? $r('app.media.patient') : 
                (this.userRole === 'doctor' ? $r('app.media.doctor') : $r('app.media.family')))
                .width(16)
                .height(16)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })

              Text(this.userRole === 'patient' ? 'Patient' : 
                (this.userRole === 'doctor' ? 'Doctor' : 'Family Member'))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.userRole === 'patient' ? '#003D9B' : 
                  (this.userRole === 'doctor' ? '#854E00' : '#006E2F'))
                .margin({ right: 6 })

              Text('⇅')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.userRole === 'patient' ? '#003D9B' : 
                  (this.userRole === 'doctor' ? '#854E00' : '#006E2F'))}.padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.userRole === 'patient' ? '#E8EEFF' : 
              (this.userRole === 'doctor' ? '#FFF4E5' : '#E6F9ED'))
            .borderRadius(16)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.showRoleSwitcher = true;
            })

            // DOB / Email / Hospital display based on role
            if (this.userRole === 'patient') {
              Row() {
                Image($r('app.media.dob'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text(this.medicalProfile.birthDate ? `${this.formatBirthDate(this.medicalProfile.birthDate)} (${this.getAge(this.medicalProfile.birthDate)} Years Old)` : 'Birth Date & Age: Not Set')
                  .fontSize(14)
                  .fontColor('#737685')}.margin({ bottom: 16 })
              .justifyContent(FlexAlign.Center)
            } else if (this.userRole === 'doctor') {
              Row() {
                Image($r('app.media.place'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text(this.doctorProfile.hospital ? `${this.doctorProfile.hospital}` : 'Hospital Name: Not Set')
                  .fontSize(14)
                  .fontColor('#737685')}.margin({ bottom: 16 })
              .justifyContent(FlexAlign.Center)
            } else {
              Row() {
                Image($r('app.media.email'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 6 })
                Text(this.userEmail ? this.userEmail : 'Email: Not Set')
                  .fontSize(14)
                  .fontColor('#737685')}.margin({ bottom: 16 })
              .justifyContent(FlexAlign.Center)
            }

            // Interactive Medical Badges (Blood Type, Allergies, Diseases) - Only for Patient
            if (this.userRole === 'doctor') {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                // Specialty Badge
                if (this.doctorProfile.specialty) {
                  Row() {
                    Image($r('app.media.stethoscope'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Specialty: ${this.doctorProfile.specialty}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#003D9B')}.padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#E8EEFF')
                  .borderRadius(16)
                  .margin(4)
                }

                // Verified Email Badge
                if (this.doctorProfile.email) {
                  Row() {
                    Image($r('app.media.email'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Verified Email: ${this.doctorProfile.email}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#006E2F')}.padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#E6F9ED')
                  .borderRadius(16)
                  .margin(4)
                }}.width('95%')
              .margin({ bottom: 10 })
            }

            if (this.userRole === 'patient') {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                // Blood Type Badge
                if (this.medicalProfile.bloodType) {
                  Row() {
                    Image($r('app.media.blood'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Blood: ${this.medicalProfile.bloodType}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#BA1A1A')}.padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#FFEBEA')
                  .borderRadius(16)
                  .margin(4)
                }

                // Allergy Badge
                if (this.medicalProfile.allergies) {
                  Row() {
                    Image($r('app.media.alert'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(`Allergy: ${this.medicalProfile.allergies}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#854E00')}.padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#FFF4E5')
                  .borderRadius(16)
                  .margin(4)
                }

                // Chronic Disease Badges
                ForEach(this.medicalProfile.diseases, (disease: string) => {
                  Row() {
                    Image($r('app.media.stethoscope'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 4 })
                    Text(disease === 'Other' && this.medicalProfile.otherChronicDisease ? this.medicalProfile.otherChronicDisease : disease)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#434654')}.padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor('#F3F4F5')
                  .borderRadius(16)
                  .margin(4)
                })

                // Fallback text if no medical parameters are registered
                if (!this.medicalProfile.bloodType && !this.medicalProfile.allergies && this.medicalProfile.diseases.length === 0) {
                  Text('No medical parameters registered')
                    .fontSize(13)
                    .fontColor('#737685')
                    .fontStyle(FontStyle.Italic)
                    .margin(4)
                }}.width('100%')
            }}.width('100%')
          .padding(24)
          .backgroundColor('rgba(255, 255, 255, 0.85)')
          .borderRadius(28)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
          .shadow({ radius: 12, color: 'rgba(0, 61, 155, 0.04)', offsetX: 0, offsetY: 4 })
          .margin({ bottom: 20 })

          // Conditionally Render Patient Cards
          if (this.userRole === 'patient') {
            // Share Patient QR Code Card
            Row() {
              Row() {
                Image($r('app.media.qr'))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)}.width(40)
              .height(40)
              .borderRadius(8)
              .backgroundColor('rgba(0, 110, 47, 0.08)')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text('Share Patient QR Code')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#006E2F')
                  .margin({ bottom: 2 })
                Text('Let your doctor or a family member scan this code to link with your account.')
                  .fontSize(12)
                  .fontColor('#737685')}.alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('Show QR', { type: ButtonType.Normal })
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#006E2F')
                .borderRadius(8)
                .height(30)
                .onClick(() => {
                  this.qrMode = 'link';
                  this.isMyQrModalOpen = true;
                  this.generateQrToken();
                })
                .id('btn_show_qr')
            }
            .id('card_patient_qr')
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(0, 110, 47, 0.2)', style: BorderStyle.Solid })
            .margin({ bottom: 20 })
            .alignItems(VerticalAlign.Center)

            // 3b. Emergency access history. The QR above hands out a key to
            // this patient's medical card; this is where they can see who used
            // it - and who was turned away.
            Column() {
              Row() {
                Image($r('app.media.alert'))
                  .width(18)
                  .height(18)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 10 })
                Column() {
                  Text('Emergency Card Access History')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#434654')
                  Text('Who opened your emergency medical card')
                    .fontSize(12)
                    .fontColor('#737685')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.isAccessLogExpanded ? '▲' : '▼')
                  .fontSize(14)
                  .fontColor('#8F92A1')
              }
              .width('100%')
              .onClick(() => {
                this.isAccessLogExpanded = !this.isAccessLogExpanded;
                if (this.isAccessLogExpanded && !this.accessLogLoaded) {
                  this.loadAccessLogs();
                }
              })

              if (this.isAccessLogExpanded) {
                Divider().color('#EBECEF').margin({ top: 12, bottom: 12 })

                if (this.accessLogs.length === 0) {
                  Text(this.accessLogLoaded
                    ? 'Nobody has opened your emergency card yet.'
                    : 'Loading...')
                    .fontSize(13)
                    .fontColor('#737685')
                    .width('100%')
                } else {
                  Column({ space: 10 }) {
                    ForEach(this.accessLogs, (entry: AuditLogEntry) => {
                      Row() {
                        Image(entry.allowed ? $r('app.media.check') : $r('app.media.cancel'))
                          .width(16)
                          .height(16)
                          .objectFit(ImageFit.Contain)
                          .margin({ right: 8, top: 2 })

                        Column() {
                          Text(this.responderLabel(entry))
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .fontColor('#191C1D')
                          Text(entry.allowed
                            ? DisplayFormat.dateTime(entry.createdAt)
                            : `${DisplayFormat.dateTime(entry.createdAt)} · refused${entry.reason !== undefined && entry.reason.length > 0 ? ` (${entry.reason})` : ''}`)
                            .fontSize(12)
                            .fontColor(entry.allowed ? '#737685' : '#BA1A1A')
                            .margin({ top: 2 })
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Top)
                    }, (entry: AuditLogEntry) => entry.id)
                  }
                  .width('100%')
                }
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            .margin({ bottom: 20 })

            // 4. Physical Info & Devices Card
            Column() {
              Text('Physical & Devices')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                // Height Info
                Row() {
                  Row() {
                    Image($r('app.media.ruler'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Height')
                      .fontSize(14)
                      .fontColor('#737685')
                  }
                  Blank()
                  Text(`${this.medicalProfile.height} cm`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')}.width('100%')
                .padding({ top: 12, bottom: 12 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Weight Info
                Row() {
                  Row() {
                    Image($r('app.media.scale'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Weight')
                      .fontSize(14)
                      .fontColor('#737685')
                  }
                  Blank()
                  Text(`${this.medicalProfile.weight} kg`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')}.width('100%')
                .padding({ top: 12, bottom: 12 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Pacemaker Status
                Row() {
                  Row() {
                    Image($r('app.media.pacemaker'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Pacemaker')
                      .fontSize(14)
                      .fontColor('#737685')
                  }
                  Blank()
                  Text(this.medicalProfile.pacemaker ? 'Active' : 'None')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.medicalProfile.pacemaker ? '#006E2F' : '#737685')}.width('100%')
                .padding({ top: 12, bottom: 12 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Hearing Aid Status
                Row() {
                  Row() {
                    Image($r('app.media.hearingaid'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text('Hearing Aid')
                      .fontSize(14)
                      .fontColor('#737685')
                  }
                  Blank()
                  Text(this.medicalProfile.hearingAid ? 'Active' : 'None')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.medicalProfile.hearingAid ? '#006E2F' : '#737685')}.width('100%')
                .padding({ top: 12, bottom: 12 })}.width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
            .margin({ bottom: 20 })

            // 5. Currently Used Medications
            Column() {
              Text('Active Medications')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                if (this.medications.length > 0) {
                  ForEach(this.medications, (med: FullMedicationItem) => {
                    Column() {
                      Row() {
                        Row() {
                          Image($r('app.media.drugs'))
                            .width(20)
                            .height(20)
                            .objectFit(ImageFit.Contain)}.width(36)
                        .height(36)
                        .borderRadius(10)
                        .backgroundColor('rgba(0, 61, 155, 0.1)')
                        .justifyContent(FlexAlign.Center)
                        .alignItems(VerticalAlign.Center)
                        .margin({ right: 12 })

                        Column() {
                          Text(med.name)
                            .fontSize(15)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#191C1D')
                            .margin({ bottom: 2 })

                          Text(`${med.totalPills} Pills left • ${med.mealTiming}`)
                            .fontSize(12)
                            .fontColor('#737685')}.alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)

                        Row() {
                          Text(this.expandedMedId === med.id ? 'Hide Detail ▲' : 'Detail ▼')
                            .fontSize(12)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#003D9B')}.padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor('#E8EEFF')
                        .borderRadius(6)}.width('100%')
                      .padding({ top: 12, bottom: 12 })
                      .onClick(() => {
                        this.expandedMedId = this.expandedMedId === med.id ? '' : med.id;
                      })

                      if (this.expandedMedId === med.id) {
                        Column() {
                          // 1. Weekly Days active
                          Row() {
                            Text('Active Days:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 8 })

                            Row() {
                              ForEach(['M', 'T', 'W', 'T', 'F', 'S', 'S'], (day: string, idx: number) => {
                                Text(day)
                                  .width(22)
                                  .height(22)
                                  .fontSize(10)
                                  .fontWeight(FontWeight.Bold)
                                  .textAlign(TextAlign.Center)
                                  .borderRadius(11)
                                  .backgroundColor(med.days.includes(day) ? '#003D9B' : '#F3F4F5')
                                  .fontColor(med.days.includes(day) ? Color.White : '#8F92A1')
                                  .margin({ right: 4 })
                              }, (day: string, idx: number) => day + idx.toString())
                            }}.width('100%')
                          .margin({ bottom: 12 })

                          // 2. Schedule times slot detail
                          Row() {
                            Text('Times:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 8 })

                            Flex({ wrap: FlexWrap.Wrap }) {
                              ForEach(med.times, (time: MedTime) => {
                                Row() {
                                  Text(time.slot)
                                    .fontSize(11)
                                    .fontWeight(FontWeight.Bold)
                                    .fontColor('#003D9B')
                                  if (time.specificTime) {
                                    Text(` (${time.specificTime})`)
                                      .fontSize(11)
                                      .fontColor('#737685')
                                  }}.padding({ left: 8, right: 8, top: 4, bottom: 4 })
                                .backgroundColor('#F0F4FF')
                                .borderRadius(6)
                                .margin({ right: 6 })
                              }, (time: MedTime) => time.slot)}.layoutWeight(1)}.width('100%')
                          .alignItems(VerticalAlign.Center)
                          .margin({ bottom: 12 })

                          // 3. Treatment Duration and Meal Timing
                          Row() {
                            Text('Treatment Duration:')
                              .fontSize(12)
                              .fontWeight(FontWeight.Bold)
                              .fontColor('#434654')
                              .margin({ right: 6 })

                            Text(`${med.durationDays} Days`)
                              .fontSize(12)
                              .fontColor('#191C1D')

                            Blank().width(16)}.width('100%')
                          .margin({ bottom: 4 })}.width('100%')
                        .padding(12)
                        .backgroundColor('#F8F9FA')
                        .borderRadius(12)
                        .margin({ bottom: 12 })
                        .alignItems(HorizontalAlign.Start)
                      }}.width('100%')
                    .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
                  }, (med: FullMedicationItem) => med.id)
                } else {
                  Column() {
                    Image($r('app.media.confetti'))
                      .width(32)
                      .height(32)
                      .objectFit(ImageFit.Contain)
                      .margin({ bottom: 8 })
                    Text('No medications scheduled.')
                      .fontSize(13)
                      .fontColor('#737685')
                      .fontStyle(FontStyle.Italic)}.width('100%')
                  .padding(16)
                  .alignItems(HorizontalAlign.Center)
                }}.width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
            .margin({ bottom: 20 })
          }

          // Conditionally Render Family Member Cards
          if (this.userRole === 'family') {
            // Monitored Family Member Card - real data from
            // GET /api/monitoring/patients, see loadLinkedPatients().
            Column() {
              Row() {
                Text('Monitored Member')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')

                Blank()

                if (this.linkedPatients.length > 1) {
                  // Switch Member Button
                  Row() {
                    Text(this.getSelectedLinkedPatient() !== undefined ? this.getSelectedLinkedPatient()!.name : '')
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#003D9B')
                      .margin({ right: 6 })
                    Text('▼')
                      .fontSize(10)
                      .fontColor('#003D9B')}.padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#E8EEFF')
                  .borderRadius(10)
                  .onClick(() => {
                    this.showMemberDropdown = !this.showMemberDropdown;
                  })
                }}.width('100%')
              .margin({ left: 4, bottom: 12 })

              // Dropdown Menu for choosing Monitored Member - one row per real linked patient.
              if (this.showMemberDropdown) {
                Column() {
                  ForEach(this.linkedPatients, (patient: MonitoredFamilyPatient) => {
                    Row() {
                      Row() {
                        Text(this.getInitials(patient.name))
                          .fontSize(11)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)}.width(26)
                      .height(26)
                      .borderRadius(13)
                      .backgroundColor(patient.id === this.selectedPatientId ? '#006E2F' : '#854E00')
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .margin({ right: 10 })

                      Text(patient.name)
                        .fontSize(14)
                        .fontWeight(patient.id === this.selectedPatientId ? FontWeight.Bold : FontWeight.Normal)
                        .fontColor(patient.id === this.selectedPatientId ? '#003D9B' : '#191C1D')

                      Blank()

                      if (patient.id === this.selectedPatientId) {
                        Text('✓')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#003D9B')
                      }}.width('100%')
                    .padding(12)
                    .onClick(() => {
                      this.selectedPatientId = patient.id;
                      this.showMemberDropdown = false;
                    })
                    .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.15)' })
                  }, (patient: MonitoredFamilyPatient) => patient.id)
                }.width('100%')
                .backgroundColor(Color.White)
                .borderRadius(16)
                .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
                .margin({ bottom: 12 })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)' })
              }

              Column() {
              if (this.linkedPatients.length === 0) {
                Column() {
                  Text('No patients linked yet.')
                    .fontSize(13)
                    .fontColor('#737685')
                    .margin({ bottom: 4 })
                  Text('Use "Link" QR scanning to add one.')
                    .fontSize(12)
                    .fontColor('#8F92A1')
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
                .alignItems(HorizontalAlign.Center)
              } else {
              Column() {
                // Header of the monitored person
                Row() {
                  // Avatar with initials
                  Row() {
                    Text(this.getInitials(this.getSelectedLinkedPatient() !== undefined ? this.getSelectedLinkedPatient()!.name : ''))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)}.width(48)
                  .height(48)
                  .borderRadius(24)
                  .backgroundColor('#006E2F')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .margin({ right: 12 })

                  Column() {
                    Row() {
                      Text(this.getSelectedLinkedPatient() !== undefined ? this.getSelectedLinkedPatient()!.name : 'Unknown Patient')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                      // Status dot - green once a reading is on file, grey otherwise.
                      Row()
                        .width(8)
                        .height(8)
                        .backgroundColor(this.getSelectedLinkedPatient() !== undefined && this.getSelectedLinkedPatient()!.heartRate > 0 ? '#006E2F' : '#C3C6D6')
                        .borderRadius(4)
                        .margin({ left: 8 })}.alignItems(VerticalAlign.Center)
                    .margin({ bottom: 4 })

                    Text(this.getSelectedLinkedPatient() !== undefined && this.getSelectedLinkedPatient()!.heartRate > 0 ? 'Readings available' : 'No readings yet')
                      .fontSize(12)
                      .fontColor(this.getSelectedLinkedPatient() !== undefined && this.getSelectedLinkedPatient()!.heartRate > 0 ? '#006E2F' : '#8F92A1')}.alignItems(HorizontalAlign.Start)}.width('100%')
                .padding({ bottom: 16 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Quick stats
                Row() {
                  Column() {
                    Text('Heart Rate')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.heart'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text(this.getSelectedLinkedPatient() !== undefined && this.getSelectedLinkedPatient()!.heartRate > 0 ? `${this.getSelectedLinkedPatient()!.heartRate} bpm` : '--')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#BA1A1A')
                    }}.layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)

                  Row()
                    .width(1)
                    .height(30)
                    .backgroundColor('rgba(195, 198, 214, 0.3)')

                  Column() {
                    Text('Oxygen Sat.')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.oxygensaturation'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text(this.getSelectedLinkedPatient() !== undefined && this.getSelectedLinkedPatient()!.oxygen > 0 ? `${this.getSelectedLinkedPatient()!.oxygen}%` : '--')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }}.layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)

                  Row()
                    .width(1)
                    .height(30)
                    .backgroundColor('rgba(195, 198, 214, 0.3)')

                  Column() {
                    Text('Steps Today')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 4 })
                    Row() {
                      Image($r('app.media.walking'))
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 4 })
                      Text('--')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#006E2F')
                    }}.layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)}.width('100%')
                .padding({ top: 16, bottom: 16 })
                .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

                // Shared phone number. Present only when the patient consented
                // while generating the link QR; nothing is shown otherwise, so
                // an absent number never looks like a missing feature.
                if (this.getSelectedLinkedPatient()?.phone) {
                  Row() {
                    Image($r('app.media.phone'))
                      .width(16)
                      .height(16)
                      .objectFit(ImageFit.Contain)
                      .margin({ right: 8 })
                    Text(this.getSelectedLinkedPatient()?.phone)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#191C1D')
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 4 })
                }

                // Actions row
                Row() {
                  Button() {
                    Row() {
                      Image($r('app.media.dashboard'))
                        .width(16)
                        .height(16)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })
                      Text('View Live Health Data')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#003D9B')
                    }}.layoutWeight(1)
                  .height(38)
                  .backgroundColor('rgba(0, 61, 155, 0.06)')
                  .borderRadius(8)
                  .margin({ right: 12 })
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/HomePage' }, (err) => {
                      if (err) {
                        promptAction.showToast({ message: `Routing Error: ${err.message}` });
                        console.error(`Routing to HomePage failed: ${err.code} - ${err.message}`);
                      }
                    });
                  })

                  Button() {
                    Row() {
                      Image($r('app.media.phone'))
                        .width(16)
                        .height(16)
                        .objectFit(ImageFit.Contain)
                        .margin({ right: 6 })
                      Text('Copy No.')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#006E2F')
                    }}.width(90)
                  .height(38)
                  .backgroundColor('rgba(0, 110, 47, 0.06)')
                  .borderRadius(8)
                  .onClick(() => {
                    // The number is only here when the patient ticked "share my
                    // phone number" while generating the link QR; otherwise the
                    // backend sends an empty string and there is nothing to dial.
                    const selected: MonitoredFamilyPatient | undefined = this.getSelectedLinkedPatient();
                    const phone: string = selected !== undefined ? selected.phone : '';
                    if (phone.length === 0) {
                      promptAction.showToast({ message: 'This patient has not shared their phone number with you.' });
                      return;
                    }
                    this.copyPatientPhone(phone);
                  })}.width('100%')
                .padding({ top: 16 })
              }.width('100%')
              }
              }
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
            .margin({ bottom: 20 })
          }

          // Conditionally Render Doctor Cards
          if (this.userRole === 'doctor') {
            Column() {
              Text('Professional Profile')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4, bottom: 12 })

              Column() {
                // Clinic Row
                Row() {
                  Image($r('app.media.place'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Affiliated Clinic / Hospital')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.hospital || 'Not Configured')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')}.alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)}.width('100%')
                .margin({ bottom: 16 })

                // Specialty Row
                Row() {
                  Image($r('app.media.doctor'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Medical Specialty')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.specialty || 'Not Configured')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')}.alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)}.width('100%')
                .margin({ bottom: 16 })

                // Verification Status Row
                Row() {
                  Image($r('app.media.like'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 12 })

                  Column() {
                    Text('Account Status')
                      .fontSize(11)
                      .fontColor('#737685')
                      .margin({ bottom: 2 })
                    Text(this.doctorProfile.isVerified ? 'Verified Medical Professional' : 'Verification Required')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.doctorProfile.isVerified ? '#006E2F' : '#BA1A1A')}.alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)}.width('100%')}.width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
            .margin({ bottom: 20 })
          }

          // Emergency Contacts - Rendered only for Patients
          if (this.userRole === 'patient') {
            Column() {
              Row() {
                Text('Emergency Contacts')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#434654')

                Blank()

                // Show the Add button only when fewer than 2 contacts exist
                if (this.sosContacts.length < 2) {
                  Button('+ Add')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#003D9B')
                    .backgroundColor('#E8EEFF')
                    .height(28)
                    .onClick(() => {
                      this.dialogController.open();
                    })
                }}.width('100%')
              .margin({ bottom: 12 })
              .padding({ left: 4, right: 4 })

              Column() {
                if (this.sosContacts.length > 0) {
                  ForEach(this.sosContacts, (contact: EmergencyContact, index: number) => {
                    Row() {
                      // Avatar (Left Side)
                      Row() {
                        Text(this.getInitials(contact.fullName))
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)}.width(40)
                      .height(40)
                      .borderRadius(20)
                      .backgroundColor('#003D9B')
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .margin({ right: 12 })

                      // Contact Info
                      Column() {
                        Text(contact.fullName)
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#191C1D')
                          .margin({ bottom: 4 })

                        // Priority Badge and Relation
                        Row() {
                          Text(index === 0 ? '1st to Call' : '2nd to Call')
                            .fontSize(10)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Color.White)
                            .backgroundColor(index === 0 ? '#BA1A1A' : '#854E00')
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4)
                            .margin({ right: 6 })

                          Text(contact.relation)
                            .fontSize(12)
                            .fontColor('#737685')
                        }}.alignItems(HorizontalAlign.Start)

                      Blank()

                      // Remove Button
                      Button('Remove', { type: ButtonType.Normal })
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#BA1A1A')
                        .backgroundColor('rgba(186, 26, 26, 0.08)')
                        .borderRadius(8)
                        .height(28)
                        .onClick(() => {
                          ContactsRepository.remove(contact.id)
                            .then(() => {
                              promptAction.showToast({ message: 'Contact removed.' });
                            })
                            .catch((err: Error) => {
                              console.error(`[API] DELETE /api/emergency-contacts - FAILED: ${err.message}`);
                              promptAction.showToast({ message: `Could not remove contact: ${err.message}` });
                            });
                        })}.width('100%')
                    .padding({ top: 12, bottom: 12 })
                    .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
                  }, (contact: EmergencyContact) => contact.id)
                } else {
                  // Fallback screen if no contacts are added
                  Column() {
                    Text('No emergency contacts added yet.')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#191C1D')
                      .margin({ bottom: 4 })
                    Text('Please use the Add button above to register responders.')
                      .fontSize(12)
                      .fontColor('#737685')}.width('100%')
                  .padding(16)
                  .alignItems(HorizontalAlign.Center)
                }}.width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .borderRadius(20)
              .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
            .margin({ bottom: 20 })
          }

          // Sign Out Button
          Button() {
            Row() {
              Image($r('app.media.logout'))
                .width(20)
                .height(20)
                .margin({ right: 8 })
                .objectFit(ImageFit.Contain)
              Text('Sign Out')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8C0013')}.width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)}.width('100%')
          .height(56)
          .backgroundColor('rgba(140, 0, 19, 0.08)')
          .borderRadius(16)
          .margin({ top: 8, bottom: 20 })
          .onClick(() => {
              // Remove the registered notification endpoint and clear the session.
              ApiService.logout()
                .catch((err: Error) => console.warn(`[API] Error during sign-out: ${err.message}`));
              AppStorage.setOrCreate('fullName', '');
              AppStorage.setOrCreate('profilePicture', '');
              AppStorage.setOrCreate('userRole', 'patient');
              AppStorage.setOrCreate('userEmail', '');
              AppStorage.setOrCreate('medicalProfile', {
                birthDate: '',
                gender: '',
                height: '',
                weight: '',
                bloodType: '',
                diseases: [],
                otherChronicDisease: '',
                allergies: '',
                pacemaker: false,
                hearingAid: false
              });
              promptAction.showToast({ message: 'Signed out successfully' });
              router.clear();
              router.replaceUrl({ url: 'pages/WelcomePage' });
            })

          // Blank space to prevent overlap with BottomNavBar
          Blank().height(100)}.width('100%')
        .padding({ left: 24, right: 24, top: 20 })}.scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // Bottom Navigation Bar
      BottomNavBar({ activeTab: 'profile' })
        .zIndex(1)

      if (this.isTutorialActive && this.currentTutorialStep === 3) {
        CoachMarkOverlay({
          targetId: 'card_patient_qr',
          title: 'Quick QR Connection',
          description: 'Share your QR code with your doctor or family member to link accounts securely.',
          stepIndex: 3,
          totalSteps: 4
        })
      }

      // Role Switcher Drawer/Card Overlay
      if (this.showRoleSwitcher) {
        // Semi-transparent Overlay Background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.4)')
          .zIndex(10)
          .onClick(() => {
            this.showRoleSwitcher = false;
          })

        // Role Switcher Bottom Sheet Card
        Column() {
          // Drag Handle
          Row()
            .width(40)
            .height(5)
            .backgroundColor('#E1E2E4')
            .borderRadius(3)
            .margin({ bottom: 20 })

          Text('Switch Active Role')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Text('Choose the role you want to act as. If you select a new role, you can set it up instantly.')
            .fontSize(14)
            .fontColor('#737685')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
            .width('90%')

          // Role 1: Patient
          Row() {
            Image($r('app.media.patient'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Patient')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.medicalProfile.birthDate ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.medicalProfile.birthDate ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)}.alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'patient') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }}.width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 12 })
          .border({ width: this.userRole === 'patient' ? 2 : 1, color: this.userRole === 'patient' ? '#003D9B' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.medicalProfile.birthDate) {
              this.userRole = 'patient';
              promptAction.showToast({ message: 'Switched to Patient role' });
            } else {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'patient', canGoBack: true }
              });
            }
          })

          // Role 2: Family Member
          Row() {
            Image($r('app.media.family'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Family Member')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.userEmail ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.userEmail ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)}.alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'family') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
            }}.width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 12 })
          .border({ width: this.userRole === 'family' ? 2 : 1, color: this.userRole === 'family' ? '#006E2F' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.userEmail) {
              this.userRole = 'family';
              promptAction.showToast({ message: 'Switched to Family Member role' });
            } else {
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'family', canGoBack: true }
              });
            }
          })

          // Role 3: Doctor
          Row() {
            Image($r('app.media.doctor'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .margin({ right: 16 })

            Column() {
              Text('Doctor')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              Text(this.doctorProfile.email ? 'Configured' : 'Setup Required')
                .fontSize(12)
                .fontColor(this.doctorProfile.email ? '#006E2F' : '#BA1A1A')
                .fontWeight(FontWeight.Medium)}.alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.userRole === 'doctor') {
              Text('✓')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#854E00')
            }}.width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(16)
          .margin({ bottom: 24 })
          .border({ width: this.userRole === 'doctor' ? 2 : 1, color: this.userRole === 'doctor' ? '#854E00' : 'rgba(0,0,0,0.05)' })
          .onClick(() => {
            this.showRoleSwitcher = false;
            if (this.doctorProfile.email) {
              AppStorage.setOrCreate('previousRole', this.userRole);
              this.userRole = 'doctor';
              promptAction.showToast({ message: 'Switched to Doctor role' });
            } else {
              AppStorage.setOrCreate('previousRole', this.userRole);
              router.pushUrl({
                url: 'pages/ProfileSetupPage',
                params: { role: 'doctor', canGoBack: true }
              });
            }
          })

          // Close Button
          Button('Cancel')
            .width('100%')
            .height(50)
            .backgroundColor('#E1E2E4')
            .fontColor('#191C1D')
            .borderRadius(12)
            .onClick(() => {
              this.showRoleSwitcher = false;
            })}.width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 30 })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 32, topRight: 32 })
        .zIndex(11)
      }

      // My Patient QR Code Modal Dialog
      if (this.isMyQrModalOpen) {
        Stack() {
          // Semi-transparent background
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.45)')
            .onClick(() => {
              this.isMyQrModalOpen = false;
            })

          Column() {
            Row() {
              Text('My Patient QR Code')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')

              Blank()

              // Close Button
              Row() {
                Image($r('app.media.cancel'))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)}.onClick(() => {
                this.isMyQrModalOpen = false;
              })}.width('100%')
            .margin({ bottom: 20 })

            // QR kind selector. The two flows use different token types; a single
            // QR cannot serve both (a token sent to the wrong endpoint gets a 400).
            Row() {
              Text('Emergency Access')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.qrMode === 'emergency' ? Color.White : '#434654')
                .textAlign(TextAlign.Center)
                .align(Alignment.Center)
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .backgroundColor(this.qrMode === 'emergency' ? '#BA1A1A' : '#F0F4F8')
                .onClick(() => { this.switchQrMode('emergency'); })

              Text('Link')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.qrMode === 'link' ? Color.White : '#434654')
                .textAlign(TextAlign.Center)
                .align(Alignment.Center)
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .backgroundColor(this.qrMode === 'link' ? '#003D9B' : '#F0F4F8')
                .margin({ left: 8 })
                .onClick(() => { this.switchQrMode('link'); })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Who the "Link" QR is for. One QR flow, two possible relationship
            // kinds - reusing the doctor QR for a family member would record
            // the relationship as "clinician" on the backend, which is wrong.
            if (this.qrMode === 'link') {
              Row() {
                Text('Doctor')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.linkTargetKind === 'clinician' ? Color.White : '#434654')
                  .textAlign(TextAlign.Center)
                  .align(Alignment.Center)
                  .layoutWeight(1)
                  .height(32)
                  .borderRadius(8)
                  .backgroundColor(this.linkTargetKind === 'clinician' ? '#854E00' : '#F0F4F8')
                  .onClick(() => { this.switchLinkTarget('clinician'); })

                Text('Family Member')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.linkTargetKind === 'family' ? Color.White : '#434654')
                  .textAlign(TextAlign.Center)
                  .align(Alignment.Center)
                  .layoutWeight(1)
                  .height(32)
                  .borderRadius(8)
                  .backgroundColor(this.linkTargetKind === 'family' ? '#006E2F' : '#F0F4F8')
                  .margin({ left: 8 })
                  .onClick(() => { this.switchLinkTarget('family'); })
              }
              .width('100%')
              .margin({ bottom: 16 })

              // Phone-number consent. Sits with the QR because that is where
              // the decision takes effect: the flag is baked into the token.
              Row() {
                Column() {
                  Text('Share my phone number')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#191C1D')
                  Text(this.sharePhoneWithMonitor
                    ? 'They will be able to see and call your number.'
                    : 'Your number stays hidden from them.')
                    .fontSize(11)
                    .fontColor('#737685')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.sharePhoneWithMonitor })
                  .selectedColor('#003D9B')
                  .onChange((isOn: boolean) => { this.toggleSharePhone(isOn); })
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor('#F8F9FA')
              .borderRadius(12)
              .margin({ bottom: 16 })
            }

            // Display Dynamic QR Code Container
            Row() {
              QRCode(this.getQrCodeValue())
                .width(180)
                .height(180)
                .color(this.qrMode === 'emergency' ? '#BA1A1A' : '#003D9B')}.width(220)
            .height(220)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#E8EEFF', style: BorderStyle.Solid })
            .borderRadius(16)
            .margin({ bottom: 16 })

            Text(this.fullName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
              .margin({ bottom: 4 })

            Text(`Patient ID: ${this.getPatientId()}`)
              .fontSize(12)
              .fontColor('#737685')
              .margin({ bottom: 16 })

            if (this.isGeneratingQr) {
              Text('Generating code...')
                .fontSize(13)
                .fontColor('#737685')
                .margin({ bottom: 8 })
            } else if (this.linkInvitationExpiresAt.length > 0) {
              Text(`Single use. Expires: ${DisplayFormat.dateTime(this.linkInvitationExpiresAt)}`)
                .fontSize(12)
                .fontColor('#BA1A1A')
                .textAlign(TextAlign.Center)
                .margin({ bottom: 8 })
            }

            Text(this.qrMode === 'emergency'
              ? 'Emergency responders can scan this code to see your blood type, allergies and medications. Every access is logged.'
              : (this.linkTargetKind === 'family'
                  ? 'Let a family member scan this code to link to your account, monitor your readings, and be alerted if you trigger an SOS.'
                  : 'Your doctor can scan this code to add you to their patient list and monitor your readings.'))
              .fontSize(13)
              .fontColor('#434654')
              .textAlign(TextAlign.Center)
              .lineHeight(18)
              .width('90%')}.width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)' })}.width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }}.width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}