#import "JATemplateTests.h"
#import "JATemplate.h"


@implementation JATemplateTests

- (void) testTrivial
{
	NSString *template = @"Trivial string with no substitutions";
	NSString *expansion = JATExpand(template);
	
	STAssertEqualObjects(expansion, template, @"Template with no substitutions should be unchanged after expansion.");
}


- (void) testBasicSubstitution
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo}", foo);
	
	STAssertEqualObjects(expansion, foo, @"Substitution of entire string failed.");
}


- (void) testBoxedNumberSubstitution
{
	int foo = 42;
	NSString *expansion = JATExpand(@"{foo}", @(foo));
	
	STAssertEqualObjects(expansion, @"42", @"Substitution of entire string using boxed variable failed.");
}


- (void) testBoxedStringSubstitution
{
	const char *foo = "frob";
	NSString *expansion = JATExpand(@"{foo}", @(foo));
	
	STAssertEqualObjects(expansion, @"frob", @"Substitution of entire string using boxed variable failed.");
}


- (void) testBasicSubstitutionAtStart
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo} at start", foo);
	
	STAssertEqualObjects(expansion, @"frob at start", @"Substitution at beginning of string failed.");
}


- (void) testBasicSubstitutionAtEnd
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"at end: {foo}", foo);
	
	STAssertEqualObjects(expansion, @"at end: frob", @"Substitution at end of string failed.");
}


- (void) testBasicSubstitutionInMiddle
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"This has {foo} in the middle", foo);
	
	STAssertEqualObjects(expansion, @"This has frob in the middle", @"Substitution in middle of string failed.");
}


- (void) testRepeatedBasicSubstitution
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo} and {foo} and {foo} again", foo);
	
	STAssertEqualObjects(expansion, @"frob and frob and frob again", @"Repeated substitution failed.");
}


- (void) testMultipleBasicSubstitution
{
	NSString *foo = @"frob";
	NSString *bar = @"banana";
	NSString *expansion = JATExpand(@"{foo} and {bar} and {foo} and {bar}", foo, bar);
	
	STAssertEqualObjects(expansion, @"frob and banana and frob and banana", @"Expansion with multiple substitutions failed.");
}


- (void) testBraceExpansion
{
	NSString *expansion = JATExpand(@"{(} {)}");
	
	STAssertEqualObjects(expansion, @"{ }", @"Brace escape handling failed.");
}


- (void) testMultipleOperators
{
	NSString *foo = @"frob";
	NSString *expansion = JATExpand(@"{foo|uppercase} {foo|capitalize}", foo);
	
	STAssertEqualObjects(expansion, @"FROB Frob", @"Expansion with multiple substitutions using operators failed.");
}


- (void) testChainedOperators
{
	int foo = 76;
	NSString *expansion = JATExpand(@"{foo|num:spellout|capitalize}", @(foo));
	
	STAssertEqualObjects(expansion, @"Seventy-Six", @"Expansion with chained substitutions using operators failed.");
}


- (void) testLocalization
{
	NSString *localizationFile = @"Localizable.strings";
	NSString *expansion = JATExpand(@"This is a template in the source code, not from {localizationFile}.", localizationFile);
	
	STAssertEqualObjects(expansion, @"This is a template from Localizable.strings, not the one in the source code.", @"Localized template lookup failed.");
}

@end
