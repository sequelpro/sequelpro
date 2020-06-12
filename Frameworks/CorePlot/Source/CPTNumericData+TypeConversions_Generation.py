dataTypes = ["CPTUndefinedDataType", "CPTIntegerDataType", "CPTUnsignedIntegerDataType", "CPTFloatingPointDataType", "CPTComplexFloatingPointDataType", "CPTDecimalDataType"]

types = { "CPTUndefinedDataType" : [],
        "CPTIntegerDataType" : ["int8_t", "int16_t", "int32_t", "int64_t"],
        "CPTUnsignedIntegerDataType" : ["uint8_t", "uint16_t", "uint32_t", "uint64_t"],
        "CPTFloatingPointDataType" : ["float", "double"],
        "CPTComplexFloatingPointDataType" : ["float complex", "double complex"],
        "CPTDecimalDataType" : ["NSDecimal"] }

nsnumber_factory = { "int8_t" : "Char",
                    "int16_t" : "Short",
                    "int32_t" : "Long",
                    "int64_t" : "LongLong",
                    "uint8_t" : "UnsignedChar",
                   "uint16_t" : "UnsignedShort",
                   "uint32_t" : "UnsignedLong",
                   "uint64_t" : "UnsignedLongLong",
                      "float" : "Float",
                     "double" : "Double",
              "float complex" : "Float",
             "double complex" : "Double",
                  "NSDecimal" : "Decimal"
}

nsnumber_methods = { "int8_t" : "char",
                    "int16_t" : "short",
                    "int32_t" : "long",
                    "int64_t" : "longLong",
                    "uint8_t" : "unsignedChar",
                   "uint16_t" : "unsignedShort",
                   "uint32_t" : "unsignedLong",
                   "uint64_t" : "unsignedLongLong",
                      "float" : "float",
                     "double" : "double",
              "float complex" : "float",
             "double complex" : "double",
                  "NSDecimal" : "decimal"
}

null_values = { "int8_t" : "0",
               "int16_t" : "0",
               "int32_t" : "0",
               "int64_t" : "0",
               "uint8_t" : "0",
              "uint16_t" : "0",
              "uint32_t" : "0",
              "uint64_t" : "0",
                 "float" : "NAN",
                "double" : "(double)NAN",
         "float complex" : "CMPLXF(NAN, NAN)",
        "double complex" : "CMPLX(NAN, NAN)",
             "NSDecimal" : "CPTDecimalNaN()"
}

print "[CPTNumericData sampleValue:]"
print ""
print "switch ( self.dataTypeFormat ) {"
for dt in dataTypes:
    print "\tcase %s:" % dt
    if ( len(types[dt]) == 0 ):
        print '\t\t[NSException raise:NSInvalidArgumentException format:@"Unsupported data type (%s)"];' % (dt)
    else:
        print "\t\tswitch ( self.sampleBytes ) {"
        for t in types[dt]:
            print "\t\t\tcase sizeof(%s):" % t
            if ( t == "float complex" ):
                print "\t\t\t\tresult = @(*( crealf(const %s *)[self samplePointer:sample]) );" % (t)
            elif ( t == "double complex" ):
                print "\t\t\t\tresult = @(*( creal(const %s *)[self samplePointer:sample]) );" % (t)
            elif ( t == "NSDecimal" ):
                print "\t\t\t\tresult = [NSDecimalNumber decimalNumberWithDecimal:*(const %s *)[self samplePointer:sample]];" % (t)
            else:
                print "\t\t\t\tresult = @(*(const %s *)[self samplePointer:sample]);" % (t)
            print "\t\t\t\tbreak;"
        print "\t\t}"
    print "\t\tbreak;"
print "}"

print "\n\n"
print "---------------"
print "\n\n"

print "[CPTNumericData dataFromArray:dataType:]"
print ""
print "switch ( newDataType.dataTypeFormat ) {"
for dt in dataTypes:
    print "\tcase %s:" % dt
    if ( len(types[dt]) == 0 ):
        print "\t\t// Unsupported"
    else:
        print "\t\tswitch ( newDataType.sampleBytes ) {"
        for t in types[dt]:
            print "\t\t\tcase sizeof(%s): {" % t
            print "\t\t\t\t%s *toBytes = (%s *)sampleData.mutableBytes;" % (t, t)
            print "\t\t\t\tfor ( id sample in newData ) {"
            print "\t\t\t\t\tif ( [sample respondsToSelector:@selector(%sValue)] ) {" % nsnumber_methods[t]
            print "\t\t\t\t\t\t*toBytes++ = (%s)[sample %sValue];" % (t, nsnumber_methods[t])
            print "\t\t\t\t\t}"
            print "\t\t\t\t\telse {"
            print "\t\t\t\t\t\t*toBytes++ = %s;" % null_values[t]
            print "\t\t\t\t\t}"
            print "\t\t\t\t}"
            print "\t\t\t}"
            print "\t\t\t\tbreak;"
        print "\t\t}"
    print "\t\tbreak;"
print "}"

print "\n\n"
print "---------------"
print "\n\n"

print "[CPTNumericData convertData:dataType:toData:dataType:]"
print ""
print "switch ( sourceDataType->dataTypeFormat ) {"
for dt in dataTypes:
    print "\tcase %s:" % dt
    if ( len(types[dt]) > 0 ):
        print "\t\tswitch ( sourceDataType->sampleBytes ) {"
        for t in types[dt]:
            print "\t\t\tcase sizeof(%s):" % t
            print "\t\t\t\tswitch ( destDataType->dataTypeFormat ) {"
            for ndt in dataTypes:
                print "\t\t\t\t\tcase %s:" % ndt
                if ( len(types[ndt]) > 0 ):
                    print "\t\t\t\t\t\tswitch ( destDataType->sampleBytes ) {"
                    for nt in types[ndt]:
                        print "\t\t\t\t\t\t\tcase sizeof(%s): { // %s -> %s" % (nt, t, nt)
                        if ( t == nt ):
                            print "\t\t\t\t\t\t\t\t\tmemcpy(destData.mutableBytes, sourceData.bytes, sampleCount * sizeof(%s));" % t
                        else:
                            print "\t\t\t\t\t\t\t\t\tconst %s *fromBytes = (const %s *)sourceData.bytes;" % (t, t)
                            print "\t\t\t\t\t\t\t\t\tconst %s *lastSample = fromBytes + sampleCount;" % t
                            print "\t\t\t\t\t\t\t\t\t%s *toBytes = (%s *)destData.mutableBytes;" % (nt, nt)
                            if ( t == "NSDecimal" ):
                                print "\t\t\t\t\t\t\t\t\twhile ( fromBytes < lastSample ) *toBytes++ = CPTDecimal%sValue(*fromBytes++);" % nsnumber_factory[nt]
                            elif ( nt == "NSDecimal" ):
                                print "\t\t\t\t\t\t\t\t\twhile ( fromBytes < lastSample ) *toBytes++ = CPTDecimalFrom%s(*fromBytes++);" % nsnumber_factory[t]
                            else:
                                print "\t\t\t\t\t\t\t\t\twhile ( fromBytes < lastSample ) *toBytes++ = (%s)*fromBytes++;" % nt
                        print "\t\t\t\t\t\t\t\t}"
                        print "\t\t\t\t\t\t\t\tbreak;"
                    print "\t\t\t\t\t\t}"
                print "\t\t\t\t\t\tbreak;"
            print "\t\t\t\t}"
            print "\t\t\t\tbreak;"
        print "\t\t}"
    print "\t\tbreak;"
print "}"
