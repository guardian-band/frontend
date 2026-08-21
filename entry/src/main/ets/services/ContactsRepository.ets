import { ApiService, EmergencyContact, EmergencyContactInput } from './ApiService';
import { SessionStore } from './SessionStore';

/**
 * Sync layer for emergency contacts.
 *
 * This list used to live only in AppStorage('sosContacts'), i.e. on the device.
 * The backend reads SOS notification targets from the emergency_contacts table,
 * so that table stayed empty and SOS alerts reached nobody.
 *
 * This file maps between the two models:
 *   UI     : { id, fullName, phone, relation }
 *   Backend: { id, displayName, phone, relationship, isPrimary }
 */

/** View model used by the pages. */
export interface UiEmergencyContact {
  id: string;
  fullName: string;
  phone: string;
  relation: string;
}

const STORAGE_KEY: string = 'sosContacts';

export class ContactsRepository {
  private static toUi(contact: EmergencyContact): UiEmergencyContact {
    return {
      id: contact.id,
      fullName: contact.displayName,
      phone: contact.phone,
      relation: contact.relationship
    };
  }

  private static writeToStorage(list: UiEmergencyContact[]): void {
    AppStorage.setOrCreate(STORAGE_KEY, list);
  }

  private static readFromStorage(): UiEmergencyContact[] {
    const cached = AppStorage.get<UiEmergencyContact[]>(STORAGE_KEY);
    return cached !== undefined ? cached : [];
  }

  /**
   * Loads from the backend and refreshes the local cache.
   * On a network error the cached list is kept and the error is rethrown.
   */
  static async load(): Promise<UiEmergencyContact[]> {
    if (!SessionStore.isAuthenticated()) {
      return ContactsRepository.readFromStorage();
    }
    const remote: EmergencyContact[] = await ApiService.getEmergencyContacts();
    const list: UiEmergencyContact[] = remote.map((c: EmergencyContact) => ContactsRepository.toUi(c));
    ContactsRepository.writeToStorage(list);
    return list;
  }

  /** Refresh without blocking the UI when it fails. */
  static async refreshQuietly(): Promise<void> {
    try {
      await ContactsRepository.load();
    } catch (err) {
      console.warn(`[ContactsRepository] Could not refresh contacts: ${(err as Error).message}`);
    }
  }

  /** Writes to the backend, then updates the local list. */
  static async add(fullName: string, phone: string, relation: string, isPrimary: boolean = false): Promise<UiEmergencyContact> {
    const input: EmergencyContactInput = {
      displayName: fullName,
      phone: phone,
      relationship: relation,
      isPrimary: isPrimary
    };
    const created: EmergencyContact = await ApiService.createEmergencyContact(input);
    const ui: UiEmergencyContact = ContactsRepository.toUi(created);
    const list: UiEmergencyContact[] = ContactsRepository.readFromStorage();
    list.push(ui);
    ContactsRepository.writeToStorage([...list]);
    return ui;
  }

  /**
   * Editing a contact is currently done as delete + re-create.
   *
   * Reason: the backend expects `PATCH /api/emergency-contacts/{id}`, but the
   * HarmonyOS SDK 6.1.1(24) http stack does not support the PATCH method (see
   * the "PLATFORM LIMITATION" note in ApiService). This path changes the
   * contact id - fix it once the backend adds a PUT counterpart.
   */
  static async update(contactId: string, fullName: string, phone: string, relation: string): Promise<UiEmergencyContact> {
    await ContactsRepository.remove(contactId);
    return ContactsRepository.add(fullName, phone, relation);
  }

  static async remove(contactId: string): Promise<void> {
    await ApiService.deleteEmergencyContact(contactId);
    const list: UiEmergencyContact[] = ContactsRepository.readFromStorage()
      .filter((c: UiEmergencyContact) => c.id !== contactId);
    ContactsRepository.writeToStorage(list);
  }

  static count(): number {
    return ContactsRepository.readFromStorage().length;
  }

  /** So the SOS screen can show a warning. */
  static isEmpty(): boolean {
    return ContactsRepository.count() === 0;
  }
}