/*

JATemplateHairy.m

Copyright © 2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software“), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 
*/

#import "JATemplateInternal.h"

#if !__has_feature(objc_arc)
#error This file requires ARC.
#endif


static NSDictionary *JATBuildParameterDictionary(JATNameArray names, JATParameterArray objects, NSUInteger expectedCount);


#pragma mark - Public

/*
	JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, paddedObjectArray, expectedCount)
	
		- template is the string to expand - for example, @"foo = {foo}, bar = {bar}".
		- names is an array of stringified, preprocessed arguments, for example
		  { @"foo", @"bar" }. Note that the preprocessor will remove comments
		  and trime whitespace from the ends for us.
		- objects is an array of the parameter values.
		- expectedCount is the number of parameters.
*/
NSString *JAT_DoExpandTemplateUsingMacroKeysAndValues(NSString *template, JATNameArray names, JATParameterArray objects, NSUInteger expectedCount)
{
	NSCParameterAssert(template != nil);
	NSCParameterAssert(names != nil);
	NSCParameterAssert(objects != NULL || expectedCount == 0);
	
	/*	Non-optimization: it's tempting to short-circuit here if there are no
		parameters, but that breaks if there are {{/}} escapes.
	*/
	
	// Build dictionary of parametes and hand off to Boring Mode.
	NSDictionary *parameters = JATBuildParameterDictionary(names, objects, expectedCount);
	if (parameters == nil)  return template;
	
	return JATExpandLiteralWithParameters(template, parameters);
}


/*
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(...)
	
	Equivalent to using one of the NSLocalizedString macro family before calling
	JAT_DoExpandTemplateUsingMacroKeysAndValues().
*/
NSString *JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *template, NSBundle *bundle, NSString *localizationTable, JATNameArray names, JATParameterArray objects, NSUInteger count)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	template = [bundle localizedStringForKey:template value:@"" table:localizationTable];
	
	return JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, objects, count);
}


#pragma mark - Name string parsing

static NSString *JATemplateParseOneName(NSString *name);


/*	JATBuildParameterDictionary(names, objects, expectedCount)
	
	<names> is an array of (at least) <expectedCount> strings.
	<objects> is an array of <expectedCount> objects (may contain nils).
	
	Given these, we construct a dictionary mapping each index from 0 to
	<expectedCount> to the appropriate object, and each name to an object if
	the name is a plain C identifier or an identifier wrapped in boxing syntax.
	Nils are replaced with NSNull.
*/
static NSDictionary *JATBuildParameterDictionary(JATNameArray names, JATParameterArray objects, NSUInteger expectedCount)
{
	if (expectedCount == 0)  return @{};
	
	__strong id keys[expectedCount * 2];
	__strong id values[expectedCount * 2];
	NSUInteger mapIndex = 0;
	
	for (NSUInteger arrayIndex = 0; arrayIndex < expectedCount; arrayIndex++)
	{
		// Insert NSNumber keys for positional parameters.
		id value = objects[arrayIndex];
		keys[mapIndex] = @(arrayIndex);
		if (value == nil)  value = [NSNull null];
		values[mapIndex] = value;
		mapIndex++;
		
		// Insert NSString keys for name parameters which are identifiers or boxed identifiers.
		NSString *name1 = names[arrayIndex];
		NSString *name = JATemplateParseOneName(name1);
		if (name != nil)
		{
			keys[mapIndex] = name;
			values[mapIndex] = value;
			mapIndex++;
		}
	}
	
	// Build dictionary of parameters.
	return [NSDictionary dictionaryWithObjects:values forKeys:keys count:mapIndex];
}


static NSString *JATemplateParseOneName(NSString *name)
{
	NSCharacterSet *whiteSpace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	
	/*	Handle boxing expressions: "@(foo)" -> "foo".
		Syntax note: @ (foo) is invalid, so we can treat @( as one token.
		However, we need to strip out whitespace inside the parentheses.
	*/
	NSUInteger length = name.length;
	if (length > 3 &&
		[name characterAtIndex:0] == '@' &&
		[name characterAtIndex:1] == '(' &&
		[name characterAtIndex:length - 1] == ')')
	{
		name = [name substringWithRange:(NSRange){2, length - 3}];
		name = [name stringByTrimmingCharactersInSet:whiteSpace];
	}
	
	if (!JATIsValidIdentifier(name))  name = nil;
	
	return name;
}
