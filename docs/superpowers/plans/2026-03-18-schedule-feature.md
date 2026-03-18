# Schedule Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a weekly schedule that automatically enables/disables Jiggler's master switch based on configurable day/time ranges.

**Architecture:** New `ScheduleEntry` model class holds day + start/end minutes. `PrefsController` manages the schedule UI (NSTableView + add/remove controls) and persists entries to NSUserDefaults. `AppDelegate` evaluates the schedule every ~4 seconds in its existing timer, toggling the master switch at schedule boundaries with manual override support.

**Tech Stack:** Objective-C, Cocoa (AppKit), manual retain/release (no ARC), XIB-based UI, NSUserDefaults persistence.

**Spec:** `docs/superpowers/specs/2026-03-18-schedule-feature-design.md`

**Note:** This project has no test suite. Verification is done by building with xcodebuild and manual testing.

---

### Task 1: Create ScheduleEntry model class

**Files:**
- Create: `ScheduleEntry.h`
- Create: `ScheduleEntry.m`

- [ ] **Step 1: Create ScheduleEntry.h**

```objc
//
//  ScheduleEntry.h
//  Jiggler
//

#import <Foundation/Foundation.h>

@interface ScheduleEntry : NSObject
{
    int day;           // 1-7 (NSCalendar weekday: Sunday=1, Monday=2, ..., Saturday=7)
    int startMinute;   // 0-1425, minutes from midnight, 15-min increments
    int endMinute;     // 15-1440, minutes from midnight, must be > startMinute
}

- (int)day;
- (void)setDay:(int)newDay;
- (int)startMinute;
- (void)setStartMinute:(int)newStartMinute;
- (int)endMinute;
- (void)setEndMinute:(int)newEndMinute;

- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)entryWithDictionary:(NSDictionary *)dict;
+ (instancetype)entryWithDay:(int)day startMinute:(int)startMinute endMinute:(int)endMinute;

- (NSString *)dayString;
- (NSString *)startTimeString;
- (NSString *)endTimeString;
+ (NSString *)timeStringForMinute:(int)minute;

- (NSComparisonResult)compare:(ScheduleEntry *)other;

@end
```

- [ ] **Step 2: Create ScheduleEntry.m**

```objc
//
//  ScheduleEntry.m
//  Jiggler
//

#import "ScheduleEntry.h"

@implementation ScheduleEntry

- (int)day { return day; }
- (void)setDay:(int)newDay { day = newDay; }
- (int)startMinute { return startMinute; }
- (void)setStartMinute:(int)newStartMinute { startMinute = newStartMinute; }
- (int)endMinute { return endMinute; }
- (void)setEndMinute:(int)newEndMinute { endMinute = newEndMinute; }

- (void)dealloc
{
    [super dealloc];
}

+ (instancetype)entryWithDay:(int)aDay startMinute:(int)aStartMinute endMinute:(int)anEndMinute
{
    ScheduleEntry *entry = [[[ScheduleEntry alloc] init] autorelease];
    entry->day = aDay;
    entry->startMinute = aStartMinute;
    entry->endMinute = anEndMinute;
    return entry;
}

+ (instancetype)entryWithDictionary:(NSDictionary *)dict
{
    return [self entryWithDay:[[dict objectForKey:@"day"] intValue]
                  startMinute:[[dict objectForKey:@"startMinute"] intValue]
                    endMinute:[[dict objectForKey:@"endMinute"] intValue]];
}

- (NSDictionary *)dictionaryRepresentation
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:day], @"day",
            [NSNumber numberWithInt:startMinute], @"startMinute",
            [NSNumber numberWithInt:endMinute], @"endMinute",
            nil];
}

- (NSString *)dayString
{
    // NSCalendar weekday: 1=Sunday, 2=Monday, ... 7=Saturday
    NSArray *days = [NSArray arrayWithObjects:
                     @"Sunday", @"Monday", @"Tuesday", @"Wednesday",
                     @"Thursday", @"Friday", @"Saturday", nil];
    if (day >= 1 && day <= 7)
        return [days objectAtIndex:day - 1];
    return @"?";
}

+ (NSString *)timeStringForMinute:(int)minute
{
    int hours = minute / 60;
    int mins = minute % 60;
    NSString *ampm = (hours < 12) ? @"AM" : @"PM";
    int displayHour = hours % 12;
    if (displayHour == 0) displayHour = 12;
    return [NSString stringWithFormat:@"%d:%02d %@", displayHour, mins, ampm];
}

- (NSString *)startTimeString
{
    return [ScheduleEntry timeStringForMinute:startMinute];
}

- (NSString *)endTimeString
{
    return [ScheduleEntry timeStringForMinute:endMinute];
}

- (NSComparisonResult)compare:(ScheduleEntry *)other
{
    if (day != [other day])
        return (day < [other day]) ? NSOrderedAscending : NSOrderedDescending;
    if (startMinute != [other startMinute])
        return (startMinute < [other startMinute]) ? NSOrderedAscending : NSOrderedDescending;
    return NSOrderedSame;
}

@end
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Debug build 2>&1 | tail -5`

