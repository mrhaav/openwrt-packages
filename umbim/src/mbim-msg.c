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

#include <sys/types.h>
#include <sys/stat.h>

#include <alloca.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libubox/utils.h>
#include <libubox/uloop.h>

#include "mbim.h"

#include "data/mbim-service-basic-connect.h"

int transaction_id = 1;
uint8_t basic_connect[16] = { 0xa2, 0x89, 0xcc, 0x33, 0xbc, 0xbb, 0x8b, 0x4f,
		     0xb6, 0xb0, 0x13, 0x3e, 0xc2, 0xaa, 0xe6,0xdf };
static int payload_offset, payload_free, payload_len;
static uint8_t *payload_buffer;

int
mbim_add_payload(uint8_t len)
{
	uint32_t offset = payload_offset;

	if (payload_free < len)
		return 0;

	payload_free -= len;
	payload_offset += len;
	payload_len += len;

	return offset;
}

int
mbim_encode_string(struct mbim_string *str, char *in)
{
	int l = strlen(in);
	int s = mbim_add_payload(l * 2);
	uint8_t *p = &payload_buffer[s];
	int i;

	if (!s)
		return -1;

	str->offset = htole32(s);
	str->length = htole32(l * 2);
	for (i = 0; i < l; i++)
		p[i * 2] = in[i];

	return 0;
}


char *
mbim_get_string(struct mbim_string *str, char *in)
{
	char *p = &in[le32toh(str->offset)];
	unsigned int i;

	if (!le32toh(str->offset))
		return NULL;

	if (le32toh(str->length)) {
		for (i = 0; i < le32toh(str->length) / 2; i++)
			p[i] = p[i * 2];
		p[i] = '\0';
		str->length = 0;
	}

	return p;
}

void
mbim_get_ipv4(void *buffer, char *out, uint32_t offset)
{
	uint8_t *b = buffer + offset;

	snprintf(out, 16, "%d.%d.%d.%d", b[0], b[1], b[2], b[3]);
}

void
mbim_get_ipv6(void *buffer, char *out, uint32_t offset)
{
	uint8_t *b = buffer + offset;

	snprintf(out, 40, "%x:%x:%x:%x:%x:%x:%x:%x", b[0] << 8 | b[1],
		 b[2] << 8 | b[3], b[4] << 8 | b[5], b[6] << 8 | b[7],
		 b[8] << 8 | b[9], b[10] << 8 | b[11], b[12] << 8 | b[13],
		 b[14] << 8 | b[15]);
}

uint32_t
mbim_get_int(void *buffer, uint32_t offset)
{
	uint32_t *i = buffer + offset;

	return le32toh(*i);
}

const char*
mbim_enum_string(struct mbim_enum *e, uint32_t key)
{
	while (e->skey) {
		if (key == e->key)
			return e->val;
		e++;
	}
	return NULL;
}

void
mbim_setup_header(struct mbim_message_header *hdr, MbimMessageType type, int length)
{
	if (length < 16)
		length = 16;

	hdr->transaction_id = htole32(transaction_id++);
	hdr->type = htole32(type);
	hdr->length = htole32(length);
}

uint8_t*
mbim_setup_command_msg(uint8_t *uuid, uint32_t type, uint32_t command_id, int len)
{
	struct command_message *cmd = (struct command_message *) mbim_buffer;

	if (!mbim_buffer)
		return NULL;
	memset(mbim_buffer, 0, mbim_bufsize);

	cmd->fragment_header.total = htole32(1);
	cmd->fragment_header.current = htole32(0);
	memcpy(cmd->service_id, uuid, 16);
	cmd->command_id = htole32(command_id);
	cmd->command_type = htole32(type);
	cmd->buffer_length = htole32(len);

	payload_offset = len;
	payload_free = mbim_bufsize - (sizeof(*cmd) + len);
	payload_len = 0;
	payload_buffer = cmd->buffer;

	return cmd->buffer;
}

int
mbim_send_command_msg(void)
{
	struct command_message *cmd = (struct command_message *) mbim_buffer;

	if (!mbim_buffer)
		return 0;
	if (payload_len & 0x3) {
		payload_len &= ~0x3;
		payload_len += 4;
	}

        cmd->buffer_length = htole32(le32toh(cmd->buffer_length) + payload_len);
	mbim_setup_header(&cmd->header, MBIM_MESSAGE_TYPE_COMMAND, sizeof(*cmd) + le32toh(cmd->buffer_length));

	return mbim_send();
}

int
mbim_send_open_msg(void)
{
	struct mbim_open_message *msg = (struct mbim_open_message *) mbim_buffer;

	mbim_setup_header(&msg->header, MBIM_MESSAGE_TYPE_OPEN, sizeof(*msg));
	msg->max_control_transfer = htole32(mbim_bufsize);

	return mbim_send();
}

int
mbim_send_close_msg(void)
{
	struct mbim_message_header *hdr = (struct mbim_message_header *) mbim_buffer;

	if (no_close || !mbim_buffer) {
		mbim_end();
		return 0;
	}
	mbim_setup_header(hdr, MBIM_MESSAGE_TYPE_CLOSE, sizeof(*hdr));

	return mbim_send();
}
