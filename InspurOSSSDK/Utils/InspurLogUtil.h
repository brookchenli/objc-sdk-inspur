//
//  InspurLogUtil.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/12/25.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, InspurLogLevel){
    InspurLogLevelNone,
    InspurLogLevelError,
    InspurLogLevelWarn,
    InspurLogLevelInfo,
    InspurLogLevelDebug,
    InspurLogLevelVerbose
};

@interface InspurLogUtil : NSObject

+ (void)setLogLevel:(InspurLogLevel)level;

+ (void)enableLogDate:(BOOL)enable;
+ (void)enableLogFile:(BOOL)enable;
+ (void)enableLogFunction:(BOOL)enable;

+ (void)log:(InspurLogLevel)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString * _Nullable)format, ...;


@end

#define InspurLog(level, fmt, ...) \
    [InspurLogUtil log:level \
              file:__FILE__ \
          function:__FUNCTION__  \
              line:__LINE__ \
              format:(fmt), ##__VA_ARGS__]

#define InspurLogError(format, ...)   InspurLog(InspurLogLevelError, format, ##__VA_ARGS__)
#define InspurLogWarn(format, ...)    InspurLog(InspurLogLevelWarn, format, ##__VA_ARGS__)
#define InspurLogInfo(format, ...)    InspurLog(InspurLogLevelInfo, format, ##__VA_ARGS__)
#define InspurLogDebug(format, ...)   InspurLog(InspurLogLevelDebug, format, ##__VA_ARGS__)
#define InspurLogVerbose(format, ...) InspurLog(InspurLogLevelVerbose, format, ##__VA_ARGS__)

NS_ASSUME_NONNULL_END