Note: The build will fail at this point because the files are not yet in the Xcode project. That is expected and will be resolved in Task 4.

- [ ] **Step 4: Commit**

```bash
git add ScheduleEntry.h ScheduleEntry.m
git commit -m "feat: add ScheduleEntry model class for weekly schedule"
```

---

### Task 2: Add schedule persistence to PrefsController

**Files:**
- Modify: `PrefsController.h` — add schedule ivars, outlets, and method declarations
- Modify: `PrefsController.m` — add NSUserDefaults keys, init loading, save method, accessors, table data source/delegate, and action methods

- [ ] **Step 1: Add ivars and method declarations to PrefsController.h**

Add `#import "ScheduleEntry.h"` at the top.

Add to the ivar block (after existing ivars, before the closing `}`):

```objc
    // Schedule
    BOOL scheduleEnabled;
    NSMutableArray *scheduleEntries;

    IBOutlet NSButton *scheduleEnabledCheckbox;
    IBOutlet NSTableView *scheduleTableView;
    IBOutlet NSButton *addScheduleEntryButton;
    IBOutlet NSButton *removeScheduleEntryButton;
    IBOutlet NSPopUpButton *scheduleDayPopUp;
    IBOutlet NSPopUpButton *scheduleStartTimePopUp;
    IBOutlet NSPopUpButton *scheduleEndTimePopUp;
```

Add method declarations (after existing method declarations, before `@end`):

```objc
// Schedule
- (BOOL)scheduleEnabled;
- (NSArray *)scheduleEntries;
- (BOOL)isCurrentTimeInSchedule;
- (NSInteger)currentScheduleEntryIndex;  // returns index of matching entry, or -1 if none

- (IBAction)scheduleEnabledChanged:(id)sender;
- (IBAction)addScheduleEntry:(id)sender;
- (IBAction)removeScheduleEntry:(id)sender;
- (IBAction)scheduleTimePopUpChanged:(id)sender;
```

- [ ] **Step 2: Add schedule defaults keys and init loading to PrefsController.m**

Add after existing defaults key declarations:

```objc
static NSString *ScheduleEnabledDefaultsKey = @"ScheduleEnabled";
static NSString *ScheduleEntriesDefaultsKey = @"ScheduleEntries";
```

Add to the `registerDefaults:` dictionary (inside `init`):

```objc
@"NO", ScheduleEnabledDefaultsKey,
```

Add after the existing ivar loading section in `init` (after `frontAppNameComponents = nil;`):

```objc
// Schedule
scheduleEnabled = [userDefaults boolForKey:ScheduleEnabledDefaultsKey];
scheduleEntries = [[NSMutableArray alloc] init];
NSArray *savedEntries = [userDefaults arrayForKey:ScheduleEntriesDefaultsKey];
if (savedEntries)
{
    int i, c;
    for (i = 0, c = (int)[savedEntries count]; i < c; ++i)
    {
        NSDictionary *dict = [savedEntries objectAtIndex:i];
        ScheduleEntry *entry = [ScheduleEntry entryWithDictionary:dict];
        [scheduleEntries addObject:entry];
    }
    [scheduleEntries sortUsingSelector:@selector(compare:)];
}
```

- [ ] **Step 3: Add schedule accessor methods to PrefsController.m**

Add after existing accessor methods (e.g., after `frontAppNameComponents`):

