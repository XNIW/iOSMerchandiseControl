#import "ExcelLegacyReader.h"
#import "xls.h"   // header di libxls

static const unsigned int XLS_MAX_ROWS = 50000; // limite prudenziale

@implementation ExcelLegacyReader

+ (nullable NSArray<NSArray<NSString *> *> *)rowsFromXLSData:(NSData *)data
                                                       error:(NSError * _Nullable * _Nullable)errorPtr
{
    if (data.length == 0) {
        if (errorPtr) {
            *errorPtr = [NSError errorWithDomain:@"ExcelLegacyReader"
                                            code:-1
                                        userInfo:@{NSLocalizedDescriptionKey: @"File .xls vuoto"}];
        }
        return nil;
    }

    xls_error_t xerr = LIBXLS_OK;

    xlsWorkBook *wb = xls_open_buffer((unsigned char *)data.bytes,
                                      (unsigned int)data.length,
                                      "UTF-8",
                                      &xerr);
    if (wb == NULL) {
        if (errorPtr) {
            const char *cmsg = xls_getError(xerr);
            NSString *msg = cmsg
                ? [NSString stringWithUTF8String:cmsg]
                : @"Errore lettura file .xls";
            *errorPtr = [NSError errorWithDomain:@"ExcelLegacyReader"
                                            code:xerr
                                        userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }

    NSMutableArray<NSMutableArray<NSString *> *> *allRows = [NSMutableArray array];

    if (wb->sheets.count > 0) {
        xlsWorkSheet *ws = xls_getWorkSheet(wb, 0);
        xerr = xls_parseWorkSheet(ws);
        if (xerr != LIBXLS_OK) {
            xls_close_WS(ws);
            xls_close_WB(wb);
            if (errorPtr) {
                const char *cmsg = xls_getError(xerr);
                NSString *msg = cmsg
                    ? [NSString stringWithUTF8String:cmsg]
                    : @"Errore parsing foglio .xls";
                *errorPtr = [NSError errorWithDomain:@"ExcelLegacyReader"
                                                code:xerr
                                            userInfo:@{NSLocalizedDescriptionKey: msg}];
            }
            return nil;
        }

        for (unsigned int r = 0;
             r <= ws->rows.lastrow && r < XLS_MAX_ROWS;
             r++) {

            xlsRow *row = xls_row(ws, r);
            if (!row) { continue; }

            NSMutableArray<NSString *> *cells = [NSMutableArray array];

            for (unsigned int c = 0; c <= ws->rows.lastcol; c++) {
                xlsCell *cell = &row->cells.cell[c];
                NSString *value = @"";

                if (cell->id == XLS_RECORD_BLANK) {
                    value = @"";
                } else if (cell->id == XLS_RECORD_NUMBER ||
                           cell->id == XLS_RECORD_FORMULA) {

                    if (cell->str && cell->str[0] != '\0') {
                        // usa la stringa formattata (stile DataFormatter di POI)
                        value = [NSString stringWithUTF8String:cell->str];
                    } else {
                        char buffer[64];
                        snprintf(buffer, sizeof(buffer), "%g", cell->d);
                        value = [NSString stringWithUTF8String:buffer];
                    }

                } else if (cell->str && cell->str[0] != '\0') {
                    value = [NSString stringWithUTF8String:cell->str];
                } else {
                    value = @"";
                }

                if (!value) { value = @""; }
                [cells addObject:value];
            }

            // rimuovi celle vuote in coda
            while (cells.count > 0 &&
                   [[cells lastObject] length] == 0) {
                [cells removeLastObject];
            }

            [allRows addObject:cells];
        }

        xls_close_WS(ws);
    }

    xls_close_WB(wb);
    return allRows;
}

@end
