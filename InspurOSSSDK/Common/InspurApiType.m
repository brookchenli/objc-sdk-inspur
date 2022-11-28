//
//  QNApiType.m
//  InspurOSSSDK
//
//  Created by Brook on 2022/11/15.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurApiType.h"

@implementation InspurApiType

+ (NSString *)actionTypeString:(QNActionType)actionType {
    NSString *type = @"";
    switch (actionType) {
        case QNActionTypeUploadByForm:
            type = @"form";
            break;
        case QNActionTypeUploadByResumeV1:
            type = @"resume-v1";
            break;
        case QNActionTypeUploadByResumeV2:
            type = @"resume-v2";
            break;
        default:
            break;
    }
    return type;
}

+ (NSArray <NSString *> *)apisWithActionType:(QNActionType)actionType {
    NSArray *apis = nil;
    switch (actionType) {
        case QNActionTypeUploadByForm:
            apis = @[@"up.formupload"];
            break;
        case QNActionTypeUploadByResumeV1:
            apis = @[@"up.mkblk", @"up.bput", @"up.mkfile"];
            break;
        case QNActionTypeUploadByResumeV2:
            apis = @[@"up.initparts", @"up.uploadpart", @"up.completeparts"];
            break;
        default:
            break;
    }
    return apis;
}

@end
