//
//  QNApiType.h
//  QiniuSDK
//
//  Created by Brook on 2022/11/15.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, QNActionType) {
    QNActionTypeNone,
    QNActionTypeUploadByForm,
    QNActionTypeUploadByResumeV1,
    QNActionTypeUploadByResumeV2,
};

@interface InspurApiType : NSObject

+ (NSString *)actionTypeString:(QNActionType)actionType;

+ (NSArray <NSString *> *)apisWithActionType:(QNActionType)actionType;

@end

NS_ASSUME_NONNULL_END
