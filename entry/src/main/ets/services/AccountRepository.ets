import { ApiService, ApiError, UserAccount, RoleFacts } from './ApiService';
import { SessionStore, LocalUserProfile, LocalUserProfilePatch } from './SessionStore';

/**
 * Sync layer for the user's role.
 *
 * The role and the family/doctor details (email, hospital, specialty) used to
 * exist ONLY on the device: `SessionStore` kept them in a phone-number-keyed
 * map, because the backend had no place for them. Signing in on a second
 * device therefore looked like a brand-new account - the role picker and the
 * whole setup flow came up again every time.
 *
 * The backend now owns them: `GET/PUT /api/account` stores `role` plus a
 * free-form `roleFacts` object. The server is the source of truth; the device
 * map is kept as an offline cache so a failed request does not drop the user
 * back into the role picker.
 *
 * NOTE - two different notions of "role":
 *   - the PRIMARY role, stored here and on the server; it decides which
 *     dashboard a login lands on.
 *   - the ACTIVE role in `AppStorage('userRole')`, which ProfilePage's role
 *     switcher flips for the current session only.
 * A role switch must not silently rewrite the primary role, so the switcher
 * still only touches AppStorage.
 */

/** Mirrors AppStorage('doctorProfile'), which the pages read. */
export interface DoctorProfileView {
  hospital: string;
  specialty: string;
  email: string;
  isVerified: boolean;
}

/** View model: the account as the pages need it. */
export interface UiAccount {
  role: string;
  email: string;
  doctorHospital: string;
  doctorSpecialty: string;
  doctorEmail: string;
  doctorVerified: boolean;
}

export interface AccountLoadResult {
  /** false only when the server explicitly answered 404 - no role picked yet. */
  exists: boolean;
  /** true when the server could not be reached and the device cache was used. */
  fromCache: boolean;
  account: UiAccount;
}

const KEY_ROLE: string = 'userRole';
const KEY_EMAIL: string = 'userEmail';
const KEY_DOCTOR: string = 'doctorProfile';

export class AccountRepository {
  private static fromLocal(local: LocalUserProfile): UiAccount {
    return {
      role: local.role,
      email: local.email,
      doctorHospital: local.doctorHospital,
      doctorSpecialty: local.doctorSpecialty,
      doctorEmail: local.doctorEmail,
      doctorVerified: local.doctorVerified
    };
  }

  private static cached(): UiAccount {
    return AccountRepository.fromLocal(SessionStore.getLocalProfile(SessionStore.getPhone()));
  }

  /** Server payload -> view model. Every fact is optional on the wire. */
  private static toUi(account: UserAccount): UiAccount {
    const facts: RoleFacts = account.roleFacts !== undefined ? account.roleFacts : {} as RoleFacts;
    return {
      role: account.role !== undefined ? account.role : '',
      email: facts.email !== undefined ? facts.email : '',
      doctorHospital: facts.doctorHospital !== undefined ? facts.doctorHospital : '',
      doctorSpecialty: facts.doctorSpecialty !== undefined ? facts.doctorSpecialty : '',
      doctorEmail: facts.doctorEmail !== undefined ? facts.doctorEmail : '',
      doctorVerified: facts.doctorVerified !== undefined ? facts.doctorVerified : false
    };
  }

  /** View model -> server payload. */
  private static toWire(account: UiAccount): UserAccount {
    const facts: RoleFacts = {
      email: account.email,
      doctorHospital: account.doctorHospital,
      doctorSpecialty: account.doctorSpecialty,
      doctorEmail: account.doctorEmail,
      doctorVerified: account.doctorVerified
    };
    return { role: account.role, roleFacts: facts };
  }

  /**
   * Server value over cached value, field by field.
   *
   * An empty value from the server does NOT clear a cached one. The cache can
   * legitimately be ahead: `savePatch` writes it before the PUT, so a save that
   * failed offline leaves details here that the server has never seen. Blanking
   * them on the next sign-in would throw that away silently, and nothing in the
   * app ever clears these fields on purpose - so "empty means unknown, not
   * deleted" is the safe reading. The next successful save pushes the merged
   * result up.
   */
  private static mergeOverCache(server: UiAccount): UiAccount {
    const cache: UiAccount = AccountRepository.cached();
    return {
      role: server.role.length > 0 ? server.role : cache.role,
      email: server.email.length > 0 ? server.email : cache.email,
      doctorHospital: server.doctorHospital.length > 0 ? server.doctorHospital : cache.doctorHospital,
      doctorSpecialty: server.doctorSpecialty.length > 0 ? server.doctorSpecialty : cache.doctorSpecialty,
      doctorEmail: server.doctorEmail.length > 0 ? server.doctorEmail : cache.doctorEmail,
      // Verification only ever moves forward, so either side saying "verified"
      // is enough; a stale `false` must not lock a verified doctor out again.
      doctorVerified: server.doctorVerified || cache.doctorVerified
    };
  }

