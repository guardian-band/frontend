import { router, promptAction } from '@kit.ArkUI';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

// Define a clear interface for medication items
interface MedicationItem {
  name: string;
  dose: string;
  times: Array<string>;
}

interface DashboardMedItem {
  id: string;
  name: string;
  dosage: string;
  time: string;
  taken: boolean;
}

@Entry
@Component
struct MedsPage {
  @StorageLink('dashboardMeds') dashboardMeds: Array<DashboardMedItem> = [];
  // Allows the main page content to be scrollable
  private scroller: Scroller = new Scroller();

  // State to hold our dynamic list of added medications
  @State medications: Array<MedicationItem> = [];

  // Form states for the medication modal
  @State isModalOpen: boolean = false;
  
  // Medication search and dropdown visibility states
  @State searchQuery: string = '';
  @State isDropdownOpen: boolean = false;
  private allMeds: Array<string> = ['Pill A', 'Pill B', 'Pill C', 'Pill D', 'Pill E', 'Pill F', 'Pill G'];
  @State selectedMedName: string = 'Pill A'; 

  // Dosage array and index
  private availableDoses: Array<number> = [5, 10, 15, 20, 25, 30, 45, 50];
  @State selectedDoseIndex: number = 1; // Default to 10 mg

  // Selection states for time slots
  @State isMorningSelected: boolean = false;
  @State isAfternoonSelected: boolean = false;
  @State isEveningSelected: boolean = false;

  // Default times for each slot
  @State morningTime: string = '08:00';
  @State afternoonTime: string = '13:00';
  @State eveningTime: string = '20:00';

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background Hologram & Ambient Blurs
      Row()
        .width(500)
        .height(500)
        .position({ x: -100, y: -150 })
        .radialGradient({
          center: ['50%', '50%'],
          radius: 250,
          colors: [
            ['rgba(218, 226, 255, 0.6)', 0.0],
            ['rgba(218, 226, 255, 0.0)', 1.0]
          ]
        })

