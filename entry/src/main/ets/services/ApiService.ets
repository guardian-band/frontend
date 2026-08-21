import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { ApiConfig } from './ApiConfig';
import { SessionStore } from './SessionStore';

// =============================================================================
// Hata tipi
// =============================================================================

/**
 * Carries a backend error together with its status code.
 * Errors used to be swallowed with `console.error`; now they reach the caller.
 */
export class ApiError extends Error {
  public readonly status: number;
  public readonly detail: string;

  constructor(status: number, detail: string, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.detail = detail;
  }

  /** When the network layer was never reached (no connection, timeout). */
  static network(detail: string): ApiError {
    return new ApiError(0, detail, 'Cannot reach the server. Please check your connection.');
  }

  /**
   * Turns the backend's plain-text error bodies into messages that can be
   * shown to the user. The raw bodies are terse and technical, so they are not
   * suitable for display as-is.
   */
  private static translate(detail: string, status: number): string {
    const d: string = detail.toLowerCase();

    // CAREFUL: "invalid or expired token" means two different things.
    //   401 -> AuthenticateMiddleware; the JWT expired (a session problem)
    //   400 -> emergency-access/redeem; the QR code is invalid
    // So the QR message is used only OUTSIDE 401; a 401 falls through to the
    // "session has expired" message below.
    if (d.includes('invalid or expired token')) {
      return status === 401 ? '' : 'This code is invalid or has expired. A new code needs to be generated.';
    }

    if (d.includes('invalid credentials')) {
      return 'Phone number or password is incorrect.';
    }
    if (d.includes('user already exists')) {
      return 'This phone number is already registered. Try signing in instead.';
    }
    if (d.includes('invalid phone number format')) {
      return 'Invalid phone number. Example: +905551234567';
    }
    if (d.includes('password must be at least')) {
      return 'Password must be at least 8 characters.';
    }
    if (d.includes('missing required fields')) {
      return 'Please fill in all fields.';
    }
    if (d.includes('invalid bloodtype')) {
      return 'Invalid blood type.';
    }
    if (d.includes('patient profile not found')) {
      return 'You need to create your health profile first.';
    }
    if (d.includes('profile not found')) {
      return 'Profile not found.';
    }
    if (d.includes('invitation is invalid')) {
      return 'The invitation code is invalid, expired, or already used.';
    }
    if (d.includes('cannot link to yourself')) {
      return 'You cannot use your own code.';
    }
    if (d.includes('session was revoked')) {
      return 'This access has been revoked.';
    }
    if (d.includes('device does not belong')) {
      return 'This device is not registered to the patient.';
    }
    if (d.includes('emergency contact already exists')) {
      return 'This contact has already been added.';
    }
    if (d.includes('invalid frequencyhours')) {
      return 'Dose frequency must be 6, 12, or 24 hours.';
    }
    if (d.includes('invalid document kind')) {
      return 'Invalid document type.';
    }
    return '';
  }

  /**
   * Turns a status code into a message that can be shown to the user.
   *
   * @param authenticated Did the request require a session? A `401` means very
   *   different things depending on this: on a protected endpoint the session
   *   has expired, but on sign-in/sign-up it means **wrong credentials**. Both
   *   used to be shown as "session expired".
   */
  static fromStatus(status: number, body: string, authenticated: boolean): ApiError {
    const detail: string = body.trim();

    // Prefer the server's own message when recognised; it is the most specific.
    const translated: string = ApiError.translate(detail, status);
    if (translated.length > 0) {
      return new ApiError(status, detail, translated);
    }

    let message: string = '';
    switch (status) {
      case 400:
        message = 'There is a problem with the information you entered. Please check it.';
        break;
      case 401:
        message = authenticated
          ? 'Your session has expired. Please sign in again.'
          : 'Phone number or password is incorrect.';
        break;
      case 403:
        message = 'You do not have permission for this action.';
        break;
      case 404:
        message = 'Not found.';
        break;
      case 409:
        message = 'This record already exists.';
        break;
      case 413:
        message = 'File is too large.';
        break;
      default:
        message = status >= 500
          ? 'Server error. This is not your fault; please try again later.'
          : `Unexpected error (${status}).`;
        break;
    }
    return new ApiError(status, detail, message);
  }

