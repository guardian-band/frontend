import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * Persistent store for session state.
 *
 * The token used to live only in AppStorage (in memory), so the session was
 * lost whenever the app closed. Here it is persisted with `preferences`.
 *
 * The AppStorage mirror is kept: every write is also reflected into AppStorage
 * so existing pages can keep reading via AppStorage.get('token').
 */

const STORE_NAME: string = 'guardianband_session';
const KEY_TOKEN: string = 'token';
const KEY_USER_ID: string = 'userId';
const KEY_PHONE: string = 'userPhone';
const KEY_ROLE: string = 'userRole';
const KEY_ENDPOINT_ID: string = 'notificationEndpointId';
/**
 * Phone number -> per-user local profile map.
 * Offline cache of the account (role + role facts) that the backend owns; see
 * `AccountRepository`.
 */
const KEY_PROFILE_MAP: string = 'userProfiles';

/**
 * The account as cached on this device, per user.
 *
 * These fields all live on the server now: `role` is `UserAccount.role` and the
 * rest are keys inside its free-form `roleFacts`. The device copy exists so a
 * sign-in with no connection still knows which dashboard to open; the server
 * wins whenever it answers.
 */
export interface LocalUserProfile {
  role: string;
  /** Family member email. */
  email: string;
  doctorHospital: string;
  doctorSpecialty: string;
  doctorEmail: string;
  doctorVerified: boolean;
}

/** For partial updates. ArkTS does not support the `Partial<T>` utility type. */
export interface LocalUserProfilePatch {
  role?: string;
  email?: string;
  doctorHospital?: string;
  doctorSpecialty?: string;
  doctorEmail?: string;
  doctorVerified?: boolean;
}

export class SessionStore {
  private static store: preferences.Preferences | null = null;
  private static token: string = '';
  private static userId: string = '';
  private static phone: string = '';
  private static role: string = '';
  private static endpointId: string = '';
  private static roleMapRaw: string = '';
  private static ready: boolean = false;

  /**
   * Called at app start (EntryAbility.onCreate).
   * If the persistent store cannot be opened the app does not crash; it keeps
   * running in memory.
   */
  static async attach(context: common.Context): Promise<void> {
    try {
      SessionStore.store = await preferences.getPreferences(context, STORE_NAME);
      SessionStore.token = await SessionStore.readString(KEY_TOKEN);
      SessionStore.userId = await SessionStore.readString(KEY_USER_ID);
      SessionStore.phone = await SessionStore.readString(KEY_PHONE);
      SessionStore.role = await SessionStore.readString(KEY_ROLE);
      SessionStore.endpointId = await SessionStore.readString(KEY_ENDPOINT_ID);
      SessionStore.roleMapRaw = await SessionStore.readString(KEY_PROFILE_MAP);
      SessionStore.ready = true;
      SessionStore.mirrorToAppStorage();
      console.info(`[SessionStore] Session loaded. Has token: ${SessionStore.token.length > 0}`);
    } catch (err) {
      SessionStore.store = null;
      SessionStore.ready = true;
      console.error(`[SessionStore] Could not open persistent store, continuing in memory: ${(err as Error).message}`);
    }
  }

  private static async readString(key: string): Promise<string> {
    if (SessionStore.store === null) {
      return '';
    }
    const value = await SessionStore.store.get(key, '');
    return typeof value === 'string' ? value as string : '';
  }

  private static async writeString(key: string, value: string): Promise<void> {
    if (key === KEY_PROFILE_MAP) {
      // Keep the in-memory copy fresh even if the store failed to open.
      SessionStore.roleMapRaw = value;
    }
    if (SessionStore.store === null) {
      return;
    }
    try {
      await SessionStore.store.put(key, value);
      await SessionStore.store.flush();
    } catch (err) {
      console.error(`[SessionStore] Could not write '${key}': ${(err as Error).message}`);
    }
  }

  /** So existing pages can keep reading through AppStorage. */
  private static mirrorToAppStorage(): void {
    AppStorage.setOrCreate(KEY_TOKEN, SessionStore.token);
    AppStorage.setOrCreate(KEY_USER_ID, SessionStore.userId);
    if (SessionStore.phone.length > 0) {
      AppStorage.setOrCreate(KEY_PHONE, SessionStore.phone);
    }
    if (SessionStore.role.length > 0) {
      AppStorage.setOrCreate(KEY_ROLE, SessionStore.role);
    }
  }

  // --- Reads ------------------------------------------------------------------

