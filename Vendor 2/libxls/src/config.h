#ifndef LIBXLS_CONFIG_H
#define LIBXLS_CONFIG_H

// Versione "fake" per xls_getVersion()
#define PACKAGE_VERSION "1.6.2-ios"

// Non usiamo iconv in questa build iOS
// (lasciamo il fallback semplice già presente nel codice)
#undef HAVE_ICONV

// Per semplicità non usiamo la variante wcstombs_l controllata da macro
#undef HAVE_WCSTOMBS_L

#endif /* LIBXLS_CONFIG_H */
