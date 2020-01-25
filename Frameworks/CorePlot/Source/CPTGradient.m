#import "CPTGradient.h"

#import "CPTColor.h"
#import "CPTColorSpace.h"
#import "CPTPlatformSpecificFunctions.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"
#import <tgmath.h>

/// @cond
@interface CPTGradient()

@property (nonatomic, readwrite, strong, nonnull) CPTColorSpace *colorspace;
@property (nonatomic, readwrite, assign) CPTGradientBlendingMode blendingMode;
@property (nonatomic, readwrite, assign) CPTGradientElement *elementList;
@property (nonatomic, readwrite, assign, nonnull) CGFunctionRef gradientFunction;

-(void)commonInit;
-(void)addElement:(nonnull CPTGradientElement *)newElement;

-(nonnull CGShadingRef)newAxialGradientInRect:(CGRect)rect;
-(nonnull CGShadingRef)newRadialGradientInRect:(CGRect)rect context:(nonnull CGContextRef)context;

-(nullable CPTGradientElement *)elementAtIndex:(NSUInteger)idx NS_RETURNS_INNER_POINTER;
-(NSUInteger)elementCount;

-(CPTGradientElement)removeElementAtIndex:(NSUInteger)idx;
-(CPTGradientElement)removeElementAtPosition:(CGFloat)position;
-(void)removeAllElements;

@end

// C Functions for color blending
static void CPTLinearEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out);
static void CPTChromaticEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out);
static void CPTInverseChromaticEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out);
static void CPTTransformRGB_HSV(CGFloat *__nonnull components);
static void CPTTransformHSV_RGB(CGFloat *__nonnull components);
static void CPTResolveHSV(CGFloat *__nonnull color1, CGFloat *__nonnull color2);

/// @endcond

#pragma mark -

/** @brief Draws color gradient fills.
 *
 *  Gradients consist of multiple colors blended smoothly from one to the next at
 *  specified positions using one of three blending modes. The color positions are
 *  defined in a range between zero (@num{0}) and one (@num{1}). Axial gradients are drawn with
 *  color positions increasing from left to right when the angle property is zero (@num{0}).
 *  Radial gradients are drawn centered in the provided drawing region with position zero (@num{0})
 *  in the center and one (@num{1}) at the outer edge.
 *
 *  @note Based on @par{CTGradient} (http://blog.oofn.net/2006/01/15/gradients-in-cocoa/).
 *  @par{CTGradient} is in the public domain (Thanks Chad Weider!).
 **/
@implementation CPTGradient

/// @cond

/** @property nonnull CPTColorSpace *colorspace;
 *  @brief The colorspace for the gradient colors.
 **/
@synthesize colorspace;

/// @endcond

/** @property CPTGradientBlendingMode blendingMode
 *  @brief The color blending mode used to create the gradient.
 **/
@synthesize blendingMode;

/** @property CGFloat angle
 *  @brief The axis angle of an axial gradient, expressed in degrees and measured counterclockwise from the positive x-axis.
 **/
@synthesize angle;

/** @property CPTGradientType gradientType
 *  @brief The gradient type.
 **/
@synthesize gradientType;

/** @property CGPoint startAnchor
 *  @brief The anchor point for starting point of a radial gradient. Defaults to (@num{0.5}, @num{0.5}) which centers the gradient on the drawing rectangle.
 **/
@synthesize startAnchor;

/** @property CGPoint endAnchor
 *  @brief The anchor point for ending point of a radial gradient. Defaults to (@num{0.5}, @num{0.5}) which centers the gradient on the drawing rectangle.
 **/
@synthesize endAnchor;

/** @property BOOL opaque
 *  @brief If @YES, the gradient is completely opaque.
 */
@dynamic opaque;

@synthesize elementList;
@synthesize gradientFunction;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTGradient object.
 *
 *  The initialized object will have the following properties:
 *  - @ref blendingMode = #CPTLinearBlendingMode
 *  - @ref angle = @num{0.0}
 *  - @ref gradientType = #CPTGradientTypeAxial
 *  - @ref startAnchor = (@num{0.5}, @num{0.5})
 *  - @ref endAnchor = (@num{0.5}, @num{0.5})
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        [self commonInit];

        self.blendingMode = CPTLinearBlendingMode;

        angle        = CPTFloat(0.0);
        gradientType = CPTGradientTypeAxial;
        startAnchor  = CPTPointMake(0.5, 0.5);
        endAnchor    = CPTPointMake(0.5, 0.5);
    }
    return self;
}

/// @}

/// @cond

-(void)commonInit
{
    self.colorspace  = [CPTColorSpace genericRGBSpace];
    self.elementList = NULL;
}

-(void)dealloc
{
    CGFunctionRelease(gradientFunction);
    [self removeAllElements];
}

