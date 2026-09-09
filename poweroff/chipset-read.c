/* Read-only HM97 snapshot. No out* instructions or hardware-register writes.
 * Intel 330550-002 sections 12.8.3 and 12.9; TCOBASE = PMBASE + 0x60.
 * Build: cc -O2 -Wall -Wextra -Werror -o chipset-read chipset-read.c
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/io.h>
#include <unistd.h>

static uint32_t cfg32(int fd, off_t offset)
{
    uint32_t value;
    if (pread(fd, &value, sizeof(value), offset) != sizeof(value)) {
        perror("PCI configuration read");
        exit(1);
    }
    return value;
}

int main(void)
{
    int fd = open("/sys/bus/pci/devices/0000:00:1f.0/config", O_RDONLY);
    if (fd < 0) { perror("open LPC config"); return 1; }
    uint32_t id = cfg32(fd, 0), bar = cfg32(fd, 0x40);
    close(fd);
    if (id != 0x8cc38086 || bar == UINT32_MAX || !(bar & 1)) {
        fprintf(stderr, "Refusing unexpected LPC/PMBASE: %08x %08x\n", id, bar);
        return 1;
    }
    unsigned base = bar & 0xff80;
    if (base != 0x1800) {
        fprintf(stderr, "Refusing unexpected PMBASE: %04x\n", base);
        return 1;
    }
    if (ioperm(base, 0x80, 1)) { perror("ioperm (root required)"); return 1; }
    uint16_t pmsts = inw(base), pmcnt = inw(base + 4);
    uint32_t smien = inl(base + 0x30), smists = inl(base + 0x34);
    uint16_t tcosts = inw(base + 0x64), tco2sts = inw(base + 0x66);
    uint16_t tcocnt = inw(base + 0x68), tco2cnt = inw(base + 0x6a);
    uint16_t count = inw(base + 0x60), initial = inw(base + 0x72);
    if (ioperm(base, 0x80, 0)) { perror("release ioperm"); return 1; }
    printf("LPC=%08x PMBASE=%04x (read-only snapshot)\n", id, base);
    printf("PM1_STS=%04x PM1_CNT=%04x SCI_EN=%u SLP_TYP=%u SLP_EN=%u\n",
           pmsts, pmcnt, pmcnt & 1, (pmcnt >> 10) & 7, (pmcnt >> 13) & 1);
    printf("SMI_EN=%08x SMI_STS=%08x SLP_SMI_EN=%u SLP_SMI_STS=%u TCO_EN=%u\n",
           smien, smists, (smien >> 4) & 1, (smists >> 4) & 1, (smien >> 13) & 1);
    printf("TCO1_STS=%04x TCO2_STS=%04x TCO1_CNT=%04x TCO2_CNT=%04x\n",
           tcosts, tco2sts, tcocnt, tco2cnt);
    printf("TCO_HALTED=%u TCO_LOCK=%u TIMEOUT=%u SECOND_TIMEOUT=%u BOOT_STS=%u\n",
           (tcocnt >> 11) & 1, (tcocnt >> 12) & 1, (tcosts >> 3) & 1,
           (tco2sts >> 1) & 1, (tco2sts >> 2) & 1);
    printf("TCO_COUNT=%u TCO_INITIAL=%u (0.6 seconds/tick)\n", count & 1023, initial & 1023);
    return 0;
}
