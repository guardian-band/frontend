import { promptAction } from '@kit.ArkUI';

export interface OrganRisk {
  organId: string;
  riskLevel: 'low' | 'medium' | 'high';
  culpritMeds?: string[];
  detailMessage?: string;
}

export interface AnalysisResult {
  overallStatus: 'safe' | 'medium' | 'high';
  message: string;
  organs: OrganRisk[];
}

export class MarkerPosition {
  x: string = '50%';
  y: string = '50%';
  constructor(x: string, y: string) {
    this.x = x;
    this.y = y;
  }
}

@Component
struct PulseMarker {
  @Prop markerSize: number = 32;
  @Prop color: string = '#BA1A1A';
  @Prop delay: number = 0;
  
  @State scaleValue: number = 0.5;
  @State opacityValue: number = 1.0;

  aboutToAppear() {
    setTimeout(() => {
      this.scaleValue = 2.0;
      this.opacityValue = 0.0;
    }, this.delay);
  }

  build() {
    Circle({ width: this.markerSize, height: this.markerSize })
      .fill(this.color)
      .opacity(this.opacityValue)
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .animation({
        duration: 1500,
        curve: Curve.EaseOut,
        iterations: -1,
        playMode: PlayMode.Normal
      })
  }
}

@Component
struct OrganRiskCard {
  @Prop organ: OrganRisk;
  @State isExpanded: boolean = false;
  
  getRiskColor(level: string) {
    if (level === 'high') return '#BA1A1A';
    if (level === 'medium') return '#FF8C00';
    return '#006E2F';
  }
  
  getRiskBgColor(level: string) {
    if (level === 'high') return 'rgba(186, 26, 26, 0.4)';
    if (level === 'medium') return 'rgba(255, 140, 0, 0.4)';
    return 'rgba(0, 110, 47, 0.4)';
  }

  getOrganIcon(organId: string): string {
    switch (organId) {
      case 'brain': return '🧠';
      case 'lungs': return '🫁';
      case 'liver': return '🩸';
      case 'stomach': return '💊';
      case 'kidney': return '💧';
      case 'intestines': return '🦠';
      case 'joints': return '🦴';
      case 'vascular': return '❤️';
      case 'breasts': return '🧬';
      default: return '⚠️';
    }
  }
  
  getOrganLabel(organId: string): string {
    return organId.charAt(0).toUpperCase() + organId.slice(1);
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text(this.getOrganIcon(this.organ.organId))
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .backgroundColor(this.getRiskBgColor(this.organ.riskLevel))
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text(this.getOrganLabel(this.organ.organId))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
          Text(this.organ.riskLevel.toUpperCase() + ' RISK')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getRiskColor(this.organ.riskLevel))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.organ.detailMessage) {
          Text(this.isExpanded ? '▲' : '▼')
            .fontSize(14)
            .fontColor('#8F92A1')
            .margin({ right: 8 })
        }
      }
      .width('100%')

      if (this.isExpanded && this.organ.detailMessage) {
        Column() {
          Divider().color('#EBECEF').margin({ top: 12, bottom: 12 })
          
          if (this.organ.culpritMeds && this.organ.culpritMeds.length > 0) {
            Row() {
              Text('Triggered by: ')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#434654')
              Text(this.organ.culpritMeds.join(', '))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          Text(this.organ.detailMessage)
            .fontSize(13)
            .fontColor('#434654')
            .lineHeight(20)
            .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#EDEEEF')
    .borderRadius(12)
    .onClick(() => {
      if (this.organ.detailMessage) {
        animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
          this.isExpanded = !this.isExpanded;
        });
      }
    })
  }
}

@Component
export struct SafetyAnalysisCard {
  @Prop analysisResult: AnalysisResult;
  @Prop userGender: string; // 'male' | 'female'
  
  @State isExpanded: boolean = false;
  @State isBooking: boolean = false;
  @State isBooked: boolean = false;

  getRiskColor(level: string) {
    if (level === 'high') return '#BA1A1A';
    if (level === 'medium') return '#FF8C00';
    return '#006E2F';
  }
  
  getRiskBgColor(level: string) {
    if (level === 'high') return 'rgba(186, 26, 26, 0.4)';
    if (level === 'medium') return 'rgba(255, 140, 0, 0.4)';
    return 'rgba(0, 110, 47, 0.4)';
  }

