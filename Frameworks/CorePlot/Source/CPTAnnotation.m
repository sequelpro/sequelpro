#import "CPTAnnotation.h"

#import "CPTAnnotationHostLayer.h"
#import "NSCoderExtensions.h"

/** @brief An annotation positions a content layer relative to some anchor point.
 *
 *  Annotations can be used to add text or images that are anchored to a feature
 *  of a graph. For example, the graph title is an annotation anchored to the graph.
 *  The annotation content layer can be any CPTLayer.
 **/
@implementation CPTAnnotation

/** @property nullable CPTLayer *contentLayer
 *  @brief The annotation content.
 **/
@synthesize contentLayer;

/** @property nullable CPTAnnotationHostLayer *annotationHostLayer
 *  @brief The host layer for the annotation content.
 **/
@synthesize annotationHostLayer;

/** @property CGPoint displacement
 *  @brief The displacement from the layer anchor point.
 **/
@synthesize displacement;

/** @property CGPoint contentAnchorPoint
 *  @brief The anchor point for the content layer.
 **/
@synthesize contentAnchorPoint;

/** @property CGFloat rotation
 *  @brief The rotation of the label in radians.
 **/
@synthesize rotation;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTAnnotation object.
 *
 *  The initialized object will have the following properties:
 *  - @ref annotationHostLayer = @nil
 *  - @ref contentLayer = @nil
 *  - @ref displacement = (@num{0.0}, @num{0.0})
 *  - @ref contentAnchorPoint = (@num{0.5}, @num{0.5})
 *  - @ref rotation = @num{0.0}
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        annotationHostLayer = nil;
        contentLayer        = nil;
        displacement        = CGPointZero;
        contentAnchorPoint  = CPTPointMake(0.5, 0.5);
        rotation            = CPTFloat(0.0);
    }
    return self;
}

/// @}

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeConditionalObject:self.annotationHostLayer forKey:@"CPTAnnotation.annotationHostLayer"];
    [coder encodeObject:self.contentLayer forKey:@"CPTAnnotation.contentLayer"];
    [coder encodeCPTPoint:self.contentAnchorPoint forKey:@"CPTAnnotation.contentAnchorPoint"];
    [coder encodeCPTPoint:self.displacement forKey:@"CPTAnnotation.displacement"];
    [coder encodeCGFloat:self.rotation forKey:@"CPTAnnotation.rotation"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        annotationHostLayer = [coder decodeObjectOfClass:[CPTAnnotationHostLayer class]
                                                  forKey:@"CPTAnnotation.annotationHostLayer"];
        contentLayer = [coder decodeObjectOfClass:[CPTLayer class]
                                           forKey:@"CPTAnnotation.contentLayer"];
        contentAnchorPoint = [coder decodeCPTPointForKey:@"CPTAnnotation.contentAnchorPoint"];
        displacement       = [coder decodeCPTPointForKey:@"CPTAnnotation.displacement"];
        rotation           = [coder decodeCGFloatForKey:@"CPTAnnotation.rotation"];
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
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ {%@}>", super.description, self.contentLayer];
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setContentLayer:(nullable CPTLayer *)newLayer
{
    if ( newLayer != contentLayer ) {
        [contentLayer removeFromSuperlayer];
        contentLayer = newLayer;
        if ( newLayer ) {
            CPTLayer *layer = newLayer;

            CPTAnnotationHostLayer *hostLayer = self.annotationHostLayer;
            [hostLayer addSublayer:layer];
        }
    }
}

-(void)setAnnotationHostLayer:(nullable CPTAnnotationHostLayer *)newLayer
{
    if ( newLayer != annotationHostLayer ) {
        CPTLayer *myContent = self.contentLayer;

        [myContent removeFromSuperlayer];
        annotationHostLayer = newLayer;
        if ( myContent ) {
            [newLayer addSublayer:myContent];
        }
    }
}

-(void)setDisplacement:(CGPoint)newDisplacement
{
    if ( !CGPointEqualToPoint(newDisplacement, displacement)) {
        displacement = newDisplacement;
        [self.contentLayer.superlayer setNeedsLayout];
    }
}

-(void)setContentAnchorPoint:(CGPoint)newAnchorPoint
{
    if ( !CGPointEqualToPoint(newAnchorPoint, contentAnchorPoint)) {
        contentAnchorPoint = newAnchorPoint;
        [self.contentLayer.superlayer setNeedsLayout];
    }
}

-(void)setRotation:(CGFloat)newRotation
{
    if ( newRotation != rotation ) {
        rotation = newRotation;
        [self.contentLayer.superlayer setNeedsLayout];
    }
}

/// @endcond

@end

#pragma mark -
#pragma mark Layout

@implementation CPTAnnotation(AbstractMethods)

/** @brief Positions the content layer relative to its reference anchor.
 *
 *  This method must be overridden by subclasses. The default implementation
 *  does nothing.
 **/
-(void)positionContentLayer
{
    // Do nothing--implementation provided by subclasses
}

@end
