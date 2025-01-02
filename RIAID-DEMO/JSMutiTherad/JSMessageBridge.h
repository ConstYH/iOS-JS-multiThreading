//
//  JSMessageBridge.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSThreadDefines.h"

@class JSWorkerThread;

NS_ASSUME_NONNULL_BEGIN

typedef void(^JSMessageHandler)(NSDictionary *message, JSWorkerThread * _Nullable sender);

@interface JSMessageBridge : NSObject

@property (nonatomic, weak) JSWorkerThread *workerThread;

/**
 * 初始化消息桥接器
 * @param workerThread 关联的工作线程
 */
- (instancetype)initWithWorkerThread:(JSWorkerThread *)workerThread;

/**
 * 发送消息到指定线程
 * @param message 消息内容
 * @param thread 目标线程
 */
- (void)postMessage:(id)message toThread:(JSWorkerThread *)thread;

/**
 * 注册消息处理器
 * @param handler 处理器block
 * @param type 消息类型
 */
- (void)registerMessageHandler:(JSMessageHandler)handler forType:(NSString *)type;

/**
 * 处理缓冲区中的消息
 */
- (void)processBufferedMessages;

/**
 * 清空消息缓冲区
 */
- (void)clearMessageBuffer;

/**
 * 获取缓冲区消息数量
 */
- (NSUInteger)bufferedMessageCount;

@end

// 声明一些必要的接口，避免循环引用
@protocol JSWorkerThreadInterface
@property (nonatomic, strong, readonly) JSContext *jsContext;
@property (nonatomic, assign, readonly) JSThreadStatus status;
- (void)executeBlock:(void(^)(void))block;
@end

NS_ASSUME_NONNULL_END