/// @endcond

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    CPTGradient *copy = [[[self class] allocWithZone:zone] init];

    CPTGradientElement *currentElement = self.elementList;

    while ( currentElement != NULL ) {
        [copy addElement:currentElement];
        currentElement = currentElement->nextElement;
    }

    copy.blendingMode = self.blendingMode;
    copy.angle        = self.angle;
    copy.gradientType = self.gradientType;
    copy.startAnchor  = self.startAnchor;
    copy.endAnchor    = self.endAnchor;

    return copy;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    NSUInteger count = 0;

    CPTGradientElement *currentElement = self.elementList;

    while ( currentElement != NULL ) {
        [coder encodeCGFloat:currentElement->color.red forKey:[NSString stringWithFormat:@"red%lu", (unsigned long)count]];
        [coder encodeCGFloat:currentElement->color.green forKey:[NSString stringWithFormat:@"green%lu", (unsigned long)count]];
        [coder encodeCGFloat:currentElement->color.blue forKey:[NSString stringWithFormat:@"blue%lu", (unsigned long)count]];
        [coder encodeCGFloat:currentElement->color.alpha forKey:[NSString stringWithFormat:@"alpha%lu", (unsigned long)count]];
        [coder encodeCGFloat:currentElement->position forKey:[NSString stringWithFormat:@"position%lu", (unsigned long)count]];

        count++;
        currentElement = currentElement->nextElement;
    }

    [coder encodeInteger:(NSInteger)count forKey:@"CPTGradient.elementCount"];
    [coder encodeInteger:self.blendingMode forKey:@"CPTGradient.blendingMode"];
    [coder encodeCGFloat:self.angle forKey:@"CPTGradient.angle"];
    [coder encodeInteger:self.gradientType forKey:@"CPTGradient.type"];
    [coder encodeCPTPoint:self.startAnchor forKey:@"CPTPlotSymbol.startAnchor"];
    [coder encodeCPTPoint:self.endAnchor forKey:@"CPTPlotSymbol.endAnchor"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        [self commonInit];

        gradientType      = (CPTGradientType)[coder decodeIntegerForKey:@"CPTGradient.type"];
        angle             = [coder decodeCGFloatForKey:@"CPTGradient.angle"];
        self.blendingMode = (CPTGradientBlendingMode)[coder decodeIntegerForKey:@"CPTGradient.blendingMode"];
        startAnchor       = [coder decodeCPTPointForKey:@"CPTPlotSymbol.startAnchor"];
        endAnchor         = [coder decodeCPTPointForKey:@"CPTPlotSymbol.endAnchor"];

        NSUInteger count = (NSUInteger)[coder decodeIntegerForKey:@"CPTGradient.elementCount"];

        for ( NSUInteger i = 0; i < count; i++ ) {
            CPTGradientElement newElement;

            newElement.color.red   = [coder decodeCGFloatForKey:[NSString stringWithFormat:@"red%lu", (unsigned long)i]];
            newElement.color.green = [coder decodeCGFloatForKey:[NSString stringWithFormat:@"green%lu", (unsigned long)i]];
            newElement.color.blue  = [coder decodeCGFloatForKey:[NSString stringWithFormat:@"blue%lu", (unsigned long)i]];
            newElement.color.alpha = [coder decodeCGFloatForKey:[NSString stringWithFormat:@"alpha%lu", (unsigned long)i]];
            newElement.position    = [coder decodeCGFloatForKey:[NSString stringWithFormat:@"position%lu", (unsigned long)i]];

            [self addElement:&newElement];
        }
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
#pragma mark Factory Methods

/** @brief Creates and returns a new CPTGradient instance initialized with an axial linear gradient between two given colors.
 *  @param begin The beginning color.
 *  @param end The ending color.
 *  @return A new CPTGradient instance initialized with an axial linear gradient between the two given colors.
 **/
+(nonnull instancetype)gradientWithBeginningColor:(nonnull CPTColor *)begin endingColor:(nonnull CPTColor *)end
{
    return [self gradientWithBeginningColor:begin endingColor:end beginningPosition:CPTFloat(0.0) endingPosition:CPTFloat(1.0)];
}

/** @brief Creates and returns a new CPTGradient instance initialized with an axial linear gradient between two given colors, at two given normalized positions.
 *  @param begin The beginning color.
 *  @param end The ending color.
 *  @param beginningPosition The beginning position (@num{0} ≤ @par{beginningPosition} ≤ @num{1}).
 *  @param endingPosition The ending position (@num{0} ≤ @par{endingPosition} ≤ @num{1}).
 *  @return A new CPTGradient instance initialized with an axial linear gradient between the two given colors, at two given normalized positions.
 **/
+(nonnull instancetype)gradientWithBeginningColor:(nonnull CPTColor *)begin endingColor:(nonnull CPTColor *)end beginningPosition:(CGFloat)beginningPosition endingPosition:(CGFloat)endingPosition
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;
    CPTGradientElement color2;

    color1.color = CPTRGBAColorFromCGColor(begin.cgColor);
    color2.color = CPTRGBAColorFromCGColor(end.cgColor);

    color1.position = beginningPosition;
    color2.position = endingPosition;

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the Aqua selected gradient.
 *  @return A new CPTGradient instance initialized with the Aqua selected gradient.
 **/
+(nonnull instancetype)aquaSelectedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = CPTFloat(0.58);
    color1.color.green = CPTFloat(0.86);
    color1.color.blue  = CPTFloat(0.98);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = CPTFloat(0.42);
    color2.color.green = CPTFloat(0.68);
    color2.color.blue  = CPTFloat(0.90);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(0.5);

    CPTGradientElement color3;
    color3.color.red   = CPTFloat(0.64);
    color3.color.green = CPTFloat(0.80);
    color3.color.blue  = CPTFloat(0.94);
    color3.color.alpha = CPTFloat(1.00);
    color3.position    = CPTFloat(0.5);

    CPTGradientElement color4;
    color4.color.red   = CPTFloat(0.56);
    color4.color.green = CPTFloat(0.70);
    color4.color.blue  = CPTFloat(0.90);
    color4.color.alpha = CPTFloat(1.00);
    color4.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];
    [newInstance addElement:&color3];
    [newInstance addElement:&color4];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the Aqua normal gradient.
 *  @return A new CPTGradient instance initialized with the Aqua normal gradient.
 **/
+(nonnull instancetype)aquaNormalGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.95);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.83);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(0.5);

    CPTGradientElement color3;
    color3.color.red   = color3.color.green = color3.color.blue = CPTFloat(0.95);
    color3.color.alpha = CPTFloat(1.00);
    color3.position    = CPTFloat(0.5);

    CPTGradientElement color4;
    color4.color.red   = color4.color.green = color4.color.blue = CPTFloat(0.92);
    color4.color.alpha = CPTFloat(1.00);
    color4.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];
    [newInstance addElement:&color3];
    [newInstance addElement:&color4];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the Aqua pressed gradient.
 *  @return A new CPTGradient instance initialized with the Aqua pressed gradient.
 **/
+(nonnull instancetype)aquaPressedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.80);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.64);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(0.5);

    CPTGradientElement color3;
    color3.color.red   = color3.color.green = color3.color.blue = CPTFloat(0.80);
    color3.color.alpha = CPTFloat(1.00);
    color3.position    = CPTFloat(0.5);

    CPTGradientElement color4;
    color4.color.red   = color4.color.green = color4.color.blue = CPTFloat(0.77);
    color4.color.alpha = CPTFloat(1.00);
    color4.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];
    [newInstance addElement:&color3];
    [newInstance addElement:&color4];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the unified selected gradient.
 *  @return A new CPTGradient instance initialized with the unified selected gradient.
 **/
