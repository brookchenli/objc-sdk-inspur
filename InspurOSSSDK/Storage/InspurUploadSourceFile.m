//
//  InspurUploadSourceFile.m
//  InspurOSSSDK
//
//  Created by Brook on 2021/5/10.
//  Copyright © 2021 Inspur. All rights reserved.
//

#import "InspurUploadSourceFile.h"

@interface InspurUploadSourceFile()

@property(nonatomic, strong)id <InspurFileDelegate> file;

@end
@implementation InspurUploadSourceFile

+ (instancetype)file:(id <InspurFileDelegate>)file {
    InspurUploadSourceFile *sourceFile = [[InspurUploadSourceFile alloc] init];
    sourceFile.file = file;
    return sourceFile;
}


- (BOOL)couldReloadSource {
    return self.file != nil;
}

- (BOOL)reloadSource {
    return true;
}

- (nonnull NSString *)getId {
    return [NSString stringWithFormat:@"%@_%lld", [self getFileName], [self.file modifyTime]];
}

- (nonnull NSString *)getFileName {
    return [[self.file path] lastPathComponent];
}

- (long long)getSize {
    return [self.file size];
}

- (NSData *)readData:(NSInteger)dataSize dataOffset:(long long)dataOffset error:(NSError *__autoreleasing  _Nullable *)error {
    return [self.file read:dataOffset size:dataSize error:error];
}

- (void)close {
    [self.file close];
}

- (NSString *)sourceType {
    if ([self.file respondsToSelector:@selector(fileType)]) {
        return self.file.fileType;
    } else {
        return @"SourceFile";
    }
}
@end