  static getToken(): string {
    if (SessionStore.token.length > 0) {
      return SessionStore.token;
    }
    // Fall back to AppStorage if the store is not open yet.
    const fromAppStorage = AppStorage.get<string>(KEY_TOKEN);
    return fromAppStorage !== undefined ? fromAppStorage : '';
  }

  static getUserId(): string {
    if (SessionStore.userId.length > 0) {
      return SessionStore.userId;
    }
    const fromAppStorage = AppStorage.get<string>(KEY_USER_ID);
    return fromAppStorage !== undefined ? fromAppStorage : '';
  }

  static getPhone(): string {
    return SessionStore.phone;
  }

  /**
   * Cached role of the signed-in user. The per-user record wins, since the
   * global key is only a leftover mirror.
   *
   * Reads the DEVICE cache. Anything that needs the authoritative value should
   * go through `AccountRepository`, and anything writing a role must go through
   * it - a role written only here would never reach the server.
   */
  static getRole(): string {
    const perUser: string = SessionStore.getRoleForPhone(SessionStore.phone);
    if (perUser.length > 0) {
      return perUser;
    }
    return SessionStore.role;
  }

  static getNotificationEndpointId(): string {
    return SessionStore.endpointId;
  }

  static isAuthenticated(): boolean {
    return SessionStore.getToken().length > 0;
  }

  // --- Writes -----------------------------------------------------------------

  /**
   * Persists a freshly obtained session.
   *
   * When the incoming session belongs to a DIFFERENT user than the one already
   * in the store, the device view caches are wiped first. AppStorage lives in
   * memory for the life of the process and was only ever cleared on sign-out,
   * so signing in as another account - or registering a new one - while the
   * previous account's data was still loaded left that data on screen. The
   * setup form then opened pre-filled with the PREVIOUS patient's birth date,
   * blood type, chronic conditions and allergies, and saving it wrote them onto
   * the new patient's profile: wrong data on someone else's emergency card,
   * not just a cosmetic glitch.
   *
   * Signing in again as the same user keeps the caches, so nothing flickers on
   * an ordinary re-login.
   */
  static async saveSession(token: string, userId: string, phone: string): Promise<void> {
    const isDifferentUser: boolean = userId.length > 0
      ? userId !== SessionStore.userId
      : phone !== SessionStore.phone;
    if (isDifferentUser) {
      console.info('[SessionStore] A different account signed in; device caches cleared.');
      SessionStore.clearDeviceViewCaches();
      // The in-memory role belongs to the previous account. Without this the
      // mirror below would write it straight back into AppStorage, undoing part
      // of the clear.
      SessionStore.role = '';
    }

    SessionStore.token = token;
    SessionStore.userId = userId;
    SessionStore.phone = phone;
    SessionStore.mirrorToAppStorage();
    await SessionStore.writeString(KEY_TOKEN, token);
    await SessionStore.writeString(KEY_USER_ID, userId);
    await SessionStore.writeString(KEY_PHONE, phone);
  }

  private static readProfileMap(): Record<string, LocalUserProfile> {
    if (SessionStore.roleMapRaw.length === 0) {
      return {};
    }
    try {
      return JSON.parse(SessionStore.roleMapRaw) as Record<string, LocalUserProfile>;
    } catch (err) {
      console.error(`[SessionStore] Could not read user profile map: ${(err as Error).message}`);
      return {};
    }
  }

  private static emptyLocalProfile(): LocalUserProfile {
    return {
      role: '', email: '',
      doctorHospital: '', doctorSpecialty: '', doctorEmail: '', doctorVerified: false
    };
  }

  /**
   * Partially updates the device cache of the account.
   *
   * This data used to live only in AppStorage (i.e. IN MEMORY); it was wiped on
   * sign-out and lost when the app closed, so setup was requested again on
   * every sign-in even after it had been completed. It is persisted here and
   * owned by the backend.
   *
   * Writing here does NOT reach the server. Call
   * `AccountRepository.savePatch()` instead; it updates this cache and then
   * pushes the merged account with `PUT /api/account`.
   */
  static async patchLocalProfile(patch: LocalUserProfilePatch): Promise<void> {
    const phone: string = SessionStore.phone;
    if (phone.length === 0) {
      console.warn('[SessionStore] Phone unknown; local profile could not be bound to a user.');
      return;
    }
    const map: Record<string, LocalUserProfile> = SessionStore.readProfileMap();
    const current: LocalUserProfile = map[phone] !== undefined
      ? map[phone] : SessionStore.emptyLocalProfile();

    if (patch.role !== undefined) {
      current.role = patch.role;
    }
    if (patch.email !== undefined) {
      current.email = patch.email;
    }
    if (patch.doctorHospital !== undefined) {
      current.doctorHospital = patch.doctorHospital;
    }
    if (patch.doctorSpecialty !== undefined) {
      current.doctorSpecialty = patch.doctorSpecialty;
    }
    if (patch.doctorEmail !== undefined) {
      current.doctorEmail = patch.doctorEmail;
    }
    if (patch.doctorVerified !== undefined) {
      current.doctorVerified = patch.doctorVerified;
    }

    map[phone] = current;
    await SessionStore.writeString(KEY_PROFILE_MAP, JSON.stringify(map));
  }