  isUnauthorized(): boolean {
    return this.status === 401;
  }

  isNetwork(): boolean {
    return this.status === 0;
  }
}

// =============================================================================
// Data types - aligned one-to-one with the openapi.yaml schemas
// =============================================================================

export interface AuthResult {
  token: string;
  /**
   * NOT PROVIDED BY THE BACKEND YET.
   *
   * `AuthResponse` in `openapi.yaml` returns only `token`; the user UUID lives
   * solely in the JWT `sub` claim and the client does not decode it. This field
   * fills in automatically once the backend adds it; until then it is undefined.
   *
   * Impact: a patient cannot fetch their own latest reading
   * (`GET /api/vitals/{userId}/latest` takes a UUID path parameter).
   * See backend request BT-01.
   */
  userId?: string;
}

export interface RegisterResult {
  id: string;
  phoneNumber: string;
  displayName?: string;
}

export interface CriticalFacts {
  allergies?: string[];
  chronicConditions?: string[];
  pacemaker?: boolean;
  hearingAid?: boolean;
  gender?: string;
  heightCm?: number;
  weightKg?: number;
}

export interface PatientProfile {
  displayName?: string;
  birthDate: string;
  bloodType: string;
  criticalFacts: CriticalFacts;
  timezone: string;
}

export interface DocumentCatalog {
  id: string;
  kind: string;
  title: string;
  contentType: string;
  currentVersionId: string;
  createdAt: string;
  updatedAt: string;
}

export interface UploadedDocument {
  id: string;
  objectKey: string;
  versionId: string;
  message: string;
}

/**
 * Counterpart of MonitoringPatient in the backend.
 * The name is kept as ClinicianPatient for backwards compatibility.
 */
export interface ClinicianPatient {
  id: string;
  patientId: string;
  displayName?: string;
  name: string;
  relationship: string;
  bloodType: string;
  birthDate: string;
}

export interface PatientRelationship {
  id: string;
  memberUserId: string;
  memberDisplayName: string;
  relationship: string;
  kind: string;
  canMonitor: boolean;
  isEmergencyContact: boolean;
  active: boolean;
  createdAt: string;
  revokedAt?: string;
}

export interface MonitoringInvitation {
  token: string;
  expiresAt: string;
}

export interface MonitoringRelationship {
  id: string;
  patientId: string;
  memberUserId: string;
  relationship: string;
  kind: string;
  canMonitor: boolean;
  isEmergencyContact: boolean;
}

export interface CreateInvitationRequest {
  relationship: string;
  kind: string;
  canMonitor: boolean;
  isEmergencyContact?: boolean;
  expiresInSeconds?: number;
}

export interface VitalsResponse {
  userId?: string;
  heartRate: number;
  bloodOxygen: number;
  recordedAt?: string;
  deviceSn?: string;
  readingId?: string;
}

export interface MedicationCatalogItem {
  id: string;
  name: string;
  strength: string;
}

export interface CreateMedicationRequest {
  name: string;
  strength: string;
  instructions: string;
  frequencyHours: number;
  prescriptionDocumentId?: string;
}

export interface MedicationResponse {
  id: string;
  name: string;
  strength: string;
  instructions: string;
  frequencyHours: number;
  lastTakenAt?: string;
  nextScheduledFor?: string;
}

export interface TakenResponse {
  nextScheduledFor: string;
}

export interface SOSIncident {
  id: string;
  patientId: string;
  status: string;
  latitude?: number;
  longitude?: number;
  accuracyMeters?: number;
  address?: string;
  startedAt: string;
}

export interface SOSAllClear {
  id: string;
  status: string;
  allClearAt?: string;
}

/** Emergency contact aligned with the backend field names. */
export interface EmergencyContact {
  id: string;
  displayName: string;
  phone: string;
  relationship: string;
  isPrimary: boolean;
}

export interface EmergencyContactInput {
  displayName: string;
  phone: string;
  relationship: string;
  isPrimary?: boolean;
}

export interface EmergencyContactPatch {
  displayName?: string;
  phone?: string;
  relationship?: string;
  isPrimary?: boolean;
}

