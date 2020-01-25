@interface CPTCalendarFormatter : NSNumberFormatter

@property (nonatomic, readwrite, strong, nullable) NSDateFormatter *dateFormatter;
@property (nonatomic, readwrite, copy, nullable) NSDate *referenceDate;
@property (nonatomic, readwrite, copy, nullable) NSCalendar *referenceCalendar;
@property (nonatomic, readwrite, assign) NSCalendarUnit referenceCalendarUnit;

/// @name Initialization
/// @{
-(nonnull instancetype)initWithDateFormatter:(nullable NSDateFormatter *)aDateFormatter NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

@end
