import { router, promptAction } from '@kit.ArkUI';
import { BottomNavBar } from '../components/BottomNavBar';
import { AppHeader } from '../components/AppHeader';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

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

      TextInput({ placeholder: 'First Name' })
        .onChange((val: string) => this.firstName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Last Name' })
        .onChange((val: string) => this.lastName = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Phone Number' })
        .type(InputType.PhoneNumber)
        .onChange((val: string) => this.phoneNumber = val)
        .margin({ bottom: 12 })
        .backgroundColor('#F3F4F5')

      TextInput({ placeholder: 'Relationship / Title (e.g. Son, Security)' })
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
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}

@Entry
@Component
struct SOSPage {
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';

  private scroller: Scroller = new Scroller();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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

      Scroll(this.scroller) {
        Column() {
          if (this.userRole === 'patient') {
            PatientSOSView({ fullName: this.fullName })
          } else if (this.userRole === 'family') {
            FamilySOSView({ fullName: this.fullName })
          } else {
            ResponderSOSView({ fullName: this.fullName })
          }

          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

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

  @State locationAddress: string = 'Locating...';
  @State locationAccuracy: string = 'Calculating...';
  @State mapUrl: string = 'https://lh3.googleusercontent.com/aida-public/AB6AXuB3DOyWbt3lkFVxP7NZrMYwn2N2qMUViMOW8kmdLoZRwafSBGctOWa0h_NyOGWvH7lLEe-peA0lMD0rWxan9ngub_ZscVBdvYK36Ok2LwedrhLMChEBn0HbW1M3W2J52BmUHnVkqCD_IXASCujUzz0YHctn6QPQ0AE3diw5bECh8ePev6al4j6vy_EAhApcfrwDxV1v2zuTEugICNWfy6OR6LZSiSzPJW4Q5nh-PNv7WHRwX0UwoBqkYQiorTLYWnFGyukCa8wwmW8';

  dialogController: CustomDialogController = new CustomDialogController({
    builder: AddContactDialog({
      onAdd: (name: string, phone: string, relation: string) => {
        // Yalnızca 2 kişiye kadar eklenmesine izin veriyoruz
        if (this.sosContacts.length < 2) {
          this.sosContacts.push({
            id: Date.now().toString(),
            fullName: name,
            phone: phone,
            relation: relation
          });
        }
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true
  });

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
      ]).then(() => {
        this.getCurrentLocation();
      }).catch(() => {
        this.getCurrentLocation();
      });
    } catch (e) {
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

  handleTouch(event: TouchEvent) {
    if (this.sosSent) return;

    if (event.type === TouchType.Down) {
      this.isPressing = true;
      this.countdown = 5;

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
      // Temizlenmiş ve düzeltilmiş üst başlık (Çift yazılar kaldırıldı)
      AppHeader({ title: 'Emergency' })
        .margin({ bottom: 24 })

      // Sadece durum bilgilendirme yazısı kaldı
      Column() {
        Text(this.sosSent ? 'Emergency alert broadcasted.' : 'Stay calm. Help is on the way.')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#434654')
      }
      .width('100%')
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

      // Contacts Notified Card
      Column() {
        Row() {
          Text('Emergency Responders')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')

          Blank()

          // Sadece 2 kişiden az eklendiyse Add butonunu gösterir
          if (this.sosContacts.length < 2) {
            Button('+ Add')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .backgroundColor('#E8EEFF')
              .height(28)
              .onClick(() => {
                this.dialogController.open();
              })
          }
        }
        .width('100%')
        .margin({ bottom: 12 })
        .padding({ left: 4, right: 4 })

        Column() {
          // Dinamik eklenen kullanıcılar ve öncelik sıralamaları
          ForEach(this.sosContacts, (contact: EmergencyContact, index: number) => {
            Row() {
              Row() {
                Text(this.getInitials(contact.fullName))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#003D9B')
              }
              .width(44)
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

                // Öncelik Sırası Rozeti ve Unvan
                Row() {
                  Text(index === 0 ? '1st to Call' : '2nd to Call')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                    .backgroundColor(index === 0 ? '#BA1A1A' : '#854E00') // 1. Sıra Kırmızı, 2. Sıra Turuncu
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .margin({ right: 6 })

                  Text(contact.relation)
                    .fontSize(12)
                    .fontColor('#003D9B')
                    .fontWeight(FontWeight.Medium)
                }
                .margin({ bottom: 4 })

                Row() {
                  Text(this.sosSent ? 'Notified' : contact.phone)
                    .fontSize(13)
                    .fontWeight(this.sosSent ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.sosSent ? '#006E2F' : '#737685')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('Remove')
                .fontSize(12)
                .fontColor('#BA1A1A')
                .padding(8)
                .onClick(() => {
                  this.sosContacts = this.sosContacts.filter(c => c.id !== contact.id);
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: 'rgba(195, 198, 214, 0.2)', style: BorderStyle.Solid })
          }, (contact: EmergencyContact) => contact.id)

          // 112 Default Fixed EMS
          Row() {
            Row() {
              Text('🚑')
                .fontSize(20)
            }
            .width(44)
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
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
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

      // Location Card
      Column() {
        Row() {
          Row() {
            Text('📍').margin({ right: 8 })
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
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 24 })

      // Cancel Action
      Button() {
        Row() {
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
      })
    }
    .width('100%')
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

      Column() {
        Text('Patient Vitals (At Alert Time)')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#434654')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        Row() {
          Column() {
            Text('❤️ Heart Rate')
              .fontSize(13)
              .fontColor('#737685')
              .margin({ bottom: 4 })
            Text('135 bpm')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#BA1A1A')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text('💨 Oxygen SpO2')
              .fontSize(13)
              .fontColor('#737685')
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

      Column() {
        Button('📞 Call Father')
          .width('100%')
          .height(50)
          .backgroundColor('#006E2F')
          .borderRadius(12)
          .margin({ bottom: 12 })

        Button('🚑 Dispatch EMS')
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
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFEBEA')
      .borderRadius(20)
      .border({ width: 1, color: '#BA1A1A', style: BorderStyle.Solid })
      .margin({ bottom: 20 })

      Button('Mark as Resolved')
        .width('100%')
        .height(50)
        .backgroundColor('#006E2F')
        .borderRadius(12)
    }
    .width('100%')
  }
}