#import "CPTLineCap.h"

#import "CPTDefinitions.h"
#import "CPTFill.h"
#import "CPTLineStyle.h"
#import "CPTPlatformSpecificFunctions.h"
#import "NSCoderExtensions.h"
#import <tgmath.h>

/// @cond
@interface CPTLineCap()

@property (nonatomic, readwrite, assign, nullable) CGPathRef cachedLineCapPath;

-(nonnull CGPathRef)newLineCapPath;

@end

/// @endcond

#pragma mark -

/**
 *  @brief End cap decorations for lines.
 */
@implementation CPTLineCap

/** @property CGSize size;
 *  @brief The symbol size when the line is drawn in a vertical direction.
 **/
@synthesize size;

/** @property CPTLineCapType lineCapType
 *  @brief The line cap type.
 **/
@synthesize lineCapType;

/** @property nullable CPTLineStyle *lineStyle
 *  @brief The line style for the border of the line cap.
 *  If @nil, the border is not drawn.
 **/
@synthesize lineStyle;

/** @property nullable CPTFill *fill
 *  @brief The fill for the interior of the line cap.
 *  If @nil, the symbol is not filled.
 **/
@synthesize fill;

/** @property nullable CGPathRef customLineCapPath
 *  @brief The drawing path for a custom line cap. It will be scaled to size before being drawn.
 **/
@synthesize customLineCapPath;

/** @property BOOL usesEvenOddClipRule
 *  @brief If @YES, the even-odd rule is used to draw the line cap, otherwise the non-zero winding number rule is used.
 *  @see <a href="http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_paths/dq_paths.html#//apple_ref/doc/uid/TP30001066-CH211-TPXREF106">Filling a Path</a> in the Quartz 2D Programming Guide.
 **/
@synthesize usesEvenOddClipRule;

@synthesize cachedLineCapPath;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTLineCap object.
 *
 *  The initialized object will have the following properties:
 *  - @ref size = (@num{5.0}, @num{5.0})
 *  - @ref lineCapType = #CPTLineCapTypeNone
 *  - @ref lineStyle = a new default line style
 *  - @ref fill = @nil
 *  - @ref customLineCapPath = @NULL
 *  - @ref usesEvenOddClipRule = @NO
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        size                = CPTSizeMake(5.0, 5.0);
        lineCapType         = CPTLineCapTypeNone;
        lineStyle           = [[CPTLineStyle alloc] init];
        fill                = nil;
        cachedLineCapPath   = NULL;
        customLineCapPath   = NULL;
        usesEvenOddClipRule = NO;
    }
    return self;
}

/// @}

/// @cond

-(void)dealloc
{
    CGPathRelease(cachedLineCapPath);
    CGPathRelease(customLineCapPath);
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeCPTSize:self.size forKey:@"CPTLineCap.size"];
    [coder encodeInteger:self.lineCapType forKey:@"CPTLineCap.lineCapType"];
    [coder encodeObject:self.lineStyle forKey:@"CPTLineCap.lineStyle"];
    [coder encodeObject:self.fill forKey:@"CPTLineCap.fill"];
    [coder encodeCGPath:self.customLineCapPath forKey:@"CPTLineCap.customLineCapPath"];
    [coder encodeBool:self.usesEvenOddClipRule forKey:@"CPTLineCap.usesEvenOddClipRule"];

    // No need to archive these properties:
    // cachedLineCapPath
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        size        = [coder decodeCPTSizeForKey:@"CPTLineCap.size"];
        lineCapType = (CPTLineCapType)[coder decodeIntegerForKey:@"CPTLineCap.lineCapType"];
        lineStyle   = [coder decodeObjectOfClass:[CPTLineStyle class]
                                          forKey:@"CPTLineCap.lineStyle"];
        fill = [coder decodeObjectOfClass:[CPTFill class]
                                   forKey:@"CPTLineCap.fill"];
        customLineCapPath   = [coder newCGPathDecodeForKey:@"CPTLineCap.customLineCapPath"];
        usesEvenOddClipRule = [coder decodeBoolForKey:@"CPTLineCap.usesEvenOddClipRule"];

        cachedLineCapPath = NULL;
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
#pragma mark Accessors

/// @cond

