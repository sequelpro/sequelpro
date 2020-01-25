@interface CPTTimeFormatter : NSNumberFormatter

@property (nonatomic, readwrite, strong, nullable) NSDateFormatter *dateFormatter;
@property (nonatomic, readwrite, copy, nullable) NSDate *referenceDate;

/// @name Initialization
/// @{
-(nonnull instancetype)initWithDateFormatter:(nullable NSDateFormatter *)aDateFormatter NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

@end
