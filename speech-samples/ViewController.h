//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (nonatomic, strong) NSMutableString *resultAll; // 全局变量，记录累积结果
// 定义 completionBlock 属性
@property (nonatomic, copy) void (^completionBlock)(NSDictionary *response, NSError *error);

@end

