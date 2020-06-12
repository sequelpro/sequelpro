#import "CPTTestCase.h"

#import "CPTDefinitions.h"

@class CPTLayer;

@interface CPTLayerTests : CPTTestCase

@property (nonatomic, readwrite, strong, nonnull) CPTLayer *layer;
@property (nonatomic, readwrite, strong, nonnull) CPTNumberArray *positions;

@end
