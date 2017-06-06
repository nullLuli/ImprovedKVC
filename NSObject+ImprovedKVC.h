//
//  NSObject+ImprovedKVC.h
//  KVC方法改进
//
//  Created by qianfeng on 15/12/5.
//  Copyright (c) 2015年 qianfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (ImprovedKVC)

//用字典初始化自定义类型
+(id)l_objectFromDic:(NSDictionary*)dict;

//为多个变量赋值
-(void)l_setValuesWithDic:(NSDictionary*)dict;

//可以为自定义类型的变量正确赋值
-(void)l_setValue:(id)value forKey:(NSString*)key;

//用路径赋值，目前只支持用 点 路径赋值
-(void)l_setValue:(id)value forKeyPath:(NSString*)keyPath;

@end
