#import "CPTPlotRange.h"

@interface CPTMutablePlotRange : CPTPlotRange

/// @name Range Limits
/// @{
@property (nonatomic, readwrite, strong, nonnull) NSNumber *location;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *length;
@property (nonatomic, readwrite) NSDecimal locationDecimal;
@property (nonatomic, readwrite) NSDecimal lengthDecimal;
@property (nonatomic, readwrite) double locationDouble;
@property (nonatomic, readwrite) double lengthDouble;
/// @}

/// @name Combining Ranges
/// @{
-(void)unionPlotRange:(nullable CPTPlotRange *)otherRange;
-(void)intersectionPlotRange:(nullable CPTPlotRange *)otherRange;
/// @}

/// @name Shifting Ranges
/// @{
-(void)shiftLocationToFitInRange:(nonnull CPTPlotRange *)otherRange;
-(void)shiftEndToFitInRange:(nonnull CPTPlotRange *)otherRange;
/// @}

/// @name Expanding/Contracting Ranges
/// @{
-(void)expandRangeByFactor:(nonnull NSNumber *)factor;
/// @}

@end
