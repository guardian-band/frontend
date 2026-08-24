import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class TutorialManager {
  private static readonly PREF_NAME = 'tutorial_prefs';
  private static readonly KEY_HAS_SEEN_TUTORIAL = 'hasSeenTutorial';
  
  private static getUserKey(): string {
    let phone = AppStorage.get<string>('userPhone') || 'guest';
    return `${TutorialManager.KEY_HAS_SEEN_TUTORIAL}_${phone}`;
  }

  /**
   * Initializes the tutorial flow for a new user.
   * Checks persistent preferences to determine if the user has already completed the tutorial.
   * If not, activates the global tutorial state via AppStorage.
   * @param context Application or UIAbility context
   * @returns true if the tutorial was started, false if already completed or on error
   */
  public static async initializeTutorial(context: common.UIAbilityContext | common.Context): Promise<boolean> {
    try {
      let prefs: preferences.Preferences = await preferences.getPreferences(context, TutorialManager.PREF_NAME);
      let hasSeen = await prefs.get(TutorialManager.getUserKey(), false) as boolean;
      
      if (!hasSeen) {
        // Start tutorial flow by setting global application state
        AppStorage.setOrCreate('isTutorialActive', true);
        AppStorage.setOrCreate('currentTutorialStep', 1);
        return true;
      }
      return false;
    } catch (err) {
      console.error("TutorialManager", "Failed to init preferences: " + err);
      return false;
    }
  }

  public static async finishTutorial(context: common.UIAbilityContext | common.Context): Promise<void> {
    try {
      let prefs: preferences.Preferences = await preferences.getPreferences(context, TutorialManager.PREF_NAME);
      await prefs.put(TutorialManager.getUserKey(), true);
      await prefs.flush();
      AppStorage.setOrCreate('isTutorialActive', false);
      AppStorage.setOrCreate('currentTutorialStep', 0);
    } catch (err) {
      console.error("TutorialManager", "Failed to finish tutorial: " + err);
    }
  }

  public static nextStep(): void {
    let currentStep = AppStorage.get<number>('currentTutorialStep') || 0;
    if (currentStep > 0) {
      AppStorage.set('currentTutorialStep', currentStep + 1);
    }
  }

  public static async resetTutorial(context: common.UIAbilityContext | common.Context): Promise<void> {
    try {
      let prefs: preferences.Preferences = await preferences.getPreferences(context, TutorialManager.PREF_NAME);
      await prefs.put(TutorialManager.getUserKey(), false);
      await prefs.flush();
    } catch (err) {
      console.error("TutorialManager", "Failed to reset tutorial: " + err);
    }
  }

  public static skipTutorial(context: common.UIAbilityContext | common.Context): void {
    TutorialManager.finishTutorial(context);
  }
}
