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

#include <linux/usb/cdc-wdm.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include <libubox/uloop.h>

#include "mbim.h"


#ifdef LIBQMI_MBIM_PROXY
#include <sys/socket.h>
#include <sys/un.h>
#include "data/mbim-service-proxy-control.h"

uint8_t proxy_control[16] = { 0x83, 0x8c, 0xf7, 0xfb, 0x8d, 0x0d, 0x4d, 0x7f, 0x87, 0x1e, 0xd7, 0x1d, 0xbe, 0xfb, 0xb3, 0x9b };
#endif

size_t mbim_bufsize = 0;
uint8_t *mbim_buffer = NULL;
static struct uloop_fd mbim_fd;
static uint32_t expected;
int no_close;

static void mbim_msg_tout_cb(struct uloop_timeout *t)
{
	fprintf(stderr, "ERROR: mbim message timeout\n");
	mbim_end();
}

static struct uloop_timeout tout = {
	.cb = mbim_msg_tout_cb,
};

int
mbim_send(void)
{
	struct mbim_message_header *hdr = (struct mbim_message_header *) mbim_buffer;
	unsigned int ret = 0;

	if (le32toh(hdr->length) > mbim_bufsize) {
		fprintf(stderr, "message too big %d\n", le32toh(hdr->length));
		return -1;
	}

	if (verbose) {
		fprintf(stderr, "sending (%d): ", le32toh(hdr->length));
		for (ret = 0; ret < le32toh(hdr->length); ret++)
			printf("%02x ", ((uint8_t *) mbim_buffer)[ret]);
		printf("\n");
		printf("  header_type: %04X\n", le32toh(hdr->type));
		printf("  header_length: %04X\n", le32toh(hdr->length));
		printf("  header_transaction: %04X\n", le32toh(hdr->transaction_id));
	}

	ret = write(mbim_fd.fd, mbim_buffer, le32toh(hdr->length));
	if (!ret) {
		perror("writing data failed: ");
	} else {
		expected = le32toh(hdr->type) | 0x80000000;
		uloop_timeout_set(&tout, 15000);
	}
	return ret;
}

static void
mbim_recv(struct uloop_fd *u, unsigned int events)
{
	ssize_t cnt = read(u->fd, mbim_buffer, mbim_bufsize);
	struct mbim_message_header *hdr = (struct mbim_message_header *) mbim_buffer;
	struct command_done_message *msg = (struct command_done_message *) (hdr + 1);
	int i;

	if (cnt < 0)
		return;

	if (cnt < (ssize_t) sizeof(struct mbim_message_header)) {
		perror("failed to read() data: ");
		return;
	}
	if (verbose) {
		printf("reading (%zu): ", cnt);
		for (i = 0; i < cnt; i++)
			printf("%02x ", mbim_buffer[i]);
		printf("\n");
		printf("  header_type: %04X\n", le32toh(hdr->type));
		printf("  header_length: %04X\n", le32toh(hdr->length));
		printf("  header_transaction: %04X\n", le32toh(hdr->transaction_id));
	}

	if (le32toh(hdr->type) == expected)
		uloop_timeout_cancel(&tout);

	switch(le32toh(hdr->type)) {
	case MBIM_MESSAGE_TYPE_OPEN_DONE:
		if (current_handler->request() < 0)
			mbim_send_close_msg();
		break;
	case MBIM_MESSAGE_TYPE_COMMAND_DONE:
		if (verbose) {
			printf("  command_id: %04X\n", le32toh(msg->command_id));
			printf("  status_code: %04X\n", le32toh(msg->status_code));
		}
		if (msg->status_code && !msg->buffer_length)
			return_code = -le32toh(msg->status_code);
#ifdef LIBQMI_MBIM_PROXY
		else if (le32toh(msg->command_id) == MBIM_CMD_PROXY_CONTROL_CONFIGURATION && !memcmp(msg->service_id, proxy_control, 16))
			break;
#endif
		else
			return_code = current_handler->response(msg->buffer, le32toh(msg->buffer_length));
		if (return_code < 0)
			no_close = 0;
		mbim_send_close_msg();
		break;
	case MBIM_MESSAGE_TYPE_CLOSE_DONE:
		mbim_end();
		break;
	case MBIM_MESSAGE_TYPE_FUNCTION_ERROR:
		no_close = 0;
		mbim_send_close_msg();
		return_code = -1;
		break;
	}
}

void
mbim_open(const char *path)
{
	__u16 max;
	int rc;

	mbim_fd.cb = mbim_recv;
	mbim_fd.fd = open(path, O_RDWR);
	if (mbim_fd.fd < 1) {
		perror("open failed: ");
		exit(-1);
	}
	rc = ioctl(mbim_fd.fd, IOCTL_WDM_MAX_COMMAND, &max);
	if (!rc)
		mbim_bufsize = max;
	else
		mbim_bufsize = 512;
	mbim_buffer = malloc(mbim_bufsize);
	uloop_fd_add(&mbim_fd, ULOOP_READ);
}

#ifdef LIBQMI_MBIM_PROXY
static int
mbim_send_proxy_msg(const char *path)
{
	struct mbim_proxy_control_configuration_s *p =
		(struct mbim_proxy_control_configuration_s *) mbim_setup_command_msg(proxy_control,
			MBIM_MESSAGE_COMMAND_TYPE_SET, MBIM_CMD_PROXY_CONTROL_CONFIGURATION,
			sizeof(struct mbim_proxy_control_configuration_s));
	mbim_encode_string(&p->devicepath, (char *)path);
	p->timeout = htole32(30); // FIXME: hard coded timeout
	return mbim_send_command_msg();
}

void
mbim_proxy_open(const char *path)
{
	struct sockaddr_un addr = { .sun_family = AF_UNIX, .sun_path = "\0mbim-proxy" };

	mbim_fd.cb = mbim_recv;
	mbim_fd.fd = socket(PF_UNIX, SOCK_STREAM, 0);
	if (mbim_fd.fd < 1) {
		perror("socket failed: ");
		exit(-1);
	}
	if (connect(mbim_fd.fd, (struct sockaddr *)&addr, 13)) {
		perror("failed to connect to mbim-proxy: ");
		exit(-1);
	}
	mbim_bufsize = 512; // FIXME
	mbim_buffer = malloc(mbim_bufsize);
	uloop_fd_add(&mbim_fd, ULOOP_READ);
	no_close = 1;
	mbim_send_proxy_msg(path);
}
#endif

void
mbim_end(void)
{
	if (mbim_buffer) {
		free(mbim_buffer);
		mbim_bufsize = 0;
		mbim_buffer = NULL;
	}
	uloop_end();
}
