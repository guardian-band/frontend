import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { AppHeader } from '../components/AppHeader';
import { contact } from '@kit.ContactsKit';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { ApiService, SOSIncident } from '../services/ApiService';
import { SessionStore } from '../services/SessionStore';
import { ContactsRepository } from '../services/ContactsRepository';
import { CoachMarkOverlay } from '../components/CoachMarkOverlay';
import { TutorialManager } from '../utils/TutorialManager';

interface ContactWithDisplayName {
  displayName: string;
}

interface EmergencyContact {
  id: string;
  fullName: string;
  phone: string;
  relation: string;
}

@CustomDialog
struct AddContactDialog {
  controller?: CustomDialogController;
  @State firstName: string = '';
  @State lastName: string = '';
  @State phoneNumber: string = '';
  @State relation: string = '';

  onAdd: (name: string, phone: string, relation: string) => void = () => {};

  build() {
    Column() {
      Text('Add Emergency Contact')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 16 })

      Button('Select from Contacts')
        .backgroundColor('rgba(0, 61, 155, 0.08)')
        .fontColor('#003D9B')
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .height(44)
        .borderRadius(12)
        .margin({ bottom: 16 })
        .onClick(() => {
          let selectionOptions: contact.ContactSelectionOptions = {
            isMultiSelect: false
          };
          contact.selectContacts(selectionOptions)
            .then((contacts) => {
              if (contacts && contacts.length > 0) {
                let selected = contacts[0];
                let displayName = '';
                if (selected.name) {
                  displayName = selected.name.fullName || '';
                }
                let selectedWithDisplayName = selected as ContactWithDisplayName;
                if (!displayName && selectedWithDisplayName.displayName) {
                  displayName = selectedWithDisplayName.displayName;
                }
                if (!displayName) {
                  displayName = 'Unknown Contact';
                }
                let parts = displayName.trim().split(' ');
                this.firstName = parts[0] || '';
                this.lastName = parts.slice(1).join(' ') || '';

                let phone = '';
                if (selected.phoneNumbers && selected.phoneNumbers.length > 0) {
                  phone = selected.phoneNumbers[0].phoneNumber || '';
                }
                this.phoneNumber = phone.replace(/\s+/g, '');
                this.relation = 'Other';
                promptAction.showToast({ message: 'Contact selected successfully!' });
              } else {
                promptAction.showToast({ message: 'No contact was selected.' });
              }
            })
            .catch((err: Error) => {
              console.error("selectContacts error", err.message);
              promptAction.showToast({ message: 'Could not access device contacts.' });
            });
        })

      TextInput({ placeholder: 'First Name', text: this.firstName })
        .onChange((val: string) => this.firstName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Last Name', text: this.lastName })
        .onChange((val: string) => this.lastName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Phone Number', text: this.phoneNumber })
        .type(InputType.PhoneNumber)
        .onChange((val: string) => this.phoneNumber = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Relationship / Title (e.g. Son, Security)', text: this.relation })
        .onChange((val: string) => this.relation = val)
        .margin({ bottom: 24 })
        .backgroundColor('#F3F4F5')

      Row() {
        Button('Cancel')
          .backgroundColor('#F1F2F5')
          .fontColor('#191C1D')
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.controller?.close();
          })

        Button('Save')
          .backgroundColor('#003D9B')
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            if (this.firstName && this.phoneNumber) {
              this.onAdd(`${this.firstName} ${this.lastName}`.trim(), this.phoneNumber, this.relation || 'Emergency Contact');
              this.controller?.close();
            } else {
              promptAction.showToast({ message: 'Name and Phone are required!' });
            }
          })}.width('100%')}.padding(24)
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

@Entry
@Component
struct SOSPage {
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';
  @StorageLink('isResponderVerified') isResponderVerified: boolean = false;

  @StorageLink('isTutorialActive') isTutorialActive: boolean = false;
  @StorageLink('currentTutorialStep') currentTutorialStep: number = 0;

