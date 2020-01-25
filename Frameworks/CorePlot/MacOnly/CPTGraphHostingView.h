#import <Cocoa/Cocoa.h>

@class CPTGraph;

@interface CPTGraphHostingView : NSView<NSCoding, NSSecureCoding>

/// @name Hosted graph
/// @{
@property (nonatomic, readwrite, strong, nullable) CPTGraph *hostedGraph;
/// @}

/// @name Printing
/// @{
@property (nonatomic, readwrite, assign) NSRect printRect;
/// @}

/// @name Cursors
/// @{
@property (nonatomic, readwrite, strong, nullable) NSCursor *closedHandCursor;
@property (nonatomic, readwrite, strong, nullable) NSCursor *openHandCursor;
/// @}

/// @name User Interaction
/// @{
@property (nonatomic, readwrite, assign) BOOL allowPinchScaling;
/// @}

@end
