#import <XCTest/XCTest.h>

#import "JATemplateTests.h"
#import "JATemplate.h"


@interface JATemplateOperatorTests: XCTestCase
@end


@implementation JATemplateOperatorTests

- (void) setUp
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// Check that locale is en_US. NOTE: in the shared JATemplate scheme,
		// this is ensured using a command line argument.
		
		NSString *localeID = [NSLocale.currentLocale localeIdentifier];
		if (![localeID isEqual:@"en_US"])
		{
			JATLog(@"\n\nWARNING: unit tests assume en_US locale, your current locale is {localeID}.\n\n", localeID);
		}
	});
	JATResetWarnings();
}


- (void) testImplicitNumDecimal
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"10,723.056", @"number-to-string coersion failed.");
}


- (void) testOperatorRound
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|round}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"10,723", @"round operator failed.");
}


- (void) testOperatorNumDecimal
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|num:decimal}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"10,723.056", @"num:decimal operator failed.");
}


- (void) testOperatorNumHex
{
	int foo = 0x4a;
	NSString *expansion = JATExpand(@"{foo|num:hex}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"4a", @"num:hex operator failed.");
}


- (void) testOperatorNumHexArg
{
	int foo = 0x4a;
	NSString *expansion = JATExpand(@"{foo|num:hex;5}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"0004a", @"num:hex;5 operator failed.");
}


- (void) testOperatorNumHEX
{
	int foo = 0x4a;
	NSString *expansion = JATExpand(@"{foo|num:HEX}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"4A", @"num:HEX operator failed.");
}


- (void) testOperatorNumHEXArg
{
	int foo = 0x4a;
	NSString *expansion = JATExpand(@"{foo|num:HEX;5}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"0004A", @"num:HEX;5 operator failed.");
}


- (void) testOperatorNumNoloc
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|num:noloc}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"10723.056", @"num:noloc operator failed.");
}


- (void) testOperatorNumCurrency
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:currency}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"$723.06", @"num:currency operator failed.");
}


- (void) testOperatorNumPercent
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:percent}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"72,306%", @"num:percent operator failed.");
}


- (void) testOperatorNumScientific
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:scientific}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"7.23056E2", @"num:scientific operator failed.");
}


- (void) testOperatorNumSpellout
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:spellout}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"seven hundred twenty-three point zero five six", @"num:spellout operator failed.");
}


- (void) testOperatorNumDecimalBytes
{
	double foo = 723056;
	NSString *expansion = JATExpand(@"{foo|num:decimalbytes}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"723 KB", @"num:decimalbytes operator failed.");
}


- (void) testOperatorNumBinaryBytes
{
	double foo = 723056;
	NSString *expansion = JATExpand(@"{foo|num:binarybytes}", @(foo));
	
	XCTAssertEqualObjects(expansion, @"706 KB", @"num:binarybytes operator failed.");
}


// TODO: a few tests of num: with NSNumberFormatter format strings.


- (void) testOperatorPlural
{
	unsigned myKittenCount = 1;
	unsigned myGooseCount = 7;
	unsigned yourKittenCount = 3;
	unsigned yourGooseCount = 1;
	NSString *expansion = JATExpand(@"I have {myKittenCount|num:spellout} kitten{myKittenCount|plural:s}. You have {yourKittenCount|num:spellout} kitten{yourKittenCount|plural:s}. I have {myGooseCount|num:spellout} {myGooseCount|plural:goose;geese}. You have {yourGooseCount|num:spellout} {yourGooseCount|plural:goose;geese}.", @(myKittenCount), @(myGooseCount), @(yourKittenCount), @(yourGooseCount));
	
	XCTAssertEqualObjects(expansion, @"I have one kitten. You have three kittens. I have seven geese. You have one goose.", @"plural: operator failed.");
}


- (void) testOperatorPluralNesting
{
	NSString *sing = @"frog";
	NSString *plur = @"frogs";
	NSString *expansion = JATExpand(@"{0} {0|plural:{sing};{plur}} {1} {1|plural:{sing};{plur}} {2} {2|plural:{sing|uppercase};{plur|uppercase}}", @1, @2, @3, sing, plur);
	
	XCTAssertEqualObjects(expansion, @"1 frog 2 frogs 3 FROGS", @"plural: operator with nested expansions failed.");
}


- (void) testOperatorIf
{
	NSNumber *yes = @YES;
	NSNumber *no = @NO;
	NSString *expansion = JATExpand(@"{yes|if:yep!;nope!} {no|if:yep!;nope!}", yes, no);
	
	XCTAssertEqualObjects(expansion, @"yep! nope!", @"if: operator failed.");
}


- (void) testOperatorSelect
{
	NSUInteger weekDay = 4;
	NSString *expansion = JATExpand(@"Gotta get down on {weekDay|select:Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday;Blarnsday}", @(weekDay));
	
	XCTAssertEqualObjects(expansion, @"Gotta get down on Friday", @"select: operator failed.");
}


- (void) testOperatorOrTrueString
{
	NSString *value = @"foo";
	NSString *expansion = JATExpand(@"{value|or:bar}", value);
	
	XCTAssertEqualObjects(expansion, @"foo", @"{foo|or:bar} should return foo if it is a non-empty string.");
}


- (void) testOperatorOrFalseString
{
	NSString *value = @"";
	NSString *expansion = JATExpand(@"{value|or:bar}", value);
	
	XCTAssertEqualObjects(expansion, @"bar", @"{foo|or:bar} should return bar if foo is an empty string.");
}


- (void) testOperatorOrTrueNumber
{
	NSNumber *value = @YES;
	NSString *expansion = JATExpand(@"{value|or:bar}", value);
	
	XCTAssertEqualObjects(expansion, @"1", @"{foo|or:bar} should return foo if it is a non-zero number.");
}


- (void) testOperatorOrFalseNumber
{
	NSNumber *value = @NO;
	NSString *expansion = JATExpand(@"{value|or:bar}", value);
	
	XCTAssertEqualObjects(expansion, @"bar", @"{foo|or:bar} should return bar if foo is a zero number.");
}


- (void) testOperatorIfWithNestedTemplates
{
	NSNumber *yes = @YES;
	NSNumber *no = @NO;
	NSString *yesString = @"yep!";
	NSString *noString = @"nope!";
	NSString *expansion = JATExpand(@"{yes|if:{yesString};{noString}} {no|if:{yesString};{noString}}", yes, no, yesString, noString);
	
	XCTAssertEqualObjects(expansion, @"yep! nope!", @"if: operator failed.");
}


- (void) testOperatorUppercase
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|uppercase}", foo);
	
	XCTAssertEqualObjects(expansion, @"FROB", @"uppercase operator failed.");
}


