

#import <Foundation/Foundation.h>
#import "InspurConfiguration.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)

@class InspurResponseInfo;

typedef void (^InspurInternalProgressBlock)(long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void (^InspurCompleteBlock)(InspurResponseInfo *httpResponseInfo, NSDictionary *respBody);
typedef BOOL (^InspurCancelBlock)(void);


@interface InspurSessionManager : NSObject

- (instancetype)initWithProxy:(NSDictionary *)proxyDict
                      timeout:(UInt32)timeout
                 urlConverter:(InspurUrlConvert)converter;

- (void)multipartPost:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
         withFileName:(NSString *)key
         withMimeType:(NSString *)mime
   withIdentifier:(NSString *)identifier
    withCompleteBlock:(InspurCompleteBlock)completeBlock
    withProgressBlock:(InspurInternalProgressBlock)progressBlock
      withCancelBlock:(InspurCancelBlock)cancelBlock
           withAccess:(NSString *)access;

- (void)post:(NSString *)url
             withData:(NSData *)data
           withParams:(NSDictionary *)params
          withHeaders:(NSDictionary *)headers
    withIdentifier:(NSString *)identifier
    withCompleteBlock:(InspurCompleteBlock)completeBlock
    withProgressBlock:(InspurInternalProgressBlock)progressBlock
      withCancelBlock:(InspurCancelBlock)cancelBlock
           withAccess:(NSString *)access;

- (void)get:(NSString *)url
          withHeaders:(NSDictionary *)headers
    withCompleteBlock:(InspurCompleteBlock)completeBlock;

- (void)invalidateSessionWithIdentifier:(NSString *)identifier;

@end

#endif
