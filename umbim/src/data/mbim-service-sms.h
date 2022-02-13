/*
 * ID: 1
 * Command: Configuration
 */

#define MBIM_CMD_SMS_CONFIGURATION	1

struct mbim_sms_configuration_r =
	u32 smsstoragestate;
	u32 format;
	u32 maxmessages;
	u32 cdmashortmessagesize;
	struct mbim_string scaddress;
}

struct mbimsmspdureadrecord = {
	u32 messageindex;
	u32 messagestatus;
	struct mbim_ref_byte_array pdudata;
}

struct mbimsmscdmareadrecord = {
	u32 messageindex;
	u32 messagestatus;
	struct mbim_string address;
	struct mbim_string timestamp;
	u32 encoding;
	u32 language;
	struct mbim_ref_byte_array encodedmessage;
	u32 encodedmessagesizeincharacters;
}

/*
 * ID: 2
 * Command: Read
 */

#define MBIM_CMD_SMS_READ	2

struct mbim_sms_read_q = {
	u32 format;
	u32 flag;
	u32 messageindex;
}

struct mbim_sms_read_r =
	u32 format;
	u32 messagescount;
	struct mbim_ref_struct_array pdumessages;
	struct mbim_ref_struct_array cdmamessages;
}

struct mbimsmspdusendrecord = {
	struct mbim_ref_byte_array pdudata;
}

struct mbimsmscdmasendrecord = {
	u32 encoding;
	u32 language;
	struct mbim_string address;
	struct mbim_ref_byte_array encodedmessage;
	u32 encodedmessagesizeincharacters;
}

/*
 * ID: 3
 * Command: Send
 */

#define MBIM_CMD_SMS_SEND	3

struct mbim_sms_send_r =
	u32 messagereference;
}

/*
 * ID: 4
 * Command: Delete
 */

#define MBIM_CMD_SMS_DELETE	4

/*
 * ID: 5
 * Command: Message Store Status
 */

#define MBIM_CMD_SMS_MESSAGE_STORE_STATUS	5

struct mbim_sms_message_store_status_r =
	u32 flag;
	u32 messageindex;
}

