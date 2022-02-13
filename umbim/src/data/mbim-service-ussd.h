/*
 * ID: 1
 * Command: 
 */

#define MBIM_CMD_USSD_	1

struct mbim_ussd__r =
	u32 response;
	u32 sessionstate;
	u32 datacodingscheme;
	struct mbim_ref_byte_array payload;
}