```objc
#pragma mark Schedule

- (BOOL)scheduleEnabled
{
    return scheduleEnabled;
}

- (NSArray *)scheduleEntries
{
    return scheduleEntries;
}

- (BOOL)isCurrentTimeInSchedule
{
    return [self currentScheduleEntryIndex] >= 0;
}

- (NSInteger)currentScheduleEntryIndex
{
    if (!scheduleEnabled || [scheduleEntries count] == 0)
        return -1;

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:[NSDate date]];
    int currentDay = (int)[components weekday];
    int currentMinute = (int)[components hour] * 60 + (int)[components minute];
    int i, c;

    for (i = 0, c = (int)[scheduleEntries count]; i < c; ++i)
    {
        ScheduleEntry *entry = [scheduleEntries objectAtIndex:i];
        if ([entry day] == currentDay && currentMinute >= [entry startMinute] && currentMinute < [entry endMinute])
            return i;
    }

    return -1;
}

- (void)saveScheduleEntries
{
    NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:[scheduleEntries count]];
    int i, c;
    for (i = 0, c = (int)[scheduleEntries count]; i < c; ++i)
    {
        ScheduleEntry *entry = [scheduleEntries objectAtIndex:i];
        [dicts addObject:[entry dictionaryRepresentation]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:dicts forKey:ScheduleEntriesDefaultsKey];
}

- (void)updateAddButtonState
{
    int startMinute = (int)[[scheduleStartTimePopUp selectedItem] tag];
    int endMinute = (int)[[scheduleEndTimePopUp selectedItem] tag];
    [addScheduleEntryButton setEnabled:(scheduleEnabled && endMinute > startMinute)];
}
```

- [ ] **Step 4: Add schedule UI setup to showWindow in PrefsController.m**

Add after the existing control state setup (after `[frontAppsNameComponentTextfield setEnabled:notWithFrontAppsNamedX];` and before `[preferencesWindow centerOnPrimaryScreen];`):

```objc
// Schedule
[scheduleEnabledCheckbox setState:scheduleEnabled];
[scheduleTableView setDataSource:(id<NSTableViewDataSource>)self];
[scheduleTableView setDelegate:(id<NSTableViewDelegate>)self];
[scheduleTableView reloadData];

// Populate day popup
[scheduleDayPopUp removeAllItems];
NSArray *dayNames = [NSArray arrayWithObjects:@"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday", nil];
int i_day;
for (i_day = 0; i_day < 7; ++i_day)
{
    [scheduleDayPopUp addItemWithTitle:[dayNames objectAtIndex:i_day]];
    [[scheduleDayPopUp lastItem] setTag:i_day + 1];
}
// Default to Monday
[scheduleDayPopUp selectItemWithTag:2];

// Populate start time popup (0 to 1425 in 15-min increments)
[scheduleStartTimePopUp removeAllItems];
int t;
for (t = 0; t <= 1425; t += 15)
{
    [scheduleStartTimePopUp addItemWithTitle:[ScheduleEntry timeStringForMinute:t]];
    [[scheduleStartTimePopUp lastItem] setTag:t];
}
// Default to 9:00 AM (540)
[scheduleStartTimePopUp selectItemWithTag:540];

// Populate end time popup (15 to 1440 in 15-min increments)
[scheduleEndTimePopUp removeAllItems];
for (t = 15; t <= 1440; t += 15)
{
    NSString *title = (t == 1440) ? @"12:00 AM (midnight)" : [ScheduleEntry timeStringForMinute:t];
    [scheduleEndTimePopUp addItemWithTitle:title];
    [[scheduleEndTimePopUp lastItem] setTag:t];
}
// Default to 5:00 PM (1020)
[scheduleEndTimePopUp selectItemWithTag:1020];

// Enable/disable schedule controls
[scheduleTableView setEnabled:scheduleEnabled];
[scheduleDayPopUp setEnabled:scheduleEnabled];
[scheduleStartTimePopUp setEnabled:scheduleEnabled];
[scheduleEndTimePopUp setEnabled:scheduleEnabled];
[removeScheduleEntryButton setEnabled:(scheduleEnabled && [scheduleTableView selectedRow] >= 0)];
[self updateAddButtonState];
```

- [ ] **Step 5: Add NSTableView data source and delegate methods to PrefsController.m**

Add in the Schedule pragma section:

```objc
#pragma mark Schedule Table Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [scheduleEntries count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    ScheduleEntry *entry = [scheduleEntries objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];

    if ([identifier isEqualToString:@"day"])
        return [entry dayString];
    else if ([identifier isEqualToString:@"start"])
        return [entry startTimeString];
    else if ([identifier isEqualToString:@"end"])
        return [entry endTimeString];

    return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [removeScheduleEntryButton setEnabled:(scheduleEnabled && [scheduleTableView selectedRow] >= 0)];
}
```

- [ ] **Step 6: Add schedule action methods to PrefsController.m**

