//
//  JATemplate.h
//  JATemplate
//
//  Created by Jens Ayton on 2013-01-07.
//  Copyright (c) 2013 Jens Ayton. All rights reserved.
//

#import <Foundation/Foundation.h>


#define JAExpand(TEMPLATE, ...) \
	JALocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, nil, \
	@#__VA_ARGS__, (__unsafe_unretained id[]){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JAExpandLiteral(TEMPLATE, ...) \
	JAExpandTemplateUsingMacroKeysAndValues(TEMPLATE, \
	@#__VA_ARGS__, (__unsafe_unretained id[]){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JAExpandFromTable(TEMPLATE, TABLE, ...) \
	JALocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, TABLE, \
	@#__VA_ARGS__, (__unsafe_unretained id[]){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JAExpandFromTableInBundle(TEMPLATE, TABLE, BUNDLE, ...) \
	JALocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, BUNDLE, TABLE, \
	@#__VA_ARGS__, (__unsafe_unretained id[]){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JALog(TEMPLATE, ...)  NSLog(@"%@", JAExpandLiteral(TEMPLATE, __VA_ARGS__))

#define JALogLocalized(TEMPLATE, ...)  NSLog(@"%@", JAExpand(TEMPLATE, __VA_ARGS__))


/*
	JAExpandTemplateUsingMacroKeysAndValues()
	JALocalizeAndExpandTemplateUsingMacroKeysAndValues()
	
	Implementation details, do not call directly.
*/
NSString *JAExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSString *names, __unsafe_unretained id paddedObjectArray[], NSUInteger count);

NSString *JALocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSBundle *bundle, NSString *localizationTable, NSString *names, __unsafe_unretained id paddedObjectArray[], NSUInteger count);


/*
	Macros to assist with sanity checking.
	
	JATEMPLATE_ARGUMENT_COUNT returns the number of elements in a __VA_ARGS__
	list. Trivially modified from code by Laurent Deniau and
	"arpad.goret...@gmail.com" (full name not available). Source:
	https://groups.google.com/forum/?fromgroups=#!topic/comp.std.c/d-6Mj5Lko_s
	
	This version relies on the GCC/Clang ##__VA_ARGS__ extension to handle
	zero-length lists. It supports up to 62 arguments.
*/

#define JATEMPLATE_ARGUMENT_COUNT(...) \
		JATEMPLATE_ARGUMENT_COUNT_INNER(_0, ##__VA_ARGS__, JATEMPLATE_ARGUMENT_COUNT_63_VALUES())
#define JATEMPLATE_ARGUMENT_COUNT_INNER(...) \
		JATEMPLATE_ARGUMENT_COUNT_EXTRACT_64TH_ARG(__VA_ARGS__)
#define JATEMPLATE_ARGUMENT_COUNT_EXTRACT_64TH_ARG( \
		 _1, _2, _3, _4, _5, _6, _7, _8, _9,_10, \
		_11,_12,_13,_14,_15,_16,_17,_18,_19,_20, \
		_21,_22,_23,_24,_25,_26,_27,_28,_29,_30, \
		_31,_32,_33,_34,_35,_36,_37,_38,_39,_40, \
		_41,_42,_43,_44,_45,_46,_47,_48,_49,_50, \
		_51,_52,_53,_54,_55,_56,_57,_58,_59,_60, \
		_61,_62,_63,N,...) N
#define JATEMPLATE_ARGUMENT_COUNT_63_VALUES() \
		62,61,60, \
		59,58,57,56,55,54,53,52,51,50, \
		49,48,47,46,45,44,43,42,41,40, \
		39,38,37,36,35,34,33,32,31,30, \
		29,28,27,26,25,24,23,22,21,20, \
		19,18,17,16,15,14,13,12,11,10, \
		9,8,7,6,5,4,3,2,1,0