-(void)setSize:(CGSize)newSize
{
    if ( !CGSizeEqualToSize(newSize, size)) {
        size                   = newSize;
        self.cachedLineCapPath = NULL;
    }
}

-(void)setLineCapType:(CPTLineCapType)newType
{
    if ( newType != lineCapType ) {
        lineCapType            = newType;
        self.cachedLineCapPath = NULL;
    }
}

-(void)setCustomLineCapPath:(nullable CGPathRef)newPath
{
    if ( customLineCapPath != newPath ) {
        CGPathRelease(customLineCapPath);
        customLineCapPath      = CGPathRetain(newPath);
        self.cachedLineCapPath = NULL;
    }
}

-(nullable CGPathRef)cachedLineCapPath
{
    if ( !cachedLineCapPath ) {
        cachedLineCapPath = [self newLineCapPath];
    }
    return cachedLineCapPath;
}

-(void)setCachedLineCapPath:(nullable CGPathRef)newPath
{
    if ( cachedLineCapPath != newPath ) {
        CGPathRelease(cachedLineCapPath);
        cachedLineCapPath = CGPathRetain(newPath);
    }
}

/// @endcond

#pragma mark -
#pragma mark Factory methods

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeNone.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeNone.
 **/
+(nonnull instancetype)lineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeNone;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeOpenArrow.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeOpenArrow.
 **/
+(nonnull instancetype)openArrowPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeOpenArrow;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSolidArrow.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSolidArrow.
 **/
+(nonnull instancetype)solidArrowPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeSolidArrow;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSweptArrow.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSweptArrow.
 **/
+(nonnull instancetype)sweptArrowPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeSweptArrow;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeRectangle.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeRectangle.
 **/
+(nonnull instancetype)rectanglePlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeRectangle;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeEllipse.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeEllipse.
 **/
+(nonnull instancetype)ellipsePlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeEllipse;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeDiamond.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeDiamond.
 **/
+(nonnull instancetype)diamondPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeDiamond;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypePentagon.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypePentagon.
 **/
+(nonnull instancetype)pentagonPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypePentagon;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeHexagon.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeHexagon.
 **/
+(nonnull instancetype)hexagonPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeHexagon;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeBar.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeBar.
 **/
+(nonnull instancetype)barPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeBar;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeCross.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeCross.
 **/
+(nonnull instancetype)crossPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeCross;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSnow.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeSnow.
 **/
+(nonnull instancetype)snowPlotLineCap
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType = CPTLineCapTypeSnow;

    return lineCap;
}

/** @brief Creates and returns a new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeCustom.
 *  @param aPath The bounding path for the custom line cap.
 *  @return A new CPTLineCap instance initialized with a line cap type of #CPTLineCapTypeCustom.
 **/
+(nonnull instancetype)customLineCapWithPath:(nullable CGPathRef)aPath
{
    CPTLineCap *lineCap = [[self alloc] init];

    lineCap.lineCapType       = CPTLineCapTypeCustom;
    lineCap.customLineCapPath = aPath;

    return lineCap;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    CPTLineCap *copy = [[[self class] allocWithZone:zone] init];

    copy.size                = self.size;
    copy.lineCapType         = self.lineCapType;
    copy.usesEvenOddClipRule = self.usesEvenOddClipRule;
    copy.lineStyle           = [self.lineStyle copy];
    copy.fill                = [self.fill copy];

    if ( self.customLineCapPath ) {
        CGPathRef pathCopy = CGPathCreateCopy(self.customLineCapPath);
        copy.customLineCapPath = pathCopy;
        CGPathRelease(pathCopy);
    }

    return copy;
}

/// @endcond

#pragma mark -
#pragma mark Drawing

/** @brief Draws the line cap into the given graphics context centered at the provided point.
 *  @param context The graphics context to draw into.
 *  @param center The center point of the line cap.
 *  @param direction The direction the line is pointing.
 **/
