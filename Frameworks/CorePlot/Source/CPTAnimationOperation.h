#import "CPTAnimation.h"
#import "CPTDefinitions.h"

@class CPTAnimationPeriod;

@interface CPTAnimationOperation : NSObject

/// @name Animation Timing
/// @{
@property (nonatomic, strong, nonnull) CPTAnimationPeriod *period;
@property (nonatomic, assign) CPTAnimationCurve animationCurve;
/// @}

/// @name Animated Property
/// @{
@property (nonatomic, strong, nonnull) id boundObject;
@property (nonatomic, nonnull) SEL boundGetter;
@property (nonatomic, nonnull) SEL boundSetter;
/// @}

/// @name Delegate
/// @{
@property (nonatomic, cpt_weak_property, nullable) id<CPTAnimationDelegate> delegate;
/// @}

/// @name Status
/// @{
@property (atomic, getter = isCanceled) BOOL canceled;
/// @}

/// @name Identification
/// @{
@property (nonatomic, readwrite, copy, nullable) id<NSCopying, NSObject> identifier;
@property (nonatomic, readwrite, copy, nullable) NSDictionary *userInfo;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithAnimationPeriod:(nonnull CPTAnimationPeriod *)animationPeriod animationCurve:(CPTAnimationCurve)curve object:(nonnull id)object getter:(nonnull SEL)getter setter:(nonnull SEL)setter NS_DESIGNATED_INITIALIZER;
/// @}

@end
