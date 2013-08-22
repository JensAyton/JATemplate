# Manifesto

Software that communicates with users often needs to insert dynamic data into strings for presentation. Cocoa Foundation’s solution for this is `printf()`–style formatting, which is fundamentally unsuitable for the task, for two reasons:

* There are many formatting options, none of which are suitable for producing well-formatted prose text.
* The interpretation of data on the stack, including its length, is specified in the formatting string itself. This means that format strings loaded from data can crash your application. This is problematic for integrated localization, and a deal-breaker for other use cases such as sandboxed plug-ins.

The C standard library has a third problem: the `%n` specifier can be used to write arbitrary data onto the stack, which is [serious business](http://en.wikipedia.org/wiki/Uncontrolled_format_string). Foundation does not implement `%n`, but malicious format strings can still be used to read data you didn’t intend to expose, or simply crash your app.

In short, I feel that `printf()` and `+[NSString stringWithFormat:]` should be deprecated. For producing text in formal languages for computer consumption, I suggest a fully-fledged template system such as [MGTemplateEngine](http://mattgemmell.com/2008/05/20/mgtemplateengine-templates-with-cocoa/). But for logging, presenting alerts, and hacking together command-line tools, `printf()`-style formatting wins on convenience. This is an attempt at beating `printf()`on its own ground.

# JATemplate
JATemplate provides a family of macros and functions for inserting variables into strings. Convenience wrappers are provided for using it in conjunction with `NSLog()`, `NSAssert()` and `-[NSMutableString stringByAppendingString:]`.

This is the Vanilla Edition of JATemplate. It’s designed to minimize dependence on preprocessor tricks, since many people have a quite understandable aversion to them. There is also a Hairy Edition in the `hairy` branch of [the repository](https://github.com/JensAyton/JATemplate/), which is marginally faster, technically more type safe and more expressive at the cost of some preprocessor voodoo.

JATemplate is currently experimental. The syntax and operators are in flux, and I’m not satisfied with the robustness of the parser. That said, fuzz testing has repeatedly found a crashing bug in CoreFoundation and/or ICU, but no crashes, assertions or unexpected warnings in JATemplate itself. It is certainly far safer than `+[NSString stringWithFormat:]`.

To date, it has only been tested on Mac OS X 10.8 with ARC. Some formatting operators have known incompatibilities with Mac OS X 10.7 and iOS 5.

## Basic usage
```objc
NSString *flavor = @"strawberry";
NSString *size = @"large";
unsigned scoopCount = 3;
NSString *message = JATExpand(@"My {size} ice cream tastes of {flavor} and has {scoopCount} scoops!", flavor, size, @(scoopCount));
```
Because easy internationalization is a central goal in the design, `JATExpand()` looks up the format string (template) in Localizable.strings by default. There are variants to control this behaviour.

Templates can directly refer to variables by name, but they only have access to variables specified at the call site. Parameters can also be referred to by position; in the example, `{0}` could be used instead of `{flavor}`. Name references are less error-prone and easier to localize, but positional references allow you to refer to an expression without creating a temporary variable. This is particularly useful in logging and assertions, which are less likely to be localized anyway.

The default behaviour for numerical parameters is to format them with `NSNumberFormatter`’s `NSNumberFormatterDecimalStyle`. If `scoopCount` is set to `1000` in the example above, it is printed as *1,000* in English locales.

In JATemplate: Vanilla Edition, all parameters must be Objective-C objects. However, variables may use `@()` boxing syntax and still be referred to by name. The Hairy Edition supports additional types, and it is easy to add support for custom types (structs, unions, C++ classes and C++11 enum classes).

The most important feature of the design is that even though `JAExpand()` *et al.* are variadic, the number of arguments passed is fixed at compile time, and they are all known to be object pointers. If a format string refers to a non-existent parameter, either by name or by index, it will simply not be expanded.

## Formatting
The formatting of expanded parameters can be modified by appending *formatting operators*, separated by a pipe character:
```objc
NSString *intensifier = @"really";
NSString *message = JATExpand(@"I {intensifier|uppercase} like ice cream!", intensifier);
// Produces “I REALLY like ice cream!”
```

Multiple operators can be chained together in the obvious fashion. Operators may optionally take an argument, separated by a colon. By convention, operators that need to split the argument into parts use semicolons as a separator.
```objc
NSString *message = JATExpand(@"Pi is about {0|round|num:spellout}.", @(M_PI));
// Produces “Pi is about three.”

// BUG 2013-02-01: Some people’s ice cream only has one scoop. :-(
// FIX: support pluralization.
NSString *message = JATExpand(@"My {size} ice cream tastes of {flavor} and has {scoopCount} {scoopCount|plural:scoop.;scoops!}", flavor, size, @(scoopCount));
```

For the full set of built-in operators, see **Built-in operators** below. The `num:` operator and the pluralization operators are particularly important.

## Variants
The full list of string expanding functions and macros, and their notional signatures, is as follows. All variadic arguments (`...`) actually take a series of zero or more objects, and are type safe (as much as pointers in C are in general).

* `NSString *JATExpand(NSString *template, ...)` — Looks up `template` in Localizable.strings in the same manner as `NSLocalizedString()`, then expands substitution expressions in the resulting template using the provided parameters.
* `NSString *JATExpandLiteral(NSString *template, ...)` — Like `JATExpand()`, but skips the localization step.
* `NSString *JATExpandFromTable(NSString *template, NSString *table, ...)` — Like `JATExpand()`, but looks up the template in the specified .strings file (like `NSLocalizedStringFromTable()`). The table name should not include the .strings extension.
* `NSString *JATExpandFromTableInBundle(NSString *template, NSString *table, NSBundle *bundle ...)` — Like `JATExpand()`, but looks up the template in the specified .strings file and bundle (like `NSLocalizedStringFromTableInBundle()`).
* `NSString *JATExpandWithParameters(NSString *template, NSDictionary *parameters)` – Like `JATExpand()`, but passes the parameters in a dictionary. “Positional” parameters in this case are looked up using `NSNumber`s as keys.
* `NSString *JATExpandLiteralWithParameters(NSString *template, NSDictionary *parameters)` – Like `JATExpandWithParameters()`, but without the localization step.
* `NSString *JATExpandFromTableWithParameters(NSString *template, NSString *table, NSDictionary *parameters)` and `NSString *JATExpandFromTableInBundleWithParameters(NSString *template, NSString *table, NSBundle *bundle, NSDictionary *parameters)` — they exist.
* `void JATAppend(NSMutableString *string, NSString *template, ...)`, `void JATAppendLiteral(NSMutableString *string, NSString *template, ...)`, `void JATAppendFromTable(NSMutableString *string, NSString *template, NSString *table, ...)`, `void JATAppendFromTableInBundle(NSMutableString *string, NSString *template, NSString *table, NSBundle *bundle, ...)` — append an expanded template to a mutable string; Equivalent to `[string appendString:JATExpand*(template, ...)]`.
* `void JATLog(NSString *template, ...)` — performs non-localized expansion and sends the result to `NSLog()`.
* `JATAssert(condition, template, ...)` and `JATCAssert(condition, template, ...)` — wrappers for `NSAssert()` and `NSCAssert()` which perform template expansion on failure.

## Customization
There are two major ways to customize JATemplate: custom coercion methods and custom operators.

The three coercion methods in the protocol `<JATCoercible>` are used by operators and the template expansion system to interpret parameters as particular types. They are implemented on `NSObject` and a few other classes, but can be overridden to customize the treatment of your own classes.

* `-jatemplateCoerceToString` returns an `NSString *`. In addition to being used by operators, it is used by the template expander to produce the final string that will be inserted into the template. The default implementation calls `-description`. It is overridden for `NSString` to return `self`, for `NSNumber` to use `NSNumberFormatterDecimalStyle`, for `NSNull` to return `@"(null)"`, and for `NSArray` to return a comma-separated list.
* `-jatemplateCoerceToNumber` returns an `NSNumber *`. The default implementation will look for methods `-(double)doubleValue`, `-(float)floatValue`, `-(NSInteger)integerValue` or `-(int)intValue`, in that order. If none of these is found, it returns `nil`, which causes expansion to fail. It is overridden by `NSNumber` to return `self`.
* `-jatemplateCoerceToBoolean` returns an `NSNumber *` which is treated as a boolean. The default implementation calls `-(BOOL)boolValue` if implemented, otherwise returns `nil`. Overridden by `NSNull` to return `@NO`.

Operators are implemented as methods following this template:
```objc
-(id <JATCoercible>)jatemplatePerform_{operator}_withArgument:(NSString *)argument
                                                    variables:(NSDictionary *)variables
```
The receiver is the object being formatted – either one of the parameters to the template or the result of a previous operator in a chain. (For a `nil` parameter, the operator message is sent to `[NSNull null]`.) The `argument` is the string following the colon in the operator invocation, or `nil` if there was no colon. The `variables` dictionary contains all the parameters to the expansion operation; named parameters are addressed with `NSString` keys, and positional parameters with `NSNumber` keys. For example, this is the implementation of the `uppercase` operator:
```objc
- (id <JATCoercible>) jatemplatePerform_uppercase_withArgument:(NSString *)argument
                                                     variables:(NSDictionary *)variables
{
    NSString *value = [self jatemplateCoerceToString];
    if (value == nil)  return nil;
    
    return [value uppercaseStringWithLocale:[NSLocale currentLocale]];
}
```
In most cases, operators should be implemented in a category on `NSObject`, and coerce the receiver to whatever class is relevant for the operation. However, it may be reasonable to implement specialized class-specific operators as, say, a category on a model object class.

## Built-in operators
The “built-in” operators are actually implemented in a separate file, JATemplateDefaultOperators.m. If you don’t like them, you can just exclude this file and write your own. Selecting a good set of operators is perhaps the most difficult design aspect of the library. Some that are currently missing are date formatting and hexadecimal numbers.

### Number operators
These operators coerce the receiver to a number using `-jatemplateCoerceToNumber`.

* `num:` — Format a number using one of several predefined formats, or an ICU/NSNumberFormatter format string. The predefined formats are:
  * `decimal` or `dec` — Locale-sensitive decimal formatting using `NSNumberFormatterDecimalStyle`. This is the default for `NSNumber`s.
  * `noloc` – Non-locale-sensitive formatting using `-[NSNumber description]`.
  * `hex` or `HEX`: unsigned hexadecimal formatting, using lowercase or uppercase characters respectively. Takes an optional argument specifying the number of digits (`"0x{foo|num:hex;8}"`). Not localized.
  * `currency` or `cur` – Locale-sensitive currency formatting using `NSNumberFormatterCurrencyStyle`.
  * `percent` or `pct` – Locale-sensitive percentage notation using `NSNumberFormatterPercentStyle`.
  * `scientific` or `sci` – Locale-sensitive scientific notation using `NSNumberFormatterScientificStyle`.
  * `spellout` – Locale-sensitive text formatting using `NSNumberFormatterSpellOutStyle`.
  * `filebytes`, `file` or `bytes` – Byte count formatting using `NSByteCountFormatterCountStyleFile`.
  * `memorybytes` or `memory` – Byte count formatting using `NSByteCountFormatterCountStyleMemory`.
  * `decimalbytes` – Power-of-ten byte count formatting using `NSByteCountFormatterCountStyleDecimal`.
  * `binarybytes` – Power-of-two byte count formatting using `NSByteCountFormatterCountStyleBinary`.
* `round` – Round to an integer, rounding half-way cases away from zero (“school rounding”).
* `plur:` – A powerful pluralization operator with support for many languages. It takes three to seven arguments separated by semicolons. The first is a number specifying a pluralization rule, and the others are different word forms determined by the rule. The rules are the same as used by [Mozilla’s PluralForm system](https://developer.mozilla.org/en-US/docs/Localization_and_Plurals) (except that rule 0 is not supported or needed).<br>For example, the template `"{count} minute{count|plural:s}"` might be translated to Polish as `"{count} {count|plur:9;minuta;minuty;minut}"`.<br>The selected string is also expanded as a template, so it’s possible to do things like `"{plur:1;{singularString};{pluralString}}"`. This is generally a bad idea, because handling all the different language rules this way is likely to be impossible, but it’s there if you need it. (This also works with `plural:` and `pluraz:`.)
* `plural:` – A simplified plural operator for languages that use the same numeric inflection structure as English (`plur:` rule 1). If one argument is given, the empty string is used for a singular value and the argument is used for plural. If two arguments separated by a semicolon are given, the first is singular and the second is plural.<br>Example: `"I have {gooseCount} {gooseCount|plural:goose;geese}.".`
* `pluraz:` — Like `plural:`, except that a count of zero is treated as singular (`plur:` rule 2).<br>Example: `"J’ai {gooseCount} {gooseCount|pluraz:oie;oies}."`, or equivalently `"J’ai {gooseCount} oie{gooseCount|pluraz:s}."`.
* `select:` – Takes any number of arguments separated by semicolons. The receiver is coerced to a number and truncated to an integer. The corresponding argument is selected (and expanded). Arguments are numbered from zero; if the value is out of range, the last item is used.<br>Example: `"Today is {weekDay|select:Mon;Tues;Wednes;Thurs;Fri;Satur;Sun}day."`
* `padding` — Truncates the value to an integer and produces the corresponding number of spaces. Negative values are treated as 0.

### String operators
These operators coerce the receiver to a number using `-jatemplateCoerceToString`.

* `uppercase`, `lowercase` and `capitalize` — Locale-sensitive conversion to capitals/lower case/naïve title case using `-[NSString uppercaseWithLocale:]` etc.
* `uppercase_noloc`, `lowercase_noloc` and `capitalize_noloc` — Locale-insensitive conversion to capitals/lower case/naïve title case using `-[NSString uppercase]` etc..
* `trim` — Removes leading and trailing whitespace and newlines.
* `length` — Produces the length of the receiver (coerced to a string).
* `fold:` — Locale-sensitive removal of lesser character distinctions using `-[NSString stringByFoldingWithOptions:locale:]`. The argument is a comma-separated list of options. The currently supported options are `case`, `width` and `diacritics`.
* `fit:` — Truncates or pads the string as necessary to fit in a particular number of characters. It is intended for column formatting in command-line tools and logging, and is of little use with variable-width fonts. It takes one to four arguments separated by semicolons:
  * The first is the desired width, a positive integer.
  * The second is `start`, `center`, `end` or `none`, specifying where padding will be added if necessary. The default is `end`. `center` means padding will be added at both ends. `none` means no padding will be added.
  * The third is also `start`, `center`, `end` or `none`, specifying where truncation will occur if necessary. The default is `end` (irrespective of the second argument). `none` means no truncation will occur.
  * The fourth is a string to insert when truncating. The default is `…` (a single-character elipsis). This may be any string, including the empty string or a string longer than the fit width; in this case, truncation will return the full replacement string and nothing else.
* `trunc:` – Truncates the string without adding a placeholder. Takes one or two arguments, the first being the desired length and the second being a mode string as for `fit:`. `trunc:x;y` is equivalent to `fit:x;none;y;`.

### Boolean operators
These operators coerce the receiver to a number using `-jatemplateCoerceToBoolean`.

* `if:` — Takes one or two arguments separated by a semicolon. If the receiver, as a boolean, is true, selects the first argument. Otherwise selects the second argument (or the empty string if none). The selected argument is then expanded as a template.<br>Example: `"The flag is {flag|if:set;not set}."`

### Non-coercing operators
* `pointer` — Produces the address of the receiver, formatted as with `%p`. (`NSNull` is treated as `nil`, since the distinction can’t be made in an operator.)
* `basedesc` – Produces the class name and address of the receiver, suitable for use in implementing `-description`.
* `debugdesc` – Calls `-debugDescription` on the receiver if implemented, otherwise `-description.`
