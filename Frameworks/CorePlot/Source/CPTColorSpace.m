#import "CPTColorSpace.h"

#import "NSCoderExtensions.h"

/** @brief An immutable color space.
 *
 *  An immutable object wrapper class around @ref CGColorSpaceRef.
 **/

@implementation CPTColorSpace

/** @property nonnull CGColorSpaceRef cgColorSpace
 *  @brief The @ref CGColorSpaceRef to wrap around.
 **/
@synthesize cgColorSpace;

#pragma mark -
#pragma mark Class methods

/** @brief Returns a shared instance of CPTColorSpace initialized with the standard RGB space.
 *
 *  The standard RGB space is created by the
 *  @if MacOnly @ref CGColorSpaceCreateWithName ( @ref kCGColorSpaceGenericRGB ) function. @endif
 *  @if iOSOnly @ref CGColorSpaceCreateDeviceRGB() function. @endif
 *
 *  @return A shared CPTColorSpace object initialized with the standard RGB colorspace.
 **/
+(nonnull instancetype)genericRGBSpace
{
    static CPTColorSpace *space      = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        CGColorSpaceRef cgSpace = NULL;
#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        cgSpace = CGColorSpaceCreateDeviceRGB();
#else
        cgSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
#endif
        space = [[self alloc] initWithCGColorSpace:cgSpace];
        CGColorSpaceRelease(cgSpace);
    });

    return space;
}

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated colorspace object with the specified color space.
 *  This is the designated initializer.
 *
 *  @param colorSpace The color space.
 *  @return The initialized CPTColorSpace object.
 **/
-(nonnull instancetype)initWithCGColorSpace:(nonnull CGColorSpaceRef)colorSpace
{
    if ((self = [super init])) {
        CGColorSpaceRetain(colorSpace);
        cgColorSpace = colorSpace;
    }
    return self;
}

/// @cond

-(nonnull instancetype)init
{
    CGColorSpaceRef cgSpace = NULL;

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
    cgSpace = CGColorSpaceCreateDeviceRGB();
#else
    cgSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
#endif

    self = [self initWithCGColorSpace:cgSpace];

    CGColorSpaceRelease(cgSpace);

    return self;
}

-(void)dealloc
{
    CGColorSpaceRelease(cgColorSpace);
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeCGColorSpace:self.cgColorSpace forKey:@"CPTColorSpace.cgColorSpace"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        CGColorSpaceRef colorSpace = [coder newCGColorSpaceDecodeForKey:@"CPTColorSpace.cgColorSpace"];

        if ( colorSpace ) {
            cgColorSpace = colorSpace;
        }
        else {
            self = nil;
        }
    }
    return self;
}

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

@end
