#import "CPTNumericDataTests.h"

#import "CPTExceptions.h"
#import "CPTNumericData+TypeConversion.h"

@implementation CPTNumericDataTests

-(void)testNilShapeGivesSingleDimension
{
    NSMutableData *data = [NSMutableData dataWithLength:1 * sizeof(float)];
    CPTNumericData *nd  = [[CPTNumericData alloc] initWithData:data
                                                dataTypeString:@"=f4"
                                                         shape:nil];
    NSUInteger actual   = nd.numberOfDimensions;
    NSUInteger expected = 1;

    XCTAssertEqual(actual, expected, @"numberOfDimensions == 1");
    expected = nd.shape.count;
    XCTAssertEqual(actual, expected, @"numberOfDimensions == 1");
}

-(void)testNumberOfDimensionsGivesShapeCount
{
    id shape = @[@2, @2, @2];

    NSUInteger nElems = 2 * 2 * 2;

    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    CPTNumericData *nd  = [[CPTNumericData alloc] initWithData:data
                                                      dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                         shape:shape];

    XCTAssertEqual(nd.numberOfDimensions, nd.shape.count, @"numberOfDimensions == shape.count == 3");
}

-(void)testNilShapeCorrectElementCount
{
    NSUInteger nElems = 13;

    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    CPTNumericData *nd  = [[CPTNumericData alloc] initWithData:data
                                                dataTypeString:@"=f4"
                                                         shape:nil];

    XCTAssertEqual(nd.numberOfDimensions, (NSUInteger)1, @"numberOfDimensions == 1");

    NSUInteger prod = 1;
    for ( NSNumber *num in nd.shape ) {
        prod *= num.unsignedIntegerValue;
    }

    XCTAssertEqual(prod, nElems, @"prod == nElems");
}

-(void)testIllegalShapeRaisesException
{
    id shape = @[@2, @2, @2];

    NSUInteger nElems = 5;

    CPTNumericData *testData = nil;

    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(NSUInteger)];

    XCTAssertThrowsSpecificNamed(testData = [[CPTNumericData alloc] initWithData:data
                                                                        dataType:CPTDataType(CPTUnsignedIntegerDataType, sizeof(NSUInteger), NSHostByteOrder())
                                                                           shape:shape],
                                 NSException,
                                 CPTNumericDataException,
                                 @"Illegal shape should throw");
}

-(void)testReturnsDataLength
{
    NSMutableData *data = [NSMutableData dataWithLength:10 * sizeof(float)];
    CPTNumericData *nd  = [[CPTNumericData alloc] initWithData:data
                                                dataTypeString:@"=f4"
                                                         shape:nil];

    NSUInteger expected = 10 * sizeof(float);
    NSUInteger actual   = nd.data.length;

    XCTAssertEqual(expected, actual, @"data length");
}

-(void)testBytesEqualDataBytes
{
    NSUInteger nElements = 10;
    NSMutableData *data  = [NSMutableData dataWithLength:nElements * sizeof(NSInteger)];
    NSInteger *intData   = (NSInteger *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElements; i++ ) {
        intData[i] = (NSInteger)i;
    }

    CPTNumericData *nd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTIntegerDataType, sizeof(NSInteger), NSHostByteOrder())
                                                        shape:nil];

    NSData *expected = data;
    XCTAssertEqualObjects(data, nd.data, @"equal objects");
    XCTAssertTrue([expected isEqualToData:nd.data], @"data isEqualToData:");
}

-(void)testArchivingRoundTrip
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *nd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    CPTNumericData *nd2 = [self archiveRoundTrip:nd];

    XCTAssertTrue([nd.data isEqualToData:nd2.data], @"equal data");

    CPTNumericDataType ndType  = nd.dataType;
    CPTNumericDataType nd2Type = nd2.dataType;

    XCTAssertEqual(ndType.dataTypeFormat, nd2Type.dataTypeFormat, @"dataType.dataTypeFormat equal");
    XCTAssertEqual(ndType.sampleBytes, nd2Type.sampleBytes, @"dataType.sampleBytes equal");
    XCTAssertEqual(ndType.byteOrder, nd2Type.byteOrder, @"dataType.byteOrder equal");
    XCTAssertEqualObjects(nd.shape, nd2.shape, @"shapes equal");
}

-(void)testKeyedArchivingRoundTrip
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *nd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    CPTNumericData *nd2 = [self archiveRoundTrip:nd];

    XCTAssertTrue([nd.data isEqualToData:nd2.data], @"equal data");

    CPTNumericDataType ndType  = nd.dataType;
    CPTNumericDataType nd2Type = nd2.dataType;

    XCTAssertEqual(ndType.dataTypeFormat, nd2Type.dataTypeFormat, @"dataType.dataTypeFormat equal");
    XCTAssertEqual(ndType.sampleBytes, nd2Type.sampleBytes, @"dataType.sampleBytes equal");
    XCTAssertEqual(ndType.byteOrder, nd2Type.byteOrder, @"dataType.byteOrder equal");
    XCTAssertEqualObjects(nd.shape, nd2.shape, @"shapes equal");
}

