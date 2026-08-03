import { router, promptAction } from '@kit.ArkUI';
import { AppHeader } from '../components/AppHeader';
import { BottomNavBar } from '../components/BottomNavBar';

interface MedicationItem {
  id: string;
  name: string;
  dose: string;
  times: Array<string>;
  duration: string;
  days: Array<string>;
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
  private scroller: Scroller = new Scroller();

  @State medications: Array<MedicationItem> = [];

  // Modal and Search States
  @State isModalOpen: boolean = false;
  @State searchQuery: string = '';
  @State isDropdownOpen: boolean = false;
  private allMeds: Array<string> = ['Pill A', 'Pill B', 'Pill C', 'Pill D', 'Pill E', 'Pill F', 'Pill G'];
  @State selectedMedName: string = 'Pill A';

  // Dose States
  private availableDoses: Array<number> = [5, 10, 15, 20, 25, 30, 45, 50, 100, 500];
  @State selectedDoseIndex: number = 1;

  // Duration States (Ongoing vs Specific)
  @State isOngoing: boolean = false;
  @State durationDays: number = 14;

  // Day Selection States (M, T, W, T, F, S, S)
  private weekDays: Array<string> = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  @State selectedDays: boolean[] = [true, true, true, true, true, true, true];

  // Time States
  @State isMorningSelected: boolean = false;
  @State isAfternoonSelected: boolean = false;
  @State isEveningSelected: boolean = false;
  @State morningTime: string = '08:00';
  @State afternoonTime: string = '13:00';
  @State eveningTime: string = '20:00';

  // Restricted Time Data
  private morningHours: string[] = ['06', '07', '08', '09', '10', '11'];
  private afternoonHours: string[] = ['12', '13', '14', '15', '16', '17'];
  private eveningHours: string[] = ['18', '19', '20', '21', '22', '23'];
  private minutesList: string[] = ['00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55'];

  // Custom Time Picker Dialog
  showCustomTimePicker(slot: 'morning' | 'afternoon' | 'evening') {
    let hours = slot === 'morning' ? this.morningHours : slot === 'afternoon' ? this.afternoonHours : this.eveningHours;

    TextPickerDialog.show({
      range: [hours, this.minutesList],
      selected: [0, 0],
      onAccept: (value: TextPickerResult) => {
        if (Array.isArray(value.value) && value.value.length === 2) {
          const formattedTime = `${value.value[0]}:${value.value[1]}`;
          if (slot === 'morning') {
            this.morningTime = formattedTime;
            this.isMorningSelected = true;
          } else if (slot === 'afternoon') {
            this.afternoonTime = formattedTime;
            this.isAfternoonSelected = true;
          } else {
            this.eveningTime = formattedTime;
            this.isEveningSelected = true;
          }
        }
      }
    });
  }

