//
//  InspurLogUtil.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/12/25.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurLogUtil.h"

#if DEBUG
static InspurLogLevel _level = InspurLogLevelError;
#else
static InspurLogLevel _level = InspurLogLevelNone;
#endif

static BOOL _enableDate = false;
static BOOL _enableFile = true;
static BOOL _enableFunction = false;

@implementation InspurLogUtil

+ (void)setLogLevel:(InspurLogLevel)level {
    _level = level < 0 ? 0 : level;
}

+ (void)enableLogDate:(BOOL)enable {
    _enableDate = enable;
}
+ (void)enableLogFile:(BOOL)enable {
    _enableFile = enable;
}
+ (void)enableLogFunction:(BOOL)enable {
    _enableFunction = enable;
}


+ (void)log:(InspurLogLevel)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    
    if (!format || level > _level) {
        return;
    }
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *fileName = @"";
    if (_enableFile) {
        fileName =  [NSString stringWithFormat:@"%s", file];
        if ([fileName containsString:@"/"]) {
            fileName = [fileName componentsSeparatedByString:@"/"].lastObject;
        }
    }
    
    NSString *functionName = @"";
    if (_enableFunction) {
        functionName = [NSString stringWithFormat:@"->%s", function];
    }
    
    NSString *lineNumber = [NSString stringWithFormat:@"->%ld", line];
    
    NSString *date = @"";
    if (_enableDate) {
        date = [NSString stringWithFormat:@"%@", [NSDate date]];
        if ([date length] > 20) {
            date = [date substringToIndex:19];
        }
    }
    
    NSThread *thread = [NSThread currentThread];
    NSString *levelString = @[@"N", @"E", @"W", @"I", @"D", @"V"][level%6];
    message = [NSString stringWithFormat:@"%@[%@] %@ %@%@%@ %@", date, levelString, thread, fileName, functionName, lineNumber, message];

    NSLog(@"%@", message);
}


@end
