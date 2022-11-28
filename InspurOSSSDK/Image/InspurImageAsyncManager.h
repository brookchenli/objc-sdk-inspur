//
//  InspurImageSessionManager.h
//  InspurOSSDemo
//
//  Created by 陈历 on 2022/11/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^InspurImageInfoCompletion)(id _Nullable obj, NSError * _Nullable error);

@interface InspurImageAsyncManager : NSObject

+ (InspurImageAsyncManager *)shardInstance;

- (void)averageHue:(NSString *)url completion: (InspurImageInfoCompletion)completion;
- (void)exifInfo: (InspurImageInfoCompletion)completion;;

@end

NS_ASSUME_NONNULL_END