export interface EmergencyAccessToken {
  token: string;
  expiresAt: string;
}

export interface EmergencyAccessSession {
  sessionId: string;
  expiresAt: string;
}

export interface EmergencyMedication {
  name: string;
  strength: string;
  instructions: string;
}

export interface EmergencyLatestVitals {
  heartRate: number;
  bloodOxygen: number;
  recordedAt: string;
}

export interface EmergencyMedicalCard {
  bloodType: string;
  criticalFacts: CriticalFacts;
  medications: EmergencyMedication[];
  latestVitals?: EmergencyLatestVitals;
  /**
   * NOT PROVIDED BY THE BACKEND YET - see BACKEND_REQUESTS.md #1.
   * `EmergencyMedicalCard` in `openapi.yaml` has no name/birth date field, so
   * the emergency card cannot show who the patient is. These stay undefined
   * until the backend adds them (same field names as `PatientProfile`).
   */
  displayName?: string;
  birthDate?: string;
}

export interface NotificationEndpoint {
  id: string;
  channel: string;
  token: string;
  active: boolean;
  updatedAt: string;
}

// --- Dahili istek tipleri ----------------------------------------------------

interface HttpResult {
  code: number;
  body: string;
}

interface SendOptions {
  auth: boolean;
  body?: string;
  timeoutMs?: number;
  retries?: number;
}

// =============================================================================
// Servis
// =============================================================================

export class ApiService {
  /**
   * Fired when the session drops (401). Registered at app start so it can
   * route back to the sign-in screen.
   */
  private static unauthorizedHandler: (() => void) | null = null;

  static onUnauthorized(handler: () => void): void {
    ApiService.unauthorizedHandler = handler;
  }

  // ---------------------------------------------------------------------------
  // Central request layer
  // ---------------------------------------------------------------------------

