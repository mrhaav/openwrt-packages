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

#ifndef _MBIM_MSG_H__
#define _MBIM_MSG_H__

#include <string.h>

struct mbim_message_header {
	uint32_t type;
	uint32_t length;
	uint32_t transaction_id;
} __attribute__((packed));

struct mbim_open_message {
	struct mbim_message_header header;
	uint32_t max_control_transfer;
} __attribute__((packed));

struct mbim_open_done_message {
	struct mbim_message_header header;
	uint32_t status_code;
} __attribute__((packed));

struct mbim_close_done_message {
	uint32_t status_code;
} __attribute__((packed));

struct mbim_error_message {
	uint32_t error_status_code;
} __attribute__((packed));

struct mbim_fragment_header {
	uint32_t total;
	uint32_t current;
} __attribute__((packed));

struct fragment_message {
	struct mbim_fragment_header fragment_header;
	uint8_t buffer[];
} __attribute__((packed));

struct command_message {
	struct mbim_message_header header;
	struct mbim_fragment_header fragment_header;
	uint8_t service_id[16];
	uint32_t command_id;
	uint32_t command_type;
	uint32_t buffer_length;
	uint8_t buffer[];
} __attribute__((packed));

struct command_done_message {
	struct mbim_fragment_header fragment_header;
	uint8_t service_id[16];
	uint32_t command_id;
	uint32_t status_code;
	uint32_t buffer_length;
	uint8_t buffer[];
} __attribute__((packed));

struct indicate_status_message {
	struct mbim_fragment_header fragment_header;
	uint8_t service_id[16];
	uint32_t command_id;
	uint32_t buffer_length;
	uint8_t buffer[];
} __attribute__((packed));

typedef int (*_mbim_cmd_request)(void);
typedef int (*_mbim_cmd_response)(void *buffer, size_t len);

extern uint8_t basic_connect[16];
extern int transaction_id;

const char* mbim_enum_string(struct mbim_enum *e, uint32_t key);
char* mbim_get_string(struct mbim_string *str, char *in);
void mbim_setup_header(struct mbim_message_header *hdr, MbimMessageType type, int length);
uint8_t* mbim_setup_command_msg(uint8_t *uuid, uint32_t type, uint32_t command_id, int len);
int mbim_send_open_msg(void);
int mbim_send_close_msg(void);
int mbim_send_command_msg(void);
int mbim_add_payload(uint8_t len);
int mbim_encode_string(struct mbim_string *str, char *in);
void mbim_get_ipv4(void *buffer, char *out, uint32_t offset);
void mbim_get_ipv6(void *buffer, char *out, uint32_t offset);
uint32_t mbim_get_int(void *buffer, uint32_t offset);

#endif
