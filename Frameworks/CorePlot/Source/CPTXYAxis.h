#import "CPTAxis.h"

@class CPTConstraints;

@interface CPTXYAxis : CPTAxis

/// @name Positioning
/// @{
@property (nonatomic, readwrite, strong, nullable) NSNumber *orthogonalPosition;
@property (nonatomic, readwrite, strong, nullable) CPTConstraints *axisConstraints;
/// @}

@end
