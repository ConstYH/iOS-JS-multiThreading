//
//  JSThreadPoolManager.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>
#import "JSWorkerThread.h"
#import "JSTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSThreadPoolManager : NSObject

@property (nonatomic, strong) NSMutableArray<JSWorkerThread *> *workerThreads;
@property (nonatomic, strong) NSOperationQueue *taskQueue;

+ (instancetype)sharedInstance;
- (void)executeTask:(JSTask *)task;
- (void)adjustPoolSize:(NSInteger)size;

@end

NS_ASSUME_NONNULL_END