  // Medication Deletion Function
  deleteMedication(id: string) {
    this.medications = this.medications.filter(med => med.id !== id);
    this.dashboardMeds = this.dashboardMeds.filter(med => !med.id.startsWith(id));
    promptAction.showToast({ message: 'Medication removed successfully' });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F8F9FB')

      // Main Content Container
      Column() {
        AppHeader({ title: 'Medication Schedule' })
          .margin({ bottom: 12 })

        Scroll(this.scroller) {
          Column() {
            // Empty State
            if (this.medications.length === 0) {
              Column() {
                Text('No medications added yet.')
                  .fontSize(15)
                  .fontColor('#8F92A1')
              }
              .width('100%')
              .height(250)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .border({ width: 1, color: '#EBECEF' })
            } else {
              // Medication List
              Column() {
                ForEach(this.medications, (item: MedicationItem) => {
                  Column() {
                    Row() {
                      Column() {
                        Text(item.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1A1C21')
                        Text(`Dose: ${item.dose} • ${item.duration}`)
                          .fontSize(13)
                          .fontColor('#8F92A1')
                          .margin({ top: 4 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Text('Active')
                        .fontSize(12)
                        .fontColor('#006E2F')
                        .backgroundColor('#E6F9ED')
                        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                        .borderRadius(8)

                      // Delete Button
                      Button('✕')
                        .type(ButtonType.Circle)
                        .width(28)
                        .height(28)
                        .backgroundColor('#FFEBEA')
                        .fontColor('#BA1A1A')
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .margin({ left: 8 })
                        .onClick(() => {
                          this.deleteMedication(item.id);
                        })
                    }
                    .width('100%')
                    .margin({ bottom: 12 })

                    // Days Badges
                    Row() {
                      Text('Days: ')
                        .fontSize(12)
                        .fontColor('#8F92A1')
                      Text(item.days.length === 7 ? 'Every Day' : item.days.join(', '))
                        .fontSize(12)
                        .fontColor('#1A1C21')
                        .fontWeight(FontWeight.Medium)
                    }
                    .width('100%')
                    .margin({ bottom: 8 })

                    // Times Badges
                    Row() {
                      ForEach(item.times, (timeSlot: string) => {
                        Text(`⏰ ${timeSlot}`)
                          .fontSize(12)
                          .fontColor('#003D9B')
                          .backgroundColor('#F0F4FF')
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .borderRadius(6)
                          .margin({ right: 6 })
                      })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor(Color.White)
                  .borderRadius(16)
                  .border({ width: 1, color: '#EBECEF' })
                  .margin({ bottom: 12 })
                })
              }
              .width('100%')
            }

            Blank().height(120)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 20 })

      // Floating Action Button (+)
      Button() {
        Text('+')
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor('#1A1C21')
      .borderRadius(28)
      .shadow({ radius: 8, color: 'rgba(26, 28, 33, 0.2)', offsetY: 4 })
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
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.isModalOpen = false;
              this.isDropdownOpen = false;
            })

          Scroll() {
            Column() {
              Text('Add Medication')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1C21')
                .margin({ bottom: 20 })
                .alignSelf(ItemAlign.Start)

              // Medication Search
              Text('Medication Name')
                .fontSize(13)
                .fontColor('#8F92A1')
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Stack({ alignContent: Alignment.TopStart }) {
                TextInput({ placeholder: 'Tap or type to search...', text: this.searchQuery })
                  .height(44)
                  .backgroundColor(Color.White)
                  .border({ width: 1, color: '#EBECEF' })
                  .borderRadius(8)
                  .fontSize(14)
                  .onClick(() => { this.isDropdownOpen = true; })
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
                              .fontColor('#1A1C21')
                              .width('100%')
                              .padding(12)
                              .backgroundColor(this.selectedMedName === filteredMed ? '#F8F9FB' : Color.Transparent)
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
                  .borderRadius(8)
                  .border({ width: 1, color: '#EBECEF' })
                  .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
                  .margin({ top: 48 })
                  .zIndex(5)
                }
              }
              .width('100%')
              .margin({ bottom: this.isDropdownOpen ? 125 : 20 })

              // Dose Selection
              Text('Dose (mg)')
                .fontSize(13)
                .fontColor('#8F92A1')
                .margin({ bottom: 6 })
                .alignSelf(ItemAlign.Start)

              Row() {
                Text(`${this.availableDoses[this.selectedDoseIndex]} mg`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1C21')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)

                // - Button
                Text('−')
                  .width(32)
                  .height(32)
                  .backgroundColor('#F1F2F5')
                  .fontColor('#1A1C21')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
                  .borderRadius(8)
                  .margin({ right: 6 })
                  .onClick(() => { if (this.selectedDoseIndex > 0) this.selectedDoseIndex--; })

                // + Button
                Text('+')
                  .width(32)
                  .height(32)
                  .backgroundColor('#F1F2F5')
                  .fontColor('#1A1C21')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
                  .borderRadius(8)
                  .onClick(() => { if (this.selectedDoseIndex < this.availableDoses.length - 1) this.selectedDoseIndex++; })
              }
              .width('100%')
              .height(48)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .padding({ left: 16, right: 12 })
              .border({ width: 1, color: '#EBECEF' })
              .margin({ bottom: 20 })

              // Duration (Ongoing Checkbox)
              Row() {
                Text('Duration')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                Blank()
                Row() {
                  Checkbox({ name: 'ongoingToggle', group: 'durationGroup' })
                    .select(this.isOngoing)
                    .selectedColor('#1A1C21')
                    .shape(CheckBoxShape.ROUNDED_SQUARE)
                    .onChange((value: boolean) => {
                      this.isOngoing = value;
                    })
                  Text('Ongoing')
                    .fontSize(13)
                    .fontColor('#1A1C21')
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .margin({ bottom: 12 })
              .alignItems(VerticalAlign.Center)

              // Show counter if NOT ongoing
              if (!this.isOngoing) {
                Row() {
                  Text('Set Days:')
                    .fontSize(14)
                    .fontColor('#1A1C21')
                  Blank()
                  Row() {
                    // - Button
                    Text('−')
                      .width(32)
                      .height(32)
                      .backgroundColor('#F1F2F5')
                      .fontColor('#1A1C21')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .textAlign(TextAlign.Center)
                      .borderRadius(8)
                      .onClick(() => { if (this.durationDays > 1) this.durationDays--; })

                    Text(`${this.durationDays}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .width(40)
                      .textAlign(TextAlign.Center)

                    // + Button
                    Text('+')
                      .width(32)
                      .height(32)
                      .backgroundColor('#F1F2F5')
                      .fontColor('#1A1C21')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .textAlign(TextAlign.Center)
                      .borderRadius(8)
                      .onClick(() => { this.durationDays++; })
                  }
                }
                .width('100%')
                .margin({ bottom: 20 })
              } else {
                Blank().height(10)
              }

              // Days Selection
              Row() {
                Text('Select Days')
                  .fontSize(13)
                  .fontColor('#8F92A1')
                Blank()
                Text(this.selectedDays.includes(false) ? 'Select All' : 'Clear')
                  .fontSize(12)
                  .fontColor('#003D9B')
                  .onClick(() => {
                    const hasFalse = this.selectedDays.includes(false);
                    this.selectedDays = [hasFalse, hasFalse, hasFalse, hasFalse, hasFalse, hasFalse, hasFalse];
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                ForEach(this.weekDays, (day: string, index: number) => {
                  Text(day)
                    .width(32)
                    .height(32)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.selectedDays[index] ? Color.White : '#8F92A1')
                    .backgroundColor(this.selectedDays[index] ? '#1A1C21' : '#F8F9FB')
                    .borderRadius(16)
                    .textAlign(TextAlign.Center)
                    .border({ width: 1, color: this.selectedDays[index] ? '#1A1C21' : '#EBECEF' })
                    .onClick(() => {
                      let temp = [...this.selectedDays];
                      temp[index] = !temp[index];
                      this.selectedDays = temp;
                    })
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 24 })

              // 5. Meal & Restricted Time Selection
              Text('Schedule (Tap to set time)')
                .fontSize(13)
                .fontColor('#8F92A1')
                .margin({ bottom: 8 })
                .alignSelf(ItemAlign.Start)

              Row() {
                // Morning
                Column() {
                  Text('Morning')
                    .fontSize(12)
                    .fontColor(this.isMorningSelected ? '#003D9B' : '#1A1C21')
                    .margin({ bottom: 2 })
                  Text(this.isMorningSelected ? this.morningTime : '--:--')
                    .fontSize(14)
                    .fontWeight(this.isMorningSelected ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.isMorningSelected ? '#003D9B' : '#8F92A1')
                }
                .layoutWeight(1)
                .height(50)
                .backgroundColor(this.isMorningSelected ? '#F0F4FF' : '#F8F9FB')
                .borderRadius(8)
                .border({ width: 1, color: this.isMorningSelected ? '#003D9B' : '#EBECEF' })
                .justifyContent(FlexAlign.Center)
                .margin({ right: 6 })
                .onClick(() => { this.showCustomTimePicker('morning'); })

                // Afternoon
                Column() {
                  Text('Afternoon')
                    .fontSize(12)
                    .fontColor(this.isAfternoonSelected ? '#003D9B' : '#1A1C21')
                    .margin({ bottom: 2 })
                  Text(this.isAfternoonSelected ? this.afternoonTime : '--:--')
                    .fontSize(14)
                    .fontWeight(this.isAfternoonSelected ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.isAfternoonSelected ? '#003D9B' : '#8F92A1')
                }
                .layoutWeight(1)
                .height(50)
                .backgroundColor(this.isAfternoonSelected ? '#F0F4FF' : '#F8F9FB')
                .borderRadius(8)
                .border({ width: 1, color: this.isAfternoonSelected ? '#003D9B' : '#EBECEF' })
                .justifyContent(FlexAlign.Center)
                .margin({ right: 6 })
                .onClick(() => { this.showCustomTimePicker('afternoon'); })

                // Evening
                Column() {
                  Text('Evening')
                    .fontSize(12)
                    .fontColor(this.isEveningSelected ? '#003D9B' : '#1A1C21')
                    .margin({ bottom: 2 })
                  Text(this.isEveningSelected ? this.eveningTime : '--:--')
                    .fontSize(14)
                    .fontWeight(this.isEveningSelected ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.isEveningSelected ? '#003D9B' : '#8F92A1')
                }
                .layoutWeight(1)
                .height(50)
                .backgroundColor(this.isEveningSelected ? '#F0F4FF' : '#F8F9FB')
                .borderRadius(8)
                .border({ width: 1, color: this.isEveningSelected ? '#003D9B' : '#EBECEF' })
                .justifyContent(FlexAlign.Center)
                .onClick(() => { this.showCustomTimePicker('evening'); })
              }
              .width('100%')
              .margin({ bottom: 30 })

              // Actions
              Row() {
                Button('Cancel')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor(Color.Transparent)
                  .fontColor('#1A1C21')
                  .borderRadius(8)
                  .border({ width: 1, color: '#EBECEF' })
                  .margin({ right: 12 })
                  .onClick(() => {
                    this.isModalOpen = false;
                  })

                Button('Save')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor('#1A1C21')
                  .fontColor(Color.White)
                  .borderRadius(8)
                  .onClick(() => {
                    let chosenTimes: Array<string> = [];
                    if (this.isMorningSelected) chosenTimes.push(`Morning (${this.morningTime})`);
                    if (this.isAfternoonSelected) chosenTimes.push(`Afternoon (${this.afternoonTime})`);
                    if (this.isEveningSelected) chosenTimes.push(`Evening (${this.eveningTime})`);

                    if (chosenTimes.length === 0) {
                      promptAction.showToast({ message: 'Please select at least one time slot' });
                      return;
                    }

                    if (!this.selectedDays.includes(true)) {
                      promptAction.showToast({ message: 'Please select at least one day' });
                      return;
                    }

                    let activeDays = this.weekDays.filter((day, index) => this.selectedDays[index]);
                    let durationStr = this.isOngoing ? 'Ongoing' : `${this.durationDays} Days`;
                    let baseId = Date.now().toString();

                    this.medications.push({
                      id: baseId,
                      name: this.selectedMedName,
                      dose: `${this.availableDoses[this.selectedDoseIndex]} mg`,
                      times: chosenTimes,
                      duration: durationStr,
                      days: activeDays
                    });

                    if (this.isMorningSelected) {
                      this.dashboardMeds.push({
                        id: baseId + '_m', name: this.selectedMedName,
                        dosage: `${this.availableDoses[this.selectedDoseIndex]} mg`, time: `Today, ${this.morningTime}`, taken: false
                      });
                    }

                    this.isMorningSelected = false;
                    this.isAfternoonSelected = false;
                    this.isEveningSelected = false;
                    this.searchQuery = '';
                    this.isDropdownOpen = false;
                    this.isModalOpen = false;
                    this.selectedDays = [true, true, true, true, true, true, true];
                    this.isOngoing = false;
                    this.durationDays = 14;

                    promptAction.showToast({ message: 'Medication added successfully!' });
                  })
              }
              .width('100%')
            }
            .width('92%')
            .padding(24)
            .backgroundColor(Color.White)
            .borderRadius(24)
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}