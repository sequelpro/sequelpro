#import "CPTShadow.h"

@class CPTColor;

@interface CPTMutableShadow : CPTShadow

@property (nonatomic, readwrite, assign) CGSize shadowOffset;
@property (nonatomic, readwrite, assign) CGFloat shadowBlurRadius;
@property (nonatomic, readwrite, strong, nullable) CPTColor *shadowColor;

@end