+(nonnull instancetype)unifiedSelectedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.85);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.95);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the unified normal gradient.
 *  @return A new CPTGradient instance initialized with the unified normal gradient.
 **/
+(nonnull instancetype)unifiedNormalGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.75);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.90);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the unified pressed gradient.
 *  @return A new CPTGradient instance initialized with the unified pressed gradient.
 **/
+(nonnull instancetype)unifiedPressedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.60);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.75);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the unified dark gradient.
 *  @return A new CPTGradient instance initialized with the unified dark gradient.
 **/
+(nonnull instancetype)unifiedDarkGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = color1.color.green = color1.color.blue = CPTFloat(0.68);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = color2.color.green = color2.color.blue = CPTFloat(0.83);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the source list selected gradient.
 *  @return A new CPTGradient instance initialized with the source list selected gradient.
 **/
+(nonnull instancetype)sourceListSelectedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = CPTFloat(0.06);
    color1.color.green = CPTFloat(0.37);
    color1.color.blue  = CPTFloat(0.85);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = CPTFloat(0.30);
    color2.color.green = CPTFloat(0.60);
    color2.color.blue  = CPTFloat(0.92);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with the source list unselected gradient.
 *  @return A new CPTGradient instance initialized with the source list unselected gradient.
 **/
+(nonnull instancetype)sourceListUnselectedGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = CPTFloat(0.43);
    color1.color.green = CPTFloat(0.43);
    color1.color.blue  = CPTFloat(0.43);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = CPTFloat(0.60);
    color2.color.green = CPTFloat(0.60);
    color2.color.blue  = CPTFloat(0.60);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with a rainbow gradient.
 *  @return A new CPTGradient instance initialized with a rainbow gradient.
 **/
+(nonnull instancetype)rainbowGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    CPTGradientElement color1;

    color1.color.red   = CPTFloat(1.00);
    color1.color.green = CPTFloat(0.00);
    color1.color.blue  = CPTFloat(0.00);
    color1.color.alpha = CPTFloat(1.00);
    color1.position    = CPTFloat(0.0);

    CPTGradientElement color2;
    color2.color.red   = CPTFloat(0.54);
    color2.color.green = CPTFloat(0.00);
    color2.color.blue  = CPTFloat(1.00);
    color2.color.alpha = CPTFloat(1.00);
    color2.position    = CPTFloat(1.0);

    [newInstance addElement:&color1];
    [newInstance addElement:&color2];

    newInstance.blendingMode = CPTChromaticBlendingMode;

    return newInstance;
}

/** @brief Creates and returns a new CPTGradient instance initialized with a hydrogen spectrum gradient.
 *  @return A new CPTGradient instance initialized with a hydrogen spectrum gradient.
 **/
+(nonnull instancetype)hydrogenSpectrumGradient
{
    CPTGradient *newInstance = [[self alloc] init];

    struct {
        CGFloat hue;
        CGFloat position;
        CGFloat width;
    }
    colorBands[4];

    colorBands[0].hue      = CPTFloat(22);
    colorBands[0].position = CPTFloat(0.145);
    colorBands[0].width    = CPTFloat(0.01);

    colorBands[1].hue      = CPTFloat(200);
    colorBands[1].position = CPTFloat(0.71);
    colorBands[1].width    = CPTFloat(0.008);

    colorBands[2].hue      = CPTFloat(253);
    colorBands[2].position = CPTFloat(0.885);
    colorBands[2].width    = CPTFloat(0.005);

    colorBands[3].hue      = CPTFloat(275);
    colorBands[3].position = CPTFloat(0.965);
    colorBands[3].width    = CPTFloat(0.003);

    for ( NSUInteger i = 0; i < 4; i++ ) {
        CGFloat color[4];
        color[0] = colorBands[i].hue - CPTFloat(180.0) * colorBands[i].width;
        color[1] = CPTFloat(1.0);
        color[2] = CPTFloat(0.001);
        color[3] = CPTFloat(1.0);
        CPTTransformHSV_RGB(color);

        CPTGradientElement fadeIn;
        fadeIn.color.red   = color[0];
        fadeIn.color.green = color[1];
        fadeIn.color.blue  = color[2];
        fadeIn.color.alpha = color[3];
        fadeIn.position    = colorBands[i].position - colorBands[i].width;

        color[0] = colorBands[i].hue;
        color[1] = CPTFloat(1.0);
        color[2] = CPTFloat(1.0);
        color[3] = CPTFloat(1.0);
        CPTTransformHSV_RGB(color);

        CPTGradientElement band;
        band.color.red   = color[0];
        band.color.green = color[1];
        band.color.blue  = color[2];
        band.color.alpha = color[3];
        band.position    = colorBands[i].position;

        color[0] = colorBands[i].hue + CPTFloat(180.0) * colorBands[i].width;
        color[1] = CPTFloat(1.0);
        color[2] = CPTFloat(0.001);
        color[3] = CPTFloat(1.0);
        CPTTransformHSV_RGB(color);

        CPTGradientElement fadeOut;
        fadeOut.color.red   = color[0];
        fadeOut.color.green = color[1];
        fadeOut.color.blue  = color[2];
        fadeOut.color.alpha = color[3];
        fadeOut.position    = colorBands[i].position + colorBands[i].width;

        [newInstance addElement:&fadeIn];
        [newInstance addElement:&band];
        [newInstance addElement:&fadeOut];
    }

    newInstance.blendingMode = CPTChromaticBlendingMode;

    return newInstance;
}

#pragma mark -
#pragma mark Modification

/** @brief Copies the current gradient and sets a new alpha value.
 *  @param alpha The alpha component (@num{0} ≤ @par{alpha} ≤ @num{1}).
 *  @return A copy of the current gradient with the new alpha value.
 **/
-(CPTGradient *)gradientWithAlphaComponent:(CGFloat)alpha
{
    CPTGradient *newGradient = [[[self class] alloc] init];

    CPTGradientElement *curElement = self.elementList;
    CPTGradientElement tempElement;

    while ( curElement != NULL ) {
        tempElement             = *curElement;
        tempElement.color.alpha = alpha;
        [newGradient addElement:&tempElement];

        curElement = curElement->nextElement;
    }

    newGradient.blendingMode = self.blendingMode;
    newGradient.angle        = self.angle;
    newGradient.gradientType = self.gradientType;

    return newGradient;
}

