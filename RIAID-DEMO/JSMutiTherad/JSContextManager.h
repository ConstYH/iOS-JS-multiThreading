//
//  JSContextManager.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface JSContextManager : NSObject

+ (instancetype)sharedInstance;

/**
 * 创建新的 JSContext 实例
 * @return 新创建的 JSContext 实例
 */
- (JSContext *)createContext;

/**
 * 配置 Context 的全局 API
 * @param context 要配置的 JSContext
 */
- (void)setupGlobalAPI:(JSContext *)context;

/**
 * 销毁指定的 Context
 * @param context 要销毁的 JSContext
 */
- (void)destroyContext:(JSContext *)context;

/**
 * 清除所有 Context
 */
- (void)clearAllContexts;

/**
 * 获取当前活跃的 Context 数量
 * @return 活跃的 Context 数量
 */
- (NSUInteger)activeContextCount;

@end

NS_ASSUME_NONNULL_END
