//
//  JSWorkerThread.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSWorkerThread.h"
#import "JSContextManager.h"
#import "JSTask.h"
#import "JSMessageBridge.h"

@interface JSWorkerThread()

@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) JSMessageBridge *messageBridge;
@property (nonatomic, weak) id<JSWorkerDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t taskQueue;

@end

@implementation JSWorkerThread

- (instancetype)initWithDelegate:(id<JSWorkerDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _pendingTasks = [NSMutableArray array];
        _status = JSThreadStatusIdle;
        _taskQueue = dispatch_queue_create("com.jsworker.queue", DISPATCH_QUEUE_SERIAL);
        [self setupThread];
    }
    return self;
}

- (void)setupThread {
    self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
    self.thread.name = [NSString stringWithFormat:@"JSWorkerThread-%p", self];
    [self.thread start];
}

- (void)threadMain {
    @autoreleasepool {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [self setupJSContext];
        
        // 保持运行循环运行
        [runLoop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

- (void)setupJSContext {
    self.jsContext = [[JSContextManager sharedInstance] createContext];
    self.messageBridge = [[JSMessageBridge alloc] initWithWorkerThread:self];
    
    // 设置错误处理
    __weak typeof(self) weakSelf = self;
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSError *error = [NSError errorWithDomain:@"JSWorkerErrorDomain"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
        [weakSelf handleError:error];
    };
}

- (void)executeTask:(JSTask *)task {
    if (!task) return;
    
    // 直接在JS线程上执行，减少一次线程切换
    [self performSelector:@selector(executeJSTask:)
                onThread:self.thread
              withObject:task
           waitUntilDone:NO];
}

- (void)executeJSTask:(JSTask *)task {
    NSLog(@"Worker %@ 准备执行任务, task %@, 调度耗时: %.2fms", 
          self.thread.name, task, task.lifeTime);
    
    @try {
        // 准备任务
        [task prepare];
        
        // 注入任务参数到 Context
        JSContext *context = self.jsContext;
        NSLog(@"Worker %@ 注入参数, task %@", self.thread.name, task);
        
        for (NSString *key in task.params) {
            context[key] = task.params[key];
        }
        
        // 执行JS代码
        NSLog(@"Worker %@ 开始执行任务, task %@", self.thread.name, task);
        JSValue *result = [context evaluateScript:task.scriptString];
        NSLog(@"Worker %@ 执行完成，结果: %@, task %@", self.thread.name, result, task);
        
        // 完成任务
        [task complete:result error:nil];
        
        // 通知代理
        if ([self.delegate respondsToSelector:@selector(worker:didCompleteTask:)]) {
            [self.delegate worker:self didCompleteTask:task];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Worker %@ 执行出错: %@", self.thread.name, exception);
        NSError *error = [NSError errorWithDomain:@"JSWorkerErrorDomain"
                                           code:-1
                                           userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        [self handleError:error];
    }
}

- (void)handleError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(worker:didFailWithError:)]) {
        [self.delegate worker:self didFailWithError:error];
    }
}

- (void)executeBlock:(void(^)(void))block {
    if (!block) return;
    
    [self performSelector:@selector(executeBlockOnThread:)
                onThread:self.thread
              withObject:[block copy]
           waitUntilDone:NO];
}

- (void)executeBlockOnThread:(void(^)(void))block {
    block();
}

- (void)dealloc {
    [self.thread cancel];
}

@end
