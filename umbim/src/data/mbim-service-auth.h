/*
 * ID: 1
 * Command: Aka
 */

#define MBIM_CMD_AUTH_AKA	1

struct mbim_auth_aka_q = {
	struct mbim_byte_array rand;
	struct mbim_byte_array autn;
}

struct mbim_auth_aka_r =
	struct mbim_byte_array res;
	u32 reslen;
	struct mbim_byte_array integratingkey;
	struct mbim_byte_array cipheringkey;
	struct mbim_byte_array auts;
}

/*
 * ID: 2
 * Command: Akap
 */

#define MBIM_CMD_AUTH_AKAP	2

struct mbim_auth_akap_q = {
	struct mbim_byte_array rand;
	struct mbim_byte_array autn;
	struct mbim_string networkname;
}

struct mbim_auth_akap_r =
	struct mbim_byte_array res;
	u32 reslen;
	struct mbim_byte_array integratingkey;
	struct mbim_byte_array cipheringkey;
	struct mbim_byte_array auts;
}

/*
 * ID: 3
 * Command: Sim
 */

#define MBIM_CMD_AUTH_SIM	3

struct mbim_auth_sim_q = {
	struct mbim_byte_array rand1;
	struct mbim_byte_array rand2;
	struct mbim_byte_array rand3;
	u32 n;
}

struct mbim_auth_sim_r =
	u32 sres1;
	u64 kc1;
	u32 sres2;
	u64 kc2;
	u32 sres3;
	u64 kc3;
	u32 n;
}

