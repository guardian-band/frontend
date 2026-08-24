import { promptAction } from '@kit.ArkUI';

export interface OrganRisk {
  /** Body-map id, e.g. 'liver'. See `RiskAnalysis.organIdFor`. */
  organId: string;
  /**
   * The model's own wording for the organ system, e.g.
   * "Hepatobiliary (Liver)". Shown as the row title: capitalising the id gave
   * "Eyeear" for anything the body map does not know about.
   */
  label?: string;
  riskLevel: 'low' | 'medium' | 'high';
  /** 0..1 from the model. Shown next to the level so the colour is explained. */
  probability?: number;
  culpritMeds?: string[];
  detailMessage?: string;
}

export interface AnalysisResult {
  overallStatus: 'safe' | 'medium' | 'high';
  message: string;
  organs: OrganRisk[];
}

/**
 * Body-map ids that have a spot on the figure. The model reports 15 organ
 * SYSTEMS, and several of them ("Dermatologic", "Immune System",
 * "General Disorders & Systemic") are body-wide - there is no honest single
 * point to pin them to. Those are left off the figure and appear only in the
 * list below it, instead of piling up on top of each other at its centre.
 */
const LOCATABLE_ORGANS: string[] = [
  'brain', 'lungs', 'liver', 'stomach', 'kidney', 'intestines', 'vascular', 'breasts', 'joints'
];

export function hasBodyPosition(organId: string): boolean {
  return LOCATABLE_ORGANS.includes(organId);
}

/**
 * Media resource per organ system. Replaces plain emojis with dedicated icons.
 */
export function getOrganResource(organId: string): Resource | null {
  switch (organId) {
    case 'vascular': return $r('app.media.med_heart');
    case 'systemic': return $r('app.media.epilepsy');
    case 'lungs': return $r('app.media.lungs');
    case 'endocrine': return $r('app.media.metabolism');
    case 'stomach':
    case 'intestines': return $r('app.media.intestine');
    case 'blood': return $r('app.media.blood');
    default: return null;
  }
}

/**
 * Icon per organ system fallback.
 */
export function organIcon(organId: string): string {
  switch (organId) {
    case 'brain': return '🧠';
    case 'liver': return '🩸';
    case 'kidney': return '💧';
    case 'joints': return '🦴';
    case 'breasts': return '🧬';
    case 'skin': return '🧴';
    case 'psychiatric': return '🧩';
    case 'immune': return '🛡️';
    case 'eyeEar': return '👁️';
    case 'infection': return '🦠';
    default: return '⚠️';
  }
}

