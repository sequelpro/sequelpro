#import "CPTLineStyle.h"

#import "CPTColor.h"
#import "CPTFill.h"
#import "CPTGradient.h"
#import "CPTMutableLineStyle.h"
#import "CPTPlatformSpecificFunctions.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"
#import "NSNumberExtensions.h"

/// @cond
@interface CPTLineStyle()

@property (nonatomic, readwrite, assign) CGLineCap lineCap;
@property (nonatomic, readwrite, assign) CGLineJoin lineJoin;
@property (nonatomic, readwrite, assign) CGFloat miterLimit;
@property (nonatomic, readwrite, assign) CGFloat lineWidth;
@property (nonatomic, readwrite, strong, nullable) CPTNumberArray *dashPattern;
@property (nonatomic, readwrite, assign) CGFloat patternPhase;
@property (nonatomic, readwrite, strong, nullable) CPTColor *lineColor;
@property (nonatomic, readwrite, strong, nullable) CPTFill *lineFill;
@property (nonatomic, readwrite, strong, nullable) CPTGradient *lineGradient;

-(void)strokePathWithGradient:(nonnull CPTGradient *)gradient inContext:(nonnull CGContextRef)context;

@end

/// @endcond

#pragma mark -

/** @brief Immutable wrapper for various line drawing properties. Create a CPTMutableLineStyle if you want to customize properties.
 *
 *  The line stroke can be drawn three different ways, prioritized in the following order:
 *
 *  -# A gradient that follows the stroked path (@ref lineGradient)
 *  -# As a cut out mask over an area filled with a CPTFill (@ref lineFill)
 *  -# Filled with a solid color (@ref lineColor)
 *
 *  @see See Apple&rsquo;s <a href="http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_paths/dq_paths.html#//apple_ref/doc/uid/TP30001066-CH211-TPXREF105">Quartz 2D</a>
 *  and <a href="http://developer.apple.com/documentation/GraphicsImaging/Reference/CGContext/Reference/reference.html">CGContext</a>
 *  documentation for more information about each of these properties.
 **/

@implementation CPTLineStyle

/** @property CGLineCap lineCap;
 *  @brief The style for the endpoints of lines drawn in a graphics context. Default is @ref kCGLineCapButt.
 **/
@synthesize lineCap;

/** @property CGLineJoin lineJoin
 *  @brief The style for the joins of connected lines in a graphics context. Default is @ref kCGLineJoinMiter.
 **/
@synthesize lineJoin;

/** @property CGFloat miterLimit
 *  @brief The miter limit for the joins of connected lines in a graphics context. Default is @num{10.0}.
 **/
@synthesize miterLimit;

/** @property CGFloat lineWidth
 *  @brief The line width for a graphics context. Default is @num{1.0}.
 **/
@synthesize lineWidth;

/** @property nullable CPTNumberArray *dashPattern
 *  @brief The dash-and-space pattern for the line. Default is @nil.
 **/
@synthesize dashPattern;

/** @property CGFloat patternPhase
 *  @brief The starting phase of the line dash pattern. Default is @num{0.0}.
 **/
@synthesize patternPhase;

/** @property nullable CPTColor *lineColor
 *  @brief The current stroke color in a context. Default is solid black.
 **/
@synthesize lineColor;

/** @property nullable CPTFill *lineFill
 *  @brief The current line fill. Default is @nil.
 *
 *  If @nil, the line is drawn using the @ref lineGradient or @ref lineColor.
 **/
@synthesize lineFill;

/** @property nullable CPTGradient *lineGradient
 *  @brief The current line gradient fill. Default is @nil.
 *
 *  If @nil, the line is drawn using the @ref lineFill or @ref lineColor.
 **/
@synthesize lineGradient;

/** @property BOOL opaque
 *  @brief If @YES, a line drawn using the line style is completely opaque.
 */
@dynamic opaque;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Creates and returns a new CPTLineStyle instance.
 *  @return A new CPTLineStyle instance.
 **/
+(nonnull instancetype)lineStyle
{
    return [[self alloc] init];
}

/** @brief Creates and returns a new line style instance initialized from an existing line style.
 *
 *  The line style will be initialized with values from the given @par{lineStyle}.
 *
 *  @param lineStyle An existing CPTLineStyle.
 *  @return A new line style instance.
 **/