/** @brief Copies the current gradient and sets a new blending mode.
 *  @param mode The blending mode.
 *  @return A copy of the current gradient with the new blending mode.
 **/
-(CPTGradient *)gradientWithBlendingMode:(CPTGradientBlendingMode)mode
{
    CPTGradient *newGradient = [self copy];

    newGradient.blendingMode = mode;
    return newGradient;
}

/** @brief Copies the current gradient and adds a color stop.
 *
 *  Adds a color stop with @par{color} at @par{position} in the list of color stops.
 *  If two elements are at the same position then it is added immediately after the one that was there already.
 *
 *  @param color The color.
 *  @param position The color stop position (@num{0} ≤ @par{position} ≤ @num{1}).
 *  @return A copy of the current gradient with the new color stop.
 **/
-(CPTGradient *)addColorStop:(nonnull CPTColor *)color atPosition:(CGFloat)position
{
    CPTGradient *newGradient = [self copy];
    CPTGradientElement newGradientElement;

    // put the components of color into the newGradientElement - must make sure it is a RGB color (not Gray or CMYK)
    newGradientElement.color    = CPTRGBAColorFromCGColor(color.cgColor);
    newGradientElement.position = position;

    // Pass it off to addElement to take care of adding it to the elementList
    [newGradient addElement:&newGradientElement];

    return newGradient;
}

/** @brief Copies the current gradient and removes the color stop at @par{position} from the list of color stops.
 *  @param position The color stop position (@num{0} ≤ @par{position} ≤ @num{1}).
 *  @return A copy of the current gradient with the color stop removed.
 **/
-(CPTGradient *)removeColorStopAtPosition:(CGFloat)position
{
    CPTGradient *newGradient          = [self copy];
    CPTGradientElement removedElement = [newGradient removeElementAtPosition:position];

    if ( isnan(removedElement.position)) {
        [NSException raise:NSRangeException format:@"-[%@ removeColorStopAtPosition:]: no such colorStop at position (%g)", [self class], (double)position];
    }

    return newGradient;
}

/** @brief Copies the current gradient and removes the color stop at @par{idx} from the list of color stops.
 *  @param idx The color stop index.
 *  @return A copy of the current gradient with the color stop removed.
 **/
-(CPTGradient *)removeColorStopAtIndex:(NSUInteger)idx
{
    CPTGradient *newGradient          = [self copy];
    CPTGradientElement removedElement = [newGradient removeElementAtIndex:idx];

    if ( isnan(removedElement.position)) {
        [NSException raise:NSRangeException format:@"-[%@ removeColorStopAtIndex:]: index (%lu) beyond bounds", [self class], (unsigned long)idx];
    }

    return newGradient;
}

#pragma mark -
#pragma mark Information

/** @brief Gets the color at color stop @par{idx} from the list of color stops.
 *  @param idx The color stop index.
 *  @return The color at color stop @par{idx}.
 **/
-(CGColorRef)newColorStopAtIndex:(NSUInteger)idx
{
    CPTGradientElement *element = [self elementAtIndex:idx];

    if ( element != NULL ) {
#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        CGFloat colorComponents[4] = { element->color.red, element->color.green, element->color.blue, element->color.alpha };
        return CGColorCreate(self.colorspace.cgColorSpace, colorComponents);
#else
        return CGColorCreateGenericRGB(element->color.red, element->color.green, element->color.blue, element->color.alpha);
#endif
    }

    [NSException raise:NSRangeException format:@"-[%@ colorStopAtIndex:]: index (%lu) beyond bounds", [self class], (unsigned long)idx];

    return NULL;
}

/** @brief Gets the color at an arbitrary position in the gradient.
 *  @param position The color stop position (@num{0} ≤ @par{position} ≤ @num{1}).
 *  @return The  color at @par{position} in gradient.
 **/
-(CGColorRef)newColorAtPosition:(CGFloat)position
{
    CGFloat components[4] = { CPTFloat(0.0), CPTFloat(0.0), CPTFloat(0.0), CPTFloat(0.0) };
    CGColorRef gradientColor;

    switch ( self.blendingMode ) {
        case CPTLinearBlendingMode:
            CPTLinearEvaluation((__bridge void *)(self), &position, components);
            break;

        case CPTChromaticBlendingMode:
            CPTChromaticEvaluation((__bridge void *)(self), &position, components);
            break;

        case CPTInverseChromaticBlendingMode:
            CPTInverseChromaticEvaluation((__bridge void *)(self), &position, components);
            break;
    }

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
    CGFloat colorComponents[4] = { components[0], components[1], components[2], components[3] };
    gradientColor = CGColorCreate(self.colorspace.cgColorSpace, colorComponents);
#else
    gradientColor = CGColorCreateGenericRGB(components[0], components[1], components[2], components[3]);
#endif

    return gradientColor;
}

#pragma mark -
#pragma mark Drawing

/** @brief Draws the gradient into the given graphics context inside the provided rectangle.
 *  @param rect The rectangle to draw into.
 *  @param context The graphics context to draw into.
 **/
-(void)drawSwatchInRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    [self fillRect:rect inContext:context];
}

/** @brief Draws the gradient into the given graphics context inside the provided rectangle.
 *  @param rect The rectangle to draw into.
 *  @param context The graphics context to draw into.
 **/
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    CGShadingRef myCGShading = NULL;

    CGContextSaveGState(context);

    CGContextClipToRect(context, rect);

    switch ( self.gradientType ) {
        case CPTGradientTypeAxial:
            myCGShading = [self newAxialGradientInRect:rect];
            break;

        case CPTGradientTypeRadial:
            myCGShading = [self newRadialGradientInRect:rect context:context];
            break;
    }

    CGContextDrawShading(context, myCGShading);

    CGShadingRelease(myCGShading);
    CGContextRestoreGState(context);
}

/** @brief Draws the gradient into the given graphics context clipped to the current drawing path.
 *  @param context The graphics context to draw into.
 **/
