import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

@Entry
@Component
struct SOSPage {
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'John Doe';

  private scroller: Scroller = new Scroller();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background Hologram/Ambient Blurs (0.5 opacity for consistency)
      Row()
        .width(500)
        .height(500)
        .position({ x: -200, y: -200 })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 250,
          colors: [
            ['rgba(255, 218, 218, 0.5)', 0.0],
            ['rgba(255, 218, 218, 0.0)', 1.0]
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
            ['rgba(255, 218, 218, 0.4)', 0.0],
            ['rgba(255, 218, 218, 0.0)', 1.0]
          ]
        })

      // Main Content Wrapped in a Scroll
      Scroll(this.scroller) {
        Column() {
          // Dynamic Render based on userRole
          if (this.userRole === 'patient') {
            PatientSOSView({ fullName: this.fullName })
          } else if (this.userRole === 'family') {
            FamilySOSView({ fullName: this.fullName })
          } else {
            ResponderSOSView({ fullName: this.fullName })
          }

          // Spacing for BottomNavBar
          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // Reusable Bottom Navigation Bar Component (SOS is active)
      BottomNavBar({ activeTab: 'sos' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

// ----------------------------------------------------
// PATIENT SOS VIEW (Interactive countdown button)
// ----------------------------------------------------
@Component
struct PatientSOSView {
  @Prop fullName: string;

  @State isPressing: boolean = false;
  @State countdown: number = 5;
  @State sosSent: boolean = false;
  @State intervalId: number = -1;

  @State locationAddress: string = 'Locating...';
  @State locationAccuracy: string = 'Calculating...';
  @State mapUrl: string = 'https://lh3.googleusercontent.com/aida-public/AB6AXuB3DOyWbt3lkFVxP7NZrMYwn2N2qMUViMOW8kmdLoZRwafSBGctOWa0h_NyOGWvH7lLEe-peA0lMD0rWxan9ngub_ZscVBdvYK36Ok2LwedrhLMChEBn0HbW1M3W2J52BmUHnVkqCD_IXASCujUzz0YHctn6QPQ0AE3diw5bECh8ePev6al4j6vy_EAhApcfrwDxV1v2zuTEugICNWfy6OR6LZSiSzPJW4Q5nh-PNv7WHRwX0UwoBqkYQiorTLYWnFGyukCa8wwmW8';

  aboutToAppear() {
    this.requestLocationPermission();
  }

  aboutToDisappear() {
    this.clearTimer();
  }

  requestLocationPermission() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(context, [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ]).then((data) => {
        console.log(`Permission request response: ${JSON.stringify(data)}`);
        this.getCurrentLocation();
      }).catch((err: Error) => {
        console.error(`Permission request failed: ${err.message}`);
        this.getCurrentLocation();
      });
    } catch (e) {
      console.error(`Permission check exception: ${e}`);
      this.getCurrentLocation();
    }
  }

  useMockLocation() {
    this.locationAddress = '123 Silver Oak Lane, Palo Alto, CA';
    this.locationAccuracy = '3.0m (Simulated)';
    this.mapUrl = 'https://static-maps.yandex.ru/1.x/?ll=-122.1697,37.4275&z=16&l=map&size=600,200';
  }

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
      }).catch((err: Error) => {
        console.error(`Location selection failed: ${err.message}`);
        this.useMockLocation();
      });
    } catch (err) {
      console.error(`Location API failed: ${err}`);
      this.useMockLocation();
    }
  }

  clearTimer() {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }
  }

  handleTouch(event: TouchEvent) {
    if (this.sosSent) return;

    if (event.type === TouchType.Down) {
      this.isPressing = true;
      this.countdown = 5;
      
      // Setup interval to simulate progress and tick every 400ms (total 2 seconds)
      this.intervalId = setInterval(() => {
        this.countdown--;
        if (this.countdown <= 0) {
          this.clearTimer();
          this.sosSent = true;
          this.isPressing = false;
          promptAction.showToast({ message: 'EMERGENCY ALERT BROADCASTED TO ALL CONTACTS!' });
        }
      }, 400);

    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.clearTimer();
      this.isPressing = false;
      this.countdown = 5;
    }
  }

  build() {
    Column() {
      // 1. Header Row
      Row() {
        Text('GuardianBand')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#003D9B')

        Blank()

        Row() {
          Text('Score: 98')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#E8EEFF')
        .borderRadius(20)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 24 })

      // 2. Emergency Title
      Column() {
        Text('EMERGENCY SOS')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#BA1A1A')
          .margin({ bottom: 8 })
        
        Text(this.sosSent ? 'Emergency alert broadcasted.' : 'Stay calm. Help is on the way.')
          .fontSize(16)
          .fontColor('#434654')
      }
      .width('100%')
      .margin({ bottom: 28 })
      .alignItems(HorizontalAlign.Center)

      // 3. HOLD TO SEND SOS Button
      Stack() {
        // Outer pulsing ring
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

        // Main Trigger Button
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
              
              Text('HOLD TO SEND')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(1)

              Text('SOS')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .letterSpacing(2)
            }
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')
        }
        .width(180)
        .height(180)
        .borderRadius(90)
        .backgroundColor(this.sosSent ? '#006E2F' : '#BA1A1A')
        .shadow({ radius: 20, color: this.sosSent ? 'rgba(0, 110, 47, 0.3)' : 'rgba(186, 26, 26, 0.3)' })
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event);
        })
      }
      .width('100%')
      .height(240)
      .margin({ bottom: 24 })

      // 4. Contacts Notified Card
      Column() {
        Text('Emergency Responders')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        Column() {
          // Contact 1 (Son)
          Row() {
            Row() {
              Image($r('app.media.man'))
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor('#E6F9ED')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Son (David)')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              
              Row() {
                Image($r('app.media.like'))
                  .width(14)
                  .height(14)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 4 })
                Text('Notified')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#006E2F')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.phone'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
              .onClick(() => {
                promptAction.showToast({ message: 'Calling David...' });
              })
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

          // Contact 2 (Daughter)
          Row() {
            Row() {
              Image($r('app.media.woman'))
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor('#E6F9ED')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Daughter (Sarah)')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              
              Row() {
                Image($r('app.media.like'))
                  .width(14)
                  .height(14)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 4 })
                Text('Notified')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#006E2F')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.phone'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
              .onClick(() => {
                promptAction.showToast({ message: 'Calling Sarah...' });
              })
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

          // Contact 3 (EMS)
          Row() {
            Row() {
              Image($r('app.media.ambulance'))
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.sosSent ? '#E6F9ED' : '#FFEBEA')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text('Local EMS')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 4 })
              
              Row() {
                if (this.sosSent) {
                  Image($r('app.media.like'))
                    .width(14)
                    .height(14)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text('Dispatched')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#006E2F')
                } else {
                  Text('🛰️ Connecting...')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#BA1A1A')
                }
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.emergency'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 5. Location Card
      Column() {
        Row() {
          Row() {
            Image($r('app.media.place'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
              .margin({ right: 8 })
            Text('Current Location')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          
          Blank()
          
          Text(`Accuracy: ${this.locationAccuracy}`)
            .fontSize(12)
            .fontColor('#737685')
        }
        .width('100%')
        .margin({ bottom: 12 })

        // Image Map (Dynamic Yandex Static Map)
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
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 2 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 24 })

      // 6. Cancel Action
      Button() {
        Row() {
          Image($r('app.media.cancel'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .margin({ right: 8 })
          
          Text('Cancel SOS Request')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#BA1A1A')
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('rgba(186, 26, 26, 0.08)')
      .borderRadius(16)
      .onClick(() => {
        this.sosSent = false;
        this.isPressing = false;
        this.countdown = 5;
        this.clearTimer();
        promptAction.showToast({ message: 'SOS request cancelled.' });
        router.back();
      })
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// FAMILY SOS VIEW (Incoming alert receiver)
// ----------------------------------------------------
@Component
struct FamilySOSView {
  @Prop fullName: string;

  build() {
    Column() {
      // Header
      Row() {
        Text('GuardianBand')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#BA1A1A')
      }
      .width('100%')
      .margin({ bottom: 24 })

      // Red Warning Card
      Column() {
        Text('🚨 EMERGENCY SOS ALERT')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#BA1A1A')
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

      // Live Vitals Box
      Column() {
        Text('Patient Vitals (At Alert Time)')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        Row() {
          // Heart Rate
          Column() {
            Text('❤️ Heart Rate')
              .fontSize(13)
              .fontColor('#737685')
              .margin({ bottom: 4 })
            Text('135 bpm')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
            Text('High Alert')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // SpO2
          Column() {
            Text('💨 Oxygen SpO2')
              .fontSize(13)
              .fontColor('#737685')
              .margin({ bottom: 4 })
            Text('91 %')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
            Text('Low SpO2')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
              .margin({ top: 4 })
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

      // Location Card
      Column() {
        Text('📍 Last Known Location')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })

        Image('https://lh3.googleusercontent.com/aida-public/AB6AXuB3DOyWbt3lkFVxP7NZrMYwn2N2qMUViMOW8kmdLoZRwafSBGctOWa0h_NyOGWvH7lLEe-peA0lMD0rWxan9ngub_ZscVBdvYK36Ok2LwedrhLMChEBn0HbW1M3W2J52BmUHnVkqCD_IXASCujUzz0YHctn6QPQ0AE3diw5bECh8ePev6al4j6vy_EAhApcfrwDxV1v2zuTEugICNWfy6OR6LZSiSzPJW4Q5nh-PNv7WHRwX0UwoBqkYQiorTLYWnFGyukCa8wwmW8')
          .width('100%')
          .height(130)
          .borderRadius(12)
          .margin({ bottom: 12 })
          .objectFit(ImageFit.Cover)

        Text('123 Silver Oak Lane, Apt 4B')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)

        Text('Palo Alto, CA 94301')
          .fontSize(13)
          .fontColor('#737685')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // Action Buttons Column
      Column() {
        Button('📞 Call Father')
          .width('100%')
          .height(50)
          .backgroundColor('#006E2F')
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            promptAction.showToast({ message: 'Calling Father...' });
          })

        Button('🚑 Dispatch EMS')
          .width('100%')
          .height(50)
          .backgroundColor('#BA1A1A')
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            promptAction.showToast({ message: 'EMS Emergency Dispatch Request Sent!' });
          })

        Button('📍 Get Navigation Directions')
          .width('100%')
          .height(50)
          .backgroundColor('#003D9B')
          .borderRadius(12)
          .onClick(() => {
            promptAction.showToast({ message: 'Opening maps with directions...' });
          })
      }
      .width('100%')
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// RESPONDER SOS VIEW (Emergency dispatch info)
// ----------------------------------------------------
@Component
struct ResponderSOSView {
  @Prop fullName: string;

  build() {
    Column() {
      // Header
      Row() {
        Text('GuardianBand Dispatch')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#BA1A1A')
      }
      .width('100%')
      .margin({ bottom: 24 })

      // Incident Card
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
            .borderRadius(8)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Text('Patient: John Doe (Age 74)')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })

        Text('Alert Type: Dynamic Heart Rate Spike & SOS Button Pressed')
          .fontSize(13)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFEBEA')
      .borderRadius(20)
      .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // Medical Profile Card
      Column() {
        Text('Triage Medical Details')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        Column() {
          // Blood Type
          Row() {
            Text('🩸 Blood Type')
              .fontSize(14)
              .fontColor('#737685')
            Blank()
            Text('A+')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

          // Allergies
          Row() {
            Text('⚠️ Allergies')
              .fontSize(14)
              .fontColor('#737685')
            Blank()
            Text('Penicillin')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })

          // Medical Devices
          Row() {
            Text('⚙️ Triage Medical Devices')
              .fontSize(14)
              .fontColor('#737685')
            Blank()
            Text('Pacemaker Active')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#006E2F')
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      }
      .width('100%')
      .margin({ bottom: 20 })

      // Location / Route Navigation Card
      Column() {
        Text('📍 Navigation Routing')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })

        Image('https://lh3.googleusercontent.com/aida-public/AB6AXuB3DOyWbt3lkFVxP7NZrMYwn2N2qMUViMOW8kmdLoZRwafSBGctOWa0h_NyOGWvH7lLEe-peA0lMD0rWxan9ngub_ZscVBdvYK36Ok2LwedrhLMChEBn0HbW1M3W2J52BmUHnVkqCD_IXASCujUzz0YHctn6QPQ0AE3diw5bECh8ePev6al4j6vy_EAhApcfrwDxV1v2zuTEugICNWfy6OR6LZSiSzPJW4Q5nh-PNv7WHRwX0UwoBqkYQiorTLYWnFGyukCa8wwmW8')
          .width('100%')
          .height(130)
          .borderRadius(12)
          .margin({ bottom: 12 })
          .objectFit(ImageFit.Cover)

        Text('123 Silver Oak Lane, Apt 4B, Palo Alto')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      // Action Buttons
      Column() {
        Button('🚨 Route to Case Location')
          .width('100%')
          .height(50)
          .backgroundColor('#003D9B')
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            promptAction.showToast({ message: 'Opening emergency navigation overlay...' });
          })

        Button('📞 Call Family Contact')
          .width('100%')
          .height(50)
          .backgroundColor('rgba(0, 61, 155, 0.08)')
          .fontColor('#003D9B')
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            promptAction.showToast({ message: 'Calling son David (Emergency contact)...' });
          })

        Button() {
          Row() {
            Image($r('app.media.like'))
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
              .margin({ right: 6 })
            Text('Mark as Resolved')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(50)
        .backgroundColor('#006E2F')
        .borderRadius(12)
        .onClick(() => {
          promptAction.showToast({ message: 'Case #924 successfully resolved and closed.' });
          router.back();
        })
      }
      .width('100%')
    }
    .width('100%')
  }
}
