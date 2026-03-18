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