  /**
   * Single entry point: sets headers, applies timeouts, handles 401 centrally,
   * and retries when appropriate.
   */
  private static async send(path: string, method: http.RequestMethod, options: SendOptions): Promise<HttpResult> {
    const url: string = ApiConfig.url(path);
    const timeout: number = options.timeoutMs !== undefined ? options.timeoutMs : ApiConfig.READ_TIMEOUT_MS;
    const attempts: number = options.retries !== undefined ? options.retries : 1;

    const header: Record<string, string> = {};
    if (options.body !== undefined) {
      header['Content-Type'] = 'application/json';
    }
    if (options.auth) {
      const token: string = SessionStore.getToken();
      if (token.length === 0) {
        throw new ApiError(401, 'no token', 'No active session. Please sign in.');
      }
      header['Authorization'] = `Bearer ${token}`;
    }

    let lastError: ApiError | null = null;

    for (let attempt = 1; attempt <= attempts; attempt++) {
      const request = http.createHttp();
      try {
        const requestOptions: http.HttpRequestOptions = {
          method: method,
          header: header,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: ApiConfig.CONNECT_TIMEOUT_MS,
          readTimeout: timeout
        };
        if (options.body !== undefined) {
          requestOptions.extraData = options.body;
        }

        const response = await request.request(url, requestOptions);
        const code: number = response.responseCode;
        const body: string = response.result !== undefined ? response.result as string : '';

        if (code >= 200 && code < 300) {
          return { code: code, body: body };
        }

        const apiError = ApiError.fromStatus(code, body, options.auth);
        // Clear the session ONLY when a 401 comes from a protected endpoint.
        // A 401 on sign-in/sign-up means "wrong credentials"; a failed sign-in
        // attempt must not drop the session or claim it expired.
        if (apiError.isUnauthorized() && options.auth) {
          await ApiService.handleUnauthorized();
          throw apiError;
        }
        // 5xx yeniden denenebilir; 4xx denenmez.
        if (code < 500 || attempt === attempts) {
          throw apiError;
        }
        lastError = apiError;
      } catch (err) {
        const apiErr: ApiError = err instanceof ApiError
          ? err as ApiError
          : ApiError.network((err as Error).message);
        // 4xx is not retried; network errors (status 0) and 5xx are.
        if (apiErr.status !== 0 && apiErr.status < 500) {
          throw apiErr;
        }
        lastError = apiErr;
        if (attempt === attempts) {
          throw apiErr;
        }
      } finally {
        request.destroy();
      }

      // Exponential backoff: 300ms, 600ms, 1200ms ...
      await ApiService.delay(300 * Math.pow(2, attempt - 1));
    }

    throw lastError !== null ? lastError : ApiError.network('bilinmeyen hata');
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  private static async handleUnauthorized(): Promise<void> {
    await SessionStore.clear();
    if (ApiService.unauthorizedHandler !== null) {
      ApiService.unauthorizedHandler();
    }
  }

  private static parse<T>(body: string): T {
    return JSON.parse(body) as T;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /**
   * Normalises a phone number to E.164. The backend expects
   * `^\+[1-9]\d{1,14}$`; input with spaces, parentheses or dashes used to 400.
   */
  static normalizePhone(raw: string, defaultCountryCode: string = '+90'): string {
    let digits: string = raw.replace(/[^\d+]/g, '');
    if (digits.startsWith('+')) {
      return `+${digits.substring(1).replace(/\D/g, '')}`;
    }
    digits = digits.replace(/\D/g, '');
    if (digits.startsWith('00')) {
      return `+${digits.substring(2)}`;
    }
    // Local number entered without a country code: drop the leading 0.
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return `${defaultCountryCode}${digits}`;
  }

  static isValidPhone(e164: string): boolean {
    return /^\+[1-9]\d{1,14}$/.test(e164);
  }

  /** The backend expects the letter O; fixes a digit 0 typed in the UI. */
  static normalizeBloodType(raw: string): string {
    return raw.trim().toUpperCase().replace(/^0/, 'O');
  }

  /**
   * Normalises an email address: trims surrounding whitespace and lowercases
   * it. Email addresses are effectively case-insensitive in practice, so
   * "Name@Example.COM" is stored in a single canonical form.
   */
  static normalizeEmail(raw: string): string {
    return raw.trim().toLowerCase();
  }

  /**
   * Email format check.
   *
   * We deliberately do not implement all of RFC 5322 - that regex is unreadable
   * and produces more false positives than real catches. This rule covers the
   * overwhelming majority of user mistakes:
   *   - exactly one "@"
   *   - non-empty on both sides of the "@"
   *   - at least one dot in the domain, followed by at least 2 letters
   *   - no whitespace anywhere
   *
   * Kabul eder : ad.soyad+etiket@alt.alan.com
   * Reddeder   : "asdf", "a@b", "a@b.", "@b.com", "a b@c.com", "a@@b.com"
   */
  static isValidEmail(raw: string): boolean {
    const email: string = ApiService.normalizeEmail(raw);
    if (email.length === 0 || email.length > 254) {
      return false;
    }
    return /^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$/.test(email);
  }

  // ===========================================================================
  // Authentication
  // ===========================================================================

  /** POST /api/register */
  static async register(phoneNumber: string, password: string, displayName?: string): Promise<RegisterResult> {
    const phone: string = ApiService.normalizePhone(phoneNumber);
    if (!ApiService.isValidPhone(phone)) {
      throw new ApiError(400, 'invalid phone', 'Invalid phone number. Example: +905551234567');
    }
    if (password.length < 8) {
      throw new ApiError(400, 'short password', 'Password must be at least 8 characters.');
    }

    const payload: Record<string, string> = { 'phoneNumber': phone, 'password': password };
    if (displayName !== undefined && displayName.trim().length > 0) {
      payload['displayName'] = displayName.trim();
    }

    const result = await ApiService.send('/api/register', http.RequestMethod.POST, {
      auth: false,
      body: JSON.stringify(payload)
    });
    return ApiService.parse<RegisterResult>(result.body);
  }

  /** POST /api/login - persists the token and userId. */
  static async login(phoneNumber: string, password: string): Promise<AuthResult> {
    const phone: string = ApiService.normalizePhone(phoneNumber);
    if (!ApiService.isValidPhone(phone)) {
      throw new ApiError(400, 'invalid phone', 'Invalid phone number. Example: +905551234567');
    }

    const payload: Record<string, string> = { 'phoneNumber': phone, 'password': password };
    const result = await ApiService.send('/api/login', http.RequestMethod.POST, {
      auth: false,
      body: JSON.stringify(payload)
    });

    const auth = ApiService.parse<AuthResult>(result.body);
    // The backend does not send userId today; this code works unchanged once it does.
    const userId: string = auth.userId !== undefined ? auth.userId : '';
    if (userId.length === 0) {
      console.warn('[ApiService] No userId in the login response - fetching your own readings is disabled (backend request BT-01).');
    }
    await SessionStore.saveSession(auth.token, userId, phone);
    return auth;
  }

  static async logout(): Promise<void> {
    const endpointId: string = SessionStore.getNotificationEndpointId();
    if (endpointId.length > 0) {
      try {
        await ApiService.deleteNotificationEndpoint(endpointId);
      } catch (err) {
        console.warn(`[ApiService] Bildirim ucu silinemedi: ${(err as Error).message}`);
      }
    }
    await SessionStore.clear();
  }

  /** GET /api/protected - connectivity and token health check. */
  static async healthCheck(): Promise<boolean> {
    try {
      await ApiService.send('/api/protected', http.RequestMethod.GET, { auth: true });
      return true;
    } catch (err) {
      console.error(`[ApiService] Health check failed: ${(err as Error).message}`);
      return false;
    }
  }

  // ===========================================================================
  // Profil
  // ===========================================================================

  /** GET /api/profile */
  static async getProfile(): Promise<PatientProfile> {
    const result = await ApiService.send('/api/profile', http.RequestMethod.GET, { auth: true });
    return ApiService.parse<PatientProfile>(result.body);
  }

  /** PUT /api/profile */
  static async putProfile(profile: PatientProfile): Promise<void> {
    const payload: PatientProfile = {
      displayName: profile.displayName,
      birthDate: profile.birthDate,
      bloodType: ApiService.normalizeBloodType(profile.bloodType),
      criticalFacts: profile.criticalFacts,
      timezone: profile.timezone
    };
    await ApiService.send('/api/profile', http.RequestMethod.PUT, {
      auth: true,
      body: JSON.stringify(payload)
    });
  }

  // ===========================================================================
  // Vitals
  // ===========================================================================

  /** POST /api/vitals */
  static async sendVitals(heartRate: number, bloodOxygen: number, deviceSn?: string): Promise<void> {
    const payload: Record<string, string | number> = {
      'heartRate': Math.round(heartRate),
      'bloodOxygen': Math.round(bloodOxygen),
      'recordedAt': new Date().toISOString()
    };
    if (deviceSn !== undefined && deviceSn.length > 0) {
      payload['deviceSn'] = deviceSn;
    }
    await ApiService.send('/api/vitals', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload)
    });
  }

