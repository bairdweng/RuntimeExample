//
//  BWHotFix.m
//  RuntimeExample
//
//  Created by bairdweng on 2020/11/10.
//

#import "BWHotFix.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <JavaScriptCore/JavaScriptCore.h>
// 消除警告
#pragma GCC diagnostic ignored "-Wundeclared-selector"


#pragma mark - JPBoxing
@implementation JPBoxing

#define JPBOXING_GEN(_name, _prop, _type)                                      \
+(instancetype)_name : (_type)obj {                                          \
JPBoxing *boxing = [[JPBoxing alloc] init];                                \
boxing._prop = obj;                                                        \
return boxing;                                                             \
}

JPBOXING_GEN(boxObj, obj, id)
JPBOXING_GEN(boxPointer, pointer, void *)
JPBOXING_GEN(boxClass, cls, Class)
JPBOXING_GEN(boxWeakObj, weakObj, id)
JPBOXING_GEN(boxAssignObj, assignObj, id)

- (id)unbox {
    if (self.obj)
        return self.obj;
    if (self.weakObj)
        return self.weakObj;
    if (self.assignObj)
        return self.assignObj;
    if (self.cls)
        return self.cls;
    return self;
}
- (void *)unboxPointer {
    return self.pointer;
}
- (Class)unboxClass {
    return self.cls;
}
@end





@implementation BWHotFix

#pragma mark 静态变量区
// js上下文
static JSContext *_context;

// 正则
static NSRegularExpression *_regex;
static NSString *_regexStr = @"(?<!\\\\)\\.\\s*(\\w+)\\s*\\(";
static NSString *_replaceStr = @".__c(\"$1\")(";
static char *kPropAssociatedObjectKey;
static BOOL _autoConvert;
static BOOL _convertOCNumberToString;
// 处理null
static NSObject *_nilObj;
static NSObject *_nullObj;
// 属性的定义
static NSMutableDictionary *_propKeys;
// 输出log
static void (^_exceptionBlock)(NSString *log) = ^void(NSString *log) {
    NSLog(@"log===%@", log);
    //    NSCAssert(NO, log);
};