```objc
- (IBAction)scheduleEnabledChanged:(id)sender
{
    BOOL newState = [sender state];

    if (newState != scheduleEnabled)
    {
        scheduleEnabled = newState;
        [[NSUserDefaults standardUserDefaults] setBool:newState forKey:ScheduleEnabledDefaultsKey];

        [scheduleTableView setEnabled:scheduleEnabled];
        [scheduleDayPopUp setEnabled:scheduleEnabled];
        [scheduleStartTimePopUp setEnabled:scheduleEnabled];
        [scheduleEndTimePopUp setEnabled:scheduleEnabled];
        [removeScheduleEntryButton setEnabled:(scheduleEnabled && [scheduleTableView selectedRow] >= 0)];
        [self updateAddButtonState];
    }
}

- (IBAction)addScheduleEntry:(id)sender
{
    int selectedDay = (int)[[scheduleDayPopUp selectedItem] tag];
    int selectedStart = (int)[[scheduleStartTimePopUp selectedItem] tag];
    int selectedEnd = (int)[[scheduleEndTimePopUp selectedItem] tag];

    if (selectedEnd <= selectedStart)
        return;

    ScheduleEntry *entry = [ScheduleEntry entryWithDay:selectedDay startMinute:selectedStart endMinute:selectedEnd];
    [scheduleEntries addObject:entry];
    [scheduleEntries sortUsingSelector:@selector(compare:)];
    [self saveScheduleEntries];
    [scheduleTableView reloadData];
}

- (IBAction)removeScheduleEntry:(id)sender
{
    NSInteger selectedRow = [scheduleTableView selectedRow];

    if (selectedRow >= 0 && selectedRow < (NSInteger)[scheduleEntries count])
    {
        [scheduleEntries removeObjectAtIndex:selectedRow];
        [self saveScheduleEntries];
        [scheduleTableView reloadData];
        [removeScheduleEntryButton setEnabled:NO];
    }
}

- (IBAction)scheduleTimePopUpChanged:(id)sender
{
    [self updateAddButtonState];
}
```

- [ ] **Step 7: Commit**

```bash
git add PrefsController.h PrefsController.m
git commit -m "feat: add schedule persistence and logic to PrefsController"
```

---

### Task 3: Add schedule evaluation to AppDelegate

**Files:**
- Modify: `AppDelegate.h` — add `scheduleManuallyOverridden` ivar
- Modify: `AppDelegate.m` — add `evaluateSchedule` method, modify `periodicJiggleStatusCheck:` and `jiggleMasterSwitchChanged:`

- [ ] **Step 1: Add ivars to AppDelegate.h**

Add to the ivar block (after `BOOL jiggleConditionsLikelyToHaveChanged;`):

```objc
    // Schedule
    BOOL scheduleManuallyOverridden;
    NSInteger lastScheduleEntryIndex;  // index of the previously active schedule entry, or -1
```

- [ ] **Step 2: Add evaluateSchedule method to AppDelegate.m**

Add `#import "PrefsController.h"` if not already present (it is).

Add before `periodicJiggleStatusCheck:`:

```objc
- (void)evaluateSchedule
{
    PrefsController *prefs = [PrefsController sharedPrefsController];

    if (![prefs scheduleEnabled])
        return;

    NSInteger currentEntryIndex = [prefs currentScheduleEntryIndex];
    BOOL inSchedule = (currentEntryIndex >= 0);

    // Detect schedule boundary transitions: entering, exiting, or switching between ranges.
    // Clear the manual override on any boundary change so that back-to-back ranges re-enable
    // the switch even if the user overrode during the previous range.
    if (currentEntryIndex != lastScheduleEntryIndex)
    {
        scheduleManuallyOverridden = NO;
        lastScheduleEntryIndex = currentEntryIndex;
    }

    if (inSchedule)
    {
        if (!scheduleManuallyOverridden && !jiggleMasterSwitch)
        {
            jiggleMasterSwitch = YES;
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:JiggleMasterSwitchDefaultsKey];
            [self fixMasterSwitchUI];
        }
    }
    else
    {
        if (jiggleMasterSwitch)
        {
            jiggleMasterSwitch = NO;
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:JiggleMasterSwitchDefaultsKey];
            [self fixMasterSwitchUI];
            [self setJigglingActive:NO];
        }
    }
}
```

Note: `JiggleMasterSwitchDefaultsKey` is a file-scope static already defined at the top of AppDelegate.m. `lastScheduleEntryIndex` tracks which specific entry was active. For back-to-back ranges (e.g., 9:00-12:00 then 12:00-17:00), when the entry index changes, the override is cleared and the new range re-enables the switch. The ivar defaults to 0 on launch, but since `scheduleManuallyOverridden` also defaults to NO, this is harmless -- initialize `lastScheduleEntryIndex = -1` in `applicationDidFinishLaunching:` for clarity.

- [ ] **Step 3: Call evaluateSchedule from periodicJiggleStatusCheck:**

