/*

JATemplateVanilla.m

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


/*
	Cache limit.
	
	By default, an NSCache is used in ParseNames (per thread) to cache the
	mapping of <names> parameters to parsed name arrays. Set
	JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT to 0 at command line to disable
	the cache.
*/
#ifndef JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT
#define JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT	64
#endif


static NSString * const kJATemplateParseCacheThreadDictionaryKey = @"se.ayton.jens JATemplate parse cache";

enum
{
	kStackStringLimit		= 1024	// Largest string length we'll allocate on the stack.
};


static NSDictionary *JATBuildParameterDictionary(NSString *names, NSArray *objects);


#pragma mark - Public

/*
	JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, objects)
	
		- template is the string to expand - for example, @"foo = {foo}, bar = {bar}".
		- names is the preprocessor stringification of the parameter list -
		  for example, "foo, @(bar)". Note that the preprocessor will remove
		  comments for us.
		- objects is an array of the parameter values.
*/
NSString *JAT_DoExpandTemplateUsingMacroKeysAndValues(NSString *template, NSString *names, NSArray *objects)
{
	NSCParameterAssert(template != nil);
	NSCParameterAssert(names != nil);
	
	/*	Non-optimization: it's tempting to short-circuit here if there are no
		parameters, but that breaks if there are {{/}} escapes.
	*/
	
	// Build dictionary of parametes and hand off to Boring Mode.
	NSDictionary *parameters = JATBuildParameterDictionary(names, objects);
	if (parameters == nil)  return template;
	
	return JATExpandLiteralWithParameters(template, parameters);
}


/*
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(...)
	
	Equivalent to using one of the NSLocalizedString macro family before calling
	JAT_DoExpandTemplateUsingMacroKeysAndValues().
*/
NSString *JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *template, NSBundle *bundle, NSString *localizationTable, NSString *names, NSArray *objects)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	template = [bundle localizedStringForKey:template value:@"" table:localizationTable];
	
	return JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, objects);
}


#pragma mark - Name string parsing

static NSDictionary *JATemplateParseNames(NSString *nameString, NSUInteger expectedCount);
static NSDictionary *JATemplateParseNamesUncached(NSString *nameString, NSUInteger expectedCount);
static NSString *JATemplateParseOneName(NSString *name);


static NSDictionary *JATBuildParameterDictionary(NSString *names, NSArray *objects)
{
	NSUInteger count = objects.count;
	if (count == 0)  return @{};
	
	__strong id keys[count * 2];
	__strong id values[count * 2];
	NSUInteger mapIndex;
	
	// Insert NSNumber keys for positional parameters.
	for (mapIndex = 0; mapIndex < count; mapIndex++)
	{
		keys[mapIndex] = @(mapIndex);
		id value = objects[mapIndex];
		if (value == nil)  value = [NSNull null];
		values[mapIndex] = value;
	}
	
	// Parse <names> into an array of identifiers. This also strips boxing @() syntax.
	NSDictionary *parameterNames = JATemplateParseNames(names, count);
	
	for (NSString *key in parameterNames)
	{
		keys[mapIndex] = key;
		NSUInteger elementIndex = [parameterNames[key] unsignedIntegerValue];
		NSCAssert(elementIndex < count, @"JATemplateParseNames produced an out-of-range index.");
		values[mapIndex] = values[elementIndex];
		mapIndex++;
	}
	
	// Build dictionary of parameters.
	return [NSDictionary dictionaryWithObjects:values forKeys:keys count:mapIndex];
}


/*
	JATemplateParseNames(nameString, expectedCount)
	
	Convert a string produced by stringifying __VA_ARGS__ in one of the wrapper
	macros to an array of <expectedCount> identifiers.
	
	The string will be a comma-separated list of expressions with comments
	stripped, but with whitespace otherwise intact.
	
	If an item is wrapped in @(), this is removed, allowing boxing expressions
	to be used directly. For example, JATExpand(@"{foo}{bar}", foo, @(bar))
	produces @"foo, @( bar )", which is mapped to @[@"foo", @"bar"].
	
	It is asserted that the string contains the correct number of items and
	that each expression is in fact a single identifier. Assertion is considered
	sufficient since these strings come directly from source code, not data
	files, so disabling assertions does not result in an equivalent to format
	string attack vulnerabilities, only increased exposure to bugs in the
	template system and client code.
	
	JATemplateParseNames() is not optimized. It should be significantly more
	efficient to take the name string as a const char[] and do a singe-pass
	scan, extracting NSStrings directly from identifier ranges. However, for
	most practical uses cases where JATemplateParseNames() is a significant
	cost, raising the cache limit is probably a better bet.
*/
static NSDictionary *JATemplateParseNames(NSString *nameString, NSUInteger expectedCount)
{
	NSCParameterAssert(nameString != nil);
	
	NSDictionary *result;
#if JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT > 0
	NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
	NSCache *cache = threadDictionary[kJATemplateParseCacheThreadDictionaryKey];
	result = [cache objectForKey:nameString];
	if (result != nil)
	{
		return result;
	}
#endif
	
	result = JATemplateParseNamesUncached(nameString, expectedCount);
	
#if JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT > 0
	if (cache == nil)
	{
		cache = [NSCache new];
		cache.name = kJATemplateParseCacheThreadDictionaryKey;
		cache.countLimit = JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT;
		threadDictionary[kJATemplateParseCacheThreadDictionaryKey] = cache;
	}
	[cache setObject:result forKey:nameString];
#endif
	
	return result;
}


static NSDictionary *JATemplateParseNamesUncached(NSString *nameString, NSUInteger expectedCount)
{
	if (expectedCount == 0)
	{
		NSCParameterAssert(nameString.length == 0);
		return @{};
	}
	
	__block NSArray *components;
	JATWithCharacters(nameString, ^(const unichar characters[], NSUInteger length)
	{
		components = JATSplitStringInternal(nameString, ',', '(', ')', characters, length, false);
	});
	NSCAssert(components.count == expectedCount, @"Expected %lu variable names in template expansion, got %lu. The problem name string is: \"%@\".", expectedCount, components.count, nameString);
	
	NSString *cleanedNames[expectedCount];
	NSNumber *indices[expectedCount];
	
	NSUInteger nameIndex = 0, mapIndex = 0;
	for (NSString *name in components)
	{
		NSString *cleaned = JATemplateParseOneName(name);
		if (cleaned != nil)
		{
			cleanedNames[mapIndex] = cleaned;
			indices[mapIndex] = @(nameIndex);
			mapIndex++;
		}
		nameIndex++;
	}
	
	return [NSDictionary dictionaryWithObjects:indices forKeys:cleanedNames count:mapIndex];
}


static NSString *JATemplateParseOneName(NSString *name)
{
	NSCharacterSet *whiteSpace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	
	name = [name stringByTrimmingCharactersInSet:whiteSpace];
	
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
