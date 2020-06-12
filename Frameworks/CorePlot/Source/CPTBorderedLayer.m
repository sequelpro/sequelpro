#import "CPTBorderedLayer.h"

#import "_CPTBorderLayer.h"
#import "_CPTMaskLayer.h"
#import "CPTFill.h"
#import "CPTLineStyle.h"
#import "CPTPathExtensions.h"

/// @cond

@interface CPTBorderedLayer()

@property (nonatomic, readonly, nullable) CPTLayer *borderLayer;

-(void)updateOpacity;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A layer with a border line and background fill.
 *
 *  Sublayers will be positioned and masked so that the border line remains visible.
 **/
@implementation CPTBorderedLayer

/** @property nullable CPTLineStyle *borderLineStyle
 *  @brief The line style for the layer border.
 *
 *  If @nil, the border is not drawn.
 **/
@synthesize borderLineStyle;

/** @property nullable CPTFill *fill
 *  @brief The fill for the layer background.
 *
 *  If @nil, the layer background is not filled.
 **/
@synthesize fill;

/** @property BOOL inLayout
 *  @brief Set to @YES when changing the layout of this layer. Otherwise, if masking the border,
 *  all layout property changes will be passed to the superlayer.
 **/
@synthesize inLayout;

@dynamic borderLayer;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTBorderedLayer object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref borderLineStyle = @nil
 *  - @ref fill = @nil
 *  - @ref inLayout = @NO
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTBorderedLayer object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        borderLineStyle = nil;
        fill            = nil;
        inLayout        = NO;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTBorderedLayer *theLayer = (CPTBorderedLayer *)layer;

        borderLineStyle = theLayer->borderLineStyle;
        fill            = theLayer->fill;
        inLayout        = theLayer->inLayout;
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

    [coder encodeObject:self.borderLineStyle forKey:@"CPTBorderedLayer.borderLineStyle"];
    [coder encodeObject:self.fill forKey:@"CPTBorderedLayer.fill"];

    // No need to archive these properties:
    // inLayout
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        borderLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                               forKey:@"CPTBorderedLayer.borderLineStyle"] copy];
        fill = [[coder decodeObjectOfClass:[CPTFill class]
                                    forKey:@"CPTBorderedLayer.fill"] copy];

        inLayout = NO;
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
    if ( self.hidden || self.masksToBorder ) {
        return;
    }

    [super renderAsVectorInContext:context];
    [self renderBorderedLayerAsVectorInContext:context];
}

/// @endcond

/** @brief Draws the fill and border of a CPTBorderedLayer into the given graphics context.
 *  @param context The graphics context to draw into.
 **/
-(void)renderBorderedLayerAsVectorInContext:(nonnull CGContextRef)context
{
    if ( !self.backgroundColor || !self.useFastRendering ) {
        CPTFill *theFill = self.fill;

        if ( theFill ) {
            BOOL useMask = self.masksToBounds;
            self.masksToBounds = YES;
            CGContextBeginPath(context);
            CGContextAddPath(context, self.maskingPath);
            [theFill fillPathInContext:context];
            self.masksToBounds = useMask;
        }
    }

    CPTLineStyle *theLineStyle = self.borderLineStyle;
    if ( theLineStyle ) {
        CGFloat inset      = theLineStyle.lineWidth * CPTFloat(0.5);
        CGRect layerBounds = CGRectInset(self.bounds, inset, inset);

        [theLineStyle setLineStyleInContext:context];

        CGFloat radius = self.cornerRadius;

        if ( radius > CPTFloat(0.0)) {
            CGContextBeginPath(context);
            CPTAddRoundedRectPath(context, layerBounds, radius);
            [theLineStyle strokePathInContext:context];
        }
        else {
            [theLineStyle strokeRect:layerBounds inContext:context];
        }
    }
}

#pragma mark -
#pragma mark Layout

/// @name Layout
/// @{

/** @brief Increases the sublayer margin on all four sides by half the width of the border line style.
 *  @param left The left margin.
 *  @param top The top margin.
 *  @param right The right margin.
 *  @param bottom The bottom margin.
 **/