Add at the top of `periodicJiggleStatusCheck:`, right after the `callout_counter++;` line:

```objc
    // Evaluate schedule every ~4 seconds (before inhibitor checks so state changes are visible)
    if ((callout_counter & 0x0F) == 0)
        [self evaluateSchedule];
```

- [ ] **Step 4: Modify jiggleMasterSwitchChanged: to support manual override**

Add at the top of `jiggleMasterSwitchChanged:`, right after `jiggleMasterSwitch = !jiggleMasterSwitch;`:

```objc
    // If schedule is active and user manually toggles, set override flag
    PrefsController *prefs = [PrefsController sharedPrefsController];
    if ([prefs scheduleEnabled] && [prefs isCurrentTimeInSchedule])
        scheduleManuallyOverridden = YES;
```

- [ ] **Step 5: Commit**

```bash
git add AppDelegate.h AppDelegate.m
git commit -m "feat: add schedule evaluation to AppDelegate timer loop"
```

---

### Task 4: Add schedule UI to Preferences.xib and register files in Xcode project

**Files:**
- Modify: `Base.lproj/Preferences.xib` — add schedule section UI elements
- Modify: `Jiggler.xcodeproj/project.pbxproj` — register ScheduleEntry.h/.m

This task involves editing the XIB XML directly and updating the Xcode project file. The XIB uses fixed-frame positioning with y=0 at the bottom of the window.

**Current window dimensions:** 510 wide x 726 tall. The lowest existing element is at y=20. The schedule section needs ~220px. Strategy: increase window height by 230px (to 956), shift all existing elements up by 230px (add 230 to all y values), and add new schedule elements in the 0-230 y range at the bottom.

- [ ] **Step 1: Update window height and shift existing elements in Preferences.xib**

The window's `contentRect` height changes from 726 to 956. The content view `frame` height also changes from 726 to 956. All existing subview y-coordinates increase by 230. The window's y changes from 501 to 271 to keep the top edge in place.

Window and content view changes:
```xml
<!-- Window contentRect (id="654") -->
<rect key="contentRect" x="489" y="271" width="510" height="956"/>
<!-- Content view frame (id="655") -->
<rect key="frame" x="0.0" y="0.0" width="510" height="956"/>
```

Complete list of existing subview y-coordinate changes (element ID -> old y -> new y):

| Element ID | Description | Old Y | New Y |
|---|---|---|---|
| BQj-CL-3jJ | Jiggle style radio | 396 | 626 |
| 2BB-LS-ihS | Apple image | 95 | 325 |
| JK7-je-yY2 | Screen locked checkbox | 95 | 325 |
| 690 | App name help text | 185 | 415 |
| 656 | Show icon checkbox | 534 | 764 |
| 658 | Jiggle time slider | 594 | 824 |
| 660 | "Time between jiggles" label | 603 | 833 |
| 662 | "5 sec." label | 573 | 803 |
| 664 | "1 min." label | 573 | 803 |
| 666 | "5 min." label | 573 | 803 |
| 668 | "1 hour" label | 573 | 803 |
| 670 | "5 hours" label | 573 | 803 |
| 672 | "24 hours" label | 573 | 803 |
| 674 | Jiggle time help text | 639 | 869 |
| 676 | Jiggle when idle radio | 476 | 706 |
| 680 | "Require at least one..." label | 352 | 582 |
| 705 | "But never jiggle..." label | 145 | 375 |
| 682 | CPU usage checkbox | 328 | 558 |
| 684 | Removable disk checkbox | 302 | 532 |
| 711 | Battery checkbox | 121 | 351 |
| 686 | App running checkbox | 250 | 480 |
| 688 | App name textfield | 220 | 450 |
| 692 | iTunes checkbox | 276 | 506 |
| 694 | Jiggle time value label | 579 | 809 |
| 696 | CPU usage slider | 329 | 559 |
| gSu-Fg-P4O | Distance slider | 437 | 667 |
| 698 | CPU usage % label | 327 | 557 |
| 700 | App/process popup | 245 | 475 |
| 707 | Front app help text | 20 | 250 |
| 713 | Front app checkbox | 69 | 299 |
| 709 | Front app textfield | 39 | 269 |
| iNl-Uo-XLe | Launch on login checkbox | 685 | 915 |
| aez-qj-q8f | Close button | 688 | 918 |
| th1-8U-YUK | "far" label | 435 | 665 |
| JZA-aL-SRX | "nearby" label | 435 | 665 |

- [ ] **Step 2: Add schedule section elements to Preferences.xib**

