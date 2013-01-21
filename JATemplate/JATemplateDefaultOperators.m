/*

JATemplateDefaultOperators.m

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

#import "JATemplate.h"


#define JATWarn(CHARACTERS, LENGTH, TEMPLATE, ...)  JATWrapWarning(CHARACTERS, LENGTH, JATExpand(TEMPLATE, __VA_ARGS__))
void JATWrapWarning(const unichar characters[], NSUInteger length, NSString *message);


@implementation NSObject (JATDefaultOperators)

- (id) jatemplatePerform_num_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if ([argument isEqual:@"decimal"] || [argument isEqual:@"dec"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterDecimalStyle];
	}
	if ([argument isEqual:@"noloc"])
	{
		return [value description];
	}
	if ([argument isEqual:@"currency"] || [argument isEqual:@"cur"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterCurrencyStyle];
	}
	if ([argument isEqual:@"percent"] || [argument isEqual:@"pct"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterPercentStyle];
	}
	if ([argument isEqual:@"scientific"] || [argument isEqual:@"sci"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterScientificStyle];
	}
	if ([argument isEqual:@"spellout"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterSpellOutStyle];
	}
	if ([argument isEqual:@"filebytes"] || [argument isEqual:@"file"] || [argument isEqual:@"bytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
	}
	if ([argument isEqual:@"memorybytes"] || [argument isEqual:@"memory"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleMemory];
	}
	if ([argument isEqual:@"decimalbytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleDecimal];
	}
	if ([argument isEqual:@"binarybytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleBinary];
	}
	
	NSNumberFormatter *formatter = [NSNumberFormatter new];
	formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
	formatter.format = argument;
	
	return [formatter stringFromNumber:value];
}


- (id) jatemplatePerform_round_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	long long rounded = llround(value.doubleValue);
	
	return [NSNumber numberWithLongLong:rounded];
}


- (id) jatemplatePerform_plural_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		JATWarn(NULL, 0, @"Template operator plural: used with no argument.");
	}
	
	// FIXME: needs better parsing to allow nested templates to contain semicolons.
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	bool isPlural = ![value isEqual:@(1)];
	
	NSUInteger count = components.count;
	NSString *selected;
	if (count == 1)
	{
		// One argument: use argument for plural, empty string for singular.
		selected = isPlural ? argument : @"";
	}
	else if (count == 2)
	{
		// Two arguments: singular;plural
		selected = isPlural ? components[1] : components[0];
	}
	else if (count == 3)
	{
		// Two arguments: singular;dual;plural
		if (!isPlural)  selected = components[0];
		else if ([value isEqual:@(2)])
		{
			selected = components[1];
		}
		else
		{
			selected = components[2];
		}
	}
	else
	{
		JATWarn(NULL, 0, @"Template operator plural: requires one to three arguments, got \"{argument}\".", argument);
		return nil;
	}
	
	// If <selected> is an expansion expression, expand it.
	NSUInteger length = selected.length;
	if (length >= 2 && [selected characterAtIndex:0] == '{' && [selected characterAtIndex:selected.length - 1] == '}')
	{
		return JATExpandLiteralWithParameters(selected, variables);
	}
	else
	{
		return selected;
	}
}


- (id) jatemplatePerform_not_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	return value.boolValue ? @NO : @YES;
}


- (id) jatemplatePerform_if_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		JATWarn(NULL, 0, @"Template operator if: used with no argument.");
	}
	
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	id trueValue = components[0], falseValue = @"";
	if (components.count > 1)  falseValue = components[1];
	
	return value.boolValue ? trueValue : falseValue;
}


- (id) jatemplatePerform_ifuse_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		JATWarn(NULL, 0, @"Template operator ifuse: used with no argument.");
	}
	
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	NSString *trueKey = components[0], *falseKey = nil;
	if (components.count > 1)  falseKey = components[1];
	
	NSString *selectedKey = value.boolValue ? trueKey : falseKey;
	
	if (selectedKey != nil)
	{
		NSString *result = variables[selectedKey];
		if (result == nil)
		{
			JATWarn(NULL, 0, @"Template substitution uses unknown key \"{selectedKey}\" in ifuse: operator.", selectedKey);
		}
		return result;
	}
	else
	{
		return @"";
	}
}


- (id) jatemplatePerform_uppercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseStringWithLocale:[NSLocale currentLocale]];
}


- (id) jatemplatePerform_lowercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseStringWithLocale:[NSLocale currentLocale]];
}


- (id) jatemplatePerform_capitalize_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedStringWithLocale:[NSLocale currentLocale]];
}


- (id) jatemplatePerform_uppercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseString];
}


- (id) jatemplatePerform_lowercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseString];
}


- (id) jatemplatePerform_capitalize_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedString];
}


- (id) jatemplatePerform_trim_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}


- (id) jatemplatePerform_length_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return @(value.length);
}


- (id) jatemplatePerform_fold_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	NSStringCompareOptions optionMask = 0;
	for (NSString *option in [argument componentsSeparatedByString:@","])
	{
		if ([option isEqual:@"case"])
		{
			optionMask |= NSCaseInsensitiveSearch;
		}
		else if ([option isEqual:@"diacritics"])
		{
			optionMask |= NSDiacriticInsensitiveSearch;
		}
		else if ([option isEqual:@"width"])
		{
			optionMask |= NSWidthInsensitiveSearch;
		}
		else
		{
			JATWarn(NULL, 0, @"Unknown option \"{option}\" for \"fold\" template operator.", option);
		}
	}
	
	if (optionMask == 0)  return value;
	
	return [value stringByFoldingWithOptions:optionMask locale:NSLocale.currentLocale];
}


- (id) jatemplatePerform_pointer_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	id value = self;
	if (self == [NSNull null])  value = nil;
	
	return [NSString stringWithFormat:@"%p", value];
}


- (id) jatemplatePerform_basedesc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	id value = self;
	if (self == [NSNull null])  return [self jatemplateCoerceToString];
	Class class = [value class];
	
	return JATExpand(@"<{class}: {value|pointer}>", (id <JATCoercable>)class, value);
}


- (id) jatemplatePerform_debugdesc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	if ([self respondsToSelector:@selector(debugDescription)])
	{
		return [self debugDescription];
	}
	else
	{
		return [self description];
	}
}

@end
