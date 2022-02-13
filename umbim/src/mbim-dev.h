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

#ifndef _MBIM_DEV_H__
#define _MBIM_DEV_H__

extern size_t mbim_bufsize;
extern uint8_t *mbim_buffer;
extern int no_close;

int mbim_send(void);
void mbim_open(const char *path);
#ifdef LIBQMI_MBIM_PROXY
void mbim_proxy_open(const char *path);
#endif
void mbim_end(void);

#endif
