/**
 *  @brief Methods used to show QuickLook previews of objects in the Xcode debugger and Swift playgrounds.
 **/
@protocol CPTDebugQuickLook<NSObject>

/// @name Debugging
/// @{

/**
 *  @brief Used to show QuickLook previews of objects in the Xcode debugger and Swift playgrounds.
 **/
-(nullable id)debugQuickLookObject;

/// @}

@end

#pragma mark -

/** @category NSObject(CPTDebugQuickLookExtension)
 *  @brief Debugging extensions to NSObject.
 **/
@interface NSObject(CPTDebugQuickLookExtension)<CPTDebugQuickLook>
{
}

@end
