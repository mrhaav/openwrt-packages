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

#ifndef _MBIM_H__
#define _MBIM_H__

#include <stdint.h>
#include <sys/types.h>

extern int return_code;
extern int verbose;

#include "mbim-type.h"
#include "mbim-enum.h"
#include "mbim-enums.h"
#include "mbim-msg.h"
#include "mbim-cid.h"
#include "mbim-dev.h"

struct mbim_handler {
	char *name;
	int argc;

	_mbim_cmd_request request;
	_mbim_cmd_response response;
};
extern struct mbim_handler *current_handler;

#endif
