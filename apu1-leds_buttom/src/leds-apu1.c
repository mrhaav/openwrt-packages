/*
 * LEDs driver for PCEngines apu
 *
 * Copyright (C) 2013 Christian Herzog <daduke@daduke.org>, based on
 * Petr Leibman's leds-alix
 * Based on leds-wrap.c
 * Hardware info taken from http://www.dpie.com/manuals/miniboards/kontron/KTD-S0043-0_KTA55_SoftwareGuide.pdf
 *
 * 2014-12-8: Mark Schank
 *	- Added GPIO support for the APU push-button switch.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/leds.h>
#include <linux/gpio.h>
#include <linux/err.h>
#include <asm/io.h>

#define DRVNAME		"apuled-button"
#define BASEADDR	(0xFED801BD)
#define LEDON		(0x8)
#define LEDOFF		(0xC8)

static struct platform_device *pdev;
unsigned int *p1;
unsigned int *p2;
unsigned int *p3;

#define BUTTONADDR	(0xFED801BB)
unsigned int *b1;

static void apu_led_set_1(struct led_classdev *led_cdev,
		enum led_brightness value) {
	if (value)
		iowrite8(LEDON, p1);
	else
		iowrite8(LEDOFF, p1);
}

static void apu_led_set_2(struct led_classdev *led_cdev,
		enum led_brightness value) {
	if (value)
		iowrite8(LEDON, p2);
	else
		iowrite8(LEDOFF, p2);
}

static void apu_led_set_3(struct led_classdev *led_cdev,
		enum led_brightness value) {
	if (value)
		iowrite8(LEDON, p3);
	else
		iowrite8(LEDOFF, p3);
}

static struct led_classdev apu_led_1 = {
	.name		= "apu:1",
	.brightness_set	= apu_led_set_1,
};

static struct led_classdev apu_led_2 = {
	.name		= "apu:2",
	.brightness_set	= apu_led_set_2,
};

static struct led_classdev apu_led_3 = {
	.name		= "apu:3",
	.brightness_set	= apu_led_set_3,
};

static int gpio_apu_button_direction_in(struct gpio_chip *gc, unsigned  gpio_num)
{
	u8 curr_state;

	curr_state = ioread8(b1);
	iowrite8(curr_state | (1 << 5), b1);

	return 0;
}

static int gpio_apu_button_get(struct gpio_chip *gc, unsigned gpio_num)
{
	u8 curr_state;

	curr_state = ioread8(b1);

	return((curr_state & (1 << 7)) == (1 << 7));
}

static struct gpio_chip apu_gpio_button = {
	.label			= "apu_button",
	.owner			= THIS_MODULE,
	.get			= gpio_apu_button_get,
	.direction_input	= gpio_apu_button_direction_in,
	.base			= 187,
	.ngpio			= 1,
};

#ifdef CONFIG_PM
static int apu_led_suspend(struct platform_device *dev,
		pm_message_t state)
{
	led_classdev_suspend(&apu_led_1);
	led_classdev_suspend(&apu_led_2);
	led_classdev_suspend(&apu_led_3);
	return 0;
}

static int apu_led_resume(struct platform_device *dev)
{
	led_classdev_resume(&apu_led_1);
	led_classdev_resume(&apu_led_2);
	led_classdev_resume(&apu_led_3);
	return 0;
}
#else
#define apu_led_suspend NULL
#define apu_led_resume NULL
#endif

static int apu_led_probe(struct platform_device *pdev)
{
	int ret;

	ret = led_classdev_register(&pdev->dev, &apu_led_1);
	if (ret == 0)
	{
		ret = led_classdev_register(&pdev->dev, &apu_led_2);
		if (ret >= 0)
		{
			ret = led_classdev_register(&pdev->dev, &apu_led_3);
			if (ret >= 0)
			{
				ret = gpiochip_add(&apu_gpio_button);
				if(ret == 0){
					if(!gpio_request_one(187, GPIOF_IN, "Button")){
						gpio_export(187, 0);
					}
				}
				if (ret < 0)
					led_classdev_unregister(&apu_led_3);
			}
			if (ret < 0)
				led_classdev_unregister(&apu_led_2);
		}
		if (ret < 0)
			led_classdev_unregister(&apu_led_1);
	}
	return ret;
}

static int apu_led_remove(struct platform_device *pdev)
{
	led_classdev_unregister(&apu_led_1);
	led_classdev_unregister(&apu_led_2);
	led_classdev_unregister(&apu_led_3);
	gpiochip_remove(&apu_gpio_button);
	return 0;
}

static struct platform_driver apu_led_driver = {
	.probe		= apu_led_probe,
	.remove		= apu_led_remove,
	.suspend	= apu_led_suspend,
	.resume		= apu_led_resume,
	.driver		= {
	.name		= DRVNAME,
	.owner		= THIS_MODULE,
	},
};

static int __init apu_led_init(void)
{
	int ret;

	b1 = ioremap(BUTTONADDR, 1);
	ret = platform_driver_register(&apu_led_driver);
	if (ret < 0)
		goto out;

	pdev = platform_device_register_simple(DRVNAME, -1, NULL, 0);
	if (IS_ERR(pdev)) {
		ret = PTR_ERR(pdev);
		platform_driver_unregister(&apu_led_driver);
		goto out;
	}

	p1 = ioremap(BASEADDR, 1);
	p2 = ioremap(BASEADDR+1, 1);
	p3 = ioremap(BASEADDR+2, 1);

out:
	return ret;
}

static void __exit apu_led_exit(void)
{
	platform_device_unregister(pdev);
	platform_driver_unregister(&apu_led_driver);
}

module_init(apu_led_init);
module_exit(apu_led_exit);

MODULE_AUTHOR("Christian Herzog");
MODULE_DESCRIPTION("PCEngines apu LED driver");
MODULE_LICENSE("GPL");