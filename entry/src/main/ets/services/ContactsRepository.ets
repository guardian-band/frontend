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
  /**
   * Carried through because `PUT /api/emergency-contacts/{id}` is a full
   * replace: an edit that did not send the current value would silently demote
   * the primary contact.
   */
  isPrimary: boolean;
}

const STORAGE_KEY: string = 'sosContacts';

export class ContactsRepository {
  private static toUi(contact: EmergencyContact): UiEmergencyContact {
    return {
      id: contact.id,
      fullName: contact.displayName,
      phone: contact.phone,
      relation: contact.relationship,
      isPrimary: contact.isPrimary
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
   * Edits a contact in place through `PUT /api/emergency-contacts/{id}`.
   *
   * This used to be a delete + re-create, because the backend only offered
   * PATCH and the HarmonyOS SDK 6.1.1(24) http stack cannot send that method.
   * The workaround changed the contact id on every edit; the PUT counterpart
   * keeps it stable.
   *
   * PUT replaces the whole record, so `isPrimary` is taken from the cached
   * contact when the caller does not pass one - otherwise editing a name would
   * also clear the primary flag.
   */
  static async update(contactId: string, fullName: string, phone: string, relation: string,
                      isPrimary?: boolean): Promise<UiEmergencyContact> {
    const list: UiEmergencyContact[] = ContactsRepository.readFromStorage();
    const cached: UiEmergencyContact | undefined = list.find((c: UiEmergencyContact) => c.id === contactId);
    const primary: boolean = isPrimary !== undefined
      ? isPrimary
      : (cached !== undefined ? cached.isPrimary : false);

    const input: EmergencyContactInput = {
      displayName: fullName,
      phone: phone,
      relationship: relation,
      isPrimary: primary
    };
    const updated: EmergencyContact = await ApiService.updateEmergencyContact(contactId, input);
    const ui: UiEmergencyContact = ContactsRepository.toUi(updated);

    const index: number = list.findIndex((c: UiEmergencyContact) => c.id === contactId);
    if (index !== -1) {
      list[index] = ui;
    } else {
      list.push(ui);
    }
    ContactsRepository.writeToStorage([...list]);
    return ui;
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