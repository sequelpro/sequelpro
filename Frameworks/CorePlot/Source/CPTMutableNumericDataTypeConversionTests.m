#import "CPTMutableNumericDataTypeConversionTests.h"

#import "CPTMutableNumericData+TypeConversion.h"
#import "CPTUtilities.h"

static const NSUInteger numberOfSamples = 5;
static const double precision           = 1.0e-6;

@implementation CPTMutableNumericDataTypeConversionTests

-(void)testFloatToDoubleInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sinf(i);
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                                               shape:nil];

    numericData.sampleBytes = sizeof(double);

    const double *doubleSamples = (const double *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertEqualWithAccuracy((double)samples[i], doubleSamples[i], precision, @"(float)%g != (double)%g", (double)samples[i], doubleSamples[i]);
    }
}

-(void)testDoubleToFloatInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(double)];
    double *samples     = (double *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sin(i);
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), NSHostByteOrder())
                                                                               shape:nil];

    numericData.sampleBytes = sizeof(float);

    const float *floatSamples = (const float *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertEqualWithAccuracy((double)floatSamples[i], samples[i], precision, @"(float)%g != (double)%g", (double)floatSamples[i], samples[i]);
    }
}

-(void)testFloatToIntegerInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(float)];
    float *samples      = (float *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sinf(i) * 1000.0f;
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder())
                                                                               shape:nil];

    numericData.dataType = CPTDataType(CPTIntegerDataType, sizeof(NSInteger), NSHostByteOrder());

    const NSInteger *intSamples = (const NSInteger *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertEqualWithAccuracy((NSInteger)samples[i], intSamples[i], precision, @"(float)%g != (NSInteger)%ld", (double)samples[i], (long)intSamples[i]);
    }
}

-(void)testIntegerToFloatInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(NSInteger)];
    NSInteger *samples  = (NSInteger *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = (NSInteger)(sin(i) * 1000.0);
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTIntegerDataType, sizeof(NSInteger), NSHostByteOrder())
                                                                               shape:nil];

    numericData.dataType = CPTDataType(CPTFloatingPointDataType, sizeof(float), NSHostByteOrder());

    const float *floatSamples = (const float *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertEqualWithAccuracy(floatSamples[i], (float)samples[i], (float)precision, @"(float)%g != (NSInteger)%ld", (double)floatSamples[i], (long)samples[i]);
    }
}

-(void)testDecimalToDoubleInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(NSDecimal)];
    NSDecimal *samples  = (NSDecimal *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = CPTDecimalFromDouble(sin(i));
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTDecimalDataType, sizeof(NSDecimal), NSHostByteOrder())
                                                                               shape:nil];

    numericData.dataType = CPTDataType(CPTFloatingPointDataType, sizeof(double), NSHostByteOrder());

    const double *doubleSamples = (const double *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertEqual(CPTDecimalDoubleValue(samples[i]), doubleSamples[i], @"(NSDecimal)%@ != (double)%g", CPTDecimalStringValue(samples[i]), doubleSamples[i]);
    }
}

-(void)testDoubleToDecimalInPlaceConversion
{
    NSMutableData *data = [NSMutableData dataWithLength:numberOfSamples * sizeof(double)];
    double *samples     = (double *)data.mutableBytes;

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sin(i);
    }

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:data
                                                                            dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), NSHostByteOrder())
                                                                               shape:nil];

    numericData.dataType = CPTDataType(CPTDecimalDataType, sizeof(NSDecimal), NSHostByteOrder());

    const NSDecimal *decimalSamples = (const NSDecimal *)numericData.data.bytes;
    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        XCTAssertTrue(CPTDecimalEquals(decimalSamples[i], CPTDecimalFromDouble(samples[i])), @"(NSDecimal)%@ != (double)%g", CPTDecimalStringValue(decimalSamples[i]), samples[i]);
    }
}

-(void)testTypeConversionSwapsByteOrderIntegerInPlace
{
    CFByteOrder hostByteOrder    = CFByteOrderGetCurrent();
    CFByteOrder swappedByteOrder = (hostByteOrder == CFByteOrderBigEndian) ? CFByteOrderLittleEndian : CFByteOrderBigEndian;

    uint32_t start    = 1000;
    NSData *startData = [NSData dataWithBytesNoCopy:&start
                                             length:sizeof(uint32_t)
                                       freeWhenDone:NO];

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:startData
                                                                            dataType:CPTDataType(CPTUnsignedIntegerDataType, sizeof(uint32_t), hostByteOrder)
                                                                               shape:nil];

    numericData.byteOrder = swappedByteOrder;

    uint32_t end = *(const uint32_t *)numericData.bytes;
    XCTAssertEqual(CFSwapInt32(start), end, @"Bytes swapped");

    numericData.byteOrder = hostByteOrder;

    uint32_t startRoundTrip = *(const uint32_t *)numericData.bytes;
    XCTAssertEqual(start, startRoundTrip, @"Round trip");
}

-(void)testTypeConversionSwapsByteOrderDoubleInPlace
{
    CFByteOrder hostByteOrder    = CFByteOrderGetCurrent();
    CFByteOrder swappedByteOrder = (hostByteOrder == CFByteOrderBigEndian) ? CFByteOrderLittleEndian : CFByteOrderBigEndian;

    double start      = 1000.0;
    NSData *startData = [NSData dataWithBytesNoCopy:&start
                                             length:sizeof(double)
                                       freeWhenDone:NO];

    CPTMutableNumericData *numericData = [[CPTMutableNumericData alloc] initWithData:startData
                                                                            dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), hostByteOrder)
                                                                               shape:nil];

    numericData.byteOrder = swappedByteOrder;

    uint64_t end = *(const uint64_t *)numericData.bytes;
    union swap {
        double           v;
        CFSwappedFloat64 sv;
    }
    result;
    result.v = start;
    XCTAssertEqual(CFSwapInt64(result.sv.v), end, @"Bytes swapped");

    numericData.byteOrder = hostByteOrder;

    double startRoundTrip = *(const double *)numericData.bytes;
    XCTAssertEqual(start, startRoundTrip, @"Round trip");
}

@end