-(void)renderAsVectorInContext:(nonnull CGContextRef)context atPoint:(CGPoint)center inDirection:(CGPoint)direction
{
    CGPathRef theLineCapPath = self.cachedLineCapPath;

    if ( theLineCapPath ) {
        CPTLineStyle *theLineStyle = nil;
        CPTFill *theFill           = nil;

        switch ( self.lineCapType ) {
            case CPTLineCapTypeSolidArrow:
            case CPTLineCapTypeSweptArrow:
            case CPTLineCapTypeRectangle:
            case CPTLineCapTypeEllipse:
            case CPTLineCapTypeDiamond:
            case CPTLineCapTypePentagon:
            case CPTLineCapTypeHexagon:
            case CPTLineCapTypeCustom:
                theLineStyle = self.lineStyle;
                theFill      = self.fill;
                break;

            case CPTLineCapTypeOpenArrow:
            case CPTLineCapTypeBar:
            case CPTLineCapTypeCross:
            case CPTLineCapTypeSnow:
                theLineStyle = self.lineStyle;
                break;

            default:
                break;
        }

        if ( theLineStyle || theFill ) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, center.x, center.y);
            CGContextRotateCTM(context, atan2(direction.y, direction.x) - CPTFloat(M_PI_2)); // standard symbol points up

            if ( theFill ) {
                // use fillRect instead of fillPath so that images and gradients are properly centered in the symbol
                CGSize symbolSize = self.size;
                CGSize halfSize   = CPTSizeMake(symbolSize.width / CPTFloat(2.0), symbolSize.height / CPTFloat(2.0));
                CGRect bounds     = CPTRectMake(-halfSize.width, -halfSize.height, symbolSize.width, symbolSize.height);

                CGContextSaveGState(context);
                if ( !CGPathIsEmpty(theLineCapPath)) {
                    CGContextBeginPath(context);
                    CGContextAddPath(context, theLineCapPath);
                    if ( self.usesEvenOddClipRule ) {
                        CGContextEOClip(context);
                    }
                    else {
                        CGContextClip(context);
                    }
                }
                [theFill fillRect:bounds inContext:context];
                CGContextRestoreGState(context);
            }

            if ( theLineStyle ) {
                [theLineStyle setLineStyleInContext:context];
                CGContextBeginPath(context);
                CGContextAddPath(context, theLineCapPath);
                [theLineStyle strokePathInContext:context];
            }

            CGContextRestoreGState(context);
        }
    }
}

#pragma mark -
#pragma mark Private methods

/// @cond

/** @internal
 *  @brief Creates and returns a drawing path for the current line cap type.
 *  The path is standardized for a line direction of @quote{up}.
 *  @return A path describing the outline of the current line cap type.
 **/
