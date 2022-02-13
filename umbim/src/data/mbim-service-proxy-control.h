/*
 * ID: 1
 * Command: Configuration
 */

#define MBIM_CMD_PROXY_CONTROL_CONFIGURATION	1

struct mbim_proxy_control_configuration_s {
	struct mbim_string devicepath;
	uint32_t timeout;
} __attribute__((packed));

