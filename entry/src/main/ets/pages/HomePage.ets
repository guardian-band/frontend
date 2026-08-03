import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { BottomNavBar } from '../components/BottomNavBar';

interface MedicationItem {
  id: string;
  name: string;
  dosage: string;
  time: string;
  taken: boolean;
}

@Entry
@Component
struct HomePage {
  @StorageLink('token') token: string = '';
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'John Doe';
  @StorageLink('profilePicture') profilePicture: string = '';

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
            ['rgba(218, 226, 255, 0.5)', 0.0],
            ['rgba(218, 226, 255, 0.0)', 1.0]
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
            ['rgba(107, 255, 143, 0.5)', 0.0],
            ['rgba(107, 255, 143, 0.0)', 1.0]
          ]
        })

      // Main Content Wrapped in a Scroll
      Scroll(this.scroller) {
        Column() {
          // Dynamic Render based on userRole
          if (this.userRole === 'patient') {
            PatientDashboardView({ fullName: this.fullName })
          } else if (this.userRole === 'family') {
            FamilyDashboardView({ fullName: this.fullName })
          } else {
            ResponderDashboardView({ fullName: this.fullName })
          }

          // Blank space to prevent the BottomNavBar from covering the bottom content
          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // Reusable Bottom Navigation Bar Component
      BottomNavBar({ activeTab: 'home' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

// ----------------------------------------------------
// PATIENT DASHBOARD VIEW
// ----------------------------------------------------
@Component
struct PatientDashboardView {
  @Prop fullName: string;
  @StorageLink('profilePicture') profilePicture: string = '';
  @State dashboardMeds: MedicationItem[] = [
    { id: '1', name: 'Lisinopril', dosage: '10mg • Blood Pressure', time: 'Today, 10:00 AM', taken: false },
    { id: '2', name: 'Metformin', dosage: '500mg • Diabetes', time: 'Today, 08:00 PM', taken: false }
  ];

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      const first = parts[0].charAt(0);
      const last = parts[parts.length - 1].charAt(0);
      return (first + last).toUpperCase();
    }
    return name.substring(0, Math.min(2, name.length)).toUpperCase();
  }

  getNextPendingMed(): MedicationItem | undefined {
    for (let i = 0; i < this.dashboardMeds.length; i++) {
      if (!this.dashboardMeds[i].taken) {
        return this.dashboardMeds[i];
      }
    }
    return undefined;
  }

  build() {
    Column() {
      // 1. Customized Welcome Header (GuardianBand -> Welcome -> Homepage Start)
      Column() {
        Row() {
          // Brand Title
          Text('GuardianBand')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')

          Blank()

          // Score Badge
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
        .margin({ bottom: 8 })

        // Welcome Username Text & Profile Avatar Row (Below GuardianBand, above dark blue card)
        Row() {
          if (this.profilePicture === '') {
            // Profile Initials Circle Avatar (Left Side)
            Row() {
              Text(this.getInitials(this.fullName))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(32)
            .height(32)
            .backgroundColor('#003D9B')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
            .margin({ right: 10 })
          } else {
            // Profile Image Avatar (Left Side)
            Image(this.profilePicture)
              .width(32)
              .height(32)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .border({ width: 2, color: '#E8EEFF', style: BorderStyle.Solid })
              .margin({ right: 10 })
          }

          Text(`Welcome, ${this.fullName}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 2. DAILY HEALTH VITALITY Card (Large Blue)
      Column() {
        Text('DAILY HEALTH VITALITY')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#DAE2FF')
          .margin({ bottom: 8 })
        
        Text('98/100')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 12 })
        
        Row() {
          Text('Optimal Health State')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#006E2F')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#E6F9ED')
        .borderRadius(12)
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#003D9B')
      .borderRadius(28)
      .shadow({ radius: 8, color: 'rgba(0, 61, 155, 0.2)', offsetX: 0, offsetY: 4 })
      .margin({ bottom: 16 })
      .alignItems(HorizontalAlign.Center)

      // 3. Human Intelligence Insight Box
      Row() {
        // Vertical indicator accent bar
        Row()
          .width(4)
          .height(36)
          .backgroundColor('#003D9B')
          .borderRadius(2)
          .margin({ right: 16 })

        // Icon
        Image($r('app.media.idea'))
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
          .margin({ right: 12 })

        // Insight Content
        Column() {
          Text('Human Intelligence Insight')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#003D9B')
            .margin({ bottom: 4 })
          Text("You're doing great! Your activity is up 10% today compared to your weekly average.")
            .fontSize(13)
            .fontColor('#434654')
            .lineHeight(18)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#E8EEFF')
      .borderRadius(20)
      .margin({ bottom: 16 })
      .alignItems(VerticalAlign.Center)

      // 4. Vitals Dual Grid (Heart Rate & Oxygen)
      Row() {
        // Heart Rate Card
        Column() {
          Row() {
            Image($r('app.media.heart'))
              .width(32)
              .height(32)
              .objectFit(ImageFit.Contain)
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#FFEBEA')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Text('Heart Rate')
            .fontSize(13)
            .fontColor('#737685')
            .margin({ bottom: 4 })
          
          Text('72 bpm')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Row() {
            Text('● Normal')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#006E2F')
          }
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        // Oxygen SpO2 Card
        Column() {
          Row() {
            Image($r('app.media.oxygensaturation'))
              .width(40)
              .height(40)
              .objectFit(ImageFit.Contain)
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#E8EEFF')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Text('Oxygen (SpO2)')
            .fontSize(13)
            .fontColor('#737685')
            .margin({ bottom: 4 })
          
          Text('98 %')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .margin({ bottom: 8 })

          Row() {
            Text('● Healthy')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#006E2F')
          }
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 5. Daily Steps Card (Horizontal Layout)
      Row() {
        Row() {
          Image($r('app.media.walking'))
            .width(40)
            .height(40)
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
          Text('Daily Steps')
            .fontSize(12)
            .fontColor('#737685')
            .margin({ bottom: 2 })
          Text('4,500')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // Steps Progress Bar
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width(100)
            .height(6)
            .backgroundColor('#E8EEFF')
            .borderRadius(3)
          
          Row()
            .width(60) // 60% progress filled
            .height(6)
            .backgroundColor('#006E2F')
            .borderRadius(3)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
      .margin({ bottom: 16 })
      .alignItems(VerticalAlign.Center)

      // 6. Next Medication Card
      Column() {
        if (this.getNextPendingMed() !== undefined) {
          Row() {
            Text('Next Medication')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
            
            Blank()
            
            Text(this.getNextPendingMed()!.time)
              .fontSize(12)
              .fontColor('#737685')
          }
          .width('100%')
          .margin({ bottom: 12 })

          // Medication Details
          Row() {
            Row() {
              Image($r('app.media.drugs'))
                .width(32)
                .height(32)
                .objectFit(ImageFit.Contain)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor('#E8EEFF')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Column() {
              Text(this.getNextPendingMed()!.name)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 2 })
              
              Text(this.getNextPendingMed()!.dosage)
                .fontSize(12)
                .fontColor('#737685')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F3F4F5')
          .borderRadius(16)
          .margin({ bottom: 12 })

          // Action Button
          Button() {
            Row() {
              Image($r('app.media.like'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
                .margin({ right: 6 })
              Text('Mark as Taken')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
          }
          .width('100%')
          .height(48)
          .backgroundColor('#003D9B')
          .borderRadius(12)
          .onClick(() => {
            const nextMed = this.getNextPendingMed();
            if (nextMed !== undefined) {
              this.dashboardMeds = this.dashboardMeds.map((med: MedicationItem): MedicationItem => {
                if (med.id === nextMed.id) {
                  return {
                    id: med.id,
                    name: med.name,
                    dosage: med.dosage,
                    time: med.time,
                    taken: true
                  };
                }
                return med;
              });
              promptAction.showToast({ message: `${nextMed.name} marked as taken!` });
            }
          })
        } else {
          // All medications are taken!
          Column() {
            Image($r('app.media.confetti'))
              .width(44)
              .height(44)
              .objectFit(ImageFit.Contain)
              .margin({ bottom: 8 })
            Text('All medications taken for today!')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#006E2F')
              .margin({ bottom: 4 })
            Text('You are doing great staying on schedule.')
              .fontSize(12)
              .fontColor('#737685')
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// FAMILY DASHBOARD VIEW (STUB)
// ----------------------------------------------------
@Component
struct FamilyDashboardView {
  @Prop fullName: string;

  build() {
    Column() {
      Row() {
        Text('GuardianBand')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#003D9B')
      }
      .width('100%')
      .margin({ bottom: 20 })

      Column() {
        Text('Family Member Dashboard')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#006E2F')
          .margin({ bottom: 8 })

        Text('Monitor your loved ones health status and receive emergency notifications.')
          .fontSize(14)
          .fontColor('#434654')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(24)
      .backgroundColor('rgba(255, 255, 255, 0.85)')
      .borderRadius(24)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetX: 0, offsetY: 4 })
    }
    .width('100%')
  }
}

// ----------------------------------------------------
// RESPONDER DASHBOARD VIEW (STUB)
// ----------------------------------------------------
@Component
struct ResponderDashboardView {
  @Prop fullName: string;

  build() {
    Column() {
      Row() {
        Text('GuardianBand')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#003D9B')
      }
      .width('100%')
      .margin({ bottom: 20 })

      Column() {
        Text('Emergency Responder Dashboard')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#8C0013')
          .margin({ bottom: 8 })

        Text('Secure emergency medical info access panel via QR scan verification.')
          .fontSize(14)
          .fontColor('#434654')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(24)
      .backgroundColor('rgba(255, 255, 255, 0.85)')
      .borderRadius(24)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.5)', style: BorderStyle.Solid })
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetX: 0, offsetY: 4 })
    }
    .width('100%')
  }
}