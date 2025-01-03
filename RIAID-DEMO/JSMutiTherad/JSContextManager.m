//
//  JSContextManager.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSContextManager.h"
#import "JSTask.h"
#import "JSThreadPoolManager.h"

@interface JSContextManager()

@property (nonatomic, strong) NSMutableDictionary<NSString *, JSContext *> *contextPool;
@property (nonatomic, strong) dispatch_queue_t contextQueue;
@property (nonatomic, assign) NSUInteger internalContextCount;
@property (nonatomic, strong) NSMutableDictionary *timerCallbacks;

@end

@implementation JSContextManager

+ (instancetype)sharedInstance {
    static JSContextManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JSContextManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _contextPool = [NSMutableDictionary dictionary];
        _contextQueue = dispatch_queue_create("com.jsmanager.queue", DISPATCH_QUEUE_SERIAL);
        _internalContextCount = 0;
        _timerCallbacks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (JSContext *)createContext {
    JSContext *context = [[JSContext alloc] init];
    [self setupGlobalAPI:context];
    [self setupExceptionHandler:context];
    
    dispatch_sync(self.contextQueue, ^{
        NSString *contextId = [[NSUUID UUID] UUIDString];
        self.contextPool[contextId] = context;
        self.internalContextCount++;
    });
    
    return context;
}

- (void)setupGlobalAPI:(JSContext *)context {
    // 基础日志功能
    context[@"log"] = ^(JSValue *message) {
        NSLog(@"[JS Log]: %@", [message toString]);
    };
    
    // 控制台API
    context[@"_consoleLog"] = ^(JSValue *message) {
        NSLog(@"[JS Console]: %@", [message toString]);
    };
    
    context[@"_consoleError"] = ^(JSValue *message) {
        NSLog(@"[JS Error]: %@", [message toString]);
    };
    
    context[@"_consoleDebug"] = ^(JSValue *message) {
        NSLog(@"[JS Debug]: %@", [message toString]);
    };
    
    // 设置 console 对象
    [context evaluateScript:@"\
        var console = {\
            log: function(msg) { _consoleLog(msg); },\
            error: function(msg) { _consoleError(msg); },\
            debug: function(msg) { _consoleDebug(msg); }\
        };\
    "];
    
    // 定时器API
    __weak typeof(self) weakSelf = self;
    __weak typeof(context) weakContext = context;
    
    context[@"setTimeout"] = ^id(JSValue *callback, JSValue *delay) {
        NSLog(@"setTimeout called with delay: %@", delay);
        if ([callback isUndefined] || ![callback isObject]) {
            NSLog(@"setTimeout: invalid callback");
            return nil;
        }
        
        NSTimeInterval delayTime = [delay toDouble];
        if (delayTime < 0) delayTime = 0;
        
        // 生成唯一的定时器ID
        NSString *timerId = [[NSUUID UUID] UUIDString];
        
        // 保存回调
        JSContextManager *strongSelf = weakSelf;
        JSContext *strongContext = weakContext;
        
        if (!strongSelf || !strongContext) {
            NSLog(@"setTimeout: context or manager is gone");
            return nil;
        }
        
        // 强引用回调和上下文
        strongSelf.timerCallbacks[timerId] = @{
            @"callback": callback,
            @"context": strongContext
        };
        // 延迟delayTime毫秒
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            @try {
                JSContextManager *strongSelf = weakSelf;
                if (!strongSelf) {
                    NSLog(@"setTimeout: manager is gone when executing callback");
                    return;
                }
                
                NSLog(@"Executing setTimeout callback for timer: %@", timerId);
                NSDictionary *timerInfo = strongSelf.timerCallbacks[timerId];
                JSValue *savedCallback = timerInfo[@"callback"];
                JSContext *savedContext = timerInfo[@"context"];
                
                if (savedCallback && savedContext) {
                    [savedCallback callWithArguments:@[]];
                }
                
                // 清理回调
                [strongSelf.timerCallbacks removeObjectForKey:timerId];
            } @catch (NSException *exception) {
                NSLog(@"setTimeout callback error: %@", exception);
            }
        });
        
        return timerId;
    };
    
    // 添加 clearTimeout
    context[@"clearTimeout"] = ^(JSValue *timerId) {
        JSContextManager *strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (![timerId isString]) return;
        [strongSelf.timerCallbacks removeObjectForKey:[timerId toString]];
    };
    
    // 添加多线程执行API
    context[@"doInSubThread"] = ^(JSValue *taskFunction, JSValue *options) {
        // 从 options 中获取配置
        NSInteger workerCount = [options[@"workers"] toInt32];
        if (workerCount <= 0) workerCount = 4;
        
        // 获取任务参数并保持强引用
        __block JSValue *taskParams = options[@"params"];
        __block JSValue *onResult = options[@"onResult"];
        __block JSValue *onComplete = options[@"onComplete"];
        
        // 创建任务组
        dispatch_group_t group = dispatch_group_create();
        
        // 创建执行器任务脚本，注意格式化和换行
        NSString *taskScript = [NSString stringWithFormat:@"(function() {\n"
            "    try {\n"
            "        console.log('Worker script starting...');\n"
            "        const taskFunc = %@;\n"
            "        const baseParams = %@;\n"
            "        const workerId = %@;\n"
            "\n"
            "        // 构建任务参数\n"
            "        const params = {\n"
            "            testCase: baseParams.testCases[workerId],\n"
            "            workerId: workerId\n"
            "        };\n"
            "\n"
            "        console.log('Worker ' + workerId + ' starting...', \n"
            "            'testCase:', params.testCase && params.testCase.name,\n"
            "            'workerId:', params.workerId);\n"
            "\n"
            "        // 执行任务函数\n"
            "        const result = taskFunc(params);\n"
            "        console.log('Worker ' + workerId + ' completed...', \n"
            "            'name:', result.name,\n"
            "            'workerId:', result.workerId,\n"
            "            'computeTime:', result.computeTime,\n"
            "            'result:', result.result);\n"
            "        return result;\n"
            "    } catch (error) {\n"
            "        console.error('Worker ' + workerId + ' error:', error.toString());\n"
            "        console.error('Stack:', error.stack);\n"
            "        throw error;\n"
            "    }\n"
            "})();",
            taskFunction.toString,
            [self JSONStringFromJSValue:taskParams],
            @"%@"];
        
        // 为每个工作线程创建任务
        for (NSInteger i = 1; i <= workerCount; i++) {
            dispatch_group_enter(group);
            
            // 记录创建开始时间
            NSDate *creationStartTime = [NSDate date];
            
            // 创建最终的执行脚本
            NSString *finalScript = [NSString stringWithFormat:taskScript, @(i)];
            JSTask *task = [[JSTask alloc] initWithScript:finalScript];
            
            // 强引用task
            __block JSTask *strongTask = task;
            
            // 设置回调
            task.callback = ^(id result) {
                @try {
                    
                    if (![onResult isUndefined]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [onResult callWithArguments:@[result ?: [NSNull null]]];
                        });
                    }
                } @catch (NSException *exception) {
                    NSLog(@"Task callback error: %@", exception);
                } @finally {
                    strongTask = nil;
                    dispatch_group_leave(group);
                }
            };
            
            task.errorCallback = ^(NSError *error) {
                NSLog(@"Task execution error: %@", error);
                strongTask = nil;
                dispatch_group_leave(group);
            };
            // 计算创建耗时
            NSLog(@"Worker %@ 创建耗时: %.2f ms", task, [task lifeTime]);
            // 提交到线程池执行
            [[JSThreadPoolManager sharedInstance] executeTask:task];
        }
        
        // 所有任务完成的回调
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            @try {
                if (![onComplete isUndefined]) {
                    [onComplete callWithArguments:@[]];
                }
            } @catch (NSException *exception) {
                NSLog(@"Complete callback error: %@", exception);
            }
        });
    };
    
    // 添加简单的 Promise 实现
    NSString *promisePolyfill = @"\
        if (typeof Promise === 'undefined') {\
            function Promise(executor) {\
                var callbacks = [];\
                var value = null;\
                var state = 'pending';\
                \
                function resolve(result) {\
                    if (state !== 'pending') return;\
                    state = 'fulfilled';\
                    value = result;\
                    callbacks.forEach(function(callback) {\
                        callback(value);\
                    });\
                }\
                \
                function reject(error) {\
                    if (state !== 'pending') return;\
                    state = 'rejected';\
                    value = error;\
                    callbacks.forEach(function(callback) {\
                        callback(value);\
                    });\
                }\
                \
                this.then = function(onFulfilled) {\
                    return new Promise(function(resolve) {\
                        if (state === 'pending') {\
                            callbacks.push(function(result) {\
                                resolve(onFulfilled(result));\
                            });\
                        } else {\
                            resolve(onFulfilled(value));\
                        }\
                    });\
                };\
                \
                executor(resolve, reject);\
            }\
            \
            Promise.resolve = function(value) {\
                return new Promise(function(resolve) {\
                    resolve(value);\
                });\
            };\
        }\
    ";
    
    [context evaluateScript:promisePolyfill];
    
    // 加载 JSON5 库
    NSString *libPath = [[NSBundle mainBundle] pathForResource:@"json5" ofType:@"js" inDirectory:@"libs"];
    if (libPath) {
        NSError *error = nil;
        NSString *json5Source = [NSString stringWithContentsOfFile:libPath 
                                                        encoding:NSUTF8StringEncoding 
                                                           error:&error];
        if (!error && json5Source) {
            [context evaluateScript:json5Source];
            NSLog(@"JSON5 library loaded successfully");
        } else {
            NSLog(@"Failed to load JSON5 library: %@", error);
        }
    }
}

