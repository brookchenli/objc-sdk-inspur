//
//  QNZone.m
//  QiniuSDK
//
//  Created by Brook on 2020/4/16.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurZone.h"
#import "InspurUpToken.h"
#import "InspurZoneInfo.h"

@implementation InspurZone

- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken *)token {
    return [self getZonesInfoWithToken:token actionType:QNActionTypeNone];
}

- (InspurZonesInfo *)getZonesInfoWithToken:(InspurUpToken * _Nullable)token
                            actionType:(QNActionType)actionType {
    return nil;
}

- (void)preQuery:(InspurUpToken *)token
              on:(InspurPrequeryReturn)ret {
    [self preQuery:token actionType:QNActionTypeNone on:ret];
}

- (void)preQuery:(InspurUpToken *)token
      actionType:(QNActionType)actionType
              on:(InspurPrequeryReturn)ret {
    ret(0, nil, nil);
}

@end
