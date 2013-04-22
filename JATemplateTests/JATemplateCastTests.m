#import "JATemplateCastTests.h"
#import "JATemplate.h"


@implementation JATemplateCastTests

- (void) testCastChar
{
	char value = 1;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"1", @"parameter cast from [char] failed.");
}


- (void) testCastSignedChar
{
	signed char value = -2;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"-2", @"parameter cast from [signed char] failed.");
}


- (void) testCastUnsignedChar
{
	unsigned char value = 3;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"3", @"parameter cast from [unsigned char] failed.");
}


- (void) testCastSignedShort
{
	signed short value = -4;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"-4", @"parameter cast from [signed short] failed.");
}


- (void) testCastUnsignedShort
{
	unsigned short value = 5;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"5", @"parameter cast from [unsigned short] failed.");
}


- (void) testCastSignedInt
{
	signed int value = -6;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"-6", @"parameter cast from [signed int] failed.");
}


- (void) testCastUnsignedInt
{
	unsigned int value = 7;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"7", @"parameter cast from [unsigned long] failed.");
}


- (void) testCastSignedLong
{
	signed long value = -8;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"-8", @"parameter cast from [signed int] failed.");
}


- (void) testCastUnsignedLong
{
	unsigned long value = 9;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"9", @"parameter cast from [unsigned long] failed.");
}


- (void) testCastSignedLongLong
{
	signed long long value = -10;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"-10", @"parameter cast from [signed long long] failed.");
}


- (void) testCastUnsignedLongLong
{
	unsigned long long value = 11;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"11", @"parameter cast from [unsigned long long] failed.");
}


- (void) testCastFloat
{
	float value = 12.5;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"12.5", @"parameter cast from [float] failed.");
}


- (void) testCastDouble
{
	double value = 13.75;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"13.75", @"parameter cast from [double] failed.");
}


- (void) testCastLongDouble
{
	long double value = 14.875;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"14.875", @"parameter cast from [long double] failed.");
}


- (void) testCastCString
{
	const char *value = "If you want a picture of the future, imagine a boot stamping on a human face — forever.";
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"If you want a picture of the future, imagine a boot stamping on a human face — forever.", @"parameter cast from [const char *] failed.");
}


#if JATEMPLATE_OBJCPP
- (void) testCastCppString
{
	std::string value = "stability. No civilization without social stability. No social stability without individual stability.";
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"stability. No civilization without social stability. No social stability without individual stability.", @"parameter cast from [std::string] failed.");
}
#endif


- (void) testCastCFString
{
	CFStringRef value = CFSTR("If they give you ruled paper, write the other way.");
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"If they give you ruled paper, write the other way.", @"parameter cast from [CFStringRef] failed.");
}


- (void) testCastCFNumber
{
	int number = 15;
	CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &number);
	NSString *expansion = JATExpand(@"{value}", value);
	CFRelease(value);
	
	STAssertEqualObjects(expansion, @"15", @"parameter cast from [CFNumberRef] failed.");
}


- (void) testCastCFBoolean
{
	CFBooleanRef value = kCFBooleanTrue;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"1", @"parameter cast from [CFBooleanRef] failed.");
}


- (void) testCastNSPoint
{
	NSPoint value = { -16, 17 };
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertTrue(NSEqualPoints(value, NSPointFromString(expansion)), @"parameter cast from [NSPoint] failed.");
}


- (void) testCastNSSize
{
	NSSize value = { 18, 19 };
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertTrue(NSEqualSizes(value, NSSizeFromString(expansion)), @"parameter cast from [NSSize] failed.");
}


- (void) testCastNSRect
{
	NSRect value = NSMakeRect(20, -21, 22, 23);
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertTrue(NSEqualRects(value, NSRectFromString(expansion)), @"parameter cast from [NSRect] failed.");
}


- (void) testCastNSRange
{
	NSRange value = { 24, 25 };
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertTrue(NSEqualRanges(value, NSRangeFromString(expansion)), @"parameter cast from [NSRange] failed.");
}


#if JATEMPLATE_OBJCPP
- (void) testCastCppNullPtr
{
	NSString *expansion = JATExpand(@"{0}", nullptr);
	
	STAssertEqualObjects(expansion, @"(null)", @"parameter cast from [std::nullptr_t] failed.");
}
#endif


typedef struct
{
	int a, b, c;
} CustomStruct;

JATDefineCast(CustomStruct)
{
	return @(value.a + value.b + value.c);
}


- (void) testCastCustom
{
	CustomStruct value = { 26, 27, 28 };
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"81", @"parameter cast from [CustomStruct] failed.");
}


#if JATEMPLATE_OBJCPP
enum class CustomEnumClass
{
	vanilla, chocolate, strawberry
};


JATDefineCast(CustomEnumClass)
{
	switch (value)
	{
		case CustomEnumClass::vanilla:
			return @"vanilla";
			
		case CustomEnumClass::chocolate:
			return @"chocolate";
			
		case CustomEnumClass::strawberry:
			return @"strawberry";
	}
	
#pragma clang diagnostic ignored "-Wunreachable-code"
	return @"<error>";
}


- (void) testCastCustomEnumClass
{
	CustomEnumClass value = CustomEnumClass::chocolate;
	NSString *expansion = JATExpand(@"{value}", value);
	
	STAssertEqualObjects(expansion, @"chocolate", @"parameter cast from [CustomEnumClass] failed.");
}
#endif

@end