-(void)sublayerMarginLeft:(nonnull CGFloat *)left top:(nonnull CGFloat *)top right:(nonnull CGFloat *)right bottom:(nonnull CGFloat *)bottom
{
    [super sublayerMarginLeft:left top:top right:right bottom:bottom];

    CGFloat inset = self.borderLineStyle.lineWidth * CPTFloat(0.5);

    if ( inset > CPTFloat(0.0)) {
        *left   += inset;
        *top    += inset;
        *right  += inset;
        *bottom += inset;
    }
}

/// @}

/// @cond

-(void)layoutSublayers
{
    [super layoutSublayers];

    self.mask.frame = self.bounds;
}

/// @endcond

#pragma mark -
#pragma mark Masking

/// @cond

-(nullable CGPathRef)maskingPath
{
    if ( self.masksToBounds ) {
        CGPathRef path = self.outerBorderPath;
        if ( path ) {
            return path;
        }

        CGFloat radius = self.cornerRadius + self.borderLineStyle.lineWidth * CPTFloat(0.5);

        path = CPTCreateRoundedRectPath(self.bounds, radius);

        self.outerBorderPath = path;
        CGPathRelease(path);

        return self.outerBorderPath;
    }
    else {
        return NULL;
    }
}

-(nullable CGPathRef)sublayerMaskingPath
{
    if ( self.masksToBorder ) {
        CGPathRef path = self.innerBorderPath;
        if ( path ) {
            return path;
        }

        CGFloat lineWidth = self.borderLineStyle.lineWidth;
        CGRect selfBounds = CGRectInset(self.bounds, lineWidth, lineWidth);

        path = CPTCreateRoundedRectPath(selfBounds, self.cornerRadius - lineWidth * CPTFloat(0.5));

        self.innerBorderPath = path;
        CGPathRelease(path);

        return self.innerBorderPath;
    }
    else {
        return NULL;
    }
}

/// @endcond

#pragma mark -
#pragma mark Layers

/// @cond

-(void)removeFromSuperlayer
{
    // remove the super layer, too, if we're masking the border
    CPTBorderLayer *superLayer = (CPTBorderLayer *)self.superlayer;

    if ( [superLayer isKindOfClass:[CPTBorderLayer class]] ) {
        if ( superLayer.maskedLayer == self ) {
            [superLayer removeFromSuperlayer];
        }
    }

    [super removeFromSuperlayer];
}

-(void)updateOpacity
{
    BOOL opaqueLayer = (self.cornerRadius <= CPTFloat(0.0));

    CPTFill *theFill = self.fill;

    if ( theFill ) {
        opaqueLayer = opaqueLayer && theFill.opaque && !theFill.cgColor;
    }

    CPTLineStyle *lineStyle = self.borderLineStyle;

    if ( lineStyle ) {
        opaqueLayer = opaqueLayer && lineStyle.opaque;
    }

    self.borderLayer.opaque = opaqueLayer;
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setBorderLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != borderLineStyle ) {
        if ( newLineStyle.lineWidth != borderLineStyle.lineWidth ) {
            self.outerBorderPath = NULL;
            self.innerBorderPath = NULL;
            [self setNeedsLayout];
        }

        borderLineStyle = [newLineStyle copy];

        [self updateOpacity];

        [self.borderLayer setNeedsDisplay];
    }
}

-(void)setFill:(nullable CPTFill *)newFill
{
    if ( newFill != fill ) {
        fill = [newFill copy];

        CPTLayer *border = self.borderLayer;
        if ( self.cornerRadius != CPTFloat(0.0)) {
            border.backgroundColor = NULL;
        }
        else {
            border.backgroundColor = fill.cgColor;
        }
        [border setNeedsDisplay];

        [self updateOpacity];
    }
}

-(void)setCornerRadius:(CGFloat)newRadius
{
    if ( newRadius != self.cornerRadius ) {
        super.cornerRadius = newRadius;

        self.borderLayer.backgroundColor = NULL;

        [self updateOpacity];
    }
}