-(void)fillPathInContext:(nonnull CGContextRef)context
{
    if ( !CGContextIsPathEmpty(context)) {
        CGShadingRef myCGShading = NULL;

        CGContextSaveGState(context);

        CGRect bounds = CGContextGetPathBoundingBox(context);
        CGContextClip(context);

        switch ( self.gradientType ) {
            case CPTGradientTypeAxial:
                myCGShading = [self newAxialGradientInRect:bounds];
                break;

            case CPTGradientTypeRadial:
                myCGShading = [self newRadialGradientInRect:bounds context:context];
                break;
        }

        CGContextDrawShading(context, myCGShading);

        CGShadingRelease(myCGShading);
        CGContextRestoreGState(context);
    }
}

#pragma mark -
#pragma mark Opacity

/// @cond

-(BOOL)isOpaque
{
    BOOL opaqueGradient = YES;

    CPTGradientElement *list = self.elementList;

    while ( opaqueGradient && (list != NULL)) {
        opaqueGradient = opaqueGradient && (list->color.alpha >= CPTFloat(1.0));
        list           = list->nextElement;
    }

    return opaqueGradient;
}

/// @endcond

#pragma mark -
#pragma mark Gradient comparison

/// @name Comparison
/// @{

/** @brief Returns a boolean value that indicates whether the received is equal to the given object.
 *  Gradients are equal if they have the same @ref blendingMode, @ref angle, @ref gradientType, and gradient colors at the same positions.
 *  @param object The object to be compared with the receiver.
 *  @return @YES if @par{object} is equal to the receiver, @NO otherwise.
 **/
-(BOOL)isEqual:(nullable id)object
{
    if ( self == object ) {
        return YES;
    }
    else if ( [object isKindOfClass:[self class]] ) {
        CPTGradient *otherGradient = (CPTGradient *)object;

        BOOL equalGradients = (self.blendingMode == otherGradient.blendingMode) &&
                              (self.angle == otherGradient.angle) &&
                              (self.gradientType == otherGradient.gradientType);

        if ( equalGradients ) {
            equalGradients = ([self elementCount] == [otherGradient elementCount]);
        }

        if ( equalGradients ) {
            CPTGradientElement *selfCurrentElement  = self.elementList;
            CPTGradientElement *otherCurrentElement = otherGradient.elementList;

            while ( selfCurrentElement && otherCurrentElement ) {
                if ( selfCurrentElement->color.red != otherCurrentElement->color.red ) {
                    equalGradients = NO;
                    break;
                }
                if ( selfCurrentElement->color.green != otherCurrentElement->color.green ) {
                    equalGradients = NO;
                    break;
                }
                if ( selfCurrentElement->color.blue != otherCurrentElement->color.blue ) {
                    equalGradients = NO;
                    break;
                }
                if ( selfCurrentElement->color.alpha != otherCurrentElement->color.alpha ) {
                    equalGradients = NO;
                    break;
                }
                if ( selfCurrentElement->position != otherCurrentElement->position ) {
                    equalGradients = NO;
                    break;
                }

                selfCurrentElement  = selfCurrentElement->nextElement;
                otherCurrentElement = otherCurrentElement->nextElement;
            }
        }

        return equalGradients;
    }
    else {
        return NO;
    }
}

/// @}

/// @cond

-(NSUInteger)hash
{
    // Equal objects must hash the same.
    CGFloat theHash    = CPTFloat(0.0);
    CGFloat multiplier = CPTFloat(256.0);

    CPTGradientElement *curElement = self.elementList;

    if ( curElement ) {
        CPTRGBAColor color = curElement->color;

        theHash    += multiplier * color.red;
        multiplier *= CPTFloat(256.0);
        theHash    += multiplier * color.green;
        multiplier *= CPTFloat(256.0);
        theHash    += multiplier * color.blue;
        multiplier *= CPTFloat(256.0);
        theHash    += multiplier * color.alpha;

        return (NSUInteger)theHash;
    }
    else {
        return (NSUInteger)(self.blendingMode + self.gradientType);
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setGradientFunction:(nonnull CGFunctionRef)newGradientFunction
{
    if ( newGradientFunction != gradientFunction ) {
        CGFunctionRelease(gradientFunction);
        gradientFunction = newGradientFunction;
    }
}

/// @endcond

#pragma mark -
#pragma mark Private Methods

/// @cond

-(nonnull CGShadingRef)newAxialGradientInRect:(CGRect)rect
{
    // First Calculate where the beginning and ending points should be
    CGPoint startPoint, endPoint;

    if ( self.angle == CPTFloat(0.0)) {
        startPoint = CPTPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)); // right of rect
        endPoint   = CPTPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)); // left  of rect
    }
    else if ( self.angle == CPTFloat(90.0)) {
        startPoint = CPTPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)); // bottom of rect
        endPoint   = CPTPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)); // top    of rect
    }
    else { // ok, we'll do the calculations now
        CGFloat x, y;
        CGFloat sinA, cosA, tanA;

        CGFloat length;
        CGFloat deltaX, deltaY;

        CGFloat rAngle = self.angle * CPTFloat(M_PI / 180.0); // convert the angle to radians

        if ( fabs(tan(rAngle)) <= CPTFloat(1.0)) { // for range [-45,45], [135,225]
            x = CGRectGetWidth(rect);
            y = CGRectGetHeight(rect);

            sinA = sin(rAngle);
            cosA = cos(rAngle);
            tanA = tan(rAngle);

            length = x / fabs(cosA) + (y - x * fabs(tanA)) * fabs(sinA);

            deltaX = length * cosA / CPTFloat(2.0);
            deltaY = length * sinA / CPTFloat(2.0);
        }
        else { // for range [45,135], [225,315]
            x = CGRectGetHeight(rect);
            y = CGRectGetWidth(rect);

            rAngle -= CPTFloat(M_PI_2);

            sinA = sin(rAngle);
            cosA = cos(rAngle);
            tanA = tan(rAngle);

            length = x / fabs(cosA) + (y - x * fabs(tanA)) * fabs(sinA);

            deltaX = -length * sinA / CPTFloat(2.0);
            deltaY = length * cosA / CPTFloat(2.0);
        }

        startPoint = CPTPointMake(CGRectGetMidX(rect) - deltaX, CGRectGetMidY(rect) - deltaY);
        endPoint   = CPTPointMake(CGRectGetMidX(rect) + deltaX, CGRectGetMidY(rect) + deltaY);
    }

    CGShadingRef myCGShading = CGShadingCreateAxial(self.colorspace.cgColorSpace, startPoint, endPoint, self.gradientFunction, false, false);

    return myCGShading;
}