+ (void)fire {
    if (![JSContext class] || _context) {
        return;
    }
    JSContext *context = [[JSContext alloc] init];
    // 注入脚本
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"BWHotFix" ofType:@"js"];
    if (!path)
        _exceptionBlock(@"can't find BWHotFix.js");
    // 处理log
    context[@"_OC_log"] = ^() {
        NSArray *args = [JSContext currentArguments];
        for (JSValue *jsVal in args) {
            NSLog(@"JSPatch.log: %@", jsVal);
        }
    };
    // 处理异常
    context[@"_OC_catch"] = ^(JSValue *msg, JSValue *stack) {
        _exceptionBlock(
                        [NSString stringWithFormat:@"js exception, \nmsg: %@, \nstack: \n %@",
                         [msg toObject], [stack toObject]]);
    };
    // 设置关联属性
    context[@"_OC_getCustomProps"] = ^id(JSValue *obj) {
        id realObj = formatJSToOC(obj);
        return objc_getAssociatedObject(realObj, kPropAssociatedObjectKey);
    };
    context[@"_OC_setCustomProps"] = ^(JSValue *obj, JSValue *val) {
        id realObj = formatJSToOC(obj);
        objc_setAssociatedObject(realObj, kPropAssociatedObjectKey, val, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    };
    
    // 对象转换
    context[@"_OC_formatJSToOC"] = ^id(JSValue *obj) {
        return formatJSToOC(obj);
    };
    context[@"_OC_formatOCToJS"] = ^id(JSValue *obj) {
        return formatOCToJS([obj toObject]);
    };
    // 定义类
    context[@"_OC_defineClass"] =  ^(NSString *classDeclaration, JSValue *instanceMethods, JSValue *classMethods) {
        return defineClass(classDeclaration, instanceMethods, classMethods);
    };
    // 获取传入类的父类名
    context[@"_OC_superClsName"] = ^(NSString *clsName) {
        Class cls = NSClassFromString(clsName);
        return NSStringFromClass([cls superclass]);
    };
    // 实例方法
    context[@"_OC_callI"] = ^id(JSValue *obj, NSString *selectorName,
                                JSValue *arguments, BOOL isSuper) {
        
        return  nil;
//        return callSelector(nil, selectorName, arguments, obj, isSuper);
    };
    
    // 类方法
    context[@"_OC_callC"] = ^id(NSString *className, NSString *selectorName, JSValue *arguments) {
        return  nil;
    };
    // 处理null
    _nullObj = [[NSObject alloc] init];
    context[@"_OC_null"] = formatOCToJS(_nullObj);
    NSString *jsCore = [[NSString alloc]
                        initWithData:[[NSFileManager defaultManager] contentsAtPath:path]
                        encoding:NSUTF8StringEncoding];
    if ([context respondsToSelector:@selector(evaluateScript:withSourceURL:)]) {
        [context evaluateScript:jsCore
                  withSourceURL:[NSURL URLWithString:@"BWHotFix.js"]];
    } else {
        [context evaluateScript:jsCore];
    }
    _context = context;
}
#pragma mark 1.加载js
+ (void)loadFile:(NSString *)filePath {
    NSString *script = [NSString stringWithContentsOfFile:filePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
    // 资源的URL
    NSURL *resourceURL = [NSURL URLWithString:[filePath lastPathComponent]];
    if (!script || ![JSContext class]) {
        _exceptionBlock(@"script is nil");
    }
    [self fire];
    if (!_regex) {
        _regex = [NSRegularExpression regularExpressionWithPattern:_regexStr
                                                           options:0
                                                             error:nil];
    }
    // 代码转换
    NSString *formatedScript = [NSString
                                stringWithFormat:@";(function(){try{\n%@\n}catch(e){_OC_catch(e.message, "
                                @"e.stack)}})();",
                                [_regex
                                 stringByReplacingMatchesInString:script
                                 options:0
                                 range:NSMakeRange(
                                                   0,
                                                   script.length)
                                 withTemplate:_replaceStr]];
    @try {
        if ([_context
             respondsToSelector:@selector(evaluateScript:withSourceURL:)]) {
            [_context evaluateScript:formatedScript withSourceURL:resourceURL];
        } else {
            [_context evaluateScript:formatedScript];
        }
    } @catch (NSException *exception) {
        _exceptionBlock([NSString stringWithFormat:@"%@", exception]);
    }
}

#pragma mark 2.对象转换
static id formatJSToOC(JSValue *jsval) {
    id obj = [jsval toObject];
    if (!obj || [obj isKindOfClass:[NSNull class]])
        return _nilObj;
    // 如果是 JPBoxing 类型的，那么解包
    if ([obj isKindOfClass:[JPBoxing class]])
        return [obj unbox];
    // 如果是数组类型的，那么把数组里的所有都 format 一遍
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *newArr = [[NSMutableArray alloc] init];
        for (int i = 0; i < [(NSArray *)obj count]; i++) {
            [newArr addObject:formatJSToOC(jsval[i])];
        }
        return newArr;
    }
    // 如果是字典类型的
    if ([obj isKindOfClass:[NSDictionary class]]) {
        // 如果内部有 __obj 字段
        if (obj[@"__obj"]) {
            // 拿到 __obj 对应的对象
            id ocObj = [obj objectForKey:@"__obj"];
            if ([ocObj isKindOfClass:[JPBoxing class]])
                return [ocObj unbox];
            return ocObj;
        } else if (obj[@"__clsName"]) {
            // 如果存在 __clsName 对象，那么把 clsName 对应的 Class 拿出
            return NSClassFromString(obj[@"__clsName"]);
        }
        // 如果是 block
        /*
         if (obj[@"__isBlock"]) {
         Class JPBlockClass = NSClassFromString(@"JPBlock");
         if (JPBlockClass && ![jsval[@"blockObj"] isUndefined]) {
         return [JPBlockClass performSelector:@selector(blockWithBlockObj:)
         withObject:[jsval[@"blockObj"] toObject]];
         } else {
         return genCallbackBlock(jsval);
         }
         }*/
        NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
        for (NSString *key in [obj allKeys]) {
            [newDict setObject:formatJSToOC(jsval[key]) forKey:key];
        }
        return newDict;
    }
    return obj;
}

