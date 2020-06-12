#import "CPTGridLines.h"

#import "CPTAxis.h"

/**
 *  @brief An abstract class that draws grid lines for an axis.
 **/
@implementation CPTGridLines

/** @property nullable CPTAxis *axis
 *  @brief The axis.
 **/
@synthesize axis;

/** @property BOOL major
 *  @brief If @YES, draw the major grid lines, else draw the minor grid lines.
 **/
@synthesize major;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTGridLines object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref axis = @nil
 *  - @ref major = @NO
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTGridLines object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        axis  = nil;
        major = NO;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTGridLines *theLayer = (CPTGridLines *)layer;

        axis  = theLayer->axis;
        major = theLayer->major;
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeConditionalObject:self.axis forKey:@"CPTGridLines.axis"];
    [coder encodeBool:self.major forKey:@"CPTGridLines.major"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        axis = [coder decodeObjectOfClass:[CPTAxis class]
                                   forKey:@"CPTGridLines.axis"];
        major = [coder decodeBoolForKey:@"CPTGridLines.major"];
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    CPTAxis *theAxis = self.axis;
    [theAxis drawGridLinesInContext:context isMajor:self.major];
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setAxis:(nullable CPTAxis *)newAxis
{
    if ( newAxis != axis ) {
        axis = newAxis;
        [self setNeedsDisplay];
    }
}

/// @endcond

@end