-(void)testNumberOfSamplesCorrectForDataType
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *nd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    XCTAssertEqual([nd numberOfSamples], nElems, @"numberOfSamples == nElems");

    nElems = 10;
    data   = [NSMutableData dataWithLength:nElems * sizeof(char)];
    char *charSamples = (char *)data.mutableBytes;
    for ( NSUInteger i = 0; i < nElems; i++ ) {
        charSamples[i] = (char)lrint(sin(i) * 100.0);
    }

    nd = [[CPTNumericData alloc] initWithData:data
                                     dataType:CPTDataType(CPTIntegerDataType, sizeof(char), NSHostByteOrder())
                                        shape:nil];

    XCTAssertEqual([nd numberOfSamples], nElems, @"numberOfSamples == nElems");
}

-(void)testDataTypeAccessorsCorrectForDataType
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *nd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    XCTAssertEqual([nd dataTypeFormat], CPTFloatingPointDataType, @"dataTypeFormat");
    XCTAssertEqual([nd sampleBytes], sizeof(float), @"sampleBytes");
    XCTAssertEqual([nd byteOrder], NSHostByteOrder(), @"byteOrder");
}

-(void)testConvertTypeConvertsType
{
    NSUInteger numberOfSamples = 10;
    NSMutableData *data        = [NSMutableData dataWithLength:numberOfSamples * sizeof(float)];
    float *samples             = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *fd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    CPTNumericData *dd = [fd dataByConvertingToType:CPTFloatingPointDataType
                                        sampleBytes:sizeof(double)
                                          byteOrder:NSHostByteOrder()];

    const double *doubleSamples = (const double *)dd.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertTrue((double)samples[i] == doubleSamples[i], @"(float)%g != (double)%g", (double)samples[i], doubleSamples[i]);
    }
}

-(void)testSamplePointerCorrect
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *fd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    XCTAssertEqual(((const float *)[fd.data bytes]) + 4, (const float *)[fd samplePointer:4], @"%p,%p", samples + 4, (const float *)[fd samplePointer:4]);
    XCTAssertEqual(((const float *)[fd.data bytes]), (const float *)[fd samplePointer:0], @"");
    XCTAssertEqual(((const float *)[fd.data bytes]) + nElems - 1, (const float *)[fd samplePointer:nElems - 1], @"");
    XCTAssertNil([fd samplePointer:nElems], @"too many samples");
}

-(void)testSampleValueCorrect
{
    NSUInteger nElems   = 10;
    NSMutableData *data = [NSMutableData dataWithLength:nElems * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < nElems; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *fd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                        shape:nil];

    XCTAssertEqualWithAccuracy([[fd sampleValue:0] doubleValue], sin(0), 0.01, @"sample value");
    XCTAssertEqualWithAccuracy([[fd sampleValue:1] doubleValue], sin(1), 0.01, @"sample value");
}

-(void)testSampleIndexRowsFirstOrder
{
    const NSUInteger rows = 3;
    const NSUInteger cols = 4;

    NSMutableData *data = [NSMutableData dataWithLength:rows * cols * sizeof(NSUInteger)];
    NSUInteger *samples = (NSUInteger *)data.mutableBytes;

    for ( NSUInteger i = 0; i < rows * cols; i++ ) {
        samples[i] = i;
    }

    CPTNumericData *fd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(NSUInteger), NSHostByteOrder())
                                                        shape:@[@(rows), @(cols)]
                                                    dataOrder:CPTDataOrderRowsFirst];

    XCTAssertEqual(([fd sampleIndex:rows, 0]), (NSUInteger)NSNotFound, @"row index out of range");
    XCTAssertEqual(([fd sampleIndex:0, cols]), (NSUInteger)NSNotFound, @"column index out of range");

    for ( NSUInteger i = 0; i < rows; i++ ) {
        for ( NSUInteger j = 0; j < cols; j++ ) {
            XCTAssertEqual(([fd sampleIndex:i, j]), i * cols + j, @"(%lu, %lu)", (unsigned long)i, (unsigned long)j);
        }
    }
}

-(void)testSampleIndexColumnsFirstOrder
{
    const NSUInteger rows = 3;
    const NSUInteger cols = 4;

    NSMutableData *data = [NSMutableData dataWithLength:rows * cols * sizeof(NSUInteger)];
    NSUInteger *samples = (NSUInteger *)data.mutableBytes;

    for ( NSUInteger i = 0; i < rows * cols; i++ ) {
        samples[i] = i;
    }

    CPTNumericData *fd = [[CPTNumericData alloc] initWithData:data
                                                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(NSUInteger), NSHostByteOrder())
                                                        shape:@[@(rows), @(cols)]
                                                    dataOrder:CPTDataOrderColumnsFirst];

    XCTAssertEqual(([fd sampleIndex:rows, 0]), (NSUInteger)NSNotFound, @"row index out of range");
    XCTAssertEqual(([fd sampleIndex:0, cols]), (NSUInteger)NSNotFound, @"column index out of range");

    for ( NSUInteger i = 0; i < rows; i++ ) {
        for ( NSUInteger j = 0; j < cols; j++ ) {
            XCTAssertEqual(([fd sampleIndex:i, j]), i + j * rows, @"(%lu, %lu)", (unsigned long)i, (unsigned long)j);
        }
    }
}

@end
