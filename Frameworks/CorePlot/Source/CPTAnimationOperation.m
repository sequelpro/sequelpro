#import "CPTAnimationOperation.h"

#import "CPTAnimationPeriod.h"

/** @brief Describes all aspects of an animation operation, including the value range, duration, animation curve, property to update, and the delegate.
**/
@implementation CPTAnimationOperation

/** @property nonnull CPTAnimationPeriod *period
 *  @brief The start value, end value, and duration of this animation operation.
 **/
@synthesize period;

/** @property CPTAnimationCurve animationCurve
 *  @brief The animation curve used to animate this operation.
 **/
@synthesize animationCurve;

/** @property nonnull id boundObject
 *  @brief The object to update for each animation frame.
 **/
@synthesize boundObject;

/** @property SEL boundGetter
 *  @brief The @ref boundObject getter method for the property to update for each animation frame.
 **/
@synthesize boundGetter;

/** @property SEL boundSetter
 *  @brief The @ref boundObject setter method for the property to update for each animation frame.
 **/
@synthesize boundSetter;

/** @property nullable id<CPTAnimationDelegate>delegate
 *  @brief The animation delegate.
 **/
@synthesize delegate;

/** @property BOOL canceled
 *  @brief If @YES, this animation operation has been canceled and will no longer post updates.
 **/
@synthesize canceled;

/** @property nullable id<NSCopying, NSObject> identifier
 *  @brief An object used to identify the animation operation in collections.
 **/
@synthesize identifier;

/** @property nullable NSDictionary *userInfo
 *  @brief Application-specific user info that can be attached to the operation.
 **/
@synthesize userInfo;

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTAnimationOperation object.
 *
 *  This is the designated initializer. The initialized object will have the following properties:
 *  - @ref period = @par{animationPeriod}
 *  - @ref animationCurve = @par{curve}
 *  - @ref boundObject = @par{object}
 *  - @ref boundGetter = @par{getter}
 *  - @ref boundSetter = @par{setter}
 *  - @ref delegate = @nil
 *  - @ref canceled = @NO
 *  - @ref identifier = @nil
 *  - @ref userInfo = @nil
 *
 *  @param animationPeriod The animation period.
 *  @param curve The animation curve.
 *  @param object The object to update for each animation frame.
 *  @param getter The @ref boundObject getter method for the property to update for each animation frame.
 *  @param setter The @ref boundObject setter method for the property to update for each animation frame.
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)initWithAnimationPeriod:(nonnull CPTAnimationPeriod *)animationPeriod animationCurve:(CPTAnimationCurve)curve object:(nonnull id)object getter:(nonnull SEL)getter setter:(nonnull SEL)setter
{
    if ((self = [super init])) {
        period         = animationPeriod;
        animationCurve = curve;
        boundObject    = object;
        boundGetter    = getter;
        boundSetter    = setter;
        delegate       = nil;
        canceled       = NO;
        identifier     = nil;
        userInfo       = nil;
    }

    return self;
}

/// @}

/// @cond

-(nonnull instancetype)init
{
    NSAssert(NO, @"Must call -initWithAnimationPeriod:animationCurve:object:getter:setter: to initialize a CPTAnimationOperation.");

    return [self initWithAnimationPeriod:[[CPTAnimationPeriod alloc] init]
                          animationCurve:CPTAnimationCurveDefault
                                  object:[[NSObject alloc] init]
                                  getter:@selector(init)
                                  setter:@selector(init)];
}

/// @endcond

#pragma mark -
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ animate %@ %@ with period %@>", super.description, self.boundObject, NSStringFromSelector(self.boundGetter), self.period];
}

/// @endcond

@end
