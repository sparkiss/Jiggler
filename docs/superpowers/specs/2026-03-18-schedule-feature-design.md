# Schedule Feature Design

Automatically enable/disable Jiggler on a recurring weekly schedule.

## Requirements

- Users define time ranges per day of week (e.g., Monday 9:00-12:00, Monday 13:00-17:00)
- Multiple entries per day allowed; days with no entries mean Jiggler stays off
- Schedule directly controls the master switch: auto-enables at range start, auto-disables at range end
- Manual toggle during an active range overrides until the next schedule boundary
- Global "Enable Schedule" checkbox toggles the feature without deleting entries
- Time granularity: 15-minute increments

## Data Model

Stored in NSUserDefaults:

| Key | Type | Description |
|-----|------|-------------|
| `ScheduleEnabled` | BOOL | Master toggle for schedule feature (default: NO) |
| `ScheduleEntries` | NSArray of NSDictionary | List of schedule entries |

Each entry dictionary:

| Key | Type | Description |
|-----|------|-------------|
| `day` | int (1-7) | Day of week. NSCalendar convention: Sunday=1, Monday=2, ..., Saturday=7 |
| `startMinute` | int (0-1425) | Start time as minutes from midnight. 15-minute increments. |
| `endMinute` | int (15-1440) | End time as minutes from midnight. Must be > startMinute. |

Example: Monday 9:00 AM - 12:00 PM = `{ day: 2, startMinute: 540, endMinute: 720 }`

Overlapping entries on the same day are allowed (both count as active).

**Validation:** `endMinute` must be > `startMinute`. The Add button is disabled when end <= start. Ranges cannot span midnight; use two entries on consecutive days if needed (e.g., 11:45 PM-12:00 AM on day 1 and 12:00 AM-12:30 AM on day 2).

**Start time popup:** 96 options (12:00 AM through 11:45 PM, i.e., 0-1425). **End time popup:** 96 options (12:15 AM through 12:00 AM next day, i.e., 15-1440).

**Empty schedule:** If schedule is enabled but has no entries, the master switch will be turned OFF by the next schedule evaluation (~4 seconds).

## Architecture

### New Class: ScheduleEntry

Simple model object. No XIB. Uses manual retain/release (no ARC), consistent with the rest of the codebase. Uses bare ivars (not @property), matching the existing AppDelegate/PrefsController style.

```objc
@interface ScheduleEntry : NSObject
{
    int day;           // 1-7 (NSCalendar weekday)
    int startMinute;   // 0-1425
    int endMinute;     // 15-1440
}

- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)entryWithDictionary:(NSDictionary *)dict;
- (NSString *)dayString;               // "Monday", "Tuesday", etc.
- (NSString *)startTimeString;         // "9:00 AM"
- (NSString *)endTimeString;           // "12:00 PM"
+ (NSString *)timeStringForMinute:(int)minute;
@end
```

### PrefsController Changes

New ivars:
- `BOOL scheduleEnabled`
- `NSMutableArray *scheduleEntries` (of ScheduleEntry)
- IBOutlets for: schedule checkbox, NSTableView, +/- buttons, day/start/end popups, Add button

New NSUserDefaults keys: `ScheduleEnabled`, `ScheduleEntries`

New methods:
- `- (BOOL)scheduleEnabled`
- `- (NSArray *)scheduleEntries`
- `- (IBAction)scheduleEnabledChanged:(id)sender`
- `- (IBAction)addScheduleEntry:(id)sender`
- `- (IBAction)removeScheduleEntry:(id)sender`

Implements `NSTableViewDataSource` and `NSTableViewDelegate` for the schedule table.

Entries are sorted by day first, then start time, on every add/load.

Saving: converts ScheduleEntry array to array of dictionaries, writes to NSUserDefaults.

### AppDelegate Changes

New ivar:
- `BOOL scheduleManuallyOverridden` -- set when user manually toggles master switch during active schedule

New method:
- `- (void)evaluateSchedule` -- called at the **top** of `periodicJiggleStatusCheck:`, before the inhibitor checks, every ~4 seconds (using existing `callout_counter & 0x0F` pattern). This ensures schedule-driven master switch changes are visible to the rest of the function within the same callout. Schedule boundaries are enforced within ~4 seconds, not exactly on the minute.

#### evaluateSchedule Logic

```
1. Get scheduleEnabled and scheduleEntries from PrefsController
2. If !scheduleEnabled, return (manual control only)
3. Get current weekday and minuteOfDay from NSCalendar
4. Check if current time is within any schedule entry
5. If within a range:
   - If scheduleManuallyOverridden, do nothing
   - Else if master switch is OFF, turn it ON
6. If outside all ranges:
   - Clear scheduleManuallyOverridden
   - If master switch is ON, turn it OFF
```

#### Modified jiggleMasterSwitchChanged:

When the user manually toggles the master switch and the schedule is enabled and current time is within an active range, set `scheduleManuallyOverridden = YES`.

### Preferences.xib Changes

New section below existing controls:

1. **"Enable Schedule"** checkbox with descriptive text
2. **NSTableView** (3 columns: Day 110px, Start 90px, End 90px)
   - Columns are not user-editable; entries managed via add/remove
3. **+/- segmented control** below table (standard macOS table button pattern)
4. **Add entry controls**: three NSPopUpButtons (day, start, end) + "Add" button
   - Day popup: Sunday through Saturday
   - Time popups: 96 options each, 12-hour format with AM/PM (12:00 AM, 12:15 AM, ... 11:45 PM)
   - Controls disabled when schedule checkbox is off

## Schedule Boundary Behavior

- **App launch**: Schedule evaluates fresh. If current time is within a range, master switch turns ON. No override flag persists across launches.
- **Manual override**: Sticks until current range ends or next range begins (any boundary transition clears it).
- **Multiple ranges same day**: Each range is independent. Override clears when exiting the current range, even if another range is about to start. When transitioning directly from one range into another (back-to-back entries), the override is cleared and the switch is re-enabled.
- **Schedule disabled**: Master switch stays in whatever state it's in. User has full manual control.

## Memory Management

All new code follows manual retain/release (no ARC), consistent with the rest of the codebase.

- `ScheduleEntry` implements `dealloc` (trivial -- no object ivars to release).
- `PrefsController`: `scheduleEntries` is `[[NSMutableArray alloc] init]` in `init`, released in `dealloc`. Individual `ScheduleEntry` objects are retained by the array.
- `dictionaryRepresentation` returns an autoreleased `NSDictionary`. `entryWithDictionary:` returns an autoreleased `ScheduleEntry`.
- New ivars in both `PrefsController` and `AppDelegate` go in the existing `@interface` ivar blocks, matching the current codebase style.

## Localization

Localization of the schedule UI labels is out of scope for the initial implementation. Strings will be hardcoded in English, consistent with how some existing UI elements are handled.

## Files Modified

| File | Change |
|------|--------|
| `ScheduleEntry.h` | New file -- model class header |
| `ScheduleEntry.m` | New file -- model class implementation |
| `PrefsController.h` | Add schedule ivars, outlets, methods |
| `PrefsController.m` | Add schedule persistence, table data source/delegate, actions |
| `AppDelegate.h` | Add scheduleManuallyOverridden ivar |
| `AppDelegate.m` | Add evaluateSchedule method, modify periodicJiggleStatusCheck: and jiggleMasterSwitchChanged: |
| `Base.lproj/Preferences.xib` | Add schedule section UI |
| `Jiggler.xcodeproj/project.pbxproj` | Add new ScheduleEntry.h/.m files |