Add the following elements as subviews of the content view (id="655"), before the closing `</subviews>` tag. These use numeric IDs in the 9000+ range to avoid collisions with existing IDs.

Schedule section label (separator):
```xml
<textField verticalHuggingPriority="750" horizontalCompressionResistancePriority="250" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9001">
    <rect key="frame" x="27" y="198" width="456" height="22"/>
    <autoresizingMask key="autoresizingMask"/>
    <textFieldCell key="cell" sendsActionOnEndEditing="YES" alignment="left" title="Schedule:" id="9002">
        <font key="font" metaFont="system"/>
        <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
        <color key="backgroundColor" name="controlColor" catalog="System" colorSpace="catalog"/>
    </textFieldCell>
</textField>
```

Enable Schedule checkbox:
```xml
<button fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9003">
    <rect key="frame" x="40" y="174" width="430" height="18"/>
    <autoresizingMask key="autoresizingMask"/>
    <buttonCell key="cell" type="check" title="Enable Schedule (automatically enable/disable on a weekly schedule)" bezelStyle="regularSquare" imagePosition="left" alignment="left" inset="2" id="9004">
        <behavior key="behavior" changeContents="YES" doesNotDimImage="YES" lightByContents="YES"/>
        <font key="font" metaFont="system"/>
    </buttonCell>
    <connections>
        <action selector="scheduleEnabledChanged:" target="-2" id="9005"/>
    </connections>
</button>
```

NSTableView (wrapped in scroll view):
```xml
<scrollView fixedFrame="YES" autohidesScrollers="YES" horizontalLineScroll="19" horizontalPageScroll="10" verticalLineScroll="19" verticalPageScroll="10" hasHorizontalScroller="NO" translatesAutoresizingMaskIntoConstraints="NO" id="9010">
    <rect key="frame" x="40" y="62" width="420" height="108"/>
    <autoresizingMask key="autoresizingMask"/>
    <clipView key="contentView" id="9011">
        <rect key="frame" x="1" y="1" width="418" height="106"/>
        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
        <subviews>
            <tableView verticalHuggingPriority="750" allowsEmptySelection="YES" allowsMultipleSelection="NO" allowsColumnSelection="NO" allowsColumnReordering="NO" allowsColumnResizing="NO" columnAutoresizingStyle="lastColumnOnly" columnReordering="NO" columnResizing="NO" multipleSelection="NO" emptySelection="YES" autosaveColumns="NO" id="9012">
                <rect key="frame" x="0" y="0" width="418" height="106"/>
                <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                <size key="intercellSpacing" width="3" height="2"/>
                <color key="backgroundColor" name="controlBackgroundColor" catalog="System" colorSpace="catalog"/>
                <color key="gridColor" name="gridColor" catalog="System" colorSpace="catalog"/>
                <tableColumns>
                    <tableColumn identifier="day" width="130" minWidth="80" maxWidth="200" id="9013">
                        <tableHeaderCell key="headerCell" lineBreakMode="truncatingTail" borderStyle="border" alignment="left" title="Day">
                            <font key="font" metaFont="smallSystem"/>
                            <color key="textColor" name="headerTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="headerColor" catalog="System" colorSpace="catalog"/>
                        </tableHeaderCell>
                        <textFieldCell key="dataCell" lineBreakMode="truncatingTail" selectable="YES" editable="NO" alignment="left" title="Text Cell" id="9014">
                            <font key="font" metaFont="system"/>
                            <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="controlBackgroundColor" catalog="System" colorSpace="catalog"/>
                        </textFieldCell>
                    </tableColumn>
                    <tableColumn identifier="start" width="130" minWidth="80" maxWidth="200" id="9015">
                        <tableHeaderCell key="headerCell" lineBreakMode="truncatingTail" borderStyle="border" alignment="left" title="Start">
                            <font key="font" metaFont="smallSystem"/>
                            <color key="textColor" name="headerTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="headerColor" catalog="System" colorSpace="catalog"/>
                        </tableHeaderCell>
                        <textFieldCell key="dataCell" lineBreakMode="truncatingTail" selectable="YES" editable="NO" alignment="left" title="Text Cell" id="9016">
                            <font key="font" metaFont="system"/>
                            <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="controlBackgroundColor" catalog="System" colorSpace="catalog"/>
                        </textFieldCell>
                    </tableColumn>
                    <tableColumn identifier="end" width="130" minWidth="80" maxWidth="200" id="9017">
                        <tableHeaderCell key="headerCell" lineBreakMode="truncatingTail" borderStyle="border" alignment="left" title="End">
                            <font key="font" metaFont="smallSystem"/>
                            <color key="textColor" name="headerTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="headerColor" catalog="System" colorSpace="catalog"/>
                        </tableHeaderCell>
                        <textFieldCell key="dataCell" lineBreakMode="truncatingTail" selectable="YES" editable="NO" alignment="left" title="Text Cell" id="9018">
                            <font key="font" metaFont="system"/>
                            <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
                            <color key="backgroundColor" name="controlBackgroundColor" catalog="System" colorSpace="catalog"/>
                        </textFieldCell>
                    </tableColumn>
                </tableColumns>
            </tableView>
        </subviews>
    </clipView>
</scrollView>
```

