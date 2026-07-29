import { http } from '@kit.NetworkKit';

export class ApiService {
  // Use 10.0.2.2 to point to host PC's localhost from Android/HarmonyOS emulator.
  // If running on a real device, change this to the host machine's actual LAN IP address.
  private static readonly BASE_URL: string = 'http://localhost:3000';

  /**
   * Register a user on the Docker backend
   */
  public static async register(username: string, password: string): Promise<void> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(
        `${ApiService.BASE_URL}/api/register`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            username: username,
            password: password
          }),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 10000,
          connectTimeout: 10000
        }
      );

      if (response.responseCode === 201) {
        return;
      } else if (response.responseCode === 409) {
        throw new Error('User already exists');
      } else if (response.responseCode === 400) {
        throw new Error('Invalid registration data');
      } else {
        throw new Error(`Registration failed (Code ${response.responseCode})`);
      }
    } catch (err) {
      const error = err as Error;
      throw new Error(error.message || 'Network request failed');
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * Log in a user on the Docker backend and return their JWT token
   */
  public static async login(username: string, password: string): Promise<string> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(
        `${ApiService.BASE_URL}/api/login`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            username: username,
            password: password
          }),
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 10000,
          connectTimeout: 10000
        }
      );

      if (response.responseCode === 201) {
        const resultJson = JSON.parse(response.result as string) as Record<string, string>;
        if (resultJson && resultJson.token) {
          return resultJson.token;
        } else {
          throw new Error('Invalid token response structure');
        }
      } else if (response.responseCode === 401) {
        throw new Error('Invalid credentials');
      } else {
        throw new Error(`Login failed (Code ${response.responseCode})`);
      }
    } catch (err) {
      const error = err as Error;
      throw new Error(error.message || 'Network request failed');
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * Access sample protected endpoint using bearer token authentication
   */
  public static async getProtected(token: string): Promise<string> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(
        `${ApiService.BASE_URL}/api/protected`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Authorization': `Bearer ${token}`
          },
          expectDataType: http.HttpDataType.STRING,
          readTimeout: 10000,
          connectTimeout: 10000
        }
      );

      if (response.responseCode === 200) {
        return response.result as string;
      } else if (response.responseCode === 401) {
        throw new Error('Unauthorized or expired session');
      } else {
        throw new Error(`Protected request failed (Code ${response.responseCode})`);
      }
    } catch (err) {
      const error = err as Error;
      throw new Error(error.message || 'Network request failed');
    } finally {
      httpRequest.destroy();
    }
  }
}