-(void)setMasksToBorder:(BOOL)newMasksToBorder
{
    if ( newMasksToBorder != self.masksToBorder ) {
        super.masksToBorder = newMasksToBorder;

        if ( newMasksToBorder ) {
            CPTMaskLayer *maskLayer = [[CPTMaskLayer alloc] initWithFrame:self.bounds];
            [maskLayer setNeedsDisplay];
            self.mask = maskLayer;
        }
        else {
            self.mask = nil;
        }

        [self.borderLayer setNeedsDisplay];
        [self setNeedsDisplay];
    }
}

-(nullable CPTLayer *)borderLayer
{
    CPTLayer *theBorderLayer   = nil;
    CPTBorderLayer *superLayer = (CPTBorderLayer *)self.superlayer;

    if ( self.masksToBorder ) {
        // check layer structure
        if ( superLayer ) {
            if ( ![superLayer isKindOfClass:[CPTBorderLayer class]] ) {
                CPTBorderLayer *newBorderLayer = [[CPTBorderLayer alloc] initWithFrame:self.frame];
                newBorderLayer.maskedLayer = self;

                [superLayer replaceSublayer:self with:newBorderLayer];
                [newBorderLayer addSublayer:self];

                newBorderLayer.transform = self.transform;
                newBorderLayer.shadow    = self.shadow;
                newBorderLayer.opaque    = self.opaque;

                newBorderLayer.backgroundColor = self.backgroundColor;

                self.transform       = CATransform3DIdentity;
                self.backgroundColor = NULL;

                [superLayer setNeedsLayout];

                theBorderLayer = newBorderLayer;
            }
            else {
                theBorderLayer = superLayer;
            }
        }
    }
    else {
        // remove the super layer for the border if no longer needed
        if ( [superLayer isKindOfClass:[CPTBorderLayer class]] ) {
            if ( superLayer.maskedLayer == self ) {
                self.transform = superLayer.transform;
                self.opaque    = superLayer.opaque;

                self.backgroundColor = superLayer.backgroundColor;

                [superLayer.superlayer replaceSublayer:superLayer with:self];

                [self setNeedsLayout];
            }
        }

        theBorderLayer = self;
    }

    return theBorderLayer;
}

-(void)setBounds:(CGRect)newBounds
{
    if ( self.masksToBorder && !self.inLayout ) {
        self.borderLayer.bounds = newBounds;
    }
    else {
        super.bounds = newBounds;
    }
}

-(void)setPosition:(CGPoint)newPosition
{
    if ( self.masksToBorder && !self.inLayout ) {
        self.borderLayer.position = newPosition;
    }
    else {
        super.position = newPosition;
    }
}

-(void)setAnchorPoint:(CGPoint)newAnchorPoint
{
    if ( self.masksToBorder && !self.inLayout ) {
        self.borderLayer.anchorPoint = newAnchorPoint;
    }
    else {
        super.anchorPoint = newAnchorPoint;
    }
}

-(void)setHidden:(BOOL)newHidden
{
    if ( self.masksToBorder ) {
        self.borderLayer.hidden = newHidden;
    }
    else {
        super.hidden = newHidden;
    }
}

-(void)setTransform:(CATransform3D)newTransform
{
    if ( self.masksToBorder ) {
        self.borderLayer.transform = newTransform;
    }
    else {
        super.transform = newTransform;
    }
}

-(void)setShadow:(nullable CPTShadow *)newShadow
{
    if ( newShadow != self.shadow ) {
        super.shadow = newShadow;

        if ( self.masksToBorder ) {
            self.borderLayer.shadow = newShadow;
        }
    }
}

-(void)setBackgroundColor:(nullable CGColorRef)newColor
{
    if ( self.masksToBorder ) {
        self.borderLayer.backgroundColor = newColor;
    }
    else {
        super.backgroundColor = newColor;
    }
}

/// @endcond

@end
