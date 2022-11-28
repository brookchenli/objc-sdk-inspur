//
//  QNUploadSourceStream.h
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurUploadSourceStream : NSObject <InspurUploadSource>

+ (instancetype)stream:(NSInputStream * _Nonnull)stream
              sourceId:(NSString * _Nullable)sourceId
                  size:(long long)size
              fileName:(NSString * _Nullable)fileName;

@end

NS_ASSUME_NONNULL_END