Plus button:
```xml
<button verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9020">
    <rect key="frame" x="40" y="36" width="24" height="24"/>
    <autoresizingMask key="autoresizingMask"/>
    <buttonCell key="cell" type="bevel" title="+" bezelStyle="smallSquare" alignment="center" lineBreakMode="truncatingTail" state="on" borderStyle="border" imageScaling="proportionallyDown" inset="2" id="9021">
        <behavior key="behavior" pushIn="YES" lightByBackground="YES" lightByGray="YES"/>
        <font key="font" metaFont="system"/>
    </buttonCell>
    <connections>
        <action selector="addScheduleEntry:" target="-2" id="9022"/>
    </connections>
</button>
```

Minus button:
```xml
<button verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9023">
    <rect key="frame" x="63" y="36" width="24" height="24"/>
    <autoresizingMask key="autoresizingMask"/>
    <buttonCell key="cell" type="bevel" title="−" bezelStyle="smallSquare" alignment="center" lineBreakMode="truncatingTail" state="on" borderStyle="border" imageScaling="proportionallyDown" inset="2" id="9024">
        <behavior key="behavior" pushIn="YES" lightByBackground="YES" lightByGray="YES"/>
        <font key="font" metaFont="system"/>
    </buttonCell>
    <connections>
        <action selector="removeScheduleEntry:" target="-2" id="9025"/>
    </connections>
</button>
```

Day popup:
```xml
<popUpButton verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9030">
    <rect key="frame" x="100" y="34" width="110" height="26"/>
    <autoresizingMask key="autoresizingMask"/>
    <popUpButtonCell key="cell" type="push" title="Monday" bezelStyle="rounded" alignment="left" lineBreakMode="truncatingTail" state="on" borderStyle="borderAndBezel" imageScaling="proportionallyDown" inset="2" selectedItem="9031" id="9032">
        <behavior key="behavior" lightByBackground="YES" lightByGray="YES"/>
        <font key="font" metaFont="system"/>
        <menu key="menu" title="OtherViews" id="9033">
            <items>
                <menuItem title="Monday" state="on" tag="2" id="9031"/>
            </items>
        </menu>
    </popUpButtonCell>
</popUpButton>
```

Start time popup:
```xml
<popUpButton verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9040">
    <rect key="frame" x="212" y="34" width="100" height="26"/>
    <autoresizingMask key="autoresizingMask"/>
    <popUpButtonCell key="cell" type="push" title="9:00 AM" bezelStyle="rounded" alignment="left" lineBreakMode="truncatingTail" state="on" borderStyle="borderAndBezel" imageScaling="proportionallyDown" inset="2" selectedItem="9041" id="9042">
        <behavior key="behavior" lightByBackground="YES" lightByGray="YES"/>
        <font key="font" metaFont="smallSystem"/>
        <menu key="menu" title="OtherViews" id="9043">
            <items>
                <menuItem title="9:00 AM" state="on" tag="540" id="9041"/>
            </items>
        </menu>
    </popUpButtonCell>
    <connections>
        <action selector="scheduleTimePopUpChanged:" target="-2" id="9044"/>
    </connections>
</popUpButton>
```

End time popup:
```xml
<popUpButton verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9050">
    <rect key="frame" x="314" y="34" width="100" height="26"/>
    <autoresizingMask key="autoresizingMask"/>
    <popUpButtonCell key="cell" type="push" title="5:00 PM" bezelStyle="rounded" alignment="left" lineBreakMode="truncatingTail" state="on" borderStyle="borderAndBezel" imageScaling="proportionallyDown" inset="2" selectedItem="9051" id="9052">
        <behavior key="behavior" lightByBackground="YES" lightByGray="YES"/>
        <font key="font" metaFont="smallSystem"/>
        <menu key="menu" title="OtherViews" id="9053">
            <items>
                <menuItem title="5:00 PM" state="on" tag="1020" id="9051"/>
            </items>
        </menu>
    </popUpButtonCell>
    <connections>
        <action selector="scheduleTimePopUpChanged:" target="-2" id="9054"/>
    </connections>
</popUpButton>
```

