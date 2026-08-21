/**
 * Network layer configuration.
 *
 * BASE_URL is no longer hard-coded inside ApiService. The environment is chosen
 * here, in one place.
 *
 * IMPORTANT: on a device or emulator `localhost` is NOT the machine running the
 * backend - it is the device itself. Pick the correct address below.
 */

export interface ApiEnvironment {
  name: string;
  baseUrl: string;
  description: string;
}

export class ApiConfig {
  /** Standard NAT address from the emulator to the host machine. */
  static readonly EMULATOR: ApiEnvironment = {
    name: 'emulator',
    baseUrl: 'http://10.0.2.2:3000',
    description: 'Emulator -> host machine (NAT gateway)'
  };

  /** Physical device: update the host machine LAN IP for your own network. */
  static readonly DEVICE: ApiEnvironment = {
    name: 'device',
    baseUrl: 'http://192.168.1.100:3000',
    description: 'Physical device -> host machine (LAN IP - update for your own network)'
  };

  /** For previews running on the same machine. */
  static readonly LOCAL: ApiEnvironment = {
    name: 'local',
    baseUrl: 'http://localhost:3000',
    description: 'Only for previews running on the same machine as the backend'
  };

  static readonly STAGING: ApiEnvironment = {
    name: 'staging',
    baseUrl: 'https://staging.guardianband.example',
    description: 'Staging environment (TLS)'
  };

  static readonly PRODUCTION: ApiEnvironment = {
    name: 'production',
    baseUrl: 'https://api.guardianband.example',
    description: 'Production environment (TLS)'
  };

  // ---------------------------------------------------------------------------
  // Active environment. This is the ONLY place to change during development.
  // ---------------------------------------------------------------------------
  private static activeName: string = ApiConfig.EMULATOR.name;
  private static activeBaseUrl: string = ApiConfig.EMULATOR.baseUrl;

  static useEnvironment(env: ApiEnvironment): void {
    ApiConfig.activeName = env.name;
    ApiConfig.activeBaseUrl = env.baseUrl;
    console.info(`[ApiConfig] Aktif ortam: ${env.name} -> ${env.baseUrl}`);
  }

  /** For a custom address that is not in the environment list. */
  static useBaseUrl(baseUrl: string): void {
    ApiConfig.activeName = 'custom';
    ApiConfig.activeBaseUrl = baseUrl;
    console.info(`[ApiConfig] Aktif ortam: custom -> ${baseUrl}`);
  }

  static environmentName(): string {
    return ApiConfig.activeName;
  }

  static baseUrl(): string {
    return ApiConfig.activeBaseUrl;
  }

  /** Turns a relative path into a full URL. */
  static url(path: string): string {
    return `${ApiConfig.activeBaseUrl}${path}`;
  }

  static isCleartext(): boolean {
    return ApiConfig.activeBaseUrl.startsWith('http://');
  }

  /**
   * The device time zone. Profile saves previously hard-coded 'Europe/Istanbul',
   * which was wrong for any user outside that zone.
   */
  static deviceTimezone(): string {
    try {
      const zone: string = Intl.DateTimeFormat().resolvedOptions().timeZone;
      return zone && zone.length > 0 ? zone : 'Europe/Istanbul';
    } catch (err) {
      return 'Europe/Istanbul';
    }
  }

  // --- Timeouts and limits ----------------------------------------------------

  static readonly CONNECT_TIMEOUT_MS: number = 10000;
  static readonly READ_TIMEOUT_MS: number = 15000;
  /** File uploads can take longer. */
  static readonly UPLOAD_TIMEOUT_MS: number = 60000;
  /** Backend multipart limit is 10 MB; we enforce the same limit client-side. */
  static readonly MAX_UPLOAD_BYTES: number = 10 * 1024 * 1024;
  /** Attempt count for calls that are retried. */
  static readonly MAX_RETRY: number = 3;
}