//
//  JAAppDelegate.m
//  JATemplate
//
//  Created by Jens Ayton on 2013-01-07.
//  Copyright (c) 2013 Jens Ayton. All rights reserved.
//

#import "JAAppDelegate.h"
#import "JATemplate.h"


@implementation JAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Test that it works with no parameters.
	JALog(@"Trivial string");
	
	// Test substitution.
	id foo = @"sausage";
	int bar = 7;
	JALog(@"foo: {foo}; bar: {bar}", foo, @(bar));
	
	// Test unknown parameter. Template system should log a warning before this line.
	JALog(@"Unknown variable: {nonesuch}");
	
	// Test formatting operators. Also a redundant parameter, and reuse of a cached parameter list parse.
	JALog(@"Fancy bar: {bar|num:spellout|capitalize}", foo, @(bar));
	
	// Test booleans.
	NSNumber *boolValue = @(NO);
	NSString *trueString = @"yes";
	NSString *falseString = @"no";
	JALog(@"Boolean: {boolValue|if:true;false}, inverted: {boolValue|not|ifuse:trueString;falseString}", boolValue, trueString, falseString);
	
	// Test byte size formatting.
	NSUInteger byteSize = 65536;
	JALog(@"File bytes: {byteSize|num:filebytes}; memory bytes: {byteSize|num:memorybytes}", @(byteSize));
	
	// Test plural: operator.
	NSUInteger catCount = 1;
	NSUInteger gooseCount = 5;
	JALog(@"I have {catCount} cat{catCount|plural:s} and {gooseCount} {gooseCount|plural:goose;geese}. That’s {gooseCount|plural:one goose;a couple of geese;several geese}.", @(catCount), @(gooseCount));
	
	// Test fold: operator.
	NSString *blargh = @"BläÄ";
	JALog(@"Fold operator: {blargh|fold:case,diacritics}", blargh);
	
	// Test brace escapes.
	JALog(@"Braces: int main() {(} return 0; {)}");
	
	// Test localization.
	NSString *localizationFile = @"Localizable.strings";
	JALogLocalized(@"This is a template in the source code, not from {localizationFile}.", localizationFile);
	
	// Test Boring Mode.
	NSString *boring = JAExpandWithParameters(@"boring_mode_test", @{ @"boring": @"SUPER EXCITING!" });
	NSLog(@"%@", boring);
	
	[NSApp terminate:nil];
}

@end