  /** GET /api/vitals/{userId}/latest */
  static async getVitalsLatest(userId: string): Promise<VitalsResponse> {
    const result = await ApiService.send(`/api/vitals/${userId}/latest`, http.RequestMethod.GET, { auth: true });
    return ApiService.parse<VitalsResponse>(result.body);
  }

  /**
   * The signed-in user's own latest reading.
   *
   * Unusable until the backend returns `userId` in the `POST /api/login`
   * response - we do not know which UUID to ask for. See backend request BT-01.
   */
  static async getMyVitalsLatest(): Promise<VitalsResponse> {
    const userId: string = SessionStore.getUserId();
    if (userId.length === 0) {
      throw new ApiError(
        501,
        'login response has no userId',
        'Your own readings cannot be shown: the server does not return a user id in the login response.'
      );
    }
    return ApiService.getVitalsLatest(userId);
  }

  // ===========================================================================
  // Documents
  // ===========================================================================

  /** GET /api/documents */
  static async getDocuments(): Promise<DocumentCatalog[]> {
    const result = await ApiService.send('/api/documents', http.RequestMethod.GET, { auth: true });
    return ApiService.parse<DocumentCatalog[]>(result.body);
  }

  /** GET /api/documents/{documentId} */
  static async getDocumentDetail(documentId: string): Promise<DocumentCatalog> {
    const result = await ApiService.send(`/api/documents/${documentId}`, http.RequestMethod.GET, { auth: true });
    return ApiService.parse<DocumentCatalog>(result.body);
  }

