/* Load a prebuilt without creating a wallet or making network requests. */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { fprintf(stderr, "%s\n", dlerror()); return 1; }
    const char *(*mnemonic)(void) = dlsym(lib, "mwc_get_mnemonic");
    char *(*open_wallet)(const char *, const char *) = dlsym(lib, "mwc_rust_open_wallet");
    void (*free_string)(char *) = dlsym(lib, "mwc_string_free");
    if (!mnemonic || !open_wallet || !free_string) return 1;
    const char *phrase = mnemonic();
    if (!phrase) return 1;
    int words = 0, in_word = 0;
    for (; *phrase; phrase++) {
        int space = *phrase == ' ' || *phrase == '\n' || *phrase == '\t';
        if (!space && !in_word) words++;
        in_word = !space;
    }
    if (words != 24) return 1;
    for (int i = 0; i < 100; i++) {
        char *error = open_wallet("{}", "unused");
        if (!error) return 1;
        int valid = strstr(error, "Unable to get wallet config") != NULL;
        free_string(error);
        if (!valid) return 1;
    }
    dlclose(lib);
    puts("C ABI smoke passed: mnemonic, error response, and 100 frees");
    return 0;
}
