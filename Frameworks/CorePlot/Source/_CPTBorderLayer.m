#import "_CPTBorderLayer.h"

#import "CPTBorderedLayer.h"

/**
 *  @brief A utility layer used to draw the fill and border of a CPTBorderedLayer.
 *
 *  This layer is always the superlayer of a single CPTBorderedLayer. It draws the fill and
 *  border so that they are not clipped by the mask applied to the sublayer.
 **/
@implementation CPTBorderLayer

/** @property nullable CPTBorderedLayer *maskedLayer
 *  @brief The CPTBorderedLayer masked being masked.
 *  Its fill and border are drawn into this layer so that they are outside the mask applied to the @par{maskedLayer}.
 **/
@synthesize maskedLayer;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTBorderLayer object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref maskedLayer = @nil
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTBorderLayer object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        maskedLayer = nil;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTBorderLayer *theLayer = (CPTBorderLayer *)layer;

        maskedLayer = theLayer->maskedLayer;
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

    [coder encodeObject:self.maskedLayer forKey:@"CPTBorderLayer.maskedLayer"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        maskedLayer = [coder decodeObjectOfClass:[CPTBorderedLayer class]
                                          forKey:@"CPTBorderLayer.maskedLayer"];
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

    CPTBorderedLayer *theMaskedLayer = self.maskedLayer;

    if ( theMaskedLayer ) {
        [super renderAsVectorInContext:context];
        [theMaskedLayer renderBorderedLayerAsVectorInContext:context];
    }
}

/// @endcond

#pragma mark -
#pragma mark Layout

/// @cond

-(void)layoutSublayers
{
    [super layoutSublayers];

    CPTBorderedLayer *theMaskedLayer = self.maskedLayer;

    if ( theMaskedLayer ) {
        CGRect newBounds = self.bounds;

        // undo the shadow margin so the masked layer is always the same size
        if ( self.shadow ) {
            CGSize sizeOffset = self.shadowMargin;

            newBounds.origin.x    -= sizeOffset.width;
            newBounds.origin.y    -= sizeOffset.height;
            newBounds.size.width  += sizeOffset.width * CPTFloat(2.0);
            newBounds.size.height += sizeOffset.height * CPTFloat(2.0);
        }

        theMaskedLayer.inLayout = YES;
        theMaskedLayer.frame    = newBounds;
        theMaskedLayer.inLayout = NO;
    }
}

-(nullable CPTSublayerSet *)sublayersExcludedFromAutomaticLayout
{
    CPTBorderedLayer *excludedLayer = self.maskedLayer;

    if ( excludedLayer ) {
        CPTMutableSublayerSet *excludedSublayers = [super.sublayersExcludedFromAutomaticLayout mutableCopy];
        if ( !excludedSublayers ) {
            excludedSublayers = [NSMutableSet set];
        }
        [excludedSublayers addObject:excludedLayer];
        return excludedSublayers;
    }
    else {
        return super.sublayersExcludedFromAutomaticLayout;
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setMaskedLayer:(nullable CPTBorderedLayer *)newLayer
{
    if ( newLayer != maskedLayer ) {
        maskedLayer = newLayer;
        [self setNeedsDisplay];
    }
}

-(void)setBounds:(CGRect)newBounds
{
    if ( !CGRectEqualToRect(newBounds, self.bounds)) {
        super.bounds = newBounds;
        [self setNeedsLayout];
    }
}

/// @endcond

@end
