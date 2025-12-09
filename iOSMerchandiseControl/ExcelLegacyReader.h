#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExcelLegacyReader : NSObject

+ (nullable NSArray<NSArray<NSString *> *> *)rowsFromXLSData:(NSData *)data
                                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
