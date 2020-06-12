#import "CPTAnnotation.h"

@class CPTPlotSpace;

@interface CPTPlotSpaceAnnotation : CPTAnnotation

@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *anchorPlotPoint;
@property (nonatomic, readonly, nonnull) CPTPlotSpace *plotSpace;

/// @name Initialization
/// @{
-(nonnull instancetype)initWithPlotSpace:(nonnull CPTPlotSpace *)space anchorPlotPoint:(nullable CPTNumberArray *)plotPoint NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/// @}

@end
