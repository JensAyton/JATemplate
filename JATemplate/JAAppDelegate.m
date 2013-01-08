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
	JALog(@"Trivial");
	
	// Test substitution.
	id foo = @"sausage";
	int bar = 7;
	JALog(@"foo: {foo}; bar: {bar}", foo, @(bar) );
	
	// Test formatting operators. Also a redundant parameter, and reuse of a cached parameter list parse.
	JALog(@"Fancy bar: {bar|num:spellout}", foo, @(bar) );
	
	// Test unknown parameter. Template system should log a warning before this line.
	JALog(@"Unknown variable: {nonesuch}");
	
	// Test brace escapes.
	JALog(@"Braces: int main() {(} return 0; {)}");
	
	// Test localization.
	NSString *localizationFile = @"Localizable.strings";
	JALogLocalized(@"This is a template in the source code, not from {localizationFile}.", localizationFile);
	
	[NSApp terminate:nil];
}

@end
