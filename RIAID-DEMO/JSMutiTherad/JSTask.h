//
//  JSTask.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JSTaskStatus) {
    JSTaskStatusPending,    // 等待中
    JSTaskStatusPreparing,  // 准备中
    JSTaskStatusReady,      // 准备完成
    JSTaskStatusRunning,    // 执行中
    JSTaskStatusCompleted,  // 已完成
    JSTaskStatusFailed,     // 失败
    JSTaskStatusCancelled   // 已取消
};

typedef NS_ENUM(NSInteger, JSTaskPriority) {
    JSTaskPriorityLow = 0,
    JSTaskPriorityDefault = 500,
    JSTaskPriorityHigh = 1000
};

typedef void(^JSTaskCallback)(id result);
typedef void(^JSTaskErrorCallback)(NSError *error);
typedef void(^JSTaskPrepareBlock)(id task);

@interface JSTask : NSObject
@property (nonatomic, copy) NSString *scriptString;
@property (nonatomic, copy) NSDictionary *params;
@property (nonatomic, assign) JSTaskPriority priority;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign, readonly) JSTaskStatus status;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) NSTimeInterval lifeTime;

@property (nonatomic, copy, nullable) JSTaskPrepareBlock prepareBlock;
@property (nonatomic, copy, nullable) JSTaskCallback callback;
@property (nonatomic, copy, nullable) JSTaskErrorCallback errorCallback;

/**
 * 使用脚本初始化任务
 * @param scriptString JS脚本字符串
 */
- (instancetype)initWithScript:(NSString *)scriptString;

/**
 * 使用脚本和参数初始化任务
 * @param scriptString JS脚本字符串
 * @param params 执行参数
 */
- (instancetype)initWithScript:(NSString *)scriptString params:(NSDictionary *)params;

/**
 * 准备任务
 */
- (void)prepare;

/**
 * 执行任务
 */
- (void)execute;

/**
 * 完成任务
 * @param result 执行结果
 * @param error 错误信息
 */
- (void)complete:(nullable id)result error:(nullable NSError *)error;

/**
 * 取消任务
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
