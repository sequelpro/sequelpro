#import "CPTMutableNumericData.h"

/// @cond
@interface CPTNumericData()

// inherited private method
-(NSUInteger)sampleIndex:(NSUInteger)idx indexList:(va_list)indexList;

@end

/// @endcond

#pragma mark -

/** @brief An annotated NSMutableData type.
 *
 *  CPTNumericData combines a mutable data buffer with information
 *  about the data (shape, data type, size, etc.).
 *  The data is assumed to be an array of one or more dimensions
 *  of a single type of numeric data. Each numeric value in the array,
 *  which can be more than one byte in size, is referred to as a @quote{sample}.
 *  The structure of this object is similar to the NumPy <code>ndarray</code>
 *  object.
 **/
@implementation CPTMutableNumericData

/** @property nonnull void *mutableBytes
 *  @brief Returns a pointer to the data buffer’s contents.
 **/
@dynamic mutableBytes;

/** @property nonnull CPTNumberArray *shape
 *  @brief The shape of the data buffer array. Set a new shape to change the size of the data buffer.
 *
 *  The shape describes the dimensions of the sample array stored in
 *  the data buffer. Each entry in the shape array represents the
 *  size of the corresponding array dimension and should be an unsigned
 *  integer encoded in an instance of NSNumber.
 **/
@dynamic shape;

#pragma mark -
#pragma mark Samples

/** @brief Gets a pointer to a given sample in the data buffer.
 *  @param sample The zero-based index into the sample array. The array is treated as if it only has one dimension.
 *  @return A pointer to the sample or @NULL if the sample index is out of bounds.
 **/
-(nullable void *)mutableSamplePointer:(NSUInteger)sample
{
    if ( sample < self.numberOfSamples ) {
        return (void *)((char *)self.mutableBytes + sample * self.sampleBytes);
    }
    else {
        return NULL;
    }
}

/** @brief Gets a pointer to a given sample in the data buffer.
 *  @param idx The zero-based indices into a multi-dimensional sample array. Each index should of type @ref NSUInteger and the number of indices
 *  (including @par{idx}) should match the @ref numberOfDimensions.
 *  @return A pointer to the sample or @NULL if any of the sample indices are out of bounds.
 **/
-(nullable void *)mutableSamplePointerAtIndex:(NSUInteger)idx, ...
{
    NSUInteger newIndex;

    if ( self.numberOfDimensions > 1 ) {
        va_list indices;
        va_start(indices, idx);

        newIndex = [self sampleIndex:idx indexList:indices];

        va_end(indices);
    }
    else {
        newIndex = idx;
    }

    return [self mutableSamplePointer:newIndex];
}

#pragma mark -
#pragma mark Accessors

/// @cond

-(nonnull void *)mutableBytes
{
    return ((NSMutableData *)self.data).mutableBytes;
}

/// @endcond

@end
