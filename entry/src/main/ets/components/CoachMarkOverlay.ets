import { componentUtils, display, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { TutorialManager } from '../utils/TutorialManager';

@Component
export struct CoachMarkOverlay {
  @Prop targetId: string = '';
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop stepIndex: number = 1;
  @Prop totalSteps: number = 4;
  
  @State targetX: number = 0;
  @State targetY: number = 0;
  @State targetW: number = 0;
  @State targetH: number = 0;
  @State isReady: boolean = false;
  @State screenWidth: number = 360;
  @State screenHeight: number = 780;

  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear() {
    try {
      let displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(displayInfo.width);
      this.screenHeight = px2vp(displayInfo.height);
    } catch (err) {
      console.warn('CoachMark', 'Display metrics error: ' + err);
      this.screenWidth = 360;
      this.screenHeight = 780;
    }
    
    // Wait for page transition animations to completely finish!
    setTimeout(() => {
      this.calculateTargetPosition();
    }, 800);
  }

  calculateTargetPosition() {
    try {
      let targetInfo = componentUtils.getRectangleById(this.targetId);
      if (targetInfo && targetInfo.size && targetInfo.size.width > 0 && targetInfo.size.height > 0) {
        let rawW = px2vp(targetInfo.size.width);
        let rawH = px2vp(targetInfo.size.height);
        let rawX = px2vp(targetInfo.screenOffset.x);
        let rawY = px2vp(targetInfo.screenOffset.y);
        
        this.targetW = rawW;
        this.targetH = rawH;
        this.targetX = rawX;
        this.targetY = rawY;

        // MANUEL HİZALAMA (Tuning)
        if (this.targetId === 'tab_meds') {
          this.targetW = 46;
          this.targetH = 46;
          this.targetX = rawX + (rawW - 46) / 2;
          // Çember şu an tam metnin altında çıkıyor, ikonu içine alması için Y'yi ~36 piksel daha yukarı alıyoruz
          this.targetY = rawY - 26;
        } else if (this.targetId === 'btn_show_qr') {
          // Kullanıcı sadece butonu değil, tüm "Share Patient QR" kartını vurgulamak istiyor!
          this.targetW = this.screenWidth - 48; // Ekranın sağı ve solundaki 24px boşlukları çıkarıyoruz
          this.targetH = 88; // Tüm kartın tahmini yüksekliği
          this.targetX = 24; // Kartın sol başlangıç noktası
          this.targetY = 420; // 380'di, 40px aşağı aldık (manuel hesapta safe area offset'e gerek yokmuş)
        } else if (this.targetId === 'btn_sos') {
          // SOSPage'deki Scroll içinde olduğu için getRectangleById 0 dönüyor! Manuel hesaplıyoruz.
          this.targetW = 180;
          this.targetH = 180;
          this.targetX = (this.screenWidth / 2) - 90;
          this.targetY = 175; // 170 (aşağı dedin) ile 180 (yukarı dedin) arasının tam milimetrik ortası!
        }
        
        this.isReady = true;
      } else {
        setTimeout(() => {
          this.calculateTargetPosition();
        }, 200);
      }
    } catch (err) {
      setTimeout(() => {
        this.calculateTargetPosition();
      }, 200);
    }
  }

  handleNext() {
    if (this.stepIndex === 1) {
      router.pushUrl({ url: 'pages/MedsPage' });
      TutorialManager.nextStep();
    } else if (this.stepIndex === 2) {
      router.pushUrl({ url: 'pages/ProfilePage' });
      TutorialManager.nextStep();
    } else if (this.stepIndex === 3) {
      router.pushUrl({ url: 'pages/SOSPage' });
      TutorialManager.nextStep();
    } else {
      TutorialManager.finishTutorial(this.context);
    }
  }

  handleSkip() {
    TutorialManager.skipTutorial(this.context);
  }

  getHighlightRadius(): number {
    const isSquare = Math.abs(this.targetW - this.targetH) < 25;
    if (isSquare) {
      return Math.max(this.targetW, this.targetH) / 2 + 8;
    }
    return 16;
  }

  getTooltipY(): number {
    if (this.stepIndex === 1) {
      return Math.max(80, this.targetY - 220);
    }
    if (this.stepIndex === 3) {
      return this.targetY + this.targetH + 16;
    }
    if (this.targetY + this.targetH + 210 < this.screenHeight - 100) {
      return Math.max(60, this.targetY + this.targetH + 16);
    }
    return Math.max(60, this.targetY - 210);
  }

  getOverlayPath(): string {
    // Path string komutları pikselleri (px) baz alır, viewport pikselleri (vp) değil!
    // Bu yüzden tüm vp koordinatlarını px'e çevirmeliyiz (vp2px)
    const sw = vp2px(this.screenWidth);
    const sh = vp2px(this.screenHeight + 300); // Ekstra güvenlik payı
    const x = vp2px(Math.max(4, this.targetX - 8));
    const y = vp2px(Math.max(4, this.targetY - 8));
    const w = vp2px(this.targetW + 16);
    const h = vp2px(this.targetH + 16);
    const r = vp2px(this.getHighlightRadius());
    
    // Dış çerçeve (Saat yönünde)
    const bgPath = `M0 0 H${sw} V${sh} H0 Z`;
    
    // İçerideki delik (Saat yönünün tersine - non-zero winding kuralı ile delik oluşturur)
    const holePath = `M${x+r} ${y} ` +
                     `A${r} ${r} 0 0 0 ${x} ${y+r} ` +
                     `V${y+h-r} ` +
                     `A${r} ${r} 0 0 0 ${x+r} ${y+h} ` +
                     `H${x+w-r} ` +
                     `A${r} ${r} 0 0 0 ${x+w} ${y+h-r} ` +
                     `V${y+r} ` +
                     `A${r} ${r} 0 0 0 ${x+w-r} ${y} Z`;
                     
    return `${bgPath} ${holePath}`;
  }

  build() {
    if (this.isReady) {
      Stack() {
        // Tıklamaları yakalayacak görünmez katman (Path tıklama kaçırmasın diye garantiye alıyoruz)
        Rect()
          .width('100%')
          .height('100%')
          .fill('rgba(0,0,0,0)')
          .onClick(() => this.handleNext())

        // 1. Ortası delik (spotlight) yarı saydam karanlık arka plan
        Path()
          .commands(this.getOverlayPath())
          .fill('rgba(15, 23, 42, 0.78)')
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.None)

        // 2. Hedefi saran parlayan mavi yüzük
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            // ArkUI'ın optimize edip silmesini engellemek için tam şeffaf yerine 0.01 opaklık
            .backgroundColor('rgba(255, 255, 255, 0.01)')
            .borderRadius(this.getHighlightRadius())
            .border({ width: 3, color: '#3B82F6', style: BorderStyle.Solid })
            .shadow({ radius: 24, color: 'rgba(59, 130, 246, 0.6)', offsetX: 0, offsetY: 0 })
        }
        .width(this.targetW + 16)
        .height(this.targetH + 16)
        .position({ x: Math.max(4, this.targetX - 8), y: Math.max(4, this.targetY - 8) })
        .hitTestBehavior(HitTestMode.None)

        // 3. Floating Tooltip Balloon Card next to spotlight hole
        Column() {
          // Step pill badge
          Row() {
            Text(`STEP ${this.stepIndex} OF ${this.totalSteps}`)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2563EB')
              .letterSpacing(1)
          }
          .backgroundColor('#EFF6FF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .margin({ bottom: 10 })

          // Title
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .margin({ bottom: 8 })

          // Description
          Text(this.description)
            .fontSize(13)
            .fontColor('#475569')
            .lineHeight(20)
            .margin({ bottom: 18 })

          // Action Buttons
          Row() {
            Text('Skip')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#94A3B8')
              .onClick(() => this.handleSkip())

            Blank()

            Button({ type: ButtonType.Normal }) {
              Row() {
                Text(this.stepIndex === this.totalSteps ? 'Done' : 'Next')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
            }
            .backgroundColor('#2563EB')
            .height(38)
            .padding({ left: 20, right: 20 })
            .borderRadius(19)
            .shadow({ radius: 8, color: 'rgba(37, 99, 235, 0.3)', offsetY: 2 })
            .onClick(() => this.handleNext())
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width(310)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .padding(20)
        .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.25)', offsetX: 0, offsetY: 10 })
        .position({
          x: Math.max(16, Math.min(this.targetX + (this.targetW / 2) - 155, this.screenWidth - 326)),
          y: this.getTooltipY()
        })
        .animation({ duration: 250, curve: Curve.EaseOut })
      }
      .width(this.screenWidth)
      .height(this.screenHeight)
      .position({ x: 0, y: 0 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .zIndex(9999)
    }
  }
}
