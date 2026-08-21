import { ApiService, PatientProfile, CriticalFacts } from './ApiService';
import { SessionStore } from './SessionStore';

/**
 * Sync layer for the health profile.
 *
 * The backend `PatientProfile` schema defines only four top-level fields:
 * `displayName`, `birthDate`, `bloodType`, `timezone`. Everything else the UI
 * collects (gender, height, weight, chronic conditions, allergies, pacemaker,
 * hearing aid) travels inside the free-form `criticalFacts` object.
 *
 * This file is the ONE place that maps between the two models. The write side
 * (ProfileSetupPage) already put those fields into criticalFacts, but the read
 * side only restored bloodType and birthDate - so after signing in again the
 * name, height, weight, gender and conditions appeared to be lost.
 */

/** View model the pages read through AppStorage('medicalProfile'). */
export interface UiMedicalProfile {
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

const KEY_PROFILE: string = 'medicalProfile';
const KEY_FULL_NAME: string = 'fullName';

export class ProfileRepository {
  private static emptyProfile(): UiMedicalProfile {
    return {
      birthDate: '', gender: '', height: '', weight: '', bloodType: '',
      diseases: [], otherChronicDisease: '', allergies: '',
      pacemaker: false, hearingAid: false
    };
  }

  /** Converts the server schema into the UI model. */
  static toUi(profile: PatientProfile): UiMedicalProfile {
    const facts: CriticalFacts = profile.criticalFacts !== undefined
      ? profile.criticalFacts : {} as CriticalFacts;

    const allergyList: string[] = facts.allergies !== undefined ? facts.allergies : [];
    const conditionList: string[] = facts.chronicConditions !== undefined ? facts.chronicConditions : [];

    return {
      birthDate: profile.birthDate !== undefined ? profile.birthDate : '',
      bloodType: profile.bloodType !== undefined ? profile.bloodType : '',
      gender: facts.gender !== undefined ? facts.gender : '',
      // Stored as a number on the server, as text in the UI. 0 is not a
      // meaningful height/weight, so it maps to an empty string.
      height: facts.heightCm !== undefined && facts.heightCm > 0 ? `${facts.heightCm}` : '',
      weight: facts.weightKg !== undefined && facts.weightKg > 0 ? `${facts.weightKg}` : '',
      diseases: conditionList,
      otherChronicDisease: '',
      // The UI expects a single line; the server array is joined with commas.
      allergies: allergyList.join(', '),
      pacemaker: facts.pacemaker !== undefined ? facts.pacemaker : false,
      hearingAid: facts.hearingAid !== undefined ? facts.hearingAid : false
    };
  }

  /**
   * GET /api/profile - fetches the server profile and mirrors it into
   * AppStorage. Pages already read it via `@StorageLink('medicalProfile')`,
   * so screens refresh on their own.
   */
  static async load(): Promise<UiMedicalProfile> {
    if (!SessionStore.isAuthenticated()) {
      const cached = AppStorage.get<UiMedicalProfile>(KEY_PROFILE);
      return cached !== undefined ? cached : ProfileRepository.emptyProfile();
    }

    const profile: PatientProfile = await ApiService.getProfile();
    const ui: UiMedicalProfile = ProfileRepository.toUi(profile);
    AppStorage.setOrCreate(KEY_PROFILE, ui);

    // The name is on the server too: saved as displayName during registration.
    if (profile.displayName !== undefined && profile.displayName.length > 0) {
      AppStorage.setOrCreate(KEY_FULL_NAME, profile.displayName);
    }
    return ui;
  }

  /** Refresh on open without blocking the screen. */
  static async refreshQuietly(): Promise<void> {
    try {
      await ProfileRepository.load();
      console.info('[ProfileRepository] Profile refreshed from server.');
    } catch (err) {
      // 404 = profile not created yet. Expected; stay silent.
      console.warn(`[ProfileRepository] Could not refresh profile: ${(err as Error).message}`);
    }
  }
}