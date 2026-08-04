// HomePage.ets
import { router, promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

interface MedicationItem {
  id: string;
  name: string;
  dosage: string;
  time: string;
  taken: boolean;
}

// Interface for chart coordinates to satisfy ArkTS strict typing
interface ChartPoint {
  x: number;
  y: number;
}

@Entry
@Component
struct HomePage {
  @StorageLink('token') token: string = '';
  @StorageLink('userRole') userRole: string = 'patient';
  @StorageLink('fullName') fullName: string = 'User';
  @StorageLink('profilePicture') profilePicture: string = '';

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

      Scroll(this.scroller) {
        Column() {
          if (this.userRole === 'patient') {
            PatientDashboardView({ fullName: this.fullName })
          } else if (this.userRole === 'family') {
            FamilyDashboardView({ fullName: this.fullName })
          } else {
            ResponderDashboardView({ fullName: this.fullName })
          }

          Blank().height(100)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

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
  @StorageLink('dashboardMeds') dashboardMeds: MedicationItem[] = [];

  @State currentHeartRate: number = 72;
  @State currentOxygen: number = 98;
  @State currentSteps: number = 4500;
  @State currentCalories: number = 1450;
  private timerId: number = -1;

  // --- REAL-TIME TELEMETRY HISTORY LISTS FOR LIVE CHARTS ---
  @State heartRateHistory: number[] = [70, 72, 71, 73, 72, 70, 72];
  @State oxygenHistory: number[] = [97, 98, 98, 97, 99, 98, 98];

  // --- MODAL GRAPH STATES ---
  @State isGraphModalOpen: boolean = false;
  @State selectedMetric: string = 'Heart Rate';
  @State selectedValue: number = 72;

  private chartCanvasController: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  openLiveChartModal(metricName: string, currentVal: number) {
    this.selectedMetric = metricName;
    this.selectedValue = currentVal;
    this.isGraphModalOpen = true;
  }

  aboutToAppear() {
    this.startSensorSimulation();
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  startSensorSimulation() {
    this.timerId = setInterval(() => {
      let hrDelta = Math.floor(Math.random() * 5) - 2;
      this.currentHeartRate = Math.max(60, Math.min(100, this.currentHeartRate + hrDelta));

      let o2Delta = Math.floor(Math.random() * 3) - 1;
      this.currentOxygen = Math.max(95, Math.min(100, this.currentOxygen + o2Delta));

      this.currentSteps += Math.floor(Math.random() * 3);
      this.currentCalories += Math.floor(Math.random() * 2);

      this.heartRateHistory.push(this.currentHeartRate);
      if (this.heartRateHistory.length > 15) {
        this.heartRateHistory.shift();
      }

      this.oxygenHistory.push(this.currentOxygen);
      if (this.oxygenHistory.length > 15) {
        this.oxygenHistory.shift();
      }

      if (this.isGraphModalOpen) {
        if (this.selectedMetric === 'Heart Rate') {
          this.selectedValue = this.currentHeartRate;
        } else if (this.selectedMetric === 'Oxygen') {
          this.selectedValue = this.currentOxygen;
        }
        this.drawMinimalistLineChart();
      }
    }, 2000);
  }

  getInitials(name: string): string {
    if (!name) return 'GB';
    const parts: string[] = name.trim().split(' ');
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
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppHeader({ title: 'Home Page' })
          .margin({ bottom: 16 })

        Row() {
          if (this.profilePicture === '') {
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

          Row() {
            Circle({ width: 8, height: 8 }).fill('#006E2F').margin({ right: 6 })
            Text('Sensors Active')
              .fontSize(12)
              .fontColor('#006E2F')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#E6F9ED')
          .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 20 })

        // AI Health Insight Box
        Row() {
          Row()
            .width(4)
            .height(42)
            .backgroundColor('#003D9B')
            .borderRadius(2)
            .margin({ right: 16 })

          Image($r('app.media.idea'))
            .width(32)
            .height(32)
            .objectFit(ImageFit.Contain)
            .margin({ right: 12 })

          Column() {
            Text('AI Health Insight')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#003D9B')
              .margin({ bottom: 4 })
            Text(`"Your vitals are stable. Heart rate is trending smoothly around ${this.currentHeartRate} bpm. Activity is up 10% today!"`)
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
        .margin({ bottom: 20 })
        .alignItems(VerticalAlign.Center)

        Text('Live Vitals & Activity')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#191C1D')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 4, bottom: 12 })

        // 2x2 Grid for Vital Cards
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          this.HeartRateCard()
          this.OxygenCard()
          this.SleepCard()
          this.CaloriesCard()
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Daily Steps Card
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
            Text(`${this.currentSteps}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#191C1D')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width(100)
              .height(6)
              .backgroundColor('#E8EEFF')
              .borderRadius(3)

            Row()
              .width(75)
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
        .margin({ bottom: 20 })
        .alignItems(VerticalAlign.Center)

        // Next Medication Card
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
            Column() {
              Image($r('app.media.confetti'))
                .width(44)
                .height(44)
                .objectFit(ImageFit.Contain)
                .margin({ bottom: 8 })
              Text('No pending medications')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#006E2F')
                .margin({ bottom: 4 })
              Text('Add medications via Meds schedule to track them here.')
                .fontSize(12)
                .fontColor('#737685')
                .textAlign(TextAlign.Center)
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

      // --- SWEET MINIMALIST REAL-TIME LINE CHART MODAL ---
      if (this.isGraphModalOpen) {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.35)')
            .onClick(() => { this.isGraphModalOpen = false; })

          Column() {
            // Header
            Row() {
              Column() {
                Text(`${this.selectedMetric} Live Trend`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#191C1D')
                Text('Real-time session stream')
                  .fontSize(12)
                  .fontColor('#737685')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Button('✕')
                .type(ButtonType.Circle)
                .width(32)
                .height(32)
                .backgroundColor('#F1F2F5')
                .fontColor('#191C1D')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .onClick(() => { this.isGraphModalOpen = false; })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Live Value Pill
            Row() {
              Text('Current Reading: ')
                .fontSize(13)
                .fontColor('#737685')
              Text(`${this.selectedValue} ${this.selectedMetric === 'Heart Rate' ? 'bpm' : '%'}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#003D9B')
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#E8EEFF')
            .borderRadius(12)
            .margin({ bottom: 16 })

            // --- MINIMALIST CLEAN CANVAS CHART ---
            Canvas(this.chartCanvasController)
              .width('100%')
              .height(180)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .border({ width: 1, color: '#EBECEF' })
              .onReady(() => {
                this.drawMinimalistLineChart();
              })
              .margin({ bottom: 20 })

            // Close Button
            Button('Done')
              .width('100%')
              .height(44)
              .backgroundColor('#003D9B')
              .fontColor(Color.White)
              .borderRadius(12)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .onClick(() => { this.isGraphModalOpen = false; })
          }
          .width('90%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(28)
          .shadow({ radius: 16, color: 'rgba(0,0,0,0.15)', offsetY: 8 })
          .zIndex(20)
        }
        .width('100%')
        .height('100%')
        .zIndex(15)
      }
    }
    .width('100%')
  }

  // Algorithm using explicit ChartPoint interface to satisfy ArkTS type safety
  drawMinimalistLineChart() {
    const ctx = this.chartCanvasController;
    const width = 300;
    const height = 180;

    ctx.clearRect(0, 0, width, height);

    let dataPoints = this.selectedMetric === 'Heart Rate' ? this.heartRateHistory : this.oxygenHistory;
    if (dataPoints.length === 0) return;

    ctx.strokeStyle = '#F1F2F5';
    ctx.lineWidth = 1;
    for (let y = 30; y < height; y += 35) {
      ctx.beginPath();
      ctx.moveTo(15, y);
      ctx.lineTo(width - 15, y);
      ctx.stroke();
    }

    let minVal = Math.min(...dataPoints);
    let maxVal = Math.max(...dataPoints);
    if (minVal === maxVal) {
      minVal -= 5;
      maxVal += 5;
    }

    let paddingX = 25;
    let usableWidth = width - (paddingX * 2);
    let stepX = dataPoints.length > 1 ? usableWidth / (dataPoints.length - 1) : usableWidth;

    ctx.strokeStyle = '#003D9B';
    ctx.lineWidth = 2.5;
    ctx.beginPath();

    let coords: ChartPoint[] = [];

    for (let i = 0; i < dataPoints.length; i++) {
      let x = paddingX + (i * stepX);
      let normalized = (dataPoints[i] - minVal) / (maxVal - minVal);
      let y = height - 30 - (normalized * (height - 60));
      coords.push({ x: x, y: y });

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();

    for (let i = 0; i < coords.length; i++) {
      ctx.fillStyle = '#FFFFFF';
      ctx.strokeStyle = '#003D9B';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(coords[i].x, coords[i].y, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  }

  @Builder HeartRateCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.heart'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFEBEA')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Heart Rate')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentHeartRate} bpm`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#BA1A1A').margin({ right: 4 })
        Text('Normal')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#BA1A1A')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
    .onClick(() => { this.openLiveChartModal('Heart Rate', this.currentHeartRate); })
  }

  @Builder OxygenCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.oxygensaturation'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#E8EEFF')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Oxygen (SpO2)')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentOxygen} %`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#003D9B').margin({ right: 4 })
        Text('Healthy')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#003D9B')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
    .onClick(() => { this.openLiveChartModal('Oxygen', this.currentOxygen); })
  }

  @Builder SleepCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.heart'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#F3E8FF')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Sleep Quality')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text('6h 45m')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#5C0099').margin({ right: 4 })
        Text('Restful')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5C0099')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
  }

  @Builder CaloriesCard() {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.walking'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFF4E5')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('Calories Burned')
        .fontSize(13)
        .fontColor('#737685')
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Text(`${this.currentCalories} kcal`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#191C1D')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Circle({ width: 6, height: 6 }).fill('#854E00').margin({ right: 4 })
        Text('Active')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#854E00')
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
    .margin({ bottom: 16 })
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
      AppHeader({ title: 'GuardianBand Family' })
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
      AppHeader({ title: 'GuardianBand Responder' })
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