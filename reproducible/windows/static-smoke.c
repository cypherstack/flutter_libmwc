/* Link the actual static archive and exercise its public C interface. */
#include <stdio.h>
#include <string.h>

extern const char *mwc_get_mnemonic(void);
extern char *mwc_rust_open_wallet(const char *config, const char *password);
extern void mwc_string_free(char *value);

int main(void) {
    const char *phrase = mwc_get_mnemonic();
    if (!phrase) return 1;
    int words = 0, in_word = 0;
    for (; *phrase; ++phrase) {
        int space = *phrase == ' ' || *phrase == '\n' || *phrase == '\t';
        if (!space && !in_word) ++words;
        in_word = !space;
    }
    if (words != 24) return 2;
    for (int i = 0; i < 100; ++i) {
        char *error = mwc_rust_open_wallet("{}", "unused");
        if (!error) return 3;
        int valid = strstr(error, "Unable to get wallet config") != NULL;
        mwc_string_free(error);
        if (!valid) return 4;
    }
    puts("Static C consumer passed: mnemonic and 100 error/free calls");
    return 0;
}
