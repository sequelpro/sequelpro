#import "CPTMutableShadow.h"

/** @brief Mutable wrapper for various shadow drawing properties.
 *
 *  If you need to customize properties of a shadow, you should use this class rather than the
 *  immutable super class.
 *
 **/
@implementation CPTMutableShadow

/** @property CGSize shadowOffset
 *  @brief The horizontal and vertical offset values, specified using the width and height fields
 *  of the @ref CGSize data type. The offsets are not affected by custom transformations. Positive values extend
 *  up and to the right. Default is (@num{0.0}, @num{0.0}).
 **/
@dynamic shadowOffset;

/** @property CGFloat shadowBlurRadius
 *  @brief The blur radius, measured in the default user coordinate space. A value of @num{0.0} (the default) indicates no blur,
 *  while larger values produce correspondingly larger blurring. This value must not be negative.
 **/
@dynamic shadowBlurRadius;

/** @property nullable CPTColor *shadowColor
 *  @brief The shadow color. If @nil (the default), the shadow will not be drawn.
 **/
@dynamic shadowColor;

@end