  private scroller: Scroller = new Scroller();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background Radial Gradients for visual effect (Balanced Brand Navy & Red)
      Row()
        .width(500)
        .height(500)
        .position({ x: -200, y: -200 })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 250,
          colors: [
            ['rgba(0, 61, 155, 0.20)', 0.0],
            ['rgba(0, 61, 155, 0.0)', 1.0]
          ]
        })

      Row()
        .width(600)
        .height(600)
        .position({ x: '30%', y: '60%' })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 300,
          colors: [
            ['rgba(227, 27, 35, 0.18)', 0.0],
            ['rgba(227, 27, 35, 0.0)', 1.0]
          ]
        })

      Scroll(this.scroller) {
        Column() {
          // Render different views based on the user's role
          if (this.userRole === 'patient') {
            PatientSOSView({ fullName: this.fullName })
          } else if (this.userRole === 'family') {
            FamilySOSView({ fullName: this.fullName })
          } else if (this.userRole === 'doctor') {
            DoctorSOSView()
          }

          Blank().height(100) // Spacer for bottom nav
        }.width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }.scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      BottomNavBar({ activeTab: 'sos' })
        .zIndex(1)

      if (this.isTutorialActive && this.currentTutorialStep === 4) {
        CoachMarkOverlay({
          targetId: 'btn_sos',
          title: 'Emergency SOS Alert',
          description: 'In case of emergency, tap this button to instantly send an alert with your live location to your emergency contacts.',
          stepIndex: 4,
          totalSteps: 4
        })
      }
    }.width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

// ----------------------------------------------------
// PATIENT SOS VIEW
// ----------------------------------------------------
@Component
struct PatientSOSView {
  @Prop fullName: string;

  @StorageLink('sosContacts') sosContacts: EmergencyContact[] = [];

  @State isPressing: boolean = false;
  @State countdown: number = 5;
  @State sosSent: boolean = false;
  @State intervalId: number = -1;
  @State activeIncidentId: string = '';

  @State locationAddress: string = 'Locating...';
  @State locationAccuracy: string = 'Calculating...';
  @State mapUrl: string = 'https://lh3.googleusercontent.com/aida-public/AB6AXuB3DOyWbt3lkFVxP7NZrMYwn2N2qMUViMOW8kmdLoZRwafSBGctOWa0h_NyOGWvH7lLEe-peA0lMD0rWxan9ngub_ZscVBdvYK36Ok2LwedrhLMChEBn0HbW1M3W2J52BmUHnVkqCD_IXASCujUzz0YHctn6QPQ0AE3diw5bECh8ePev6al4j6vy_EAhApcfrwDxV1v2zuTEugICNWfy6OR6LZSiSzPJW4Q5nh-PNv7WHRwX0UwoBqkYQiorTLYWnFGyukCa8wwmW8';


  aboutToAppear() {
    this.requestLocationPermission();
    // Refresh emergency contacts from the backend: SOS alerts go to this list.
    ContactsRepository.refreshQuietly();
  }

  aboutToDisappear() {
    this.clearTimer();
  }

