/*
 * ID: 1
 * Command: Configuration
 */

#define MBIM_CMD_PHONEBOOK_CONFIGURATION	1

struct mbim_phonebook_configuration_r =
	u32 state;
	u32 numberofentries;
	u32 usedentries;
	u32 maxnumberlength;
	u32 maxname;
}

struct mbimphonebookentry = {
	u32 entryindex;
	struct mbim_string number;
	struct mbim_string name;
}

/*
 * ID: 2
 * Command: Read
 */

#define MBIM_CMD_PHONEBOOK_READ	2

struct mbim_phonebook_read_q = {
	u32 filterflag;
	u32 filtermessageindex;
}

struct mbim_phonebook_read_r =
	u32 entrycount;
	struct mbim_ref_struct_array entries;
}

/*
 * ID: 3
 * Command: Delete
 */

#define MBIM_CMD_PHONEBOOK_DELETE	3

/*
 * ID: 4
 * Command: Write
 */

#define MBIM_CMD_PHONEBOOK_WRITE	4

