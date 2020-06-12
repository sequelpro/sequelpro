/// @file

/**
 *  @brief Enumeration of paragraph alignments.
 **/
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= 101200)
typedef NS_ENUM (NSInteger, CPTTextAlignment) {
    CPTTextAlignmentLeft      = NSTextAlignmentLeft,      ///< Left alignment.
    CPTTextAlignmentCenter    = NSTextAlignmentCenter,    ///< Center alignment.
    CPTTextAlignmentRight     = NSTextAlignmentRight,     ///< Right alignment.
    CPTTextAlignmentJustified = NSTextAlignmentJustified, ///< Justified alignment.
    CPTTextAlignmentNatural   = NSTextAlignmentNatural    ///< Natural alignment of the text's script.
};
#else
typedef NS_ENUM (NSInteger, CPTTextAlignment) {
    CPTTextAlignmentLeft      = NSLeftTextAlignment,      ///< Left alignment.
    CPTTextAlignmentCenter    = NSCenterTextAlignment,    ///< Center alignment.
    CPTTextAlignmentRight     = NSRightTextAlignment,     ///< Right alignment.
    CPTTextAlignmentJustified = NSJustifiedTextAlignment, ///< Justified alignment.
    CPTTextAlignmentNatural   = NSNaturalTextAlignment    ///< Natural alignment of the text's script.
};
#endif
