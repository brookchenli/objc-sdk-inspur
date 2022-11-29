//
//  InspurSignatureContentGenerator.h
//  InspurOSSSDK
//
//  Created by 陈历 on 2022/11/27.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurSignatureContentGenerator : NSObject

@property (nonatomic, assign) long deadLine;
@property (nonatomic, strong) NSString *bucket;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *accessKey;

@property (nonatomic, strong) NSString *safeKey;

- (NSString *)putData;
- (NSString *)partInit;
- (NSString *)partUpload:(NSString *)uploadId partIndex:(NSString *)partIndex;
- (NSArray <NSString *>*)partUpload:(NSString *)uploadId partIndex:(NSInteger)partIndex maxIndex:(int)maxIndex;
- (NSString *)completeUpload:(NSString *)uploadId;

- (NSString *)safeKey;

- (void)updateKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
