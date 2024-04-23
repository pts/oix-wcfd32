/* This is just a reference implementation in Watcom C, it's not used for
 * compiling WCFD32.
 */

typedef unsigned size_t;

void * __watcall malloc(size_t size);

/* Returns the number of bytes needed by append_argv_quoted(arg).
 * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static size_t __watcall get_argv_quoted_size(const char *arg) {
  const char *p;
  size_t size = 1;  /* It starts with space even if it's the first argument. */
  size_t bsc;  /* Backslash count. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') return size + (p - arg);  /* No need to quote. */
  size += 2;  /* Two '"' quotes, one on each side. */
  for (p = arg; ; ++p) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      size += bsc << 1;
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    size += bsc + 1;
  }
  return size;
}

/* Appends the quoted (escaped) arg to pout, always starting with a space, and returns the new pout.
 * Implements the inverse of parts of CommandLineToArgvW(...).
 * Implementation corresponds to get_argv_quoted_size(arg).
 * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static char * __watcall append_argv_quoted(const char *arg, char *pout) {
  const char *p;
  size_t bsc;  /* Backslash count. */
  *pout++ = ' ';  /* It starts with space even if it's the first argument. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') {  /* No need to quote. */
    for (p = arg; *p != '\0'; *pout++ = *p++) {}
    return pout;
  }
  *pout++ = '"';
  for (p = arg; ; *pout++ = *p++) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      for (bsc <<= 1; bsc != 0; --bsc, *pout++ = '\\') {}
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    for (; bsc != 0; --bsc, *pout++ = '\\') {}
  }
  *pout++ = '"';
  return pout;
}

char * __watcall concatenate_argv(char **argv) {
  char **argp, *result, *pout;
  size_t size = 1;  /* Trailing '\0'. */
  for (argp = argv + 1; *argp; size += get_argv_quoted_size(*argp++)) {}
  ++size;
  result = malloc(size);  /* Will never be freed. */
  if (result) {
    pout = result;
    for (pout = result, *pout++ = 'x', argp = argv + 1; *argp; pout = append_argv_quoted(*argp++, pout)) {}
    *pout = '\0';
  }
  return result;
}

char * __watcall concatenate_env(char **env) {
  size_t size = 4;  /* Trailing \0\0 (for extra count) and \0 (empty NUL-terminated program name). +1 for extra safety. */
  char **envp, *p, *pout;
  char *result;
  for (envp = env; (p = *envp); ++envp) {
    if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
    while (*p++ != '\0') {}
    size += p - *envp;
  }
  result = malloc(size);  /* Will never be freed. */
  if (result) {
    pout = result;
    for (envp = env; (p = *envp); ++envp) {
      if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
      while ((*pout++ = *p++) != '\0') {}
    }
    *pout++ = '\0';  /* Low byte of extra count. */
    *pout++ = '\0';  /* High byte of extra count. */
    *pout++ = '\0';  /* Empty NUL-terminated program name. */
    *pout = '\0';  /* Extra safety. */
  }
  return result;
}
