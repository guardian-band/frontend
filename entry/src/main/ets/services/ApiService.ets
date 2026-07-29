import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';

export class ApiService {
  // IMPORTANT: Since your backend runs in Docker on your local computer, 
  // 'localhost' or '127.0.0.1' inside the simulator refers to the simulator itself.
  // Replace this IP with your computer's local network IP (e.g., 'http://192.168.1.100:8080')
  // or use the emulator host loopback address: 'http://10.0.2.2:8080'.
  private static readonly BASE_URL = 'http://10.0.2.2:3000';

  /**
   * Helper to perform POST requests.
   * @param path API endpoint path (e.g. '/api/auth/register')
   * @param body JSON request payload
   */
  static async post(path: string, body: object): Promise<string> {
    const httpRequest = http.createHttp();
    const url = `${ApiService.BASE_URL}${path}`;

    return new Promise((resolve, reject) => {
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(body),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 10000,
          connectTimeout: 10000
        },
        (err, data) => {
          if (!err) {
            if (data.responseCode >= 200 && data.responseCode < 300) {
              resolve(data.result as string);
            } else {
              promptAction.showToast({ message: `HTTP Error: ${data.responseCode}` });
              reject(new Error(`HTTP Error: ${data.responseCode}`));
            }
          } else {
            promptAction.showToast({ message: 'Network connection failed' });
            reject(err);
          }
          // Destroy connection to release resources
          httpRequest.destroy();
        }
      );
    });
  }

  /**
   * Helper to perform GET requests.
   * @param path API endpoint path (e.g. '/api/users/profile')
   * @param token Optional authorization bearer token
   */
  static async get(path: string, token?: string): Promise<string> {
    const httpRequest = http.createHttp();
    const url = `${ApiService.BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    return new Promise((resolve, reject) => {
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          header: headers,
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 10000,
          connectTimeout: 10000
        },
        (err, data) => {
          if (!err) {
            if (data.responseCode >= 200 && data.responseCode < 300) {
              resolve(data.result as string);
            } else {
              promptAction.showToast({ message: `HTTP Error: ${data.responseCode}` });
              reject(new Error(`HTTP Error: ${data.responseCode}`));
            }
          } else {
            promptAction.showToast({ message: 'Network connection failed' });
            reject(err);
          }
          // Destroy connection to release resources
          httpRequest.destroy();
        }
      );
    });
  }
}
