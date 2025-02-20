#import "Tool.h"
  
@implementation Tool
  
- (instancetype)initWithType:(NSString *)type function:(NSDictionary *)function {
    self = [super init];
    if (self) {
        self.type = type;
        self.function = function;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"type": self.type,
        @"function": self.function
    };
} 
@end