- (void) testOperatorLowercase
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|lowercase}", foo);
	
	XCTAssertEqualObjects(expansion, @"frob", @"lowercase operator failed.");
}


- (void) testOperatorCapitalize
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|capitalize}", foo);
	
	XCTAssertEqualObjects(expansion, @"Frob", @"capitalize operator failed.");
}


- (void) testOperatorUppercaseNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|uppercase_noloc}", foo);
	
	XCTAssertEqualObjects(expansion, @"FROB", @"uppercase_noloc operator failed.");
}


- (void) testOperatorLowercaseNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|lowercase_noloc}", foo);
	
	XCTAssertEqualObjects(expansion, @"frob", @"lowercase_noloc operator failed.");
}


- (void) testOperatorCapitalizeNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|capitalize_noloc}", foo);
	
	XCTAssertEqualObjects(expansion, @"Frob", @"capitalize_noloc operator failed.");
}


- (void) testOperatorTrim
{
	NSString *foo = @"  \n frob  \t ";
	NSString *expansion = JATExpand(@"{foo|trim}", foo);
	
	XCTAssertEqualObjects(expansion, @"frob", @"trim operator failed.");
}


- (void) testOperatorLength
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo|length}", foo);
	
	XCTAssertEqualObjects(expansion, @"4", @"length operator failed.");
}


- (void) testOperatorFold
{
	NSString *foo = @"FrÖｂ";
	NSString *expansion = JATExpand(@"{foo|fold:diacritics,width,case}", foo);
	
	XCTAssertEqualObjects(expansion, @"frob", @"fold operator failed.");
}


#pragma mark fit: and trunc: operators

- (void) testOperatorFitPadEnd
{
	NSString *foo = @"test";
	NSUInteger length = 10;
	NSString *expansion = JATExpand(@"{foo|fit:{length}}", foo, @(length));
	
	XCTAssertEqualObjects(expansion, @"test      ", @"fit: operator failed at end padding.");
}


- (void) testOperatorFitPadStart
{
	NSString *foo = @"test";
	NSUInteger length = 10;
	NSString *mode = @"start";
	NSString *expansion = JATExpand(@"{foo|fit:{length};{mode}}", foo, @(length), mode);
	
	XCTAssertEqualObjects(expansion, @"      test", @"fit: operator failed at start padding.");
}


- (void) testOperatorFitPadCenter
{
	NSString *foo = @"test";
	NSString *expansion = JATExpand(@"{foo|fit:10;center}", foo);
	
	XCTAssertEqualObjects(expansion, @"   test   ", @"fit: operator failed at center padding.");
}


- (void) testOperatorFitExactFit
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:11}", foo);
	
	XCTAssertEqualObjects(expansion, @"test string", @"fit: operator failed with exact fit.");
}


- (void) testOperatorFitTruncEnd
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10}", foo);
	
	XCTAssertEqualObjects(expansion, @"test stri…", @"fit: operator failed at end truncation.");
}


- (void) testOperatorFitTruncCenter
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10;;center}", foo);
	
	XCTAssertEqualObjects(expansion, @"test …ring", @"fit: operator failed at center truncation.");
}


- (void) testOperatorFitTruncStart
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10;;start}", foo);
	
	XCTAssertEqualObjects(expansion, @"…st string", @"fit: operator failed at start truncation.");
}


- (void) testOperatorFitTruncCustom
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10;;;...}", foo);
	
	XCTAssertEqualObjects(expansion, @"test st...", @"fit: operator failed with custom truncation replacement.");
}


- (void) testOperatorFitTruncExactReplace
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10;;;replace me}", foo);
	
	XCTAssertEqualObjects(expansion, @"replace me", @"fit: operator failed with exact-width truncation replacement.");
}


- (void) testOperatorFitTruncHuge
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|fit:10;;;long replacement string is long}", foo);
	
	XCTAssertEqualObjects(expansion, @"long replacement string is long", @"fit: operator failed with overlong truncation replacement.");
}


- (void) testOperatorTruncEnd
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|trunc:6}", foo);
	
	XCTAssertEqualObjects(expansion, @"test s", @"trunc: operator failed at end truncation.");
}


- (void) testOperatorTruncCenter
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|trunc:6;center}", foo);
	
	XCTAssertEqualObjects(expansion, @"tesing", @"trunc: operator failed at center truncation.");
}


- (void) testOperatorTruncStart
{
	NSString *foo = @"test string";
	NSString *expansion = JATExpand(@"{foo|trunc:6;start}", foo);
	
	XCTAssertEqualObjects(expansion, @"string", @"trunc: operator failed at start truncation.");
}

@end
