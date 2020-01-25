#import "CPTLayer.h"

@class CPTAxis;

@interface CPTGridLines : CPTLayer

@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTAxis *axis;
@property (nonatomic, readwrite) BOOL major;

@end