-(nonnull CGPathRef)newLineCapPath
{
    CGFloat dx, dy;
    CGSize lineCapSize = self.size;
    CGSize halfSize    = CPTSizeMake(lineCapSize.width / CPTFloat(2.0), lineCapSize.height / CPTFloat(2.0));

    CGMutablePathRef lineCapPath = CGPathCreateMutable();

    switch ( self.lineCapType ) {
        case CPTLineCapTypeNone:
            // empty path
            break;

        case CPTLineCapTypeOpenArrow:
            CGPathMoveToPoint(lineCapPath, NULL, -halfSize.width, -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), CPTFloat(0.0));
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width, -halfSize.height);
            break;

        case CPTLineCapTypeSolidArrow:
            CGPathMoveToPoint(lineCapPath, NULL, -halfSize.width, -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), CPTFloat(0.0));
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width, -halfSize.height);
            CGPathCloseSubpath(lineCapPath);
            break;

        case CPTLineCapTypeSweptArrow:
            CGPathMoveToPoint(lineCapPath, NULL, -halfSize.width, -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), CPTFloat(0.0));
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width, -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), -lineCapSize.height * CPTFloat(0.375));
            CGPathCloseSubpath(lineCapPath);
            break;

        case CPTLineCapTypeRectangle:
            CGPathAddRect(lineCapPath, NULL, CPTRectMake(-halfSize.width, -halfSize.height, halfSize.width * CPTFloat(2.0), halfSize.height * CPTFloat(2.0)));
            break;

        case CPTLineCapTypeEllipse:
            CGPathAddEllipseInRect(lineCapPath, NULL, CPTRectMake(-halfSize.width, -halfSize.height, halfSize.width * CPTFloat(2.0), halfSize.height * CPTFloat(2.0)));
            break;

        case CPTLineCapTypeDiamond:
            CGPathMoveToPoint(lineCapPath, NULL, CPTFloat(0.0), halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width, CPTFloat(0.0));
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, -halfSize.width, CPTFloat(0.0));
            CGPathCloseSubpath(lineCapPath);
            break;

        case CPTLineCapTypePentagon:
            CGPathMoveToPoint(lineCapPath, NULL, CPTFloat(0.0), halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width * CPTFloat(0.95105651630), halfSize.height * CPTFloat(0.30901699437));
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width * CPTFloat(0.58778525229), -halfSize.height * CPTFloat(0.80901699437));
            CGPathAddLineToPoint(lineCapPath, NULL, -halfSize.width * CPTFloat(0.58778525229), -halfSize.height * CPTFloat(0.80901699437));
            CGPathAddLineToPoint(lineCapPath, NULL, -halfSize.width * CPTFloat(0.95105651630), halfSize.height * CPTFloat(0.30901699437));
            CGPathCloseSubpath(lineCapPath);
            break;

        case CPTLineCapTypeHexagon:
            dx = halfSize.width * CPTFloat(0.86602540378); // sqrt(3.0) / 2.0;
            dy = halfSize.height / CPTFloat(2.0);

            CGPathMoveToPoint(lineCapPath, NULL, CPTFloat(0.0), halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, dx, dy);
            CGPathAddLineToPoint(lineCapPath, NULL, dx, -dy);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), -halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, -dx, -dy);
            CGPathAddLineToPoint(lineCapPath, NULL, -dx, dy);
            CGPathCloseSubpath(lineCapPath);
            break;

        case CPTLineCapTypeBar:
            CGPathMoveToPoint(lineCapPath, NULL, halfSize.width, CPTFloat(0.0));
            CGPathAddLineToPoint(lineCapPath, NULL, -halfSize.width, CPTFloat(0.0));
            break;

        case CPTLineCapTypeCross:
            CGPathMoveToPoint(lineCapPath, NULL, -halfSize.width, halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, halfSize.width, -halfSize.height);
            CGPathMoveToPoint(lineCapPath, NULL, halfSize.width, halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, -halfSize.width, -halfSize.height);
            break;

        case CPTLineCapTypeSnow:
            dx = halfSize.width * CPTFloat(0.86602540378); // sqrt(3.0) / 2.0;
            dy = halfSize.height / CPTFloat(2.0);

            CGPathMoveToPoint(lineCapPath, NULL, CPTFloat(0.0), halfSize.height);
            CGPathAddLineToPoint(lineCapPath, NULL, CPTFloat(0.0), -halfSize.height);
            CGPathMoveToPoint(lineCapPath, NULL, dx, -dy);
            CGPathAddLineToPoint(lineCapPath, NULL, -dx, dy);
            CGPathMoveToPoint(lineCapPath, NULL, -dx, -dy);
            CGPathAddLineToPoint(lineCapPath, NULL, dx, dy);
            break;

        case CPTLineCapTypeCustom:
        {
            CGPathRef customPath = self.customLineCapPath;
            if ( customPath ) {
                CGRect oldBounds = CGPathGetBoundingBox(customPath);
                CGFloat dx1      = lineCapSize.width / oldBounds.size.width;
                CGFloat dy1      = lineCapSize.height / oldBounds.size.height;

                CGAffineTransform scaleTransform = CGAffineTransformScale(CGAffineTransformIdentity, dx1, dy1);
                scaleTransform = CGAffineTransformConcat(scaleTransform,
                                                         CGAffineTransformMakeTranslation(-halfSize.width, -halfSize.height));
                CGPathAddPath(lineCapPath, &scaleTransform, customPath);
            }
        }
        break;
    }
    return lineCapPath;
}

/// @endcond

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    const CGSize symbolSize   = self.size;
    const CGSize halfSize     = CPTSizeMake(symbolSize.width * CPTFloat(0.5), symbolSize.height * CPTFloat(0.5));
    const CGRect rect         = CGRectMake(-halfSize.width, -halfSize.height, symbolSize.width, symbolSize.height);
    const CGPoint centerPoint = CGPointMake(halfSize.width, halfSize.height);

    return CPTQuickLookImage(rect, ^(CGContextRef context, CGFloat __unused scale, CGRect bounds __unused) {
        [self renderAsVectorInContext:context atPoint:centerPoint inDirection:CGPointMake(1.0, 0.0)];
    });
}

/// @endcond

@end
