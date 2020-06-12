@interface CPTConstraints : NSObject<NSCopying, NSCoding, NSSecureCoding>

/// @name Factory Methods
/// @{
+(nonnull instancetype)constraintWithLowerOffset:(CGFloat)newOffset;
+(nonnull instancetype)constraintWithUpperOffset:(CGFloat)newOffset;
+(nonnull instancetype)constraintWithRelativeOffset:(CGFloat)newOffset;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithLowerOffset:(CGFloat)newOffset;
-(nonnull instancetype)initWithUpperOffset:(CGFloat)newOffset;
-(nonnull instancetype)initWithRelativeOffset:(CGFloat)newOffset;
/// @}

@end

/** @category CPTConstraints(AbstractMethods)
 *  @brief CPTConstraints abstract methods—must be overridden by subclasses
 **/
@interface CPTConstraints(AbstractMethods)

/// @name Comparison
/// @{
-(BOOL)isEqualToConstraint:(nullable CPTConstraints *)otherConstraint;
/// @}

/// @name Position
/// @{
-(CGFloat)positionForLowerBound:(CGFloat)lowerBound upperBound:(CGFloat)upperBound;
/// @}

@end
