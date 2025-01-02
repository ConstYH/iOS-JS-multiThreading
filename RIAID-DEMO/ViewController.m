//
//  ViewController.m
//  RIAID-DEMO
//
//  Created by yinhao on 2025/1/2.
//

#import "ViewController.h"
#import "JSContextManager.h"

@interface ViewController ()
@property (nonatomic, strong) JSContext *mainContext;
@property (nonatomic, strong) JSContextManager *contextManager;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 保持 JSContextManager 的引用
    self.contextManager = [JSContextManager sharedInstance];
    
    // 创建主Context
    self.mainContext = [self.contextManager createContext];
    
    // 加载JS文件
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"TestJS" ofType:@"js"];
    if (!jsPath) {
        NSLog(@"错误: 找不到TestJS.js文件");
        return;
    }
    
    NSError *error = nil;
    NSString *jsCode = [NSString stringWithContentsOfFile:jsPath 
                                               encoding:NSUTF8StringEncoding 
                                                  error:&error];
    
    if (error) {
        NSLog(@"错误: 加载JS文件失败 - %@", error.localizedDescription);
        return;
    }
    
    // 执行JS代码
    [self.mainContext evaluateScript:jsCode];
}

@end
