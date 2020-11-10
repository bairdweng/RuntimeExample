//
//  ResolveModel.m
//  RuntimeExample
//
//  Created by bairdweng on 2020/11/10.
//

#import "ResolveModel.h"
#import <objc/message.h>

@implementation ResolveModel

void dynamicMethodIMP(id self, SEL _cmd) {
    NSLog(@" >> dynamicMethodIMP");
}
/// 实例方法决议
/// @param sel 方法 执行3次
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel) {
        NSLog(@"resolveInstanceMethod");
        class_addMethod([self class],sel,(IMP)dynamicMethodIMP,"v@:");
        return NO;
    }
    return [super resolveInstanceMethod:sel];
}

+ (BOOL)resolveClassMethod:(SEL)sel {
    
    NSLog(@"+ (BOOL)resolveClassMethod:(SEL)sel");
    if (sel) {
        IMP methodIMP = class_getMethodImplementation(self, @selector(unimplementedMethod:));
        Method method = class_getInstanceMethod(self.class, @selector(unimplementedMethod:));
        const char *methodType = method_getTypeEncoding(method);
        return class_addMethod(objc_getMetaClass("ResolveModel"), sel, methodIMP, methodType);
    }
    return [super resolveClassMethod:sel];
    
}
- (void)unimplementedMethod:(SEL)sel {
    NSLog(@"没实现？没关系，绝不崩溃");
}


void dynamicMethodIMP1(id self, SEL _cmd) {
    NSLog(@" >> dynamicMethodIMP");
}
+ (void)hello {
    NSLog(@"hello");
}
- (void)insHello {
    NSLog(@"insHello");
}

@end