  // Request location permissions from the user
  requestLocationPermission() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(context, [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ]).then(() => {
        this.getCurrentLocation();
      }).catch(() => {
        this.getCurrentLocation();
      });
    } catch (e) {
      this.getCurrentLocation();
    }
  }

  // Use a fallback location if permission is denied or retrieval fails
  useMockLocation() {
    this.locationAddress = '123 Silver Oak Lane, Palo Alto, CA';
    this.locationAccuracy = '3.0m';
    this.mapUrl = 'https://static-maps.yandex.ru/1.x/?ll=-122.1697,37.4275&z=16&l=map&size=600,200';
  }

  // Fetch the current GPS location
  getCurrentLocation() {
    try {
      let requestInfo: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX
      };
      geoLocationManager.getCurrentLocation(requestInfo).then((location) => {
        if (location) {
          const lat = location.latitude;
          const lng = location.longitude;
          this.locationAddress = `Lat: ${lat.toFixed(5)}, Lng: ${lng.toFixed(5)}`;
          this.locationAccuracy = `${location.accuracy.toFixed(1)}m`;
          this.mapUrl = `https://static-maps.yandex.ru/1.x/?ll=${lng.toFixed(5)},${lat.toFixed(5)}&z=16&l=map&size=600,200`;
        } else {
          this.useMockLocation();
        }
      }).catch(() => {
        this.useMockLocation();
      });
    } catch (err) {
      this.useMockLocation();
    }
  }

  clearTimer() {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }
  }

  // Handle the emergency SOS trigger logic.
  handleTouch(event: TouchEvent) {
    if (this.sosSent) return;

    if (event.type === TouchType.Down) {
      this.sosSent = true;
      this.isPressing = false;

      if (!SessionStore.isAuthenticated()) {
        promptAction.showToast({ message: 'No active session - the emergency alert could not be sent. Please sign in.' });
        return;
      }

      // Parse location coordinates gracefully; fallback to address-only if parsing fails.
      
      let lat: number = 0;
      let lng: number = 0;
      let hasCoordinates: boolean = false;
      try {
        if (this.locationAddress.includes('Lat:')) {
          const parts = this.locationAddress.split(',');
          const parsedLat: number = parseFloat(parts[0].replace('Lat:', '').trim());
          const parsedLng: number = parseFloat(parts[1].replace('Lng:', '').trim());
          if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
            lat = parsedLat;
            lng = parsedLng;
            hasCoordinates = true;
          }
        }
      } catch (e) {
        console.error(`[SOS] Could not parse coordinates: ${(e as Error).message}`);
      }
      if (!hasCoordinates) {
        console.warn('[SOS] No coordinates available; sending address only.');
      }

      const accuracy: number = parseFloat(this.locationAccuracy.replace('m', '').trim()) || 0;

      // Emergency alert: ApiService retries this with exponential backoff.
      ApiService.triggerSOS(lat, lng, accuracy, this.locationAddress)
        .then((incident: SOSIncident) => {
          this.activeIncidentId = incident.id;
          console.info(`[API] POST /api/sos/incidents - OK id=${incident.id}`);
          if (this.sosContacts.length === 0) {
            promptAction.showToast({
              message: 'WARNING: You have no emergency contacts. The alert was recorded but nobody will be notified.'
            });
          } else {
            promptAction.showToast({ message: 'Emergency alert sent.' });
          }
        })
        .catch((err: Error) => {
          // This must not fail silently: the user has to know help is not coming.
          console.error(`[API] POST /api/sos/incidents - FAILED: ${err.message}`);
          this.sosSent = false;
          promptAction.showToast({ message: `EMERGENCY ALERT FAILED: ${err.message}` });
        });
    }
  }

  // Get initials for the contact avatar
  getInitials(name: string): string {
    if (!name) return 'C';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  build() {
    Column() {
      // Cleaned up header
      AppHeader({ title: 'Emergency' })
        .margin({ bottom: 24 })

      // Status text
      Column() {
        Text(this.sosSent ? 'Emergency alert broadcasted.' : 'Stay calm. Help is on the way.')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#434654')}.width('100%')
      .margin({ bottom: 28 })
      .alignItems(HorizontalAlign.Center)

      // HOLD TO SEND SOS Button
      Stack() {
        Row()
          .width(220)
          .height(220)
          .borderRadius(110)
          .backgroundColor(this.sosSent ? 'rgba(0, 110, 47, 0.1)' : 'rgba(186, 26, 26, 0.1)')
          .scale({
            x: this.isPressing ? 1.1 : 1.0,
            y: this.isPressing ? 1.1 : 1.0
          })
          .animation({ duration: 500, tempo: 1.0, curve: Curve.FastOutLinearIn, playMode: PlayMode.Alternate, iterations: -1 })

        Button() {
          Column() {
            if (this.sosSent) {
              Image($r('app.media.like'))
                .width(48)
                .height(48)
                .objectFit(ImageFit.Contain)
                .margin({ bottom: 8 })

              Text('SOS SENT')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(2)
            } else if (this.isPressing) {
              Text(`${this.countdown}`)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ bottom: 6 })

              Text('HOLDING...')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(1)
            } else {
              Text('🚨')
                .fontSize(44)
                .margin({ bottom: 8 })

              Text('TAP TO SEND')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(1)

              Text('SOS')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(2)
            }}.justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')}
        .id('btn_sos')
        .width(180)
        .height(180)
        .borderRadius(90)
        .backgroundColor(this.sosSent ? '#006E2F' : '#BA1A1A')
        .shadow({ radius: 20, color: this.sosSent ? 'rgba(0, 110, 47, 0.3)' : 'rgba(186, 26, 26, 0.3)' })
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event);
        })}.width('100%')
      .height(240)
      .margin({ bottom: 24 })

      // Contacts Notified Card
      Column() {
        Row() {
          Text('Emergency Responders')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')

          Blank()}.width('100%')
        .margin({ bottom: 12 })
        .padding({ left: 4, right: 4 })

        // Display a warning if the SOS was triggered but no emergency contacts are configured.
        if (this.sosContacts.length === 0) {
          Column() {
            Text('⚠ No emergency contacts set')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
              .margin({ bottom: 4 })
            Text('If you press SOS the alert is recorded but nobody is notified. Add at least one contact from the Profile screen.')
              .fontSize(12)
              .fontColor('#8C0013')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor('rgba(186, 26, 26, 0.08)')
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProfilePage' });
          })
        }

        Column() {
          // Dynamically added contacts and priority rankings
          ForEach(this.sosContacts, (contact: EmergencyContact, index: number) => {
            Row() {
              Row() {
                Text(this.getInitials(contact.fullName))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#003D9B')}.width(44)
              .height(44)
              .borderRadius(22)
              .backgroundColor('#E8EEFF')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text(contact.fullName)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                  .margin({ bottom: 4 })

                // Priority Badge and Title
                Row() {
                  Text(index === 0 ? '1st to Call' : '2nd to Call')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                    .backgroundColor(index === 0 ? '#BA1A1A' : '#854E00') // 1st Red, 2nd Orange
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .margin({ right: 6 })

                  Text(contact.relation)
                    .fontSize(12)
                    .fontColor('#003D9B')
                    .fontWeight(FontWeight.Medium)}.margin({ bottom: 4 })

                Row() {
                  Text(this.sosSent ? 'Notified' : contact.phone)
                    .fontSize(13)
                    .fontWeight(this.sosSent ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.sosSent ? '#006E2F' : '#737685')
                }}.alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              // Call Button
              Row() {
                Image($r('app.media.phone'))
                  .width(16)
                  .height(16)
                  .objectFit(ImageFit.Contain)}.width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor('#003D9B')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                promptAction.showToast({ message: `Calling ${contact.fullName}...` });
              })}.width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
          }, (contact: EmergencyContact) => contact.id)

          // 112 Default Fixed EMS
          Row() {
            Row() {
              Image($r('app.media.ambulance'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)}.width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor(this.sosSent ? '#E6F9ED' : '#FFEBEA')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('112 Emergency')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })

              Row() {
                if (this.sosSent) {
                  Text('Dispatched')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#006E2F')
                } else {
                  Text('Standard EMS / Police')
                    .fontSize(13)
                    .fontColor('#737685')
                }
              }}.alignItems(HorizontalAlign.Start)
            .layoutWeight(1)}.width('100%')
          .padding({ top: 12, bottom: 12 })}.width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })}.width('100%')
      .margin({ bottom: 20 })

      // Location Card
      Column() {
        Row() {
          Row() {
            Image($r('app.media.place'))
              .width(20)
              .height(20)
              .margin({ right: 8 })
              .objectFit(ImageFit.Contain)
            Text('Current Location')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          Blank()
          Text(`Accuracy: ${this.locationAccuracy}`)
            .fontSize(12)
            .fontColor('#737685')}.width('100%')
        .margin({ bottom: 12 })

        Image(this.mapUrl)
          .width('100%')
          .height(130)
          .borderRadius(12)
          .margin({ bottom: 12 })
          .objectFit(ImageFit.Cover)

        Text(this.locationAddress)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)}.width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 24 })

      // Cancel Action
      Button() {
        Row() {
          Image($r('app.media.cancel'))
            .width(20)
            .height(20)
            .margin({ right: 8 })
            .objectFit(ImageFit.Contain)
          Text('Cancel SOS Request')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#BA1A1A')}.justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)}.width('100%')
      .height(56)
      .backgroundColor('rgba(186, 26, 26, 0.08)')
      .borderRadius(16)
      .onClick(() => {
        if (SessionStore.isAuthenticated() && this.activeIncidentId) {
          ApiService.sendSOSAllClear(this.activeIncidentId)
            .then(() => {
              promptAction.showToast({ message: 'All-clear notification sent to contacts!' });
            })
            .catch((err: Error) => {
              promptAction.showToast({ message: 'Could not send all-clear: ' + err.message });
            });
        }
        this.sosSent = false;
        this.isPressing = false;
        this.countdown = 5;
        this.clearTimer();
        this.activeIncidentId = '';
        promptAction.showToast({ message: 'SOS request cancelled.' });
      })}.width('100%')
  }
}

