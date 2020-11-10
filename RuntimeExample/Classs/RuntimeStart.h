//
//  RuntimeStart.h
//  RuntimeExample
//
//  Created by bairdweng on 2020/11/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RuntimeStart : NSObject

+ (void)fire;

+ (id)invocationClassName:(NSString *)className
      isInstance:(BOOL)isIns
      withTarget:(id)target
      methodName:(NSString *)name
    withArgument:(id  _Nullable )arg;
@end

NS_ASSUME_NONNULL_END
