//
//  InspurImageSessionManager.m
//  InspurOSSDemo
//
//  Created by 陈历 on 2022/11/28.
//

#import "InspurImageAsyncManager.h"
#import "InspurImageProcess.h"

@interface InspurImageAsyncManager ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation InspurImageAsyncManager

+ (InspurImageAsyncManager *)shardInstance {
    static InspurImageAsyncManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[InspurImageAsyncManager alloc] init];
        [instance initData];
    });
    return instance;
}

- (void)initData {
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (void)averageHue:(NSString *)url completion: (InspurImageInfoCompletion)completion {
    InspurImageProcess *process = [[InspurImageProcess alloc] initWithURL:url];
    [process make:^(InspurImageAttributeMaker * _Nonnull maker) {
        maker.averageHue();
    }];
    [self fetchInfo:url completion:completion];
}

- (void)exifInfo:(NSString *)url completion:(InspurImageInfoCompletion)completion {
    InspurImageProcess *process = [[InspurImageProcess alloc] initWithURL:url];
    [process make:^(InspurImageAttributeMaker * _Nonnull maker) {
        maker.info();
    }];
    [self fetchInfo:url completion:completion];
}

- (void)fetchInfo:(NSString *)url completion:(InspurImageInfoCompletion)completion {
    NSURLSessionTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error && completion) {
            completion(nil, error);
        } else {
            NSError *error1;
            NSMutableDictionary * innerJson = [NSJSONSerialization JSONObjectWithData:data
                                                          options:kNilOptions
                                                            error:&error1];
            if (error) {
                completion(nil, error);
            } else {
                completion(innerJson, nil);
            }
            NSLog(@"innerJson:%@ error:%@", innerJson, error);
        }
    }];
    [task resume];
}

@end
