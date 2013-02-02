/*

JATemplateInternal.h


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

// Enable or disable syntax warnings.

#ifndef JATEMPLATE_SYNTAX_WARNINGS
#ifdef NDEBUG
#define JATEMPLATE_SYNTAX_WARNINGS 0
#else
#define JATEMPLATE_SYNTAX_WARNINGS 1
#endif
#endif

#if JATEMPLATE_SYNTAX_WARNINGS
#ifndef JATReportWarning
#define JATReportWarning(message)  NSLog(@"JATemplate warning: %@", message)
#endif

#define JATWarn(CHARACTERS, LENGTH, TEMPLATE, ...)  JATWrapWarning(CHARACTERS, LENGTH, JATExpand(TEMPLATE, __VA_ARGS__))
#else
#define JATWarn(CHARACTERS, LENGTH, TEMPLATE, ...) do {} while (0)
#endif

void JATWrapWarning(const unichar characters[], NSUInteger length, NSString *message);

bool JATIsValidIdentifier(NSString *candidate);
