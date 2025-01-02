//
//  JSTaskScheduler.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>
#import "JSTask.h"
#import "JSThreadPoolManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSTaskScheduler : NSObject

- (instancetype)initWithThreadPool:(JSThreadPoolManager *)threadPool;
- (void)scheduleTask:(JSTask *)task;
- (void)balanceLoad;

@end

NS_ASSUME_NONNULL_END