  /**
   * POST /api/documents - multipart upload.
   * The returned document id is no longer discarded; it is needed to attach a
   * prescription to a medication plan.
   */
  static async uploadDocument(fileUri: string, kind: string, title: string): Promise<UploadedDocument> {
    const token: string = SessionStore.getToken();
    if (token.length === 0) {
      throw new ApiError(401, 'no token', 'No active session. Please sign in.');
    }

    const fileName: string = ApiService.fileNameFromUri(fileUri);
    const contentType: string = ApiService.contentTypeFromName(fileName);

    let buffer: ArrayBuffer;
    try {
      const file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      if (stat.size > ApiConfig.MAX_UPLOAD_BYTES) {
        fileIo.closeSync(file);
        throw new ApiError(413, 'file too large', 'File exceeds the 10 MB limit.');
      }
      buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      throw new ApiError(400, (err as Error).message, 'Could not read the file.');
    }

    const request = http.createHttp();
    try {
      const response = await request.request(ApiConfig.url('/api/documents'), {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'multipart/form-data'
        } as Record<string, string>,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ApiConfig.CONNECT_TIMEOUT_MS,
        readTimeout: ApiConfig.UPLOAD_TIMEOUT_MS,
        multiFormDataList: [
          { name: 'file', contentType: contentType, data: buffer, remoteFileName: fileName },
          { name: 'kind', contentType: 'text/plain', data: kind },
          { name: 'title', contentType: 'text/plain', data: title }
        ]
      });

      const code: number = response.responseCode;
      const body: string = response.result !== undefined ? response.result as string : '';
      if (code < 200 || code >= 300) {
        const apiError = ApiError.fromStatus(code, body, true);
        if (apiError.isUnauthorized()) {
          await ApiService.handleUnauthorized();
        }
        throw apiError;
      }
      return ApiService.parse<UploadedDocument>(body);
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      throw ApiError.network((err as Error).message);
    } finally {
      request.destroy();
    }
  }

  private static fileNameFromUri(uri: string): string {
    const parts: string[] = uri.split('/');
    const last: string = parts.length > 0 ? parts[parts.length - 1] : '';
    const clean: string = last.split('?')[0];
    return clean.length > 0 ? clean : `upload-${Date.now()}.jpg`;
  }

  private static contentTypeFromName(name: string): string {
    const lower: string = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  // ===========================================================================
  // Medications
  // ===========================================================================

  /**
   * GET /api/medication-catalog
   *
   * The search parameter is named `search` - the backend reads
   * `r.URL.Query().Get("search")` (`medications.go:53`). Sending `q` is silently
   * ignored and the whole catalog comes back.
   */
  static async getMedicationCatalog(query?: string): Promise<MedicationCatalogItem[]> {
    const path: string = query !== undefined && query.length > 0
      ? `/api/medication-catalog?search=${encodeURIComponent(query)}`
      : '/api/medication-catalog';
    const result = await ApiService.send(path, http.RequestMethod.GET, { auth: true });
    return ApiService.parse<MedicationCatalogItem[]>(result.body);
  }

  /** GET /api/medications */
  static async getMedications(): Promise<MedicationResponse[]> {
    const result = await ApiService.send('/api/medications', http.RequestMethod.GET, { auth: true });
    return ApiService.parse<MedicationResponse[]>(result.body);
  }

  /** POST /api/medications */
  static async createMedicationPlan(medData: CreateMedicationRequest): Promise<MedicationResponse> {
    if (medData.frequencyHours !== 6 && medData.frequencyHours !== 12 && medData.frequencyHours !== 24) {
      throw new ApiError(400, 'invalid frequencyHours', 'Dose frequency must be 6, 12, or 24 hours.');
    }
    const result = await ApiService.send('/api/medications', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(medData)
    });
    return ApiService.parse<MedicationResponse>(result.body);
  }

  /** POST /api/medications/{medicationId}/taken */
  static async takeMedicationDose(medicationId: string): Promise<TakenResponse> {
    const result = await ApiService.send(`/api/medications/${medicationId}/taken`, http.RequestMethod.POST, { auth: true });
    return ApiService.parse<TakenResponse>(result.body);
  }

  // ===========================================================================
  // SOS
  // ===========================================================================

  /** POST /api/sos/incidents - emergency alert; retried on failure. */
  static async triggerSOS(lat: number, lng: number, accuracy: number, address: string): Promise<SOSIncident> {
    const payload: Record<string, string | number> = {
      'latitude': lat,
      'longitude': lng,
      'accuracyMeters': accuracy,
      'address': address
    };
    const result = await ApiService.send('/api/sos/incidents', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload),
      retries: ApiConfig.MAX_RETRY
    });
    return ApiService.parse<SOSIncident>(result.body);
  }

  /** POST /api/sos/incidents/{incidentId}/all-clear */
  static async sendSOSAllClear(incidentId: string): Promise<SOSAllClear> {
    const result = await ApiService.send(`/api/sos/incidents/${incidentId}/all-clear`, http.RequestMethod.POST, {
      auth: true,
      retries: ApiConfig.MAX_RETRY
    });
    return ApiService.parse<SOSAllClear>(result.body);
  }

  // ===========================================================================
  // Emergency contacts
  // ===========================================================================

  /** GET /api/emergency-contacts */
  static async getEmergencyContacts(): Promise<EmergencyContact[]> {
    const result = await ApiService.send('/api/emergency-contacts', http.RequestMethod.GET, { auth: true });
    return ApiService.parse<EmergencyContact[]>(result.body);
  }

  /** POST /api/emergency-contacts */
  static async createEmergencyContact(contact: EmergencyContactInput): Promise<EmergencyContact> {
    const phone: string = ApiService.normalizePhone(contact.phone);
    const payload: Record<string, string | boolean> = {
      'displayName': contact.displayName,
      'phone': phone,
      'relationship': contact.relationship,
      'isPrimary': contact.isPrimary !== undefined ? contact.isPrimary : false
    };
    const result = await ApiService.send('/api/emergency-contacts', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload)
    });
    return ApiService.parse<EmergencyContact>(result.body);
  }

  /*
   * PLATFORM LIMITATION - PATCH /api/emergency-contacts/{contactId} cannot be wired.
   *
   * The `http.RequestMethod` enum in HarmonyOS SDK 6.1.1(24) defines only
   * OPTIONS, GET, HEAD, POST, PUT, DELETE, TRACE and CONNECT. There is no PATCH,
   * and forcing a string into the enum is rejected by the ArkTS
   * `arkts-no-any-unknown` rule. So this backend endpoint is unreachable from
   * this client.
   *
   * Options (needs a backend decision):
   *   1. Add a `PUT /api/emergency-contacts/{contactId}` counterpart.
   *   2. Move the client onto Remote Communication Kit (rcp) - it supports
   *      custom HTTP methods, but that means rewriting the whole network layer.
   *
   * Until then, editing a contact is done as delete + re-create (the contact id
   * changes).
   */

  /** DELETE /api/emergency-contacts/{contactId} */
  static async deleteEmergencyContact(contactId: string): Promise<void> {
    await ApiService.send(`/api/emergency-contacts/${contactId}`, http.RequestMethod.DELETE, { auth: true });
  }

  // ===========================================================================
  // Monitoring relationships (patient-approved invitation flow)
  // ===========================================================================

  /**
   * POST /api/patient-link-invitations - PATIENT side.
   * The returned token is printed into the QR; the doctor/family member redeems it.
   */
  static async createLinkInvitation(request: CreateInvitationRequest): Promise<MonitoringInvitation> {
    const payload: Record<string, string | boolean | number> = {
      'relationship': request.relationship,
      'kind': request.kind,
      'canMonitor': request.canMonitor,
      'isEmergencyContact': request.isEmergencyContact !== undefined ? request.isEmergencyContact : false
    };
    if (request.expiresInSeconds !== undefined) {
      payload['expiresInSeconds'] = request.expiresInSeconds;
    }
    const result = await ApiService.send('/api/patient-link-invitations', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload)
    });
    return ApiService.parse<MonitoringInvitation>(result.body);
  }

  /**
   * POST /api/patient-link-invitations/redeem - DOCTOR/FAMILY side.
   * Replaces the old `linkPatient(phone, ...)` method; the backend has no
   * capability for linking directly by phone number.
   */
  static async redeemLinkInvitation(invitationToken: string): Promise<MonitoringRelationship> {
    const payload: Record<string, string> = { 'token': invitationToken.trim() };
    const result = await ApiService.send('/api/patient-link-invitations/redeem', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload)
    });
    return ApiService.parse<MonitoringRelationship>(result.body);
  }

  /** GET /api/monitoring/patients — izlenen hastalar. */
  static async getMonitoredPatients(): Promise<ClinicianPatient[]> {
    const result = await ApiService.send('/api/monitoring/patients', http.RequestMethod.GET, { auth: true });
    const list = ApiService.parse<ClinicianPatient[]>(result.body);
    // The backend sends both displayName and name; if one is empty use the other.
    for (const patient of list) {
      if ((patient.name === undefined || patient.name.length === 0) && patient.displayName !== undefined) {
        patient.name = patient.displayName;
      }
    }
    return list;
  }

  /** GET /api/patient-relationships — "beni kim izliyor". */
  static async getPatientRelationships(): Promise<PatientRelationship[]> {
    const result = await ApiService.send('/api/patient-relationships', http.RequestMethod.GET, { auth: true });
    return ApiService.parse<PatientRelationship[]>(result.body);
  }

  /** DELETE /api/patient-relationships/{relationshipId} — izni geri al. */
  static async revokeRelationship(relationshipId: string): Promise<void> {
    await ApiService.send(`/api/patient-relationships/${relationshipId}`, http.RequestMethod.DELETE, { auth: true });
  }

  // ===========================================================================
  // Emergency access (QR / medical card)
  // ===========================================================================

  /**
   * POST /api/emergency-access/tokens - PATIENT side.
   * The QR must carry ONLY this token, never plain-text medical data.
   */
  static async createEmergencyAccessToken(): Promise<EmergencyAccessToken> {
    const result = await ApiService.send('/api/emergency-access/tokens', http.RequestMethod.POST, { auth: true });
    return ApiService.parse<EmergencyAccessToken>(result.body);
  }

  /** POST /api/emergency-access/redeem - responder side. */
  static async redeemEmergencyToken(accessToken: string): Promise<EmergencyAccessSession> {
    const payload: Record<string, string> = { 'token': accessToken.trim() };
    const result = await ApiService.send('/api/emergency-access/redeem', http.RequestMethod.POST, {
      auth: true,
      body: JSON.stringify(payload)
    });
    return ApiService.parse<EmergencyAccessSession>(result.body);
  }

  /** GET /api/emergency-access/sessions/{sessionId}/medical-card */
  static async getEmergencyMedicalCard(sessionId: string): Promise<EmergencyMedicalCard> {
    const result = await ApiService.send(
      `/api/emergency-access/sessions/${sessionId}/medical-card`,
      http.RequestMethod.GET,
      { auth: true }
    );
    return ApiService.parse<EmergencyMedicalCard>(result.body);
  }

  /** DELETE /api/emergency-access/sessions/{sessionId} */
  static async revokeEmergencySession(sessionId: string): Promise<void> {
    await ApiService.send(`/api/emergency-access/sessions/${sessionId}`, http.RequestMethod.DELETE, { auth: true });
  }

  // ===========================================================================
  // Notification endpoints
  // ===========================================================================

  /** PUT /api/notification-endpoints/{endpointId} */
  static async putNotificationEndpoint(endpointId: string, channel: string, deviceToken: string): Promise<NotificationEndpoint> {
    const payload: Record<string, string> = { 'channel': channel, 'token': deviceToken };
    const result = await ApiService.send(`/api/notification-endpoints/${endpointId}`, http.RequestMethod.PUT, {
      auth: true,
      body: JSON.stringify(payload)
    });
    const endpoint = ApiService.parse<NotificationEndpoint>(result.body);
    await SessionStore.saveNotificationEndpointId(endpointId);
    return endpoint;
  }

  /** DELETE /api/notification-endpoints/{endpointId} */
  static async deleteNotificationEndpoint(endpointId: string): Promise<void> {
    await ApiService.send(`/api/notification-endpoints/${endpointId}`, http.RequestMethod.DELETE, { auth: true });
    await SessionStore.saveNotificationEndpointId('');
  }
}