/*
 * ID: 1
 * Command: Pac
 */

#define MBIM_CMD_STK_PAC	1

struct mbim_stk_pac_r =
	struct mbim_byte_array pacsupport;
}

/*
 * ID: 2
 * Command: Terminal Response
 */

#define MBIM_CMD_STK_TERMINAL_RESPONSE	2

struct mbim_stk_terminal_response_r =
	struct mbim_ref_byte_array resultdata;
	u32 statuswords;
}

/*
 * ID: 3
 * Command: Envelope
 */

#define MBIM_CMD_STK_ENVELOPE	3

struct mbim_stk_envelope_r =
	struct mbim_byte_array envelopesupport;
}