"to" label between start and end:
```xml
<textField verticalHuggingPriority="750" horizontalCompressionResistancePriority="250" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9060">
    <rect key="frame" x="310" y="40" width="15" height="17"/>
    <autoresizingMask key="autoresizingMask"/>
    <textFieldCell key="cell" sendsActionOnEndEditing="YES" alignment="center" title="–" id="9061">
        <font key="font" metaFont="system"/>
        <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
        <color key="backgroundColor" name="controlColor" catalog="System" colorSpace="catalog"/>
    </textFieldCell>
</textField>
```

Help text:
```xml
<textField verticalHuggingPriority="750" horizontalCompressionResistancePriority="250" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="9070">
    <rect key="frame" x="57" y="10" width="396" height="22"/>
    <autoresizingMask key="autoresizingMask"/>
    <textFieldCell key="cell" sendsActionOnEndEditing="YES" alignment="left" title="Use + to add time ranges. Days with no entries stay off." id="9071">
        <font key="font" metaFont="label" size="11"/>
        <color key="textColor" white="0.40000001000000002" alpha="1" colorSpace="calibratedWhite"/>
        <color key="backgroundColor" name="controlColor" catalog="System" colorSpace="catalog"/>
    </textFieldCell>
</textField>
```

- [ ] **Step 3: Add outlet connections in the File's Owner connections block**

Add these outlet connections to the File's Owner (id="-2") connections block:

```xml
<outlet property="scheduleEnabledCheckbox" destination="9003" id="9100"/>
<outlet property="scheduleTableView" destination="9012" id="9101"/>
<outlet property="addScheduleEntryButton" destination="9020" id="9102"/>
<outlet property="removeScheduleEntryButton" destination="9023" id="9103"/>
<outlet property="scheduleDayPopUp" destination="9030" id="9104"/>
<outlet property="scheduleStartTimePopUp" destination="9040" id="9105"/>
<outlet property="scheduleEndTimePopUp" destination="9050" id="9106"/>
```

- [ ] **Step 4: Add ScheduleEntry.h/.m to project.pbxproj**

Add file references, build file entries, and group membership for `ScheduleEntry.h` and `ScheduleEntry.m`. Use these pre-generated IDs (verified non-colliding with existing project IDs):

In `/* Begin PBXBuildFile section */`, add:
```
		A1B2C3D4E5F6A7B80001AAAA /* ScheduleEntry.m in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D4E5F6A7B80002AAAA /* ScheduleEntry.m */; };
```

In `/* Begin PBXFileReference section */`, add:
```
		A1B2C3D4E5F6A7B80003AAAA /* ScheduleEntry.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = ScheduleEntry.h; sourceTree = "<group>"; };
		A1B2C3D4E5F6A7B80002AAAA /* ScheduleEntry.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = ScheduleEntry.m; sourceTree = "<group>"; };
```

In the Classes group (id `987BCA12247F5B750069B2FC`), add to `children`:
```
				A1B2C3D4E5F6A7B80003AAAA /* ScheduleEntry.h */,
				A1B2C3D4E5F6A7B80002AAAA /* ScheduleEntry.m */,
```

In the Sources build phase (id `987BC9FA247F5AD80069B2FC`), add to `files`:
```
				A1B2C3D4E5F6A7B80001AAAA /* ScheduleEntry.m in Sources */,
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Debug build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

If build fails, diagnose and fix. Common issues: missing outlet connections, typos in XIB element IDs, missing pbxproj entries.

- [ ] **Step 6: Commit**

```bash
git add Base.lproj/Preferences.xib Jiggler.xcodeproj/project.pbxproj
git commit -m "feat: add schedule section UI to Preferences and register new files"
```

---

### Task 5: Build, verify, and final commit

**Files:**
- All files from previous tasks

- [ ] **Step 1: Clean build**

Run: `xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Debug clean build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Build Release configuration**

Run: `xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Release build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual smoke test checklist**

If the app can be launched, verify:
1. Open Preferences -- schedule section appears at the bottom
2. "Enable Schedule" checkbox toggles control states
3. Add an entry (Monday, 9:00 AM, 5:00 PM) -- appears in table sorted
4. Add a second entry (Tuesday, 1:00 PM, 3:00 PM) -- appears in correct position
5. Select an entry and click minus -- entry removed
6. Close and reopen Preferences -- entries persist
7. Toggle master switch during a scheduled period -- override works
8. Disable schedule -- master switch returns to manual control

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address issues found during schedule feature smoke test"
```
