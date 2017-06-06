//
//  NSObject+ImprovedKVC.m
//  KVC方法改进
//
//  Created by qianfeng on 15/12/5.
//  Copyright (c) 2015年 qianfeng. All rights reserved.
//

#import "NSObject+ImprovedKVC.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation NSObject (ImprovedKVC)

//用字典初始化自定义类型
+(id)l_objectFromDic:(NSDictionary*)dict
{
    id result = [[[self class] alloc]init];
    [result l_setValuesWithDic:dict];
    return result;
}

//为多个变量赋值 可以考虑增加功能使得dict里key也可以使用keypath
-(void)l_setValuesWithDic:(NSDictionary*)dict
{
    //我们现在有两个筹码，dict，self，我们要把dict里的数据根据self里的属性解析出来，正确处理——1，基本类型和fountation数据类型不做处理就赋值给相应的属性 2.自定义变量解析数据赋值
    //遍历dict。取出属性名，根据属性名在self里找到属性，若是自定义特殊处理，其他直接赋值
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
        //key是属性名 obj是要赋的值
        NSArray* arr = [(NSString*)key componentsSeparatedByString:@"."];
        if (arr.count > 1) {
            [self l_setValue:obj forKeyPath:key];
        }
        else
        {
            [self l_setValue:obj forKey:key];
        }
    }];
}

//可以为自定义类型的变量正确赋值
-(void)l_setValue:(id)value forKey:(NSString*)key
{
    
    //判断是不是自定义
    BOOL isUserDefine = [self isUserDefine:key];
    if (isUserDefine) {
        //特殊处理
        value = [self userDefineHander:value key:key];
    }
    //处理set方法
    char capital = [key characterAtIndex:0];
    NSString* keyR = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"%c",capital-97+65]];
    NSString* keyD = [NSString stringWithFormat:@"set%@:",keyR];
    SEL setSEL = NSSelectorFromString(keyD);
    
    objc_msgSend(self, setSEL,value);
    
}

-(id)userDefineHander:(id)value  key:(NSString*)key
{
    //找出自定义变量指向，判断是否为空，空则分配内存，不空就
    //这里需要自定义变量ivar索引
    Ivar ivar = [self ivarFromString:key];
    if (!ivar) {
        NSLog(@"没有找到对应属性");
        exit(0);
    }
    id ivarPoint = object_getIvar(self, ivar);
    if (ivarPoint) {
        //原来指向有值
        [ivarPoint l_setValue:value forKey:key];
        return ivarPoint;
    }
    Class ivarClass = [self classFromIvar:ivar];
    return [ivarClass l_objectFromDic:value];
}

-(Ivar)ivarFromString:(NSString*)key
{
    unsigned int outCount;
    Ivar* ivarList = class_copyIvarList([self class], &outCount);
    for (int i = 0; i < outCount; i++) {
        Ivar ivar = ivarList[i];
        const char * ivarNameC = ivar_getName(ivar);
        NSString * ivarNameR = [NSString stringWithCString:ivarNameC encoding:NSUTF8StringEncoding];
        NSString * ivarName = [ivarNameR stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        if ([ivarName isEqualToString:key]) {
            return ivar;
        }
    }
    NSLog(@"没有找到对应属性");
    return nil;
}

-(BOOL)isUserDefine:(NSString*)key
{
    Ivar ivar = [self ivarFromString:key];
    if (!ivar) {
        NSLog(@"没有找到对应属性");
        exit(0);
    }
    else{
        //列出非自定义类型开头
        NSArray* fountationTypeArr = @[@"NS",@"CG"];
        //现在我们已经根据key找到了属性索引,我们要判断它是不是自定义
        const char * ivarTypeC = ivar_getTypeEncoding(ivar);
        NSString* ivarTypeR = [NSString stringWithCString:ivarTypeC encoding:NSUTF8StringEncoding];
        if ([ivarTypeR hasPrefix:@"@\""]) {
            //可能是自定义可能是fountation
            //取出ivarType，与fountationTypeArr里的开头做比较
            NSString* ivarType = [ivarTypeR stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
            for (NSString* perfix in fountationTypeArr) {
                if ([ivarType hasPrefix:perfix]) {
                    //fountation类型
                    return NO;
                }
            }
            //自定义类型，特殊处理
            return YES;
        }
        else
        {
            return NO;
        }
    }
}

-(Class)classFromIvar:(Ivar)ivar
{
    const char * ivarTypeC = ivar_getTypeEncoding(ivar);
    NSString* ivarTypeR = [NSString stringWithCString:ivarTypeC encoding:NSUTF8StringEncoding];
    NSString* ivarType = [ivarTypeR stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
    Class ivarClass = NSClassFromString(ivarType);
    return ivarClass;
}

//用路径赋值，目前只支持用 点 路径赋值
-(void)l_setValue:(id)value forKeyPath:(NSString*)keyPath
{
    //分析keypath
    id point = [self parserKeyPath:keyPath];
    NSArray* keyArr = [keyPath componentsSeparatedByString:@"."];
    [point l_setValue:value forKey:[keyArr lastObject]];
    
#pragma 6
    NSLog(@"l_setValue forKeyPath: %@",self);
}

-(id)parserKeyPath:(NSString*)keyPath
{
    NSArray* keyArr = [keyPath componentsSeparatedByString:@"."];
    NSString* fristKey = [keyArr firstObject];
    if (keyArr.count > 2) {
        NSMutableArray* keyArrNext = [keyArr mutableCopy];
        [keyArrNext removeObjectAtIndex:0];
        //取出lastivar的point，如nil 赋值，非nil用point调用parserKeyPath，处理keypath
        id lastPoint = [self objectFromKey:fristKey];
        id result = [lastPoint parserKeyPath:[keyArrNext componentsJoinedByString:@"."]];
        
        return result;
    }
    else
    {
        id result = [self objectFromKey:fristKey];
        return result;
    }
}

-(id)objectFromKey:(NSString*)key
{
    Ivar resultIvar = [self ivarFromString:key];
    
    id result = object_getIvar(self, resultIvar);
    if (!result) {
        Class resultClass = [self classFromIvar:resultIvar];
        result = [[resultClass alloc]init];
        object_setIvar(self, resultIvar, result);
    }
    return result;
}

@end
