#include <zephyr/kernel.h>

int main(void)
{
	printk("Hello, Zephyr 4.4!\n");

	while (1) {
		printk("Running...\n");
		k_sleep(K_SECONDS(1));
	}

	return 0;
}
