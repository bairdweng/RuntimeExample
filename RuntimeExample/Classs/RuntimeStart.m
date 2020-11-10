//
//  RuntimeStart.m
//  RuntimeExample
//
//  Created by bairdweng on 2020/11/9.
//

#import "RuntimeStart.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import "ResolveModel.h"
@implementation RuntimeStart

+ (void)fire {
    [self replaceStartVc];
    [self dynamicInvocation];
    [self runResolve];
}

// 动态调用
+ (void)dynamicInvocation {
    Class cls = NSClassFromString(@"ResolveModel");
    id ins = [[cls alloc]init];
    // 实例
    [RuntimeStart invocationClassName:@"ResolveModel" isInstance:YES withTarget:ins methodName:@"insHello" withArgument:nil];
    // 类方法
    [RuntimeStart invocationClassName:@"ResolveModel" isInstance:NO withTarget:cls methodName:@"hello" withArgument:nil];
}

// 动态决议
+ (void)runResolve {
    
    Class cls = NSClassFromString(@"ResolveModel");
    SEL testFunc = NSSelectorFromString(@"NoFindFunc");
    id ins = [[cls alloc]init];
    [ins performSelector:testFunc];
    
    
    SEL testFunc1 = NSSelectorFromString(@"ccl");
    [ResolveModel performSelector:testFunc1];

   

}

// 替换ViewDidLoad的实现
+ (void)replaceStartVc {
    Class cls = NSClassFromString(@"ViewController");
    SEL originalSelector = NSSelectorFromString(@"viewDidLoad");
    SEL swizzledSelector = NSSelectorFromString(@"newViewDidLoad");
    // 原始方法
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    // 新的方法
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    // 交换方法
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

// 好像交换方法只能在本类
// 相当于hook viewDidLoad
- (void)newViewDidLoad {
    // 交换方法之后，self变成了ViewController
    id view = [RuntimeStart invocationClassName:@"ViewController" isInstance:YES withTarget:self methodName:@"view" withArgument:NULL];
    [RuntimeStart invocationClassName:@"UIView" isInstance:YES withTarget:view methodName:@"setBackgroundColor:" withArgument:[UIColor blueColor]];
}

/// 方法调用
/// @param className 类名称
/// @param target target
/// @param name 方法名称
/// @param arg 参数
+ (id)invocationClassName:(NSString *)className
      isInstance:(BOOL)isIns
      withTarget:(id)target
      methodName:(NSString *)name
      withArgument:(id  _Nullable )arg {
    Class cls = NSClassFromString(className);
    SEL selector = NSSelectorFromString(name);
    // 实例方法
    NSMethodSignature *methodSignature = isIns ? [cls instanceMethodSignatureForSelector:selector] : [cls methodSignatureForSelector:selector];
    if (!methodSignature) {
        return nil;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    invocation.target = target;
    invocation.selector = selector;
    if (arg) {
        [invocation setArgument:&arg atIndex:2];
    }
    [invocation invoke];
    id  returnValue = nil;
    if (methodSignature.methodReturnLength) {
        [invocation getReturnValue:&returnValue];
    }
    return returnValue;
}

@end

