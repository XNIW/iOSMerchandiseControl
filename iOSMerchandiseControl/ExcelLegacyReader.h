#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExcelLegacyReader : NSObject

/// Ritorna tutte le righe del primo foglio di un file .xls
+ (nullable NSArray<NSArray<NSString *> *> *)rowsFromXLSData:(NSData *)data
                                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
