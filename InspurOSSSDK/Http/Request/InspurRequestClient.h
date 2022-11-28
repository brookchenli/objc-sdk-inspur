//
//  QNRequestClient.h
//  InspurOSSSDK
//
//  Created by Brook on 2020/4/29.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUploadRequestMetrics.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^QNRequestClientCompleteHandler)(NSURLResponse * _Nullable, InspurUploadSingleRequestMetrics * _Nullable, NSData * _Nullable, NSError * _Nullable);

@protocol InspurRequestClient <NSObject>

// client 标识
@property(nonatomic,  copy, readonly)NSString *clientId;

- (void)request:(NSURLRequest *)request
         server:(_Nullable id <InspurUploadServer>)server
connectionProxy:(NSDictionary * _Nullable)connectionProxy
       progress:(void(^ _Nullable)(long long totalBytesWritten, long long totalBytesExpectedToWrite))progress
       complete:(_Nullable QNRequestClientCompleteHandler)complete;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
