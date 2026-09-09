// SPDX-License-Identifier: GPL-2.0
/* One-boot experiment for iMac16,2 / HM97 only.
 * No hardware writes at load, unload, restart, suspend, or halt.
 * After ACPI preparation and at POWER_OFF, optionally clear only
 * SMI_EN.SLP_SMI_EN, then let
 * the normal ACPI power-off handler execute. No direct S5 write.
 * Intel 330550-002, section 12.8.3.7.
 */
#define pr_fmt(fmt) "imac_sleep_test: " fmt
#include <linux/module.h>
#include <linux/dmi.h>
#include <linux/pci.h>
#include <linux/reboot.h>
#include <linux/io.h>

static bool clear_sleep_smi;
module_param(clear_sleep_smi, bool, 0444);
MODULE_PARM_DESC(clear_sleep_smi, "Clear SLP_SMI_EN during power-off only; default observation only");
static unsigned int pm;
static struct sys_off_handler *prepare_handler, *off_handler;

static void snapshot(const char *stage)
{
	pr_emerg("%s SMI_EN=%08x SMI_STS=%08x PM1_CNT=%04x TCO1_CNT=%04x TCO1_STS=%04x TCO2_STS=%04x\n",
		stage, inl(pm + 0x30), inl(pm + 0x34), inw(pm + 4),
		inw(pm + 0x68), inw(pm + 0x64), inw(pm + 0x66));
}

static void clear_intercept(void)
{
	u32 before = inl(pm + 0x30), after;
	if (!clear_sleep_smi)
		return;
	outl(before & ~BIT(4), pm + 0x30);
	after = inl(pm + 0x30);
	pr_emerg("clear SLP_SMI_EN: before=%08x after=%08x verified=%u\n",
		before, after, !(after & BIT(4)));
}

static int prepare(struct sys_off_data *data)
{
	snapshot("after ACPI preparation");
	/* This readback is included in the normal shutdown pstore dump. */
	clear_intercept();
	return NOTIFY_DONE;
}

static int poweroff(struct sys_off_data *data)
{
	snapshot("final callback");
	/* Repeat immediately before ACPI in case firmware re-armed the bit.
	 * These final messages occur AFTER the normal pstore dump and may not
	 * survive reset. kmsg_dump is not exported to modules on this kernel.
	 */
	clear_intercept();
	return NOTIFY_DONE;
}

static int __init test_init(void)
{
	struct pci_dev *lpc;
	u32 bar;
	int err;
	if (!dmi_match(DMI_PRODUCT_NAME, "iMac16,2") ||
	    !dmi_match(DMI_SYS_VENDOR, "Apple Inc."))
		return -ENODEV;
	lpc = pci_get_domain_bus_and_slot(0, 0, PCI_DEVFN(31, 0));
	if (!lpc)
		return -ENODEV;
	if (lpc->vendor != 0x8086 || lpc->device != 0x8cc3) {
		pci_dev_put(lpc);
		return -ENODEV;
	}
	err = pci_read_config_dword(lpc, 0x40, &bar);
	pci_dev_put(lpc);
	if (err || bar == ~0U || !(bar & 1) || (bar & 0xff80) != 0x1800)
		return -ENODEV;
	pm = bar & 0xff80;
	prepare_handler = register_sys_off_handler(SYS_OFF_MODE_POWER_OFF_PREPARE,
		SYS_OFF_PRIO_DEFAULT, prepare, NULL);
	if (IS_ERR(prepare_handler))
		return PTR_ERR(prepare_handler);
	off_handler = register_sys_off_handler(SYS_OFF_MODE_POWER_OFF,
		SYS_OFF_PRIO_FIRMWARE + 1, poweroff, NULL);
	if (IS_ERR(off_handler)) {
		unregister_sys_off_handler(prepare_handler);
		return PTR_ERR(off_handler);
	}
	pr_info("loaded: clear_sleep_smi=%u; no register writes until power-off\n", clear_sleep_smi);
	snapshot("load");
	return 0;
}

static void __exit test_exit(void)
{
	unregister_sys_off_handler(off_handler);
	unregister_sys_off_handler(prepare_handler);
	pr_info("unloaded; experiment disarmed\n");
}
module_init(test_init);
module_exit(test_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Temporary iMac16,2 SLP_SMI_EN shutdown experiment");
