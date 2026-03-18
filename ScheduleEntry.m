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