static id formatOCToJS(id obj) {
    if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDate class]]) {
        return _autoConvert ? obj: _wrapObj([JPBoxing boxObj:obj]);
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        return _convertOCNumberToString ? [(NSNumber*)obj stringValue] : obj;
    }
    if ([obj isKindOfClass:NSClassFromString(@"NSBlock")] || [obj isKindOfClass:[JSValue class]]) {
        return obj;
    }
    return _wrapObj(obj);
}
static NSDictionary *_wrapObj(id obj) {
    if (!obj || obj == _nilObj) {
        return @{@"__isNil": @(YES)};
    }
    return @{@"__obj": obj, @"__clsName": NSStringFromClass([obj isKindOfClass:[JPBoxing class]] ? [[((JPBoxing *)obj) unbox] class]: [obj class])};
}

#pragma mark 3.类的定义
static NSDictionary *defineClass(NSString *classDeclaration,
                                 JSValue *instanceMethods,
                                 JSValue *classMethods) {
    NSScanner *scanner = [NSScanner scannerWithString:classDeclaration];
    NSString *className;
    NSString *superClassName;
    NSString *protocolNames;
    [scanner scanUpToString:@":" intoString:&className];
    if (!scanner.isAtEnd) {
        scanner.scanLocation = scanner.scanLocation + 1;
        [scanner scanUpToString:@"<" intoString:&superClassName];
        if (!scanner.isAtEnd) {
            scanner.scanLocation = scanner.scanLocation + 1;
            [scanner scanUpToString:@">" intoString:&protocolNames];
        }
    }
    if (!superClassName)
        superClassName = @"NSObject";
    className = trim(className);
    superClassName = trim(superClassName);
    NSArray *protocols = [protocolNames length]
    ? [protocolNames componentsSeparatedByString:@","]
    : nil;
    
    // 反射为类名
    Class cls = NSClassFromString(className);
    if (!cls) {
        // 如果子类没有实例化成功，那么实例化父类
        Class superCls = NSClassFromString(superClassName);
        // 如果父类也没有实例化成功
        if (!superCls) {
            // 直接报错
            _exceptionBlock([NSString
                             stringWithFormat:@"can't find the super class %@", superClassName]);
            return @{ @"cls" : className };
        }
        // 存在父类，不存在子类，那么创建一个子类时 添加类
        cls = objc_allocateClassPair(superCls, className.UTF8String, 0);
        // 注册类
        objc_registerClassPair(cls);
    }
    // 如果有协议，那么拿到所有的协议名，给类增加协议
    if (protocols.count > 0) {
        for (NSString *protocolName in protocols) {
            Protocol *protocol = objc_getProtocol(
                                                  [trim(protocolName) cStringUsingEncoding:NSUTF8StringEncoding]);
            class_addProtocol(cls, protocol);
        }
    }
    // 增加方法 为什么循环两次？
    for (int i = 0; i < 2; i++) {
        BOOL isInstance = i == 0;
        JSValue *jsMethods = isInstance ? instanceMethods : classMethods;
        // 如果是类方法那么要取出 cls 的 metaClass，否则直接拿出 cls
        Class currCls = isInstance ? cls : objc_getMetaClass(className.UTF8String);
        NSDictionary *methodDict = [jsMethods toDictionary];
        for (NSString *jsMethodName in methodDict.allKeys) {
            JSValue *jsMethodArr = [jsMethods valueForProperty:jsMethodName];
            int numberOfArg = [jsMethodArr[0] toInt32];
            NSString *selectorName = convertJPSelectorString(jsMethodName);
            if ([selectorName componentsSeparatedByString:@":"].count - 1 <
                numberOfArg) {
                selectorName = [selectorName stringByAppendingString:@":"];
            }
            
            JSValue *jsMethod = jsMethodArr[1];
            // 判断某个类是否有
            if (class_respondsToSelector(currCls,
                                         NSSelectorFromString(selectorName))) {
                overrideMethod(currCls, selectorName, jsMethod, !isInstance, NULL);
            } else {
                BOOL overrided = NO;
                for (NSString *protocolName in protocols) {
                    char *types = methodTypesInProtocol(protocolName, selectorName,
                                                        isInstance, YES);
                    if (!types)
                        types = methodTypesInProtocol(protocolName, selectorName,
                                                      isInstance, NO);
                    if (types) {
                        overrideMethod(currCls, selectorName, jsMethod, !isInstance, types);
                        free(types);
                        overrided = YES;
                        break;
                    }
                }
                if (!overrided) {
                    if (![[jsMethodName substringToIndex:1] isEqualToString:@"_"]) {
                        NSMutableString *typeDescStr = [@"@@:" mutableCopy];
                        for (int i = 0; i < numberOfArg; i++) {
                            [typeDescStr appendString:@"@"];
                        }
                        overrideMethod(
                                       currCls, selectorName, jsMethod, !isInstance,
                                       [typeDescStr cStringUsingEncoding:NSUTF8StringEncoding]);
                    }
                }
            }
        }
    }
    class_addMethod(cls, @selector(getProp:), (IMP)getPropIMP, "@@:@");
    class_addMethod(cls, @selector(setProp:forKey:), (IMP)setPropIMP, "v@:@@");
    return @{ @"cls" : className, @"superCls" : superClassName };
}
static NSString *trim(NSString *string) {
    return [string
            stringByTrimmingCharactersInSet:[NSCharacterSet
                                             whitespaceAndNewlineCharacterSet]];
}
static NSString *convertJPSelectorString(NSString *selectorString) {
    // 用 - 代替 __
    NSString *tmpJSMethodName =
    [selectorString stringByReplacingOccurrencesOfString:@"__"
                                              withString:@"-"];
    NSString *selectorName =
    [tmpJSMethodName stringByReplacingOccurrencesOfString:@"_"
                                               withString:@":"];
    return [selectorName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
}
static id getPropIMP(id slf, SEL selector, NSString *propName) {
    return objc_getAssociatedObject(slf, propKey(propName));
}
static void setPropIMP(id slf, SEL selector, id val, NSString *propName) {
    objc_setAssociatedObject(slf, propKey(propName), val,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static const void *propKey(NSString *propName) {
    if (!_propKeys)
        _propKeys = [[NSMutableDictionary alloc] init];
    id key = _propKeys[propName];
    if (!key) {
        key = [propName copy];
        [_propKeys setObject:key forKey:propName];
    }
    return (__bridge const void *)(key);
}
static char *methodTypesInProtocol(NSString *protocolName,
                                   NSString *selectorName,
                                   BOOL isInstanceMethod, BOOL isRequired) {
    // 获取 protocol
    Protocol *protocol = objc_getProtocol(
                                          [trim(protocolName) cStringUsingEncoding:NSUTF8StringEncoding]);
    unsigned int selCount = 0;
    // 复制 protocol 的方法列表
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(
                                                                                 protocol, isRequired, isInstanceMethod, &selCount);
    for (int i = 0; i < selCount; i++) {
        // 遍历 protocol 的方法列表，找到和目标方法同名的方法，然后通过 c
        // 方法复制出来返回。否则返回 NULL
        if ([selectorName isEqualToString:NSStringFromSelector(methods[i].name)]) {
            char *types = malloc(strlen(methods[i].types) + 1);
            strcpy(types, methods[i].types);
            free(methods);
            return types;
        }
    }
    free(methods);
    return NULL;
}

#pragma mark 4.重写方法
static void overrideMethod(Class cls, NSString *selectorName, JSValue *function,
                           BOOL isClassMethod, const char *typeDescription) {
}
@end