-(nonnull CGShadingRef)newRadialGradientInRect:(CGRect)rect context:(nonnull CGContextRef)context
{
    CGPoint startPoint, endPoint;
    CGFloat startRadius, endRadius;
    CGFloat scaleX, scaleY;

    CGPoint theStartAnchor = self.startAnchor;

    startPoint = CPTPointMake(fma(CGRectGetWidth(rect), theStartAnchor.x, CGRectGetMinX(rect)),
                              fma(CGRectGetHeight(rect), theStartAnchor.y, CGRectGetMinY(rect)));

    CGPoint theEndAnchor = self.endAnchor;
    endPoint = CPTPointMake(fma(CGRectGetWidth(rect), theEndAnchor.x, CGRectGetMinX(rect)),
                            fma(CGRectGetHeight(rect), theEndAnchor.y, CGRectGetMinY(rect)));

    startRadius = CPTFloat(-1.0);
    if ( CGRectGetHeight(rect) > CGRectGetWidth(rect)) {
        scaleX        = CGRectGetWidth(rect) / CGRectGetHeight(rect);
        startPoint.x /= scaleX;
        endPoint.x   /= scaleX;
        scaleY        = CPTFloat(1.0);
        endRadius     = CGRectGetHeight(rect) / CPTFloat(2.0);
    }
    else {
        scaleX        = CPTFloat(1.0);
        scaleY        = CGRectGetHeight(rect) / CGRectGetWidth(rect);
        startPoint.y /= scaleY;
        endPoint.y   /= scaleY;
        endRadius     = CGRectGetWidth(rect) / CPTFloat(2.0);
    }

    CGContextScaleCTM(context, scaleX, scaleY);

    CGShadingRef myCGShading = CGShadingCreateRadial(self.colorspace.cgColorSpace, startPoint, startRadius, endPoint, endRadius, self.gradientFunction, true, true);

    return myCGShading;
}

-(void)setBlendingMode:(CPTGradientBlendingMode)mode
{
    blendingMode = mode;

    // Choose what blending function to use
    CGFunctionEvaluateCallback evaluationFunction = NULL;
    switch ( blendingMode ) {
        case CPTLinearBlendingMode:
            evaluationFunction = &CPTLinearEvaluation;
            break;

        case CPTChromaticBlendingMode:
            evaluationFunction = &CPTChromaticEvaluation;
            break;

        case CPTInverseChromaticBlendingMode:
            evaluationFunction = &CPTInverseChromaticEvaluation;
            break;
    }

    CGFunctionCallbacks evaluationCallbackInfo = { 0, evaluationFunction, NULL }; // Version, evaluator function, cleanup function

    static const CGFloat input_value_range[2]   = { 0, 1 };                   // range  for the evaluator input
    static const CGFloat output_value_ranges[8] = { 0, 1, 0, 1, 0, 1, 0, 1 }; // ranges for the evaluator output (4 returned values)

    CGFunctionRef cgFunction = CGFunctionCreate((__bridge void *)(self),  // the two transition colors
                                                1, input_value_range,     // number of inputs (just fraction of progression)
                                                4, output_value_ranges,   // number of outputs (4 - RGBa)
                                                &evaluationCallbackInfo); // info for using the evaluator function

    if ( cgFunction ) {
        self.gradientFunction = cgFunction;
    }
}

-(void)addElement:(nonnull CPTGradientElement *)newElement
{
    CPTGradientElement *curElement = self.elementList;

    if ((curElement == NULL) || (newElement->position < curElement->position)) {
        CPTGradientElement *tmpNext        = curElement;
        CPTGradientElement *newElementList = calloc(1, sizeof(CPTGradientElement));
        if ( newElementList ) {
            *newElementList             = *newElement;
            newElementList->nextElement = tmpNext;
            self.elementList            = newElementList;
        }
    }
    else {
        while ( curElement->nextElement != NULL &&
                !((curElement->position <= newElement->position) &&
                  (newElement->position < curElement->nextElement->position))) {
            curElement = curElement->nextElement;
        }

        CPTGradientElement *tmpNext = curElement->nextElement;
        curElement->nextElement              = calloc(1, sizeof(CPTGradientElement));
        *(curElement->nextElement)           = *newElement;
        curElement->nextElement->nextElement = tmpNext;
    }
}

-(CPTGradientElement)removeElementAtIndex:(NSUInteger)idx
{
    CPTGradientElement removedElement;

    if ( self.elementList != NULL ) {
        if ( idx == 0 ) {
            CPTGradientElement *tmpNext = self.elementList;
            self.elementList = tmpNext->nextElement;

            removedElement = *tmpNext;
            free(tmpNext);

            return removedElement;
        }

        NSUInteger count                   = 1; // we want to start one ahead
        CPTGradientElement *currentElement = self.elementList;
        while ( currentElement->nextElement != NULL ) {
            if ( count == idx ) {
                CPTGradientElement *tmpNext = currentElement->nextElement;
                currentElement->nextElement = currentElement->nextElement->nextElement;

                removedElement = *tmpNext;
                free(tmpNext);

                return removedElement;
            }

            count++;
            currentElement = currentElement->nextElement;
        }
    }

    // element is not found, return empty element
    removedElement.color.red   = CPTFloat(0.0);
    removedElement.color.green = CPTFloat(0.0);
    removedElement.color.blue  = CPTFloat(0.0);
    removedElement.color.alpha = CPTFloat(0.0);
    removedElement.position    = CPTNAN;
    removedElement.nextElement = NULL;

    return removedElement;
}

