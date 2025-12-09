#ifndef LIBXLS_LOCALE_H
#define LIBXLS_LOCALE_H

#include <locale.h>
#include <wchar.h>

#if defined(__APPLE__)
#include <xlocale.h>
#endif

/* Tipo di locale usato da libxls */
#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)
typedef _locale_t xls_locale_t;
#else
typedef locale_t xls_locale_t;
#endif

/* Crea un locale UTF-8 dedicato */
xls_locale_t xls_createlocale(void);

/* Libera il locale creato */
void xls_freelocale(xls_locale_t locale);

/* Conversione wide-char -> multibyte usando il locale passato */
size_t xls_wcstombs_l(char *s,
                      const wchar_t *pwcs,
                      size_t n,
                      xls_locale_t loc);

#endif /* LIBXLS_LOCALE_H */
