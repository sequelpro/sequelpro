#import "CPTBorderedLayer.h"

@class CPTAxisSet;
@class CPTPlotGroup;
@class CPTPlotArea;

@interface CPTPlotAreaFrame : CPTBorderedLayer

@property (nonatomic, readonly, nullable) CPTPlotArea *plotArea;
@property (nonatomic, readwrite, strong, nullable) CPTAxisSet *axisSet;
@property (nonatomic, readwrite, strong, nullable) CPTPlotGroup *plotGroup;

@end