      // Main Scrollable Content Area
      Scroll(this.scroller) {
        Column() {
          AppHeader({ title: 'Medication Schedule' })

          // Dynamic Medication List or Empty State Placeholder
          if (this.medications.length === 0) {
            Column() {
              Text('No medications added yet.')
                .fontSize(15)
                .fontColor('#737685')
                .margin({ top: 40 })
            }
            .width('100%')
            .height(300)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('rgba(255, 255, 255, 0.85)')
            .borderRadius(24)
            .border({ width: 1, color: 'rgba(195, 198, 214, 0.3)', style: BorderStyle.Solid })
            .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.03)', offsetY: 4 })
          } else {
            Column() {
              ForEach(this.medications, (item: MedicationItem) => {
                Column() {
                  Row() {
                    Row() {
                      Text('💊').fontSize(20)
                    }
                    .width(40)
                    .height(40)
                    .backgroundColor('rgba(0, 61, 155, 0.08)')
                    .borderRadius(20)
                    .justifyContent(FlexAlign.Center)
                    .margin({ right: 12 })

                    Column() {
                      Text(item.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#191C1D')
                      Text(`Dosage: ${item.dose}`)
                        .fontSize(13)
                        .fontColor('#737685')
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Text('🛡️ Active')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#006E2F')
                      .backgroundColor('#E6F9ED')
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .borderRadius(12)
                  }
                  .width('100%')
                  .margin({ bottom: 10 })

                  Row() {
                    ForEach(item.times, (timeSlot: string) => {
                      Text(`⏰ ${timeSlot}`)
                        .fontSize(11)
                        .fontColor('#003D9B')
                        .backgroundColor('rgba(0, 61, 155, 0.06)')
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .borderRadius(8)
                        .margin({ right: 6 })
                    })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .width('100%')
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(20)
                .margin({ bottom: 12 })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 3 })
              })
            }
            .width('100%')
          }

          Blank().height(120)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 10 })

      // Floating Action Button (+)
      Button() {
        Text('+')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(60)
      .height(60)
      .backgroundColor('#003D9B')
      .borderRadius(30)
      .shadow({ radius: 10, color: 'rgba(0, 61, 155, 0.3)', offsetY: 4 })
      .position({ x: '78%', y: '80%' })
      .zIndex(2)
      .onClick(() => {
        this.isModalOpen = true; 
      })

      // MODAL OVERLAY
      if (this.isModalOpen) {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.4)')
            .onClick(() => {
              this.isModalOpen = false;
              this.isDropdownOpen = false;
            })

          Scroll() {
            Column() {
              Text('Configure Medication')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#191C1D')
                .margin({ bottom: 16 })
                .alignSelf(ItemAlign.Start)

              // 1. Search Bar with Dropdown
              Text('Select Medication')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Stack({ alignContent: Alignment.TopStart }) {
                TextInput({ placeholder: 'Tap or type to search...', text: this.searchQuery })
                  .height(44)
                  .backgroundColor('#F3F4F5')
                  .borderRadius(12)
                  .fontSize(14)
                  .onClick(() => {
                    this.isDropdownOpen = true;
                  })
                  .onChange((value: string) => {
                    this.searchQuery = value;
                    this.isDropdownOpen = true;
                  })

                if (this.isDropdownOpen) {
                  Column() {
                    List() {
                      ForEach(
                        this.allMeds.filter((med: string) => med.toLowerCase().includes(this.searchQuery.toLowerCase())),
                        (filteredMed: string) => {
                          ListItem() {
                            Text(filteredMed)
                              .fontSize(14)
                              .fontColor('#191C1D')
                              .width('100%')
                              .padding(12)
                              .backgroundColor(this.selectedMedName === filteredMed ? '#E6F0FF' : Color.Transparent)
                          }
                          .onClick(() => {
                            this.selectedMedName = filteredMed;
                            this.searchQuery = filteredMed;
                            this.isDropdownOpen = false;
                          })
                        }
                      )
                    }
                    .width('100%')
                    .height(110)
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .borderRadius(12)
                  .border({ width: 1, color: '#C0C4CC' })
                  .shadow({ radius: 8, color: 'rgba(0,0,0,0.1)', offsetY: 4 })
                  .margin({ top: 48 })
                  .zIndex(5)
                }
              }
              .width('100%')
              .margin({ bottom: this.isDropdownOpen ? 125 : 16 })

              // 2. Dosage Bar with Increment/Decrement Arrows
              Text('Select Dosage (mg)')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Row() {
                Text(`${this.availableDoses[this.selectedDoseIndex]} mg`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#003D9B')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)

                Button('➖')
                  .height(40)
                  .width(50)
                  .backgroundColor('#F3F4F5')
                  .borderRadius(10)
                  .margin({ right: 8 })
                  .onClick(() => {
                    if (this.selectedDoseIndex > 0) {
                      this.selectedDoseIndex--;
                    }
                  })

                Button('➕')
                  .height(40)
                  .width(50)
                  .backgroundColor('#F3F4F5')
                  .borderRadius(10)
                  .onClick(() => {
                    if (this.selectedDoseIndex < this.availableDoses.length - 1) {
                      this.selectedDoseIndex++;
                    }
                  })
              }
              .width('100%')
              .height(50)
              .backgroundColor('#F9FAFB')
              .borderRadius(14)
              .padding({ left: 16, right: 8 })
              .border({ width: 1, color: '#E0E0E0' })
              .margin({ bottom: 20 })

              // 3. Time Slots Selection
              Text('Select Schedule Times')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#434654')
                .margin({ bottom: 8 })
                .alignSelf(ItemAlign.Start)

              Row() {
                // Morning Box (06:00 to 12:00)
                Column() {
                  Text('☀️ Morning')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isMorningSelected ? Color.White : '#191C1D')
                    .margin({ bottom: 2 })
                  Text(this.morningTime)
                    .fontSize(10)
                    .fontColor(this.isMorningSelected ? Color.White : '#737685')
                }
                .layoutWeight(1)
                .height(55)
                .backgroundColor(this.isMorningSelected ? '#006E2F' : '#F3F4F5') 
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .border({ width: 1, color: this.isMorningSelected ? '#006E2F' : '#E0E0E0' })
                .margin({ right: 6 })
                .onClick(() => {
                  TimePickerDialog.show({
                    selected: new Date(),
                    onAccept: (value: TimePickerResult) => {
                      if (value.hour >= 6 && value.hour < 12) {
                        let hours = value.hour < 10 ? '0' + value.hour : value.hour.toString();
                        let minutes = value.minute < 10 ? '0' + value.minute : value.minute.toString();
                        this.morningTime = `${hours}:${minutes}`;
                        this.isMorningSelected = true;
                      } else {
                        promptAction.showToast({ message: 'Invalid! Morning time must be between 06:00 and 12:00' });
                      }
                    }
                  });
                })

                // Afternoon Box (12:00 to 18:00)
                Column() {
                  Text('🌤️ Afternoon')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isAfternoonSelected ? Color.White : '#191C1D')
                    .margin({ bottom: 2 })
                  Text(this.afternoonTime)
                    .fontSize(10)
                    .fontColor(this.isAfternoonSelected ? Color.White : '#737685')
                }
                .layoutWeight(1)
                .height(55)
                .backgroundColor(this.isAfternoonSelected ? '#006E2F' : '#F3F4F5') 
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .border({ width: 1, color: this.isAfternoonSelected ? '#006E2F' : '#E0E0E0' })
                .margin({ right: 6 })
                .onClick(() => {
                  TimePickerDialog.show({
                    selected: new Date(),
                    onAccept: (value: TimePickerResult) => {
                      if (value.hour >= 12 && value.hour < 18) {
                        let hours = value.hour < 10 ? '0' + value.hour : value.hour.toString();
                        let minutes = value.minute < 10 ? '0' + value.minute : value.minute.toString();
                        this.afternoonTime = `${hours}:${minutes}`;
                        this.isAfternoonSelected = true;
                      } else {
                        promptAction.showToast({ message: 'Invalid! Afternoon time must be between 12:00 and 18:00' });
                      }
                    }
                  });
                })

                // Evening Box (18:00 to 23:59)
                Column() {
                  Text('🌙 Evening')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isEveningSelected ? Color.White : '#191C1D')
                    .margin({ bottom: 2 })
                  Text(this.eveningTime)
                    .fontSize(10)
                    .fontColor(this.isEveningSelected ? Color.White : '#737685')
                }
                .layoutWeight(1)
                .height(55)
                .backgroundColor(this.isEveningSelected ? '#006E2F' : '#F3F4F5') 
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .border({ width: 1, color: this.isEveningSelected ? '#006E2F' : '#E0E0E0' })
                .onClick(() => {
                  TimePickerDialog.show({
                    selected: new Date(),
                    onAccept: (value: TimePickerResult) => {
                      if (value.hour >= 18 && value.hour <= 23) {
                        let hours = value.hour < 10 ? '0' + value.hour : value.hour.toString();
                        let minutes = value.minute < 10 ? '0' + value.minute : value.minute.toString();
                        this.eveningTime = `${hours}:${minutes}`;
                        this.isEveningSelected = true;
                      } else {
                        promptAction.showToast({ message: 'Invalid! Evening time must be between 18:00 and 23:59' });
                      }
                    }
                  });
                })
              }
              .width('100%')
              .margin({ bottom: 24 })

              // Action Buttons
              Row() {
                Button('Cancel')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor('#F3F4F5')
                  .fontColor('#434654')
                  .fontWeight(FontWeight.Bold)
                  .borderRadius(12)
                  .margin({ right: 10 })
                  .onClick(() => {
                    this.isModalOpen = false;
                    this.isDropdownOpen = false;
                  })

                Button('Save Medication')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor('#003D9B')
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
                  .borderRadius(12)
                  .onClick(() => {
                    let chosenTimes: Array<string> = [];
                    if (this.isMorningSelected) chosenTimes.push(`Morning (${this.morningTime})`);
                    if (this.isAfternoonSelected) chosenTimes.push(`Afternoon (${this.afternoonTime})`);
                    if (this.isEveningSelected) chosenTimes.push(`Evening (${this.eveningTime})`);

                    if (chosenTimes.length === 0) {
                      promptAction.showToast({ message: 'Please select at least one time slot' });
                      return;
                    }

                    // 1. Local Medications list on Meds page
                    this.medications.push({
                      name: this.selectedMedName,
                      dose: `${this.availableDoses[this.selectedDoseIndex]} mg`,
                      times: chosenTimes
                    });

                    // 2. Sync to HomePage dashboardMeds list
                    let baseId = Date.now().toString();
                    if (this.isMorningSelected) {
                      this.dashboardMeds.push({
                        id: baseId + '_m',
                        name: this.selectedMedName,
                        dosage: `${this.availableDoses[this.selectedDoseIndex]} mg`,
                        time: `Today, ${this.morningTime}`,
                        taken: false
                      });
                    }
                    if (this.isAfternoonSelected) {
                      this.dashboardMeds.push({
                        id: baseId + '_a',
                        name: this.selectedMedName,
                        dosage: `${this.availableDoses[this.selectedDoseIndex]} mg`,
                        time: `Today, ${this.afternoonTime}`,
                        taken: false
                      });
                    }
                    if (this.isEveningSelected) {
                      this.dashboardMeds.push({
                        id: baseId + '_e',
                        name: this.selectedMedName,
                        dosage: `${this.availableDoses[this.selectedDoseIndex]} mg`,
                        time: `Today, ${this.eveningTime}`,
                        taken: false
                      });
                    }

                    this.isMorningSelected = false;
                    this.isAfternoonSelected = false;
                    this.isEveningSelected = false;
                    this.searchQuery = '';
                    this.isDropdownOpen = false;
                    this.isModalOpen = false;

                    promptAction.showToast({ message: 'Medication added successfully!' });
                  })
              }
              .width('100%')
            }
            .width('92%')
            .padding(22)
            .backgroundColor(Color.White)
            .borderRadius(28)
            .shadow({ radius: 25, color: 'rgba(0, 0, 0, 0.15)', offsetY: 10 })
            .alignSelf(ItemAlign.Center)
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Center)
        }
        .width('100%')
        .height('100%')
        .zIndex(10)
      }

      BottomNavBar({ activeTab: 'meds' })
        .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}