// ----------------------------------------------------
// FAMILY SOS VIEW
// ----------------------------------------------------
@Component
struct FamilySOSView {
  @Prop fullName: string;

  build() {
    Column() {
      AppHeader({ title: 'Family Alerts' })
        .margin({ bottom: 24 })

      Column() {
        Row() {
          Image($r('app.media.alert'))
            .width(18)
            .height(18)
            .margin({ right: 6 })
            .objectFit(ImageFit.Contain)
          Text('EMERGENCY SOS ALERT')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#BA1A1A')
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 8 })

        Text('Father (John Doe) has triggered an emergency SOS call!')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 12 })

        Text('Stay calm. Action is required.')
          .fontSize(13)
          .fontColor('#434654')
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#FFEBEA')
      .borderRadius(24)
      .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      Column() {
        Text('Patient Vitals (At Alert Time)')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        Row() {
          Column() {
            Row() {
              Image($r('app.media.heart'))
                .width(16)
                .height(16)
                .margin({ right: 6 })
                .objectFit(ImageFit.Contain)
              Text('Heart Rate')
                .fontSize(13)
                .fontColor('#737685')
            }
            .margin({ bottom: 4 })

            Text('135 bpm')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Row() {
              Image($r('app.media.oxygensaturation'))
                .width(16)
                .height(16)
                .margin({ right: 6 })
                .objectFit(ImageFit.Contain)
              Text('Oxygen SpO2')
                .fontSize(13)
                .fontColor('#737685')
            }
            .margin({ bottom: 4 })

            Text('91 %')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      }
      .width('100%')
      .margin({ bottom: 20 })

      // Patient Live Location Map Card
      Column() {
        Row() {
          Row() {
            Image($r('app.media.place'))
              .width(20)
              .height(20)
              .margin({ right: 8 })
              .objectFit(ImageFit.Contain)
            Text('Patient Current Location')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          Blank()
          Text('Live • GPS')
            .fontSize(12)
            .fontColor('#003D9B')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Stack() {
          Image('https://static-maps.yandex.ru/1.x/?ll=-122.1697,37.4275&z=16&l=map&pt=-122.1697,37.4275,pm2rdm&size=600,240')
            .width('100%')
            .height(160)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)

          Column() {
            Row() {
              Text('Father • Palo Alto')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#0052cc', style: BorderStyle.Solid })
            .shadow({ radius: 6, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
            .margin({ bottom: 6 })

            Row() {
              Image($r('app.media.patient'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor('#003D9B')
            .border({ width: 2.5, color: Color.White, style: BorderStyle.Solid })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .shadow({ radius: 8, color: 'rgba(0,61,155,0.3)', offsetY: 4 })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height(160)
        .borderRadius(16)
        .margin({ bottom: 12 })

        Text('123 Silver Oak Lane, Palo Alto, CA')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      Column() {
        Button() {
          Row() {
            Image($r('app.media.phone'))
              .width(20)
              .height(20)
              .margin({ right: 8 })
              .objectFit(ImageFit.Contain)
            Text('Call Father')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height(50)
        .backgroundColor('#006E2F')
        .borderRadius(12)
        .margin({ bottom: 12 })

        Button() {
          Row() {
            Image($r('app.media.ambulance'))
              .width(20)
              .height(20)
              .margin({ right: 8 })
              .objectFit(ImageFit.Contain)
            Text('Dispatch EMS')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height(50)
        .backgroundColor('#BA1A1A')
        .borderRadius(12)
      }
      .width('100%')
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// RESPONDER SOS VIEW
// ----------------------------------------------------
@Component
struct ResponderSOSView {
  @Prop fullName: string;

  build() {
    Column() {
      AppHeader({ title: 'Dispatch Panel' })
        .margin({ bottom: 24 })

      Column() {
        Row() {
          Text('ACTIVE CASE #924')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#BA1A1A')
          Blank()
          Text('PRIORITY 1')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#BA1A1A')
            .borderRadius(8)}.width('100%')
        .margin({ bottom: 12 })

        Text('Patient: John Doe (Age 74)')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })}.width('100%')
      .padding(16)
      .backgroundColor('#FFEBEA')
      .borderRadius(20)
      .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      Button('Mark as Resolved')
        .width('100%')
        .height(50)
        .backgroundColor('#006E2F')
        .borderRadius(12)}.width('100%')
  }
}

// ----------------------------------------------------
// RESPONDER LOCK VIEW
// ----------------------------------------------------
@Component
struct ResponderLockView {
  @StorageLink('isResponderVerified') isResponderVerified: boolean = false;
  @State responderPin: string = '';

  build() {
    Column() {
      AppHeader({ title: 'Authorized Verification' })
        .margin({ bottom: 20 })

      Column() {
        Image($r('app.media.alert'))
          .width(50)
          .height(50)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 16 })

        Text('Verification Required')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .margin({ bottom: 8 })

        Text('This dispatch panel contains sensitive patient medical records. Please verify your first responder credentials to unlock.')
          .fontSize(14)
          .fontColor('#737685')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })
          .lineHeight(20)
          .width('90%')

        // PIN Input
        TextInput({ placeholder: 'Enter 6-digit Responder PIN', text: this.responderPin })
          .type(InputType.Number)
          .maxLength(6)
          .placeholderColor('rgba(115, 118, 133, 0.5)')
          .fontSize(16)
          .backgroundColor('#F3F4F5')
          .height(50)
          .width('100%')
          .margin({ bottom: 20 })
          .textAlign(TextAlign.Center)
          .onChange((value: string) => {
            this.responderPin = value;
          })

        Button('Verify Credentials')
          .width('100%')
          .height(50)
          .backgroundColor('#BA1A1A')
          .fontColor(Color.White)
          .borderRadius(12)
          .onClick(() => {
            if (this.responderPin === '123456') {
              this.isResponderVerified = true;
              this.responderPin = '';
              promptAction.showToast({ message: 'Verified successfully!' });
            } else {
              promptAction.showToast({ message: 'Invalid credentials. Access denied.' });
            }
          })}.width('100%')
      .padding(24)
      .backgroundColor(Color.White)
      .borderRadius(24)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })}.width('100%')
  }
}

// ----------------------------------------------------
// DOCTOR SOS PORTAL VIEW
// ----------------------------------------------------
@Component
struct DoctorSOSView {
  @State activeAlertsCount: number = 1;
  @State selectedAlarmPatient: string = 'John Doe';
  @State alarmHeartRate: number = 135;

  build() {
    Column() {
      // 1. Header
      AppHeader({ title: 'Medical SOS Portal' })
        .margin({ bottom: 20 })

      // 2. Pulsing Critical Alerts Panel
      if (this.activeAlertsCount > 0) {
        Column() {
          Row() {
            Circle({ width: 10, height: 10 }).fill('#BA1A1A').margin({ right: 8 })
            Text('CRITICAL PATIENT ALARM')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')}.margin({ bottom: 8 })

          Text(`Critical telemetry received from patient ${this.selectedAlarmPatient}:`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#434654')
            .margin({ bottom: 12 })

          Row() {
            Row() {
              Image($r('app.media.heart'))
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
                .margin({ right: 8 })

              Column() {
                Text('Heart Rate')
                  .fontSize(11)
                  .fontColor('#737685')
                Text(`${this.alarmHeartRate} BPM`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#BA1A1A')}.alignItems(HorizontalAlign.Start)}.layoutWeight(1)

            Row() {
              Image($r('app.media.place'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })

              Column() {
                Text('Location')
                  .fontSize(11)
                  .fontColor('#737685')
                Text('Palo Alto')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')}.alignItems(HorizontalAlign.Start)}.layoutWeight(1)}.width('100%')
          .margin({ bottom: 16 })

          // Actions row
          Row() {
            Button('Call Patient', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(38)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#003D9B')
              .borderRadius(8)
              .margin({ right: 10 })
              .onClick(() => {
                promptAction.showToast({ message: `Calling patient ${this.selectedAlarmPatient}...` });
              })

            Button('Send Ambulance', { type: ButtonType.Normal })
              .layoutWeight(1)
              .height(38)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#BA1A1A')
              .borderRadius(8)
              .onClick(() => {
                promptAction.showToast({ message: `Ambulance dispatched to Palo Alto for ${this.selectedAlarmPatient}!` });
                this.activeAlertsCount = 0; // clear alert mockup
              })}.width('100%')}.width('100%')
        .padding(18)
        .backgroundColor('#FFEBEA')
        .borderRadius(20)
        .border({ width: 1.5, color: '#BA1A1A', style: BorderStyle.Solid })
        .margin({ bottom: 24 })
      } else {
        // Safe Banner
        Row() {
          Image($r('app.media.like'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
            .margin({ right: 10 })

          Text('All linked patients vitals stable')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#006E2F')}.width('100%')
        .padding(16)
        .backgroundColor('#E6F9ED')
        .borderRadius(20)
        .border({ width: 1, color: '#006E2F', style: BorderStyle.Solid })
        .margin({ bottom: 24 })
      }

      // 3. Hospital ER Quick Calls
      Text('Hospital Emergency Lines')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#434654')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 4, bottom: 12 })

      // ER Card
      Row() {
        Row() {
          Image($r('app.media.emergency'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)}.width(44)
        .height(44)
        .borderRadius(10)
        .backgroundColor('rgba(186, 26, 26, 0.08)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text('ER Triage Desk')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 2 })
          Text('Direct line to hospital emergency room')
            .fontSize(12)
            .fontColor('#737685')}.alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 12 })

        Button('CALL', { type: ButtonType.Normal })
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#BA1A1A')
          .borderRadius(8)
          .height(30)
          .width(64)
          .onClick(() => {
            promptAction.showToast({ message: 'Calling ER Triage Desk...' });
          })}.width('100%')
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 16 })

      // Ambulance Service Card
      Row() {
        Row() {
          Image($r('app.media.ambulance'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)}.width(44)
        .height(44)
        .borderRadius(10)
        .backgroundColor('rgba(0, 61, 155, 0.08)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text('Ambulance Dispatch')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 2 })
          Text('Priority service dispatcher hotline')
            .fontSize(12)
            .fontColor('#737685')}.alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 12 })

        Button('CALL', { type: ButtonType.Normal })
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#003D9B')
          .borderRadius(8)
          .height(30)
          .width(64)
          .onClick(() => {
            promptAction.showToast({ message: 'Calling Ambulance Dispatcher...' });
          })}.width('100%')
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 16 })

      // Chief of Medicine Card
      Row() {
        Row() {
          Image($r('app.media.doctor'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)}.width(44)
        .height(44)
        .borderRadius(10)
        .backgroundColor('rgba(0, 110, 47, 0.08)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text('ER Department Head')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 2 })
          Text('Chief medical director emergency desk')
            .fontSize(12)
            .fontColor('#737685')}.alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 12 })

        Button('CALL', { type: ButtonType.Normal })
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#006E2F')
          .borderRadius(8)
          .height(30)
          .width(64)
          .onClick(() => {
            promptAction.showToast({ message: 'Calling ER Department Head...' });
          })}.width('100%')
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 16 })}.width('100%')
  }
}