-(CPTGradientElement)removeElementAtPosition:(CGFloat)position
{
    CPTGradientElement removedElement;
    CPTGradientElement *curElement = self.elementList;

    if ( curElement != NULL ) {
        if ( curElement->position == position ) {
            CPTGradientElement *tmpNext = self.elementList;
            self.elementList = curElement->nextElement;

            removedElement = *tmpNext;
            free(tmpNext);

            return removedElement;
        }
        else {
            while ( curElement->nextElement != NULL ) {
                if ( curElement->nextElement->position == position ) {
                    CPTGradientElement *tmpNext = curElement->nextElement;
                    curElement->nextElement = curElement->nextElement->nextElement;

                    removedElement = *tmpNext;
                    free(tmpNext);

                    return removedElement;
                }
            }
        }
    }

    // element is not found, return empty element
    removedElement.color.red   = CPTFloat(0.0);
    removedElement.color.green = CPTFloat(0.0);
    removedElement.color.blue  = CPTFloat(0.0);
    removedElement.color.alpha = CPTFloat(0.0);
    removedElement.position    = CPTNAN;
    removedElement.nextElement = NULL;

    return removedElement;
}

-(void)removeAllElements
{
    CPTGradientElement *element = self.elementList;

    while ( element != NULL ) {
        CPTGradientElement *elementToRemove = element;
        element = element->nextElement;
        free(elementToRemove);
    }

    self.elementList = NULL;
}

-(nullable CPTGradientElement *)elementAtIndex:(NSUInteger)idx
{
    NSUInteger count                   = 0;
    CPTGradientElement *currentElement = self.elementList;

    while ( currentElement != NULL ) {
        if ( count == idx ) {
            return currentElement;
        }

        count++;
        currentElement = currentElement->nextElement;
    }

    return NULL;
}

-(NSUInteger)elementCount
{
    NSUInteger count                   = 0;
    CPTGradientElement *currentElement = self.elementList;

    while ( currentElement ) {
        count++;
        currentElement = currentElement->nextElement;
    }

    return count;
}

/// @endcond

#pragma mark -
#pragma mark Core Graphics

/// @cond

void CPTLinearEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out)
{
    CGFloat position      = *in;
    CPTGradient *gradient = (__bridge CPTGradient *)info;

    // This grabs the first two colors in the sequence
    CPTGradientElement *color1 = gradient.elementList;

    if ( color1 == NULL ) {
        out[0] = out[1] = out[2] = out[3] = CPTFloat(1.0);
        return;
    }

    CPTGradientElement *color2 = color1->nextElement;

    // make sure first color and second color are on other sides of position
    while ( color2 != NULL && color2->position < position ) {
        color1 = color2;
        color2 = color1->nextElement;
    }
    // if we don't have another color then make next color the same color
    if ( color2 == NULL ) {
        color2 = color1;
    }

    // ----------FailSafe settings----------
    // color1->red   = 1; color2->red   = 0;
    // color1->green = 1; color2->green = 0;
    // color1->blue  = 1; color2->blue  = 0;
    // color1->alpha = 1; color2->alpha = 1;
    // color1->position = 0.5;
    // color2->position = 0.5;
    // -------------------------------------

    if ( position <= color1->position ) {
        out[0] = color1->color.red;
        out[1] = color1->color.green;
        out[2] = color1->color.blue;
        out[3] = color1->color.alpha;
    }
    else if ( position >= color2->position ) {
        out[0] = color2->color.red;
        out[1] = color2->color.green;
        out[2] = color2->color.blue;
        out[3] = color2->color.alpha;
    }
    else {
        // adjust position so that it goes from 0 to 1 in the range from color 1 & 2's position
        position = (position - color1->position) / (color2->position - color1->position);

        out[0] = (color2->color.red - color1->color.red) * position + color1->color.red;
        out[1] = (color2->color.green - color1->color.green) * position + color1->color.green;
        out[2] = (color2->color.blue - color1->color.blue) * position + color1->color.blue;
        out[3] = (color2->color.alpha - color1->color.alpha) * position + color1->color.alpha;
    }
}

// Chromatic Evaluation -
// This blends colors by their Hue, Saturation, and Value(Brightness) right now I just
// transform the RGB values stored in the CPTGradientElements to HSB, in the future I may
// streamline it to avoid transforming in and out of HSB colorspace *for later*
//
// For the chromatic blend we shift the hue of color1 to meet the hue of color2. To do
// this we will add to the hue's angle (if we subtract we'll be doing the inverse
// chromatic...scroll down more for that). All we need to do is keep adding to the hue
// until we wrap around the color wheel and get to color2.
void CPTChromaticEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out)
{
    CGFloat position      = *in;
    CPTGradient *gradient = (__bridge CPTGradient *)info;

    // This grabs the first two colors in the sequence
    CPTGradientElement *color1 = gradient.elementList;

    if ( color1 == NULL ) {
        out[0] = out[1] = out[2] = out[3] = CPTFloat(1.0);
        return;
    }

    CPTGradientElement *color2 = color1->nextElement;

    CGFloat c1[4];
    CGFloat c2[4];

    // make sure first color and second color are on other sides of position
    while ( color2 != NULL && color2->position < position ) {
        color1 = color2;
        color2 = color1->nextElement;
    }

    // if we don't have another color then make next color the same color
    if ( color2 == NULL ) {
        color2 = color1;
    }

    c1[0] = color1->color.red;
    c1[1] = color1->color.green;
    c1[2] = color1->color.blue;
    c1[3] = color1->color.alpha;

    c2[0] = color2->color.red;
    c2[1] = color2->color.green;
    c2[2] = color2->color.blue;
    c2[3] = color2->color.alpha;

    CPTTransformRGB_HSV(c1);
    CPTTransformRGB_HSV(c2);
    CPTResolveHSV(c1, c2);

    if ( c1[0] > c2[0] ) {        // if color1's hue is higher than color2's hue then
        c2[0] += CPTFloat(360.0); // we need to move c2 one revolution around the wheel
    }

    if ( position <= color1->position ) {
        out[0] = c1[0];
        out[1] = c1[1];
        out[2] = c1[2];
        out[3] = c1[3];
    }
    else if ( position >= color2->position ) {
        out[0] = c2[0];
        out[1] = c2[1];
        out[2] = c2[2];
        out[3] = c2[3];
    }
    else {
        // adjust position so that it goes from 0 to 1 in the range from color 1 & 2's position
        position = (position - color1->position) / (color2->position - color1->position);

        out[0] = (c2[0] - c1[0]) * position + c1[0];
        out[1] = (c2[1] - c1[1]) * position + c1[1];
        out[2] = (c2[2] - c1[2]) * position + c1[2];
        out[3] = (c2[3] - c1[3]) * position + c1[3];
    }

    CPTTransformHSV_RGB(out);
}

