#import "JATAppDelegate.h"
#import "JATemplate.h"


static void RunTests(void)
{
	// Test that it works with no parameters.
	JATLog(@"Trivial string");
	
	// Test substitution.
	NSString *foo = @"sausage";
	int bar = 76;
	JATLog(@"foo: {foo}; bar: {bar}", foo, @(bar));
	
	// Test unknown parameter. Template system should log a warning before this line.
	JATLog(@"Unknown variable: {nonesuch}");
	
	// Test formatting operators. Also a redundant parameter, and reuse of a cached parameter list parse.
	JATLog(@"Fancy bar: {bar|num:spellout|capitalize}", foo, @(bar));
	
	// Test positional parameters.
	int anotherNumber = 30;
	JATLog(@"The sum of {bar} and {anotherNumber} is {2}.", @(bar), @(anotherNumber), @(bar + anotherNumber));
	
	// Test booleans.
	NSNumber *boolValue = @NO;
	JATLog(@"Boolean: {boolValue|if:true;false}", boolValue);
	
	// Test byte size formatting.
	NSUInteger byteSize = 65536;
	JATLog(@"File bytes: {byteSize|num:filebytes}; memory bytes: {byteSize|num:memorybytes}", @(byteSize));
	
	// Test plural: operator.
	unsigned myKittenCount = 1;
	unsigned myGooseCount = 7;
	unsigned yourKittenCount = 3;
	unsigned yourGooseCount = 1;
	JATLog(@"I have {myKittenCount|num:spellout} kitten{myKittenCount|plural:s}. You have {yourKittenCount|num:spellout} kitten{yourKittenCount|plural:s}. I have {myGooseCount|num:spellout} {myGooseCount|plural:goose;geese}. You have {yourGooseCount|num:spellout} {yourGooseCount|plural:goose;geese}.", @(myKittenCount), @(myGooseCount), @(yourKittenCount), @(yourGooseCount));
	
	// Test select: operator.
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *dateComponents = [calendar components:NSWeekdayCalendarUnit fromDate:NSDate.date];
	NSUInteger weekDay = dateComponents.weekday - 1;
	JATLog(@"Today is {weekDay|select:Sunday;Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Blarnsday}.", @(weekDay));
	
	// Test fold: operator.
	NSString *blargh = @"BläÄ";
	JATLog(@"Fold operator: {blargh|fold:case,diacritics}", blargh);
	
	// Test brace escapes.
	JATLog(@"Braces: int main() {{ return 0; }}");
	
	// Test localization.
	NSString *localizationFile = @"Localizable.strings";
	JATLog(@"{0}", JATExpand(@"This is a template in the source code, not from {localizationFile}.", localizationFile));
	
	// Test Boring Mode.
	NSString *boring = JATExpandWithParameters(@"boring_mode_test", @{ @"boring": @"SUPER EXCITING!" });
	NSLog(@"%@", boring);
	
	// Test debugdesc.
	NSArray *array = @[@"foo", @36, @YES];
	JATLog(@"Debug description: {array|debugdesc}", array);
}


@implementation JATAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	RunTests();	
	[NSApp terminate:nil];
}

@end
