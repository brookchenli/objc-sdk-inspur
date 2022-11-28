//
//  InspurUploadServerNetworkStatus.m
//  InspurOSSSDK
//
//  Created by Brook on 2020/11/17.
//  Copyright © 2020 Inspur. All rights reserved.
//

#import "InspurUtils.h"
#import "InspurNetworkStatusManager.h"
#import "InspurUploadServerNetworkStatus.h"

@implementation InspurUploadServerNetworkStatus

+ (InspurUploadServer *)getBetterNetworkServer:(InspurUploadServer *)serverA serverB:(InspurUploadServer *)serverB {
    return [self isServerNetworkBetter:serverA thanServerB:serverB] ? serverA : serverB;
}

+ (BOOL)isServerNetworkBetter:(InspurUploadServer *)serverA thanServerB:(InspurUploadServer *)serverB {
    if (serverA == nil) {
        return NO;
    } else if (serverB == nil) {
        return YES;
    }
    
    NSString *serverTypeA = [InspurNetworkStatusManager getNetworkStatusType:serverA.host ip:serverA.ip];
    NSString *serverTypeB = [InspurNetworkStatusManager getNetworkStatusType:serverB.host ip:serverB.ip];
    if (serverTypeA == nil) {
        return NO;
    } else if (serverTypeB == nil) {
        return YES;
    }
    
    InspurNetworkStatus *serverStatusA = [kInspurNetworkStatusManager getNetworkStatus:serverTypeA];
    InspurNetworkStatus *serverStatusB = [kInspurNetworkStatusManager getNetworkStatus:serverTypeB];

    return serverStatusB.speed < serverStatusA.speed;
}

@end
