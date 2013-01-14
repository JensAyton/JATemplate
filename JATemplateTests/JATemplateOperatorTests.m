#import "JATemplateOperatorTests.h"
#import "JATemplate.h"


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
}


- (void) testImplicitNumDecimal
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo}", @(foo));
	
	STAssertEqualObjects(expansion, @"10,723.056", @"number-to-string coersion failed.");
}


- (void) testOperatorRound
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|round}", @(foo));
	
	STAssertEqualObjects(expansion, @"10,723", @"round operator failed.");
}


- (void) testOperatorNumDecimal
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|num:decimal}", @(foo));
	
	STAssertEqualObjects(expansion, @"10,723.056", @"num:decimal operator failed.");
}


- (void) testOperatorNumNoloc
{
	double foo = 10723.056;
	NSString *expansion = JATExpand(@"{foo|num:noloc}", @(foo));
	
	STAssertEqualObjects(expansion, @"10723.056", @"num:noloc operator failed.");
}


- (void) testOperatorNumCurrency
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:currency}", @(foo));
	
	STAssertEqualObjects(expansion, @"$723.06", @"num:currency operator failed.");
}


- (void) testOperatorNumPercent
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:percent}", @(foo));
	
	STAssertEqualObjects(expansion, @"72,306%", @"num:percent operator failed.");
}


- (void) testOperatorNumScientific
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:scientific}", @(foo));
	
	STAssertEqualObjects(expansion, @"7.23056E2", @"num:scientific operator failed.");
}


- (void) testOperatorNumSpellout
{
	double foo = 723.056;
	NSString *expansion = JATExpand(@"{foo|num:spellout}", @(foo));
	
	STAssertEqualObjects(expansion, @"seven hundred twenty-three point zero five six", @"num:spellout operator failed.");
}


- (void) testOperatorNumDecimalBytes
{
	double foo = 723056;
	NSString *expansion = JATExpand(@"{foo|num:decimalbytes}", @(foo));
	
	STAssertEqualObjects(expansion, @"723 KB", @"num:decimalbytes operator failed.");
}


- (void) testOperatorNumBinaryBytes
{
	double foo = 723056;
	NSString *expansion = JATExpand(@"{foo|num:binarybytes}", @(foo));
	
	STAssertEqualObjects(expansion, @"706 KB", @"num:binarybytes operator failed.");
}


// TODO: a few tests of num: with NSNumberFormatter format strings.


- (void) testOperatorPlural
{
	unsigned myKittenCount = 1;
	unsigned myGooseCount = 7;
	unsigned yourKittenCount = 3;
	unsigned yourGooseCount = 1;
	NSString *expansion = JATExpand(@"I have {myKittenCount|num:spellout} kitten{myKittenCount|plural:s}. You have {yourKittenCount|num:spellout} kitten{yourKittenCount|plural:s}. I have {myGooseCount|num:spellout} {myGooseCount|plural:goose;geese}. You have {yourGooseCount|num:spellout} {yourGooseCount|plural:goose;geese}.", @(myKittenCount), @(myGooseCount), @(yourKittenCount), @(yourGooseCount));
	
	STAssertEqualObjects(expansion, @"I have one kitten. You have three kittens. I have seven geese. You have one goose.", @"plural: operator failed.");
}


- (void) testOperatorNot
{
	NSNumber *yes = @YES;
	NSNumber *no = @NO;
	NSString *expansion = JATExpand(@"{yes} {no} {yes|not} {no|not}", yes, no);
	
	STAssertEqualObjects(expansion, @"1 0 0 1", @"not operator failed.");
	
}


- (void) testOperatorIf
{
	NSNumber *yes = @YES;
	NSNumber *no = @NO;
	NSString *expansion = JATExpand(@"{yes|if:yep!;nope!} {no|if:yep!;nope!}", yes, no);
	
	STAssertEqualObjects(expansion, @"yep! nope!", @"if: operator failed.");
}


- (void) testOperatorIfuse
{
	NSNumber *yes = @YES;
	NSNumber *no = @NO;
	NSString *yesString = @"yep!";
	NSString *noString = @"nope!";
	NSString *expansion = JATExpand(@"{yes|ifuse:yesString;noString} {no|ifuse:yesString;noString}", yes, no, yesString, noString);
	
	STAssertEqualObjects(expansion, @"yep! nope!", @"ifuse: operator failed.");
}


- (void) testOperatorUppercase
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|uppercase}", foo);
	
	STAssertEqualObjects(expansion, @"FROB", @"uppercase operator failed.");
}


- (void) testOperatorLowercase
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|lowercase}", foo);
	
	STAssertEqualObjects(expansion, @"frob", @"lowercase operator failed.");
}


- (void) testOperatorCapitalize
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|capitalize}", foo);
	
	STAssertEqualObjects(expansion, @"Frob", @"capitalize operator failed.");
}


- (void) testOperatorUppercaseNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|uppercase_noloc}", foo);
	
	STAssertEqualObjects(expansion, @"FROB", @"uppercase_noloc operator failed.");
}


- (void) testOperatorLowercaseNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|lowercase_noloc}", foo);
	
	STAssertEqualObjects(expansion, @"frob", @"lowercase_noloc operator failed.");
}


- (void) testOperatorCapitalizeNoloc
{
	NSString *foo = @"fRoB";
	NSString *expansion = JATExpand(@"{foo|capitalize_noloc}", foo);
	
	STAssertEqualObjects(expansion, @"Frob", @"capitalize_noloc operator failed.");
}


- (void) testOperatorTrim
{
	NSString *foo = @"  \n frob  \t ";
	NSString *expansion = JATExpand(@"{foo|trim}", foo);
	
	STAssertEqualObjects(expansion, @"frob", @"trim operator failed.");
}


- (void) testOperatorLength
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo|length}", foo);
	
	STAssertEqualObjects(expansion, @"4", @"length operator failed.");
}


- (void) testOperatorFold
{
	NSString *foo = @"FrÖｂ";
	NSString *expansion = JATExpand(@"{foo|fold:diacritics,width,case}", foo);
	
	STAssertEqualObjects(expansion, @"frob", @"fold operator failed.");
}

@end
