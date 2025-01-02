//
//  JSMessageBridge.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "JSMessageBridge.h"
#import "JSWorkerThread.h"

@interface JSMessageBridge()

@property (nonatomic, strong) dispatch_queue_t messageQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, JSMessageHandler> *messageHandlers;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messageBuffer;

@end

@implementation JSMessageBridge

- (instancetype)initWithWorkerThread:(JSWorkerThread *)workerThread {
    if (self = [super init]) {
        _workerThread = workerThread;
        _messageQueue = dispatch_queue_create("com.jsmessagebridge.queue", DISPATCH_QUEUE_SERIAL);
        _messageHandlers = [NSMutableDictionary dictionary];
        _messageBuffer = [NSMutableArray array];
    }
    return self;
}

- (void)postMessage:(id)message toThread:(JSWorkerThread *)thread {
    if (!message || !thread) return;
    
    dispatch_async(self.messageQueue, ^{
        NSDictionary *messagePackage = @{
            @"sender": self.workerThread ?: [NSNull null],
            @"receiver": thread,
            @"message": message,
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        // 如果目标线程正忙，先缓存消息
        if ([(id<JSWorkerThreadInterface>)thread status] == JSThreadStatusBusy) {
            [self.messageBuffer addObject:messagePackage];
            return;
        }
        
        [self deliverMessage:messagePackage];
    });
}

- (void)registerMessageHandler:(JSMessageHandler)handler forType:(NSString *)type {
    if (!handler || !type) return;
    
    dispatch_async(self.messageQueue, ^{
        self.messageHandlers[type] = handler;
    });
}

- (void)deliverMessage:(NSDictionary *)messagePackage {
    JSWorkerThread *receiver = messagePackage[@"receiver"];
    if (!receiver) return;
    
    // 在接收线程的上下文中执行消息处理
    [(id<JSWorkerThreadInterface>)receiver executeBlock:^{
        id message = messagePackage[@"message"];
        JSWorkerThread *sender = messagePackage[@"sender"];
        
        // 如果是字典类型的消息，检查消息类型并调用对应处理器
        if ([message isKindOfClass:[NSDictionary class]]) {
            NSString *type = message[@"type"];
            JSMessageHandler handler = self.messageHandlers[type];
            if (handler) {
                handler(message, sender);
                return;
            }
        }
        
        // 默认消息处理：转换为JS对象并触发onmessage事件
        JSContext *context = [(id<JSWorkerThreadInterface>)receiver jsContext];
        JSValue *jsMessage = [JSValue valueWithObject:message inContext:context];
        
        [context evaluateScript:[NSString stringWithFormat:@"if (typeof onmessage === 'function') { onmessage(%@); }", jsMessage]];
    }];
}

- (void)processBufferedMessages {
    dispatch_async(self.messageQueue, ^{
        NSArray *bufferedMessages = [self.messageBuffer copy];
        [self.messageBuffer removeAllObjects];
        
        for (NSDictionary *messagePackage in bufferedMessages) {
            JSWorkerThread *receiver = messagePackage[@"receiver"];
            if ([(id<JSWorkerThreadInterface>)receiver status] != JSThreadStatusBusy) {
                [self deliverMessage:messagePackage];
            } else {
                [self.messageBuffer addObject:messagePackage];
            }
        }
    });
}

- (void)clearMessageBuffer {
    dispatch_async(self.messageQueue, ^{
        [self.messageBuffer removeAllObjects];
    });
}

- (NSUInteger)bufferedMessageCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.messageQueue, ^{
        count = self.messageBuffer.count;
    });
    return count;
}

@end
