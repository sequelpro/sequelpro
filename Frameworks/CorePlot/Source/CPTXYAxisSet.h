#import "CPTAxisSet.h"

@class CPTXYAxis;

@interface CPTXYAxisSet : CPTAxisSet

@property (nonatomic, readonly, nullable) CPTXYAxis *xAxis;
@property (nonatomic, readonly, nullable) CPTXYAxis *yAxis;

@end
