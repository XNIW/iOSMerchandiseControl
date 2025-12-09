#include "libxls/locale.h"
#include <stdlib.h>

xls_locale_t xls_createlocale(void)
{
#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)
    return _create_locale(LC_CTYPE, ".65001");
#elif defined(__APPLE__)
    // Su macOS/iOS "UTF-8" è il nome giusto del locale
    return newlocale(LC_CTYPE_MASK, "UTF-8", NULL);
#else
    return newlocale(LC_CTYPE_MASK, "C.UTF-8", NULL);
#endif
}

void xls_freelocale(xls_locale_t locale)
{
    if (!locale) {
        return;
    }

#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)
    _free_locale(locale);
#else
    freelocale(locale);
#endif
}

size_t xls_wcstombs_l(char *s,
                      const wchar_t *pwcs,
                      size_t n,
                      xls_locale_t loc)
{
#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64) || defined(WINDOWS)
    return _wcstombs_l(s, pwcs, n, loc);
#elif defined(HAVE_WCSTOMBS_L)
    return wcstombs_l(s, pwcs, n, loc);
#else
    // Fallback POSIX: cambia locale corrente, chiama wcstombs, poi ripristina
    locale_t oldlocale = uselocale(loc);
    size_t result = wcstombs(s, pwcs, n);
    uselocale(oldlocale);
    return result;
#endif
}