+(nonnull instancetype)lineStyleWithStyle:(nullable CPTLineStyle *)lineStyle
{
    CPTLineStyle *newLineStyle = [[self alloc] init];

    newLineStyle.lineCap      = lineStyle.lineCap;
    newLineStyle.lineJoin     = lineStyle.lineJoin;
    newLineStyle.miterLimit   = lineStyle.miterLimit;
    newLineStyle.lineWidth    = lineStyle.lineWidth;
    newLineStyle.dashPattern  = [lineStyle.dashPattern copy];
    newLineStyle.patternPhase = lineStyle.patternPhase;
    newLineStyle.lineColor    = lineStyle.lineColor;
    newLineStyle.lineFill     = lineStyle.lineFill;
    newLineStyle.lineGradient = lineStyle.lineGradient;

    return newLineStyle;
}

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTLineStyle object.
 *
 *  The initialized object will have the following properties:
 *  - @ref lineCap = @ref kCGLineCapButt
 *  - @ref lineJoin = @ref kCGLineJoinMiter
 *  - @ref miterLimit = @num{10.0}
 *  - @ref lineWidth = @num{1.0}
 *  - @ref dashPattern = @nil
 *  - @ref patternPhase = @num{0.0}
 *  - @ref lineColor = opaque black
 *  - @ref lineFill = @nil
 *  - @ref lineGradient = @nil
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        lineCap      = kCGLineCapButt;
        lineJoin     = kCGLineJoinMiter;
        miterLimit   = CPTFloat(10.0);
        lineWidth    = CPTFloat(1.0);
        dashPattern  = nil;
        patternPhase = CPTFloat(0.0);
        lineColor    = [CPTColor blackColor];
        lineFill     = nil;
        lineGradient = nil;
    }
    return self;
}

/// @}

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeInt:self.lineCap forKey:@"CPTLineStyle.lineCap"];
    [coder encodeInt:self.lineJoin forKey:@"CPTLineStyle.lineJoin"];
    [coder encodeCGFloat:self.miterLimit forKey:@"CPTLineStyle.miterLimit"];
    [coder encodeCGFloat:self.lineWidth forKey:@"CPTLineStyle.lineWidth"];
    [coder encodeObject:self.dashPattern forKey:@"CPTLineStyle.dashPattern"];
    [coder encodeCGFloat:self.patternPhase forKey:@"CPTLineStyle.patternPhase"];
    [coder encodeObject:self.lineColor forKey:@"CPTLineStyle.lineColor"];
    [coder encodeObject:self.lineFill forKey:@"CPTLineStyle.lineFill"];
    [coder encodeObject:self.lineGradient forKey:@"CPTLineStyle.lineGradient"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        lineCap     = (CGLineCap)[coder decodeIntForKey:@"CPTLineStyle.lineCap"];
        lineJoin    = (CGLineJoin)[coder decodeIntForKey:@"CPTLineStyle.lineJoin"];
        miterLimit  = [coder decodeCGFloatForKey:@"CPTLineStyle.miterLimit"];
        lineWidth   = [coder decodeCGFloatForKey:@"CPTLineStyle.lineWidth"];
        dashPattern = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                            forKey:@"CPTLineStyle.dashPattern"];
        patternPhase = [coder decodeCGFloatForKey:@"CPTLineStyle.patternPhase"];
        lineColor    = [coder decodeObjectOfClass:[CPTColor class]
                                           forKey:@"CPTLineStyle.lineColor"];
        lineFill = [coder decodeObjectOfClass:[CPTFill class]
                                       forKey:@"CPTLineStyle.lineFill"];
        lineGradient = [coder decodeObjectOfClass:[CPTGradient class]
                                           forKey:@"CPTLineStyle.lineGradient"];
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

/** @brief Sets all of the line drawing properties in the given graphics context.
 *  @param context The graphics context.
 **/
-(void)setLineStyleInContext:(nonnull CGContextRef)context
{
    CGContextSetLineCap(context, self.lineCap);
    CGContextSetLineJoin(context, self.lineJoin);
    CGContextSetMiterLimit(context, self.miterLimit);
    CGContextSetLineWidth(context, self.lineWidth);

    CPTNumberArray *myDashPattern = self.dashPattern;

    NSUInteger dashCount = myDashPattern.count;
    if ( dashCount > 0 ) {
        CGFloat *dashLengths = (CGFloat *)calloc(dashCount, sizeof(CGFloat));

        NSUInteger dashCounter = 0;
        for ( NSNumber *currentDashLength in myDashPattern ) {
            dashLengths[dashCounter++] = [currentDashLength cgFloatValue];
        }

        CGContextSetLineDash(context, self.patternPhase, dashLengths, dashCount);
        free(dashLengths);
    }
    else {
        CGContextSetLineDash(context, CPTFloat(0.0), NULL, 0);
    }
    CGContextSetStrokeColorWithColor(context, self.lineColor.cgColor);
}

/** @brief Stroke the current path in the given graphics context.
 *  Call @link CPTLineStyle::setLineStyleInContext: -setLineStyleInContext: @endlink first to set up the drawing properties.
 *
 *  @param context The graphics context.
 **/
