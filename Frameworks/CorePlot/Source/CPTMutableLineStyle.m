#import "CPTMutableLineStyle.h"

/** @brief Mutable wrapper for various line drawing properties.
 *
 *  If you need to customize properties of a line style, you should use this class rather than the
 *  immutable super class.
 *
 **/

@implementation CPTMutableLineStyle

/** @property CGLineCap lineCap
 *  @brief The style for the endpoints of lines drawn in a graphics context. Default is @ref kCGLineCapButt.
 **/
@dynamic lineCap;

/** @property CGLineJoin lineJoin
 *  @brief The style for the joins of connected lines in a graphics context. Default is @ref kCGLineJoinMiter.
 **/
@dynamic lineJoin;

/** @property CGFloat miterLimit
 *  @brief The miter limit for the joins of connected lines in a graphics context. Default is @num{10.0}.
 **/
@dynamic miterLimit;

/** @property CGFloat lineWidth
 *  @brief The line width for a graphics context. Default is @num{1.0}.
 **/
@dynamic lineWidth;

/** @property nullable CPTNumberArray *dashPattern
 *  @brief The dash-and-space pattern for the line. Default is @nil.
 **/
@dynamic dashPattern;

/** @property CGFloat patternPhase
 *  @brief The starting phase of the line dash pattern. Default is @num{0.0}.
 **/
@dynamic patternPhase;

/** @property nullable CPTColor *lineColor
 *  @brief The current stroke color in a context. Default is solid black.
 **/
@dynamic lineColor;

/** @property nullable CPTFill *lineFill
 *  @brief The current line fill. Default is @nil.
 *
 *  If @nil, the line is drawn using the @ref lineGradient or @ref lineColor.
 **/
@dynamic lineFill;

/** @property nullable CPTGradient *lineGradient
 *  @brief The current line gradient fill. Default is @nil.
 *
 *  If @nil, the line is drawn using the @ref lineFill or @ref lineColor.
 **/
@dynamic lineGradient;

@end