/** Row title: the model's own wording, falling back to the id. */
export function organDisplayLabel(organ: OrganRisk): string {
  if (organ.label !== undefined && organ.label.length > 0) {
    return organ.label;
  }
  return organ.organId.charAt(0).toUpperCase() + organ.organId.slice(1);
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
  
  getRiskColor(level: string): string {
    if (level === 'high') return '#BA1A1A';
    if (level === 'medium') return '#B45309';
    return '#006E2F';
  }
  
  getRiskIconBg(level: string): string {
    if (level === 'high') return '#FEE2E2';
    if (level === 'medium') return '#FEF3C7';
    return '#DCFCE7';
  }

  getRiskBadgeBg(level: string): string {
    if (level === 'high') return '#FEF2F2';
    if (level === 'medium') return '#FFFBEB';
    return '#F0FDF4';
  }

  getRiskBadgeBorder(level: string): string {
    if (level === 'high') return '#FECACA';
    if (level === 'medium') return '#FDE68A';
    return '#BBF7D0';
  }

  build() {
    Column() {
      Row() {
        // Left Icon Container with soft pastel background
        Row() {
          if (getOrganResource(this.organ.organId) !== null) {
            Image(getOrganResource(this.organ.organId) as Resource)
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
          } else {
            Text(organIcon(this.organ.organId))
              .fontSize(20)
          }
        }
        .width(44)
        .height(44)
        .backgroundColor(this.getRiskIconBg(this.organ.riskLevel))
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        // Title and Risk Badge
        Column() {
          Text(organDisplayLabel(this.organ))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#191C1D')
            .lineHeight(20)

          // Modern Pill Badge for Risk & Probability
          Row() {
            Circle({ width: 6, height: 6 })
              .fill(this.getRiskColor(this.organ.riskLevel))
              .margin({ right: 5 })

            Text(this.organ.probability !== undefined
              ? `${this.organ.riskLevel.toUpperCase()} RISK · ${Math.round(this.organ.probability * 100)}%`
              : `${this.organ.riskLevel.toUpperCase()} RISK`)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getRiskColor(this.organ.riskLevel))
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.getRiskBadgeBg(this.organ.riskLevel))
          .borderRadius(6)
          .border({ width: 1, color: this.getRiskBadgeBorder(this.organ.riskLevel) })
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // Expand / Collapse Chevron Button
        if (this.organ.detailMessage) {
          Row() {
            Text(this.isExpanded ? '▲' : '▼')
              .fontSize(12)
              .fontColor('#9CA3AF')
          }
          .width(28)
          .height(28)
          .justifyContent(FlexAlign.Center)
          .borderRadius(14)
          .backgroundColor(this.isExpanded ? '#F3F4F6' : Color.Transparent)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Expanded Details
      if (this.isExpanded && this.organ.detailMessage) {
        Column() {
          Divider().color('#F0F2F5').margin({ top: 12, bottom: 12 })
          
          if (this.organ.culpritMeds && this.organ.culpritMeds.length > 0) {
            Row() {
              Text('Triggered by:')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#6B7280')
                .margin({ right: 6 })

              Text(this.organ.culpritMeds.join(', '))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#F1F5F9')
            .borderRadius(8)
            .margin({ bottom: 8 })
          }

          Text(this.organ.detailMessage)
            .fontSize(13)
            .fontColor('#4B5563')
            .lineHeight(19)
            .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F8F9FB')
    .borderRadius(16)
    .border({ width: 1, color: '#E8EAED' })
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
  
  build() {
    Column() {
      // --- COLLAPSIBLE HEADER (Always Visible) ---
      Row() {
        Image($r('app.media.stethoscope'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .margin({ right: 10 })

        Column() {
          Text('AI Side Effect Analysis')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#434654')

          Text(this.isExpanded ? 'Tap to collapse' : 'Tap to view potential side effects')
            .fontSize(12)
            .fontColor('#737685')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.isExpanded ? '▲' : '▼')
          .fontSize(14)
          .fontColor('#8F92A1')
      }
      .width('100%')
      .onClick(() => {
        animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
          this.isExpanded = !this.isExpanded;
        });
      })

      // --- EXPANDABLE CONTENT ---
      if (this.isExpanded) {
        Column() {
          Divider().color('#EBECEF').margin({ top: 12, bottom: 12 })

          Column() {
            // Heatmap Image & Markers Container
            Stack({ alignContent: Alignment.TopStart }) {
              Image(this.userGender === 'male' ? $r('app.media.body_heatmap_male') : $r('app.media.body_heatmap_female'))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)

              // Dynamic Pulse Markers based on AI Result. Only organs with a
              // real location are pinned; the body-wide systems would all land
              // on the same default point in the middle of the figure.
              ForEach(this.analysisResult.organs.filter((o: OrganRisk) => hasBodyPosition(o.organId)),
                (organ: OrganRisk, index: number) => {
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
            .margin({ top: 8, bottom: 16 })

            // Dynamic Interactive Legend
            if (this.analysisResult.organs.length > 0) {
              Column({ space: 10 }) {
                ForEach(this.analysisResult.organs, (organ: OrganRisk) => {
                  OrganRiskCard({ organ: organ })
                })
              }
              .width('100%')
              .margin({ bottom: 16 })
            } else {
              // Safe State
              Row() {
                Text('All clear! No major organ risks detected.')
                  .fontSize(13)
                  .fontColor('#006E2F')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#E6F9ED')
              .borderRadius(12)
              .margin({ bottom: 16 })
            }

            // Incompatibility Summary Card (Dynamic AI Message)
            Column() {
              Row() {
                if (this.analysisResult.overallStatus !== 'safe') {
                  Image($r('app.media.alert'))
                    .width(20)
                    .height(20)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                } else {
                  Image($r('app.media.information'))
                    .width(20)
                    .height(20)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 8 })
                }
                Text('AI Analysis Summary')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.analysisResult.overallStatus === 'safe' ? '#006E2F' : '#410004')
              }
              .width('100%')
              .margin({ bottom: 8 })

              Text(this.analysisResult.message)
                .fontSize(13)
                .fontColor('#191C1D')
                .lineHeight(19)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.analysisResult.overallStatus === 'safe' ? '#E6F9ED' : 'rgba(255, 179, 174, 0.2)')
            .borderRadius(12)
            .margin({ bottom: 4 })

          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .border({ width: 1, color: '#EBECEF' })
  }
}