-(void)strokePathInContext:(nonnull CGContextRef)context
{
    CPTGradient *gradient = self.lineGradient;
    CPTFill *fill         = self.lineFill;

    if ( gradient ) {
        [self strokePathWithGradient:gradient inContext:context];
    }
    else if ( fill ) {
        CGContextReplacePathWithStrokedPath(context);
        [fill fillPathInContext:context];
    }
    else {
        CGContextStrokePath(context);
    }
}

/** @brief Stroke a rectangular path in the given graphics context.
 *  Call @link CPTLineStyle::setLineStyleInContext: -setLineStyleInContext: @endlink first to set up the drawing properties.
 *
 *  @param rect The rectangle to draw.
 *  @param context The graphics context.
 **/
-(void)strokeRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    CPTGradient *gradient = self.lineGradient;
    CPTFill *fill         = self.lineFill;

    if ( gradient ) {
        CGContextBeginPath(context);
        CGContextAddRect(context, rect);
        [self strokePathWithGradient:gradient inContext:context];
    }
    else if ( fill ) {
        CGContextBeginPath(context);
        CGContextAddRect(context, rect);
        CGContextReplacePathWithStrokedPath(context);
        [fill fillPathInContext:context];
    }
    else {
        CGContextStrokeRect(context, rect);
    }
}

/// @cond

-(void)strokePathWithGradient:(nonnull CPTGradient *)gradient inContext:(nonnull CGContextRef)context
{
    if ( gradient ) {
        CGRect deviceRect = CGContextConvertRectToDeviceSpace(context, CPTRectMake(0.0, 0.0, 1.0, 1.0));

        CGFloat step = CPTFloat(2.0) / deviceRect.size.height;

        CGFloat startWidth = self.lineWidth;

        CGPathRef path = CGContextCopyPath(context);
        CGContextBeginPath(context);

        CGFloat width = startWidth;
        while ( width > CPTFloat(0.0)) {
            CGContextSetLineWidth(context, width);

            CGColorRef gradientColor = [gradient newColorAtPosition:CPTFloat(1.0) - width / startWidth];
            CGContextSetStrokeColorWithColor(context, gradientColor);
            CGColorRelease(gradientColor);

            CGContextAddPath(context, path);
            CGContextStrokePath(context);

            width -= step;
        }

        CGPathRelease(path);
    }
}

/// @endcond

#pragma mark -
#pragma mark Opacity

/// @cond

-(BOOL)isOpaque
{
    BOOL opaqueLine = NO;

    if ( self.dashPattern.count <= 1 ) {
        if ( self.lineGradient ) {
            opaqueLine = self.lineGradient.opaque;
        }
        else if ( self.lineFill ) {
            opaqueLine = self.lineFill.opaque;
        }
        else if ( self.lineColor ) {
            opaqueLine = self.lineColor.opaque;
        }
    }

    return opaqueLine;
}

/// @endcond

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    CPTLineStyle *styleCopy = [[CPTLineStyle allocWithZone:zone] init];

    styleCopy.lineCap      = self.lineCap;
    styleCopy.lineJoin     = self.lineJoin;
    styleCopy.miterLimit   = self.miterLimit;
    styleCopy.lineWidth    = self.lineWidth;
    styleCopy.dashPattern  = [self.dashPattern copy];
    styleCopy.patternPhase = self.patternPhase;
    styleCopy.lineColor    = self.lineColor;
    styleCopy.lineFill     = self.lineFill;
    styleCopy.lineGradient = self.lineGradient;

    return styleCopy;
}

/// @endcond

#pragma mark -
#pragma mark NSMutableCopying Methods

/// @cond

-(nonnull id)mutableCopyWithZone:(nullable NSZone *)zone
{
    CPTLineStyle *styleCopy = [[CPTMutableLineStyle allocWithZone:zone] init];

    styleCopy.lineCap      = self.lineCap;
    styleCopy.lineJoin     = self.lineJoin;
    styleCopy.miterLimit   = self.miterLimit;
    styleCopy.lineWidth    = self.lineWidth;
    styleCopy.dashPattern  = [self.dashPattern copy];
    styleCopy.patternPhase = self.patternPhase;
    styleCopy.lineColor    = self.lineColor;
    styleCopy.lineFill     = self.lineFill;
    styleCopy.lineGradient = self.lineGradient;

    return styleCopy;
}

/// @endcond

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    const CGRect rect = CGRectMake(0.0, 0.0, 100.0, 100.0);

    return CPTQuickLookImage(rect, ^(CGContextRef context, CGFloat __unused scale, CGRect bounds) {
        const CGRect alignedRect = CPTAlignBorderedRectToUserSpace(context, bounds, self);

        [self setLineStyleInContext:context];
        [self strokeRect:alignedRect inContext:context];
    });
}

/// @endcond

@end
