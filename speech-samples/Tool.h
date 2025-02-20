#import <Foundation/Foundation.h>
  
@interface Tool : NSObject
  
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSDictionary *function;
  
- (instancetype)initWithType:(NSString *)type function:(NSDictionary *)function;
- (NSDictionary *)toDictionary;  
@end
