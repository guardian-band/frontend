import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SessionStore } from '../services/SessionStore';
import { ApiService } from '../services/ApiService';
import { ApiConfig } from '../services/ApiConfig';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // Pick the network environment. When testing on a physical device use
    // ApiConfig.DEVICE and update the LAN IP inside ApiConfig.ets.
    ApiConfig.useEnvironment(ApiConfig.EMULATOR);

    // Restore the persisted session: the token now survives app restarts.
    SessionStore.attach(this.context)
      .then(() => {
        hilog.info(DOMAIN, 'testTag', 'Session restored. Authenticated: %{public}s',
          `${SessionStore.isAuthenticated()}`);
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Session restore failed: %{public}s', err.message);
      });

    // On a 401, clear the session and return to the sign-in screen.
    ApiService.onUnauthorized(() => {
      hilog.warn(DOMAIN, 'testTag', '%{public}s', 'Session expired, routing to login');
      AppStorage.setOrCreate('sessionExpired', true);
    });

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/WelcomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}