  getOrganPosition(organId: string): MarkerPosition {
    // Coordinates tuned for the 1:1 minimalist images in a 1:1 stack
    switch (organId) {
      case 'brain': return new MarkerPosition('50%', '13%'); // Head
      case 'lungs': return new MarkerPosition('50%', '28%'); // Chest
      case 'liver': return new MarkerPosition('45%', '39%'); // Right abdomen (user's right)
      case 'stomach': return new MarkerPosition('55%', '40%'); // Left abdomen (user's left)
      case 'kidney': return new MarkerPosition('50%', '45%'); // Lower abdomen
      case 'intestines': return new MarkerPosition('50%', '52%'); // Lower abdomen
      case 'vascular': return new MarkerPosition('50%', '25%'); // Heart/Chest area
      case 'breasts': return new MarkerPosition('50%', '30%'); // Chest area
      case 'joints': return new MarkerPosition('50%', '82%'); // Knees
      default: return new MarkerPosition('50%', '50%');
    }
  }
  
  getOrganIcon(organId: string): string {
    switch (organId) {
      case 'brain': return '🧠';
      case 'lungs': return '🫁';
      case 'liver': return '🩸';
      case 'stomach': return '💊';
      case 'kidney': return '💧';
      case 'intestines': return '🦠';
      case 'joints': return '🦴';
      case 'vascular': return '❤️';
      case 'breasts': return '🧬';
      default: return '⚠️';
    }
  }
  
  getOrganLabel(organId: string): string {
    return organId.charAt(0).toUpperCase() + organId.slice(1);
  }

  build() {
    Column() {
      // --- COLLAPSIBLE HEADER (Always Visible) ---
      Row() {
        Row() {
          Text('🩺')
            .fontSize(20)
            .margin({ right: 12 })
          
          Column() {
            Text('AI Side Effect Analysis')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.analysisResult.overallStatus === 'safe' ? '#006E2F' : '#191C1D')
            
            Text(this.isExpanded ? 'Tap to collapse' : 'Tap to view potential side effects')
              .fontSize(13)
              .fontColor('#8F92A1')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        
        Blank()
        
        Text(this.isExpanded ? '▲' : '▼')
          .fontSize(14)
          .fontColor('#003D9B')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(this.isExpanded ? { topLeft: 24, topRight: 24, bottomLeft: 0, bottomRight: 0 } : 24)
      .shadow(this.isExpanded ? null : { radius: 4, color: 'rgba(0,0,0,0.05)' })
      .onClick(() => {
        animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
          this.isExpanded = !this.isExpanded;
        });
      })
      
      // --- EXPANDABLE CONTENT ---
      if (this.isExpanded) {
        Column() {
          Divider().color('#EBECEF').width('100%')
          
          Column() {
            // Heatmap Image & Markers Container
            Stack({ alignContent: Alignment.TopStart }) {
              Image(this.userGender === 'male' ? $r('app.media.body_heatmap_male') : $r('app.media.body_heatmap_female'))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
              
              // Dynamic Pulse Markers based on AI Result
              ForEach(this.analysisResult.organs, (organ: OrganRisk, index: number) => {
                Column() {
                  PulseMarker({ 
                    markerSize: organ.riskLevel === 'high' ? 48 : 32, 
                    color: this.getRiskBgColor(organ.riskLevel), 
                    delay: index * 300 
                  })
                }
                .position(this.getOrganPosition(organ.organId))
                .markAnchor({ x: '50%', y: '50%' })
              })
            }
            .width('100%')
            .aspectRatio(1) // Force the Stack itself to be perfectly square
            .backgroundColor('#F3F4F5')
            .borderRadius(16)
            .clip(true)
            .margin({ top: 20, bottom: 24 })

            // Dynamic Interactive Legend
            if (this.analysisResult.organs.length > 0) {
              Column({ space: 12 }) {
                ForEach(this.analysisResult.organs, (organ: OrganRisk) => {
                  OrganRiskCard({ organ: organ })
                })
              }
              .width('100%')
              .margin({ bottom: 24 })
            } else {
              // Safe State
              Row() {
                Text('✅ All clear! No major organ risks detected.')
                  .fontSize(14)
                  .fontColor('#006E2F')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#E6F9ED')
              .borderRadius(12)
              .margin({ bottom: 24 })
            }

            // Incompatibility Summary Card (Dynamic AI Message)
            Column() {
              Row() {
                Text(this.analysisResult.overallStatus === 'safe' ? 'ℹ️' : '⚠️')
                  .fontSize(20)
                  .margin({ right: 8 })
                Text('AI Analysis Summary')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.analysisResult.overallStatus === 'safe' ? '#006E2F' : '#410004')
              }
              .width('100%')
              .margin({ bottom: 12 })

              Text(this.analysisResult.message)
                .fontSize(15)
                .fontColor('#191C1D')
                .lineHeight(22)
            }
            .width('100%')
            .padding(20)
            .backgroundColor(this.analysisResult.overallStatus === 'safe' ? '#E6F9ED' : 'rgba(255, 179, 174, 0.2)')
            .borderRadius(16)
            .margin({ bottom: 24 })

          }
          .padding(20)
        }
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 4 })
      }
    }
    .width('100%')
  }
}
