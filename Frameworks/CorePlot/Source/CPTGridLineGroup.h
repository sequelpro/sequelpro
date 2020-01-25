#import "CPTLayer.h"

@class CPTPlotArea;

@interface CPTGridLineGroup : CPTLayer

@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTPlotArea *plotArea;
@property (nonatomic, readwrite) BOOL major;

@end
