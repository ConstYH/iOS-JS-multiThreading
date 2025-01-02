#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, JSThreadStatus) {
    JSThreadStatusIdle,    // 空闲
    JSThreadStatusBusy,    // 忙碌
    JSThreadStatusError    // 错误
}; 