  /** Device-stored profile for a given phone. Empty record if none. */
  static getLocalProfile(phone: string): LocalUserProfile {
    if (phone.length === 0) {
      return SessionStore.emptyLocalProfile();
    }
    const map: Record<string, LocalUserProfile> = SessionStore.readProfileMap();
    const found: LocalUserProfile | undefined = map[phone];
    return found !== undefined ? found : SessionStore.emptyLocalProfile();
  }

  /** Stored role for a given phone number. Empty string if none. */
  static getRoleForPhone(phone: string): string {
    return SessionStore.getLocalProfile(phone).role;
  }

  static async saveNotificationEndpointId(id: string): Promise<void> {
    SessionStore.endpointId = id;
    await SessionStore.writeString(KEY_ENDPOINT_ID, id);
  }

  /** Clears the session completely on sign-out or a 401. */
  static async clear(): Promise<void> {
    SessionStore.token = '';
    SessionStore.userId = '';
    SessionStore.phone = '';
    SessionStore.endpointId = '';
    // The in-session role is reset; the user->role map is kept so the role is
    // remembered when the same account signs in again.
    SessionStore.role = '';
    AppStorage.setOrCreate(KEY_TOKEN, '');
    AppStorage.setOrCreate(KEY_USER_ID, '');
    SessionStore.clearDeviceViewCaches();
    if (SessionStore.store !== null) {
      try {
        await SessionStore.store.delete(KEY_TOKEN);
        await SessionStore.store.delete(KEY_USER_ID);
        await SessionStore.store.delete(KEY_ENDPOINT_ID);
        await SessionStore.store.flush();
      } catch (err) {
        console.error(`[SessionStore] Clear failed: ${(err as Error).message}`);
      }
    }
  }

  /**
   * Wipes the per-account view-model caches that pages mirror into
   * AppStorage (medications, vitals history, medical profile, contacts, ...).
   *
   * These used to survive sign-out entirely. AppStorage lives in memory for
   * the life of the process, and none of these keys were ever reset on
   * logout - only a handful (fullName/profilePicture/userRole/userEmail/
   * medicalProfile) were manually cleared, and only on the ProfilePage
   * sign-out button specifically, not on a 401. The result: the medications
   * one account added kept showing up for the NEXT account signed in on the
   * same device (and the same happened for contacts, vitals history, etc.) -
   * every one of these is either meaningless without a session or gets
   * re-fetched from the server on the next page load, so clearing them here
   * is safe and closes the leak for both sign-out and session-expiry (401).
   */
  private static clearDeviceViewCaches(): void {
    AppStorage.setOrCreate('medications', [] as object[]);
    AppStorage.setOrCreate('dashboardMeds', [] as object[]);
    AppStorage.setOrCreate('heartRateHistory', [] as number[]);
    AppStorage.setOrCreate('oxygenHistory', [] as number[]);
    AppStorage.setOrCreate('sosContacts', [] as object[]);
    AppStorage.setOrCreate('fullName', '');
    AppStorage.setOrCreate('profilePicture', '');
    AppStorage.setOrCreate('userEmail', '');
    AppStorage.setOrCreate('userRole', 'patient');
    AppStorage.setOrCreate('doctorProfile', { hospital: '', specialty: '', email: '', isVerified: false });
    AppStorage.setOrCreate('medicalProfile', {
      birthDate: '', gender: '', height: '', weight: '', bloodType: '',
      diseases: [] as string[], otherChronicDisease: '', allergies: '',
      pacemaker: false, hearingAid: false, bandIdentifier: ''
    });
  }

  static isReady(): boolean {
    return SessionStore.ready;
  }
}