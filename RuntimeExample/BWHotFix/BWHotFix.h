//
//  BWHotFix.h
//  RuntimeExample
//
//  Created by bairdweng on 2020/11/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BWHotFix : NSObject
+ (void)fire;

+ (void)loadFile:(NSString *)filePath;

@end


@interface JPBoxing : NSObject
@property (nonatomic) id obj;
@property (nonatomic) void *pointer;
@property (nonatomic) Class cls;
@property (nonatomic, weak) id weakObj;
@property (nonatomic, assign) id assignObj;
- (id)unbox;
- (void *)unboxPointer;
- (Class)unboxClass;
@end

NS_ASSUME_NONNULL_END
