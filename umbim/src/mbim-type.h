/*
 * umbim
 * Copyright (C) 2014 John Crispin <blogic@openwrt.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#ifndef _MBIM_TYPE_H__
#define _MBIM_TYPE_H__

struct mbim_string {
	uint32_t offset;
	uint32_t length;
} __attribute__((packed));

struct mbim_enum {
	uint32_t key;
	char *skey;
	char *val;
};

#endif