// Inverse Chromatic Evaluation -
// Inverse Chromatic is about the same story as Chromatic Blend, but here the Hue
// is strictly decreasing, that is we need to get from color1 to color2 by decreasing
// the 'angle' (i.e. 90º -> 180º would be done by subtracting 270º and getting -180º...
// which is equivalent to 180º mod 360º
void CPTInverseChromaticEvaluation(void *__nullable info, const CGFloat *__nonnull in, CGFloat *__nonnull out)
{
    CGFloat position      = *in;
    CPTGradient *gradient = (__bridge CPTGradient *)info;

    // This grabs the first two colors in the sequence
    CPTGradientElement *color1 = gradient.elementList;

    if ( color1 == NULL ) {
        out[0] = out[1] = out[2] = out[3] = CPTFloat(1.0);
        return;
    }

    CPTGradientElement *color2 = color1->nextElement;

    CGFloat c1[4];
    CGFloat c2[4];

    // make sure first color and second color are on other sides of position
    while ( color2 != NULL && color2->position < position ) {
        color1 = color2;
        color2 = color1->nextElement;
    }

    // if we don't have another color then make next color the same color
    if ( color2 == NULL ) {
        color2 = color1;
    }

    c1[0] = color1->color.red;
    c1[1] = color1->color.green;
    c1[2] = color1->color.blue;
    c1[3] = color1->color.alpha;

    c2[0] = color2->color.red;
    c2[1] = color2->color.green;
    c2[2] = color2->color.blue;
    c2[3] = color2->color.alpha;

    CPTTransformRGB_HSV(c1);
    CPTTransformRGB_HSV(c2);
    CPTResolveHSV(c1, c2);

    if ( c1[0] < c2[0] ) {        // if color1's hue is higher than color2's hue then
        c1[0] += CPTFloat(360.0); // we need to move c2 one revolution back on the wheel
    }
    if ( position <= color1->position ) {
        out[0] = c1[0];
        out[1] = c1[1];
        out[2] = c1[2];
        out[3] = c1[3];
    }
    else if ( position >= color2->position ) {
        out[0] = c2[0];
        out[1] = c2[1];
        out[2] = c2[2];
        out[3] = c2[3];
    }
    else {
        // adjust position so that it goes from 0 to 1 in the range from color 1 & 2's position
        position = (position - color1->position) / (color2->position - color1->position);

        out[0] = (c2[0] - c1[0]) * position + c1[0];
        out[1] = (c2[1] - c1[1]) * position + c1[1];
        out[2] = (c2[2] - c1[2]) * position + c1[2];
        out[3] = (c2[3] - c1[3]) * position + c1[3];
    }

    CPTTransformHSV_RGB(out);
}

void CPTTransformRGB_HSV(CGFloat *__nonnull components) // H,S,B -> R,G,B
{
    CGFloat H = CPTNAN, S, V;
    CGFloat R = components[0];
    CGFloat G = components[1];
    CGFloat B = components[2];

    CGFloat MAX = R > G ? (R > B ? R : B) : (G > B ? G : B);
    CGFloat MIN = R < G ? (R < B ? R : B) : (G < B ? G : B);

    if ( MAX == R ) {
        if ( G >= B ) {
            H = CPTFloat(60.0) * (G - B) / (MAX - MIN) + CPTFloat(0.0);
        }
        else {
            H = CPTFloat(60.0) * (G - B) / (MAX - MIN) + CPTFloat(360.0);
        }
    }
    else if ( MAX == G ) {
        H = CPTFloat(60.0) * (B - R) / (MAX - MIN) + CPTFloat(120.0);
    }
    else if ( MAX == B ) {
        H = CPTFloat(60.0) * (R - G) / (MAX - MIN) + CPTFloat(240.0);
    }

    S = MAX == 0 ? 0 : 1 - MIN / MAX;
    V = MAX;

    components[0] = H;
    components[1] = S;
    components[2] = V;
}

void CPTTransformHSV_RGB(CGFloat *__nonnull components) // H,S,B -> R,G,B
{
    CGFloat R = CPTFloat(0.0), G = CPTFloat(0.0), B = CPTFloat(0.0);
    CGFloat H = fmod(components[0], CPTFloat(360.0)); // map to [0,360)
    CGFloat S = components[1];
    CGFloat V = components[2];

    int Hi    = (int)lrint(floor(H / CPTFloat(60.0))) % 6;
    CGFloat f = H / CPTFloat(60.0) - Hi;
    CGFloat p = V * (CPTFloat(1.0) - S);
    CGFloat q = V * (CPTFloat(1.0) - f * S);
    CGFloat t = V * (CPTFloat(1.0) - (CPTFloat(1.0) - f) * S);

    switch ( Hi ) {
        case 0:
            R = V;
            G = t;
            B = p;
            break;

        case 1:
            R = q;
            G = V;
            B = p;
            break;

        case 2:
            R = p;
            G = V;
            B = t;
            break;

        case 3:
            R = p;
            G = q;
            B = V;
            break;

        case 4:
            R = t;
            G = p;
            B = V;
            break;

        case 5:
            R = V;
            G = p;
            B = q;
            break;

        default:
            break;
    }

    components[0] = R;
    components[1] = G;
    components[2] = B;
}

void CPTResolveHSV(CGFloat *__nonnull color1, CGFloat *__nonnull color2) // H value may be undefined (i.e. grayscale color)
{                                                                        // we want to fill it with a sensible value
    if ( isnan(color1[0]) && isnan(color2[0])) {
        color1[0] = color2[0] = 0;
    }
    else if ( isnan(color1[0])) {
        color1[0] = color2[0];
    }
    else if ( isnan(color2[0])) {
        color2[0] = color1[0];
    }
}

/// @endcond

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    const CGRect rect = CGRectMake(0.0, 0.0, 100.0, 100.0);

    return CPTQuickLookImage(rect, ^(CGContextRef context, CGFloat __unused scale, CGRect bounds) {
        switch ( self.gradientType ) {
            case CPTGradientTypeAxial:
                CGContextAddRect(context, bounds);
                break;

            case CPTGradientTypeRadial:
                CGContextAddEllipseInRect(context, bounds);
                break;
        }
        [self fillPathInContext:context];
    });
}

/// @endcond

@end
