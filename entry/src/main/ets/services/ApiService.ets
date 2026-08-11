import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';

export interface DocumentCatalog {
  id: string;
  kind: string;
  title: string;
  contentType: string;
  currentVersionId: string;
  createdAt: string;
  updatedAt: string;
}

export interface PatientProfile {
  birthDate: string;
  bloodType: string;
  criticalFacts: Object;
  timezone: string;
}

export interface CreateMedicationRequest {
  name: string;
  strength: string;
  instructions: string;
  frequencyHours: number;
}

export class ApiService {
  private static readonly BASE_URL: string = 'http://localhost:3000';
  private static readonly MOCK_MODE: boolean = false;

  public static async register(phoneNumber: string, password: string): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(`${ApiService.BASE_URL}/api/register`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ phoneNumber: phoneNumber, password: password }),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 10000, connectTimeout: 10000
      });
      if (response.responseCode !== 201) throw new Error(`${response.result as string}`);
    } catch (err) { throw new Error((err as Error).message); } finally { httpRequest.destroy(); }
  }

  public static async login(phoneNumber: string, password: string): Promise<string> {
    if (ApiService.MOCK_MODE) { return 'mock-jwt-token-123'; }
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(`${ApiService.BASE_URL}/api/login`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ phoneNumber: phoneNumber, password: password }),
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 10000, connectTimeout: 10000
      });
      if (response.responseCode === 200) {
        const resultJson = JSON.parse(response.result as string) as Record<string, string>;
        return resultJson.token;
      } else throw new Error(`${response.result as string}`);
    } catch (err) { throw new Error((err as Error).message); } finally { httpRequest.destroy(); }
  }

  public static async getDocuments(token: string): Promise<DocumentCatalog[]> {
    if (ApiService.MOCK_MODE) { return []; }
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(`${ApiService.BASE_URL}/api/documents`, {
        method: http.RequestMethod.GET,
        header: { 'Authorization': `Bearer ${token}` },
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode === 200) return JSON.parse(response.result as string) as DocumentCatalog[];
      else throw new Error('Fetch failed');
    } catch (err) { throw new Error((err as Error).message); } finally { httpRequest.destroy(); }
  }

  public static async uploadDocument(token: string, fileUri: string, kind: string, title: string): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);
    let stat = fileIo.statSync(file.fd);
    let buffer = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buffer);
    fileIo.closeSync(file);

    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(`${ApiService.BASE_URL}/api/documents`, {
        method: http.RequestMethod.POST,
        header: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
        multiFormDataList: [
          { name: 'file', contentType: 'image/jpeg', data: buffer, remoteFileName: 'scanned.jpg' },
          { name: 'kind', contentType: 'text/plain', data: kind },
          { name: 'title', contentType: 'text/plain', data: title }
        ]
      });
      if (response.responseCode !== 201) console.error(`Upload failed`);
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }

  public static async sendVitals(token: string, heartRate: number, bloodOxygen: number): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      await httpRequest.request(`${ApiService.BASE_URL}/api/vitals`, {
        method: http.RequestMethod.POST,
        header: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ heartRate: heartRate, bloodOxygen: bloodOxygen, recordedAt: new Date().toISOString() })
      });
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }

  public static async triggerSOS(token: string, lat: number, lng: number, accuracy: number, address: string): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      await httpRequest.request(`${ApiService.BASE_URL}/api/sos/incidents`, {
        method: http.RequestMethod.POST,
        header: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ latitude: lat, longitude: lng, accuracyMeters: accuracy, address: address })
      });
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }

  public static async putProfile(token: string, profile: PatientProfile): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      await httpRequest.request(`${ApiService.BASE_URL}/api/profile`, {
        method: http.RequestMethod.PUT,
        header: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        extraData: JSON.stringify(profile)
      });
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }

  public static async createMedicationPlan(token: string, medData: CreateMedicationRequest): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      await httpRequest.request(`${ApiService.BASE_URL}/api/medications`, {
        method: http.RequestMethod.POST,
        header: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        extraData: JSON.stringify(medData)
      });
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }

  public static async takeMedicationDose(token: string, medicationId: string): Promise<void> {
    if (ApiService.MOCK_MODE) { return; }
    let httpRequest = http.createHttp();
    try {
      await httpRequest.request(`${ApiService.BASE_URL}/api/medications/${medicationId}/taken`, {
        method: http.RequestMethod.POST,
        header: { 'Authorization': `Bearer ${token}` }
      });
    } catch (err) { console.error(err); } finally { httpRequest.destroy(); }
  }
}