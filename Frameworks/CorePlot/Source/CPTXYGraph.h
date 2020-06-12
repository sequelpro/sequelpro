#import "CPTDefinitions.h"
#import "CPTGraph.h"

@interface CPTXYGraph : CPTGraph

/// @name Initialization
/// @{
-(nonnull instancetype)initWithFrame:(CGRect)newFrame xScaleType:(CPTScaleType)newXScaleType yScaleType:(CPTScaleType)newYScaleType NS_DESIGNATED_INITIALIZER;

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithLayer:(nonnull id)layer NS_DESIGNATED_INITIALIZER;
/// @}

@end
