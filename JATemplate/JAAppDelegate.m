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
	JALog(@"Trivial");
	id foo = @"sausage";
	int bar = 7;
	JALog(@"foo: {foo}, test 1: {}, test 1B: {(}{)}, test 2: {nonesuch}, bar: {bar}, formatting: {bar|num:spellout}", foo, @( bar ) );
}

@end