  /**
   * Mirrors the account into AppStorage and into the persistent device cache,
   * so pages reading `@StorageLink('userRole')` / `('doctorProfile')` refresh
   * on their own.
   *
   * `applyRole` guards the ACTIVE role: `AppStorage('userRole')` is what
   * ProfilePage's role switcher flips for the current session, so a background
   * refresh must not write the primary role over it - that would throw a
   * patient who switched to the Doctor view straight back out of it. Only
   * sign-in and an explicit save set the active role.
   */
  private static async mirror(account: UiAccount, applyRole: boolean): Promise<void> {
    if (applyRole && account.role.length > 0) {
      AppStorage.setOrCreate(KEY_ROLE, account.role);
    }
    if (account.email.length > 0) {
      AppStorage.setOrCreate(KEY_EMAIL, account.email);
    }
    // The doctor card is restored whenever the account HAS doctor details, not
    // only when 'doctor' is the current role: the role switcher lets a patient
    // configure a doctor profile as a secondary role, and gating on the primary
    // role used to wipe it back to empty on every sign-in.
    let doctor: DoctorProfileView = { hospital: '', specialty: '', email: '', isVerified: false };
    if (account.doctorEmail.length > 0) {
      doctor = {
        hospital: account.doctorHospital,
        specialty: account.doctorSpecialty,
        email: account.doctorEmail,
        isVerified: account.doctorVerified
      };
    }
    AppStorage.setOrCreate(KEY_DOCTOR, doctor);

    await SessionStore.patchLocalProfile({
      role: account.role.length > 0 ? account.role : undefined,
      email: account.email,
      doctorHospital: account.doctorHospital,
      doctorSpecialty: account.doctorSpecialty,
      doctorEmail: account.doctorEmail,
      doctorVerified: account.doctorVerified
    });
  }

  /**
   * GET /api/account.
   *
   * A 404 means the user has not picked a role yet - that is a normal state for
   * a fresh account, not an error, so it is reported through `exists: false`.
   * Any other failure falls back to the device cache and is reported through
   * `fromCache: true`, so an offline sign-in still lands on the right dashboard.
   */
  static async load(applyRole: boolean = true): Promise<AccountLoadResult> {
    if (!SessionStore.isAuthenticated()) {
      return { exists: false, fromCache: true, account: AccountRepository.cached() };
    }
    try {
      const server: UiAccount = AccountRepository.toUi(await ApiService.getAccount());
      const account: UiAccount = AccountRepository.mergeOverCache(server);
      await AccountRepository.mirror(account, applyRole);
      console.info(`[API] GET /api/account - OK, role=${account.role}`);
      return { exists: true, fromCache: false, account: account };
    } catch (err) {
      const status: number = err instanceof ApiError ? (err as ApiError).status : -1;
      if (status === 404) {
        // No account row on the server. For anyone who picked their role before
        // the role moved server-side, the answer is not "no role" - it is "the
        // role is still only on this device". Without this migration such a
        // user silently became a patient on the next sign-in, losing the
        // doctor/family dashboard (and with it the QR linking that lives there).
        const local: UiAccount = AccountRepository.cached();
        if (local.role.length > 0) {
          console.info(`[API] GET /api/account - 404; migrating the device role '${local.role}' to the server.`);
          const migrated: UiAccount | undefined = await AccountRepository.push(local);
          if (migrated !== undefined) {
            await AccountRepository.mirror(migrated, applyRole);
            return { exists: true, fromCache: false, account: migrated };
          }
          // The push failed (offline, server down). The device still knows the
          // role, so the session is not downgraded over it.
          return { exists: false, fromCache: true, account: local };
        }
        console.info('[API] GET /api/account - 404, no role picked yet.');
        return { exists: false, fromCache: false, account: local };
      }
      console.warn(`[API] GET /api/account - failed (status=${status}): ${(err as Error).message}`);
      return { exists: false, fromCache: true, account: AccountRepository.cached() };
    }
  }

  /**
   * Merges `patch` into the cached account and writes the whole thing back with
   * `PUT /api/account`.
   *
   * The merge is what makes the full-replace endpoint safe: updating only
   * `doctorVerified`, say, still sends the email and the hospital along, so the
   * server does not lose them.
   *
   * @returns the saved account, or `undefined` when it could not be written to
   *          the server (the device cache is updated either way).
   */
  static async savePatch(patch: LocalUserProfilePatch): Promise<UiAccount | undefined> {
    await SessionStore.patchLocalProfile(patch);
    const merged: UiAccount = AccountRepository.cached();

    if (merged.role.length === 0) {
      // Nothing to write: the backend rejects an account without a role.
      return undefined;
    }
    if (!SessionStore.isAuthenticated()) {
      return undefined;
    }

    const saved: UiAccount | undefined = await AccountRepository.push(merged);
    if (saved === undefined) {
      return undefined;
    }

    // Only a patch that deliberately carries a role may move the active one.
    // A patch WITHOUT a role (configuring a secondary role, confirming doctor
    // verification) still writes the stored primary role to the server, and
    // applying it here would flip the screen the user is standing on back to
    // that primary role.
    const rolePatched: boolean = patch.role !== undefined && patch.role.length > 0;
    await AccountRepository.mirror(saved, rolePatched);
    return saved;
  }

  /**
   * PUT /api/account. Returns undefined when it could not be written, leaving
   * the caller to decide what that means for its own flow.
   */
  private static async push(account: UiAccount): Promise<UiAccount | undefined> {
    try {
      const saved: UiAccount = AccountRepository.toUi(
        await ApiService.putAccount(AccountRepository.toWire(account)));
      console.info(`[API] PUT /api/account - OK, role=${saved.role}`);
      return saved;
    } catch (err) {
      // The local copy is already updated, so the screen stays consistent; the
      // next successful save pushes it up.
      console.warn(`[API] PUT /api/account - failed: ${(err as Error).message}`);
      return undefined;
    }
  }

  /**
   * Refresh on open without blocking the screen. Leaves the active role alone -
   * see `mirror`.
   */
  static async refreshQuietly(): Promise<void> {
    await AccountRepository.load(false);
  }
}
