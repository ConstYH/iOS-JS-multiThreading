//
//  JSWorkerThread.h
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSTask.h"
#import "JSThreadDefines.h"
#import "JSMessageBridge.h"

@class JSWorkerThread;

@protocol JSWorkerDelegate <NSObject>
- (void)worker:(JSWorkerThread *)worker didCompleteTask:(JSTask *)task;
- (void)worker:(JSWorkerThread *)worker didFailWithError:(NSError *)error;
@end

@interface JSWorkerThread : NSObject <JSWorkerThreadInterface>

@property (nonatomic, strong) JSContext *jsContext;
@property (nonatomic, strong) NSMutableArray<JSTask *> *pendingTasks;
@property (atomic, assign) JSThreadStatus status;

- (instancetype)initWithDelegate:(id<JSWorkerDelegate>)delegate;
- (void)setupJSContext;
- (void)executeTask:(JSTask *)task;
- (void)executeBlock:(void(^)(void))block;
- (void)updateStatus:(JSThreadStatus)newStatus completion:(void(^)(void))completion;

@end