- (void)setupExceptionHandler:(JSContext *)context {
    context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"[JS Error]: %@", exception);
        // 这里可以添加错误上报逻辑
    };
}

- (void)destroyContext:(JSContext *)context {
    if (!context) return;
    
    dispatch_sync(self.contextQueue, ^{
        NSString *contextIdToRemove = nil;
        for (NSString *contextId in self.contextPool) {
            if (self.contextPool[contextId] == context) {
                contextIdToRemove = contextId;
                break;
            }
        }
        if (contextIdToRemove) {
            [self.contextPool removeObjectForKey:contextIdToRemove];
            self.internalContextCount--;
        }
    });
}

- (void)clearAllContexts {
    dispatch_sync(self.contextQueue, ^{
        [self.contextPool removeAllObjects];
        self.internalContextCount = 0;
    });
}

- (NSUInteger)activeContextCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.contextQueue, ^{
        count = self.internalContextCount;
    });
    return count;
}

- (NSString *)JSONStringFromJSValue:(JSValue *)value {
    if ([value isUndefined] || [value isNull]) {
        return @"null";
    }
    
    // 如果是函数，直接返回函数字符串
    if ([value isObject] && [[value toString] hasPrefix:@"function"]) {
        return [value toString];
    }
    
    id objcValue = [value toObject];
    if ([NSJSONSerialization isValidJSONObject:objcValue]) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:objcValue
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
        if (jsonData) {
            return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    
    // 如果无法序列化，返回空对象
    return @"{}";
}

@end
