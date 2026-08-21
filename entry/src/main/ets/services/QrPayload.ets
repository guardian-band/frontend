/**
 * QR code payload format.
 *
 * PROBLEM: the app has two distinct QR flows and each needs a **different kind**
 * of token:
 *
 *   1. Patient-doctor linking     -> POST /api/patient-link-invitations/redeem
 *   2. Emergency access (med card) -> POST /api/emergency-access/redeem
 *
 * The tokens are not interchangeable; a token sent to the wrong endpoint is
 * rejected with `400 invalid or expired token`. The QR previously carried only a
 * bare token, so the scanner could not tell which kind it was and the user just
 * saw "QR does not scan / server error".
 *
 * SOLUTION: tag the QR payload with its kind.
 *
 *   GB1:LINK:<token>   -> monitoring invitation
 *   GB1:EMG:<token>    -> emergency access
 *
 * `GB1` is a format version prefix so older clients are not confused if the
 * format changes later.
 */

export enum QrKind {
  /** Patient-doctor/family monitoring invitation. */
  LINK = 'LINK',
  /** Emergency access medical-card session. */
  EMERGENCY = 'EMG',
  /** Kind could not be determined (untagged bare token). */
  UNKNOWN = 'UNKNOWN',
  /** Plain-text JSON card produced by older versions. No longer supported. */
  LEGACY_JSON = 'LEGACY_JSON'
}

export interface QrContent {
  kind: QrKind;
  token: string;
}

const PREFIX: string = 'GB1:';

export class QrPayload {
  /** Monitoring invitation QR payload. */
  static encodeLink(token: string): string {
    return `${PREFIX}${QrKind.LINK}:${token}`;
  }

  /** Emergency access QR payload. */
  static encodeEmergency(token: string): string {
    return `${PREFIX}${QrKind.EMERGENCY}:${token}`;
  }

  /**
   * Decodes scanned QR text.
   * With no tag the kind is UNKNOWN; the caller decides based on its own context.
   */
  static decode(raw: string): QrContent {
    const text: string = raw !== undefined ? raw.trim() : '';
    if (text.length === 0) {
      return { kind: QrKind.UNKNOWN, token: '' };
    }

    // Older versions printed a plain-text JSON medical card into the QR.
    if (text.startsWith('{')) {
      return { kind: QrKind.LEGACY_JSON, token: '' };
    }

    if (text.startsWith(PREFIX)) {
      const rest: string = text.substring(PREFIX.length);
      const sep: number = rest.indexOf(':');
      if (sep > 0) {
        const tag: string = rest.substring(0, sep);
        const token: string = rest.substring(sep + 1);
        if (tag === QrKind.LINK) {
          return { kind: QrKind.LINK, token: token };
        }
        if (tag === QrKind.EMERGENCY) {
          return { kind: QrKind.EMERGENCY, token: token };
        }
      }
      return { kind: QrKind.UNKNOWN, token: rest };
    }

    // Untagged: could be an old QR or a manually entered code.
    return { kind: QrKind.UNKNOWN, token: text };
  }

  /** Message shown when a QR of the wrong kind is scanned. */
  static wrongKindMessage(expected: QrKind): string {
    if (expected === QrKind.LINK) {
      return 'This QR is not a patient link invitation. Ask the patient to show the "Link to Doctor" QR code from their profile.';
    }
    return 'This QR is not an emergency access code. Ask the patient to show the "Emergency Access" QR code from their profile.';
  }

  /** Shown when a legacy-format QR is scanned. */
  static legacyMessage(): string {
    return 'This QR is from an older version and is no longer valid. The patient needs to update the app and generate a new code.';
  }
}

/** Small formatting helpers for on-screen display. */
export class DisplayFormat {
  /**
   * Converts an ISO 8601 timestamp into a readable local format.
   * `2026-08-21T15:05:26.389Z` -> `21.08.2026 18:05`
   */
  static dateTime(iso?: string): string {
    if (iso === undefined || iso.length === 0) {
      return 'No data';
    }
    const d = new Date(iso);
    if (isNaN(d.getTime())) {
      return iso;
    }
    const pad = (n: number): string => `${n}`.padStart(2, '0');
    return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   * Shortens long identifiers so they fit inside their container.
   * `c54f96d9-5535-415e-bbd4-83e87f18ca30` -> `c54f96d9…8ca30`
   */
  static shortId(id?: string): string {
    if (id === undefined || id.length === 0) {
      return '-';
    }
    if (id.length <= 18) {
      return id;
    }
    return `${id.substring(0, 8)}…${id.substring(id.length - 5)}`;
  }
}