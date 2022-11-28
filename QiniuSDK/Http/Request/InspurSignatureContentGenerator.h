//
//  QNSignatureContentGenerator.h
//  QiniuSDK
//
//  Created by 陈历 on 2022/11/27.
//  Copyright © 2022 Qiniu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurSignatureContentGenerator : NSObject

@property (nonatomic, assign) long deadLine;
@property (nonatomic, strong) NSString *bucket;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *accessKey;

- (NSString *)putData;
- (NSString *)partInit;
- (NSString *)partUpload:(NSString *)uploadId partIndex:(NSString *)partIndex;
- (NSString *)completeUpload:(NSString *)uploadId;

@end

NS_ASSUME_NONNULL_END
