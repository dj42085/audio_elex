#include <stdio.h>
#include <generated/csr.h>

#include "sine_test.h"

void sine_test(void) {
    static uint32_t test_mode = 0;
    test_mode ^= 1;
    dac_test_mode_write(test_mode);
    printf("Sine test %s\n", test_mode ? "enabled" : "disabled");
}