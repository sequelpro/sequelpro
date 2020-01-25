#import "CPTDefinitions.h"

@class CPTGraph;

@interface CPTGraphHostingView : UIView<NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, strong, nullable) CPTGraph *hostedGraph;
@property (nonatomic, readwrite, assign) BOOL collapsesLayers;
@property (nonatomic, readwrite, assign) BOOL allowPinchScaling;

@end
