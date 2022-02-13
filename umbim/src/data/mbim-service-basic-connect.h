/*
 * ID: 1
 * Command: Device Caps
 */

#define MBIM_CMD_BASIC_CONNECT_DEVICE_CAPS	1

struct mbim_basic_connect_device_caps_r {
	/* enum MbimDeviceType */
	uint32_t devicetype;
	/* enum MbimCellularClass */
	uint32_t cellularclass;
	/* enum MbimVoiceClass */
	uint32_t voiceclass;
	/* enum MbimSimClass */
	uint32_t simclass;
	/* enum MbimDataClass */
	uint32_t dataclass;
	/* enum MbimSmsCaps */
	uint32_t smscaps;
	/* enum MbimCtrlCaps */
	uint32_t controlcaps;
	uint32_t maxsessions;
	struct mbim_string customdataclass;
	struct mbim_string deviceid;
	struct mbim_string firmwareinfo;
	struct mbim_string hardwareinfo;
} __attribute__((packed));

/*
 * ID: 2
 * Command: Subscriber Ready Status
 */

#define MBIM_CMD_BASIC_CONNECT_SUBSCRIBER_READY_STATUS	2

struct mbim_basic_connect_subscriber_ready_status_r {
	/* enum MbimSubscriberReadyState */
	uint32_t readystate;
	struct mbim_string subscriberid;
	struct mbim_string simiccid;
	/* enum MbimReadyInfoFlag */
	uint32_t readyinfo;
	uint32_t telephonenumberscount;
	/* array type: string-array */
	uint32_t telephonenumbers;
} __attribute__((packed));

struct mbim_basic_connect_subscriber_ready_status_n {
	/* enum MbimSubscriberReadyState */
	uint32_t readystate;
	struct mbim_string subscriberid;
	struct mbim_string simiccid;
	/* enum MbimReadyInfoFlag */
	uint32_t readyinfo;
	uint32_t telephonenumberscount;
	/* array type: string-array */
	uint32_t telephonenumbers;
} __attribute__((packed));

/*
 * ID: 3
 * Command: Radio State
 */

#define MBIM_CMD_BASIC_CONNECT_RADIO_STATE	3

struct mbim_basic_connect_radio_state_r {
	/* enum MbimRadioSwitchState */
	uint32_t hwradiostate;
	/* enum MbimRadioSwitchState */
	uint32_t swradiostate;
} __attribute__((packed));

struct mbim_basic_connect_radio_state_s {
	/* enum MbimRadioSwitchState */
	uint32_t radiostate;
} __attribute__((packed));

struct mbim_basic_connect_radio_state_n {
	/* enum MbimRadioSwitchState */
	uint32_t hwradiostate;
	/* enum MbimRadioSwitchState */
	uint32_t swradiostate;
} __attribute__((packed));

/*
 * ID: 4
 * Command: Pin
 */

#define MBIM_CMD_BASIC_CONNECT_PIN	4

struct mbim_basic_connect_pin_r {
	/* enum MbimPinType */
	uint32_t pintype;
	/* enum MbimPinState */
	uint32_t pinstate;
	uint32_t remainingattempts;
} __attribute__((packed));

struct mbim_basic_connect_pin_s {
	/* enum MbimPinType */
	uint32_t pintype;
	/* enum MbimPinOperation */
	uint32_t pinoperation;
	struct mbim_string pin;
	struct mbim_string newpin;
} __attribute__((packed));

struct mbimpindesc {
	/* enum MbimPinMode */
	uint32_t pinmode;
	/* enum MbimPinFormat */
	uint32_t pinformat;
	uint32_t pinlengthmin;
	uint32_t pinlengthmax;
} __attribute__((packed));

/*
 * ID: 5
 * Command: Pin List
 */

#define MBIM_CMD_BASIC_CONNECT_PIN_LIST	5

struct mbim_basic_connect_pin_list_r {
	struct mbimpindesc pindescpin1;
	struct mbimpindesc pindescpin2;
	struct mbimpindesc pindescdevicesimpin;
	struct mbimpindesc pindescdevicefirstsimpin;
	struct mbimpindesc pindescnetworkpin;
	struct mbimpindesc pindescnetworksubsetpin;
	struct mbimpindesc pindescserviceproviderpin;
	struct mbimpindesc pindesccorporatepin;
	struct mbimpindesc pindescsubsidylock;
	struct mbimpindesc pindesccustom;
} __attribute__((packed));

struct mbimprovider {
	struct mbim_string providerid;
	/* enum MbimProviderState */
	uint32_t providerstate;
	struct mbim_string providername;
	/* enum MbimCellularClass */
	uint32_t cellularclass;
	uint32_t rssi;
	uint32_t errorrate;
} __attribute__((packed));

/*
 * ID: 6
 * Command: Home Provider
 */

#define MBIM_CMD_BASIC_CONNECT_HOME_PROVIDER	6

struct mbim_basic_connect_home_provider_r {
	struct mbimprovider provider;
} __attribute__((packed));

struct mbim_basic_connect_home_provider_s {
	struct mbimprovider provider;
} __attribute__((packed));

/*
 * ID: 7
 * Command: Preferred Providers
 */

#define MBIM_CMD_BASIC_CONNECT_PREFERRED_PROVIDERS	7

struct mbim_basic_connect_preferred_providers_r {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

struct mbim_basic_connect_preferred_providers_s {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

struct mbim_basic_connect_preferred_providers_n {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

/*
 * ID: 8
 * Command: Visible Providers
 */

#define MBIM_CMD_BASIC_CONNECT_VISIBLE_PROVIDERS	8

struct mbim_basic_connect_visible_providers_q {
	/* enum MbimVisibleProvidersAction */
	uint32_t action;
} __attribute__((packed));

struct mbim_basic_connect_visible_providers_r {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

/*
 * ID: 9
 * Command: Register State
 */

#define MBIM_CMD_BASIC_CONNECT_REGISTER_STATE	9

struct mbim_basic_connect_register_state_r {
	/* enum MbimNwError */
	uint32_t nwerror;
	/* enum MbimRegisterState */
	uint32_t registerstate;
	/* enum MbimRegisterMode */
	uint32_t registermode;
	/* enum MbimDataClass */
	uint32_t availabledataclasses;
	/* enum MbimCellularClass */
	uint32_t currentcellularclass;
	struct mbim_string providerid;
	struct mbim_string providername;
	struct mbim_string roamingtext;
	/* enum MbimRegistrationFlag */
	uint32_t registrationflag;
} __attribute__((packed));

struct mbim_basic_connect_register_state_s {
	struct mbim_string providerid;
	/* enum MbimRegisterAction */
	uint32_t registeraction;
	/* enum MbimDataClass */
	uint32_t dataclass;
} __attribute__((packed));

struct mbim_basic_connect_register_state_n {
	/* enum MbimNwError */
	uint32_t nwerror;
	/* enum MbimRegisterState */
	uint32_t registerstate;
	/* enum MbimRegisterMode */
	uint32_t registermode;
	/* enum MbimDataClass */
	uint32_t availabledataclasses;
	/* enum MbimCellularClass */
	uint32_t currentcellularclass;
	struct mbim_string providerid;
	struct mbim_string providername;
	struct mbim_string roamingtext;
	/* enum MbimRegistrationFlag */
	uint32_t registrationflag;
} __attribute__((packed));

/*
 * ID: 10
 * Command: Packet Service
 */

#define MBIM_CMD_BASIC_CONNECT_PACKET_SERVICE	10

struct mbim_basic_connect_packet_service_r {
	uint32_t nwerror;
	/* enum MbimPacketServiceState */
	uint32_t packetservicestate;
	/* enum MbimDataClass */
	uint32_t highestavailabledataclass;
	uint64_t uplinkspeed;
	uint64_t downlinkspeed;
} __attribute__((packed));

struct mbim_basic_connect_packet_service_s {
	/* enum MbimPacketServiceAction */
	uint32_t packetserviceaction;
} __attribute__((packed));

struct mbim_basic_connect_packet_service_n {
	uint32_t nwerror;
	/* enum MbimPacketServiceState */
	uint32_t packetservicestate;
	/* enum MbimDataClass */
	uint32_t highestavailabledataclass;
	uint64_t uplinkspeed;
	uint64_t downlinkspeed;
} __attribute__((packed));

/*
 * ID: 11
 * Command: Signal State
 */

#define MBIM_CMD_BASIC_CONNECT_SIGNAL_STATE	11

struct mbim_basic_connect_signal_state_r {
	uint32_t rssi;
	uint32_t errorrate;
	uint32_t signalstrengthinterval;
	uint32_t rssithreshold;
	uint32_t errorratethreshold;
} __attribute__((packed));

struct mbim_basic_connect_signal_state_s {
	uint32_t signalstrengthinterval;
	uint32_t rssithreshold;
	uint32_t errorratethreshold;
} __attribute__((packed));

struct mbim_basic_connect_signal_state_n {
	uint32_t rssi;
	uint32_t errorrate;
	uint32_t signalstrengthinterval;
	uint32_t rssithreshold;
	uint32_t errorratethreshold;
} __attribute__((packed));

/*
 * ID: 12
 * Command: Connect
 */

#define MBIM_CMD_BASIC_CONNECT_CONNECT	12

struct mbim_basic_connect_connect_q {
	uint32_t sessionid;
	/* enum MbimActivationState */
	uint32_t activationstate;
	/* enum MbimVoiceCallState */
	uint32_t voicecallstate;
	/* enum MbimContextIpType */
	uint32_t iptype;
	uint8_t contexttype[16];
	uint32_t nwerror;
} __attribute__((packed));

struct mbim_basic_connect_connect_r {
	uint32_t sessionid;
	/* enum MbimActivationState */
	uint32_t activationstate;
	/* enum MbimVoiceCallState */
	uint32_t voicecallstate;
	/* enum MbimContextIpType */
	uint32_t iptype;
	uint8_t contexttype[16];
	uint32_t nwerror;
} __attribute__((packed));

struct mbim_basic_connect_connect_s {
	uint32_t sessionid;
	/* enum MbimActivationCommand */
	uint32_t activationcommand;
	struct mbim_string accessstring;
	struct mbim_string username;
	struct mbim_string password;
	/* enum MbimCompression */
	uint32_t compression;
	/* enum MbimAuthProtocol */
	uint32_t authprotocol;
	/* enum MbimContextIpType */
	uint32_t iptype;
	uint8_t contexttype[16];
} __attribute__((packed));

struct mbim_basic_connect_connect_n {
	uint32_t sessionid;
	/* enum MbimActivationState */
	uint32_t activationstate;
	/* enum MbimVoiceCallState */
	uint32_t voicecallstate;
	/* enum MbimContextIpType */
	uint32_t iptype;
	uint8_t contexttype[16];
	uint32_t nwerror;
} __attribute__((packed));

struct mbimprovisionedcontextelement {
	uint32_t contextid;
	uint8_t contexttype[16];
	struct mbim_string accessstring;
	struct mbim_string username;
	struct mbim_string password;
	/* enum MbimCompression */
	uint32_t compression;
	/* enum MbimAuthProtocol */
	uint32_t authprotocol;
} __attribute__((packed));

/*
 * ID: 13
 * Command: Provisioned Contexts
 */

#define MBIM_CMD_BASIC_CONNECT_PROVISIONED_CONTEXTS	13

struct mbim_basic_connect_provisioned_contexts_r {
	uint32_t provisionedcontextscount;
	/* array type: ref-struct-array */
	uint32_t provisionedcontexts;
} __attribute__((packed));

struct mbim_basic_connect_provisioned_contexts_s {
	uint32_t contextid;
	uint8_t contexttype[16];
	struct mbim_string accessstring;
	struct mbim_string username;
	struct mbim_string password;
	/* enum MbimCompression */
	uint32_t compression;
	/* enum MbimAuthProtocol */
	uint32_t authprotocol;
	struct mbim_string providerid;
} __attribute__((packed));

struct mbim_basic_connect_provisioned_contexts_n {
	uint32_t provisionedcontextscount;
	/* array type: ref-struct-array */
	uint32_t provisionedcontexts;
} __attribute__((packed));

/*
 * ID: 14
 * Command: Service Activation
 */

#define MBIM_CMD_BASIC_CONNECT_SERVICE_ACTIVATION	14

struct mbim_basic_connect_service_activation_r {
	/* enum MbimNwError */
	uint32_t nwerror;
	/* array type: unsized-byte-array */
	uint32_t buffer;
} __attribute__((packed));

struct mbim_basic_connect_service_activation_s {
	/* array type: unsized-byte-array */
	uint32_t buffer;
} __attribute__((packed));

struct mbimipv4element {
	uint32_t onlinkprefixlength;
	uint8_t ipv4address[4];
} __attribute__((packed));

struct mbimipv6element {
	uint32_t onlinkprefixlength;
	uint8_t ipv6address[16];
} __attribute__((packed));

/*
 * ID: 15
 * Command: IP Configuration
 */

#define MBIM_CMD_BASIC_CONNECT_IP_CONFIGURATION	15

struct mbim_basic_connect_ip_configuration_q {
	uint32_t sessionid;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv4configurationavailable;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv6configurationavailable;
	uint32_t ipv4addresscount;
	/* struct mbimipv4element */
	uint32_t ipv4address;
	uint32_t ipv6addresscount;
	/* struct mbimipv6element */
	uint32_t ipv6address;
	/* array type: ref-ipv4 */
	uint32_t ipv4gateway;
	/* array type: ref-ipv6 */
	uint32_t ipv6gateway;
	uint32_t ipv4dnsservercount;
	/* array type: ipv4-array */
	uint32_t ipv4dnsserver;
	uint32_t ipv6dnsservercount;
	/* array type: ipv6-array */
	uint32_t ipv6dnsserver;
	uint32_t ipv4mtu;
	uint32_t ipv6mtu;
} __attribute__((packed));

struct mbim_basic_connect_ip_configuration_r {
	uint32_t sessionid;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv4configurationavailable;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv6configurationavailable;
	uint32_t ipv4addresscount;
	/* struct mbimipv4element */
	uint32_t ipv4address;
	uint32_t ipv6addresscount;
	/* struct mbimipv6element */
	uint32_t ipv6address;
	/* array type: ref-ipv4 */
	uint32_t ipv4gateway;
	/* array type: ref-ipv6 */
	uint32_t ipv6gateway;
	uint32_t ipv4dnsservercount;
	/* array type: ipv4-array */
	uint32_t ipv4dnsserver;
	uint32_t ipv6dnsservercount;
	/* array type: ipv6-array */
	uint32_t ipv6dnsserver;
	uint32_t ipv4mtu;
	uint32_t ipv6mtu;
} __attribute__((packed));

struct mbim_basic_connect_ip_configuration_n {
	uint32_t sessionid;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv4configurationavailable;
	/* enum MbimIPConfigurationAvailableFlag */
	uint32_t ipv6configurationavailable;
	uint32_t ipv4addresscount;
	/* struct mbimipv4element */
	uint32_t ipv4address;
	uint32_t ipv6addresscount;
	/* struct mbimipv6element */
	uint32_t ipv6address;
	/* array type: ref-ipv4 */
	uint32_t ipv4gateway;
	/* array type: ref-ipv6 */
	uint32_t ipv6gateway;
	uint32_t ipv4dnsservercount;
	/* array type: ipv4-array */
	uint32_t ipv4dnsserver;
	uint32_t ipv6dnsservercount;
	/* array type: ipv6-array */
	uint32_t ipv6dnsserver;
	uint32_t ipv4mtu;
	uint32_t ipv6mtu;
} __attribute__((packed));

struct mbimdeviceserviceelement {
	uint8_t deviceserviceid[16];
	uint32_t dsspayload;
	uint32_t maxdssinstances;
	uint32_t cidscount;
	/* array type: guint32-array */
	uint32_t cids;
} __attribute__((packed));

/*
 * ID: 16
 * Command: Device Services
 */

#define MBIM_CMD_BASIC_CONNECT_DEVICE_SERVICES	16

struct mbim_basic_connect_device_services_r {
	uint32_t deviceservicescount;
	uint32_t maxdsssessions;
	/* array type: ref-struct-array */
	uint32_t deviceservices;
} __attribute__((packed));

struct mbimevententry {
	uint8_t deviceserviceid[16];
	uint32_t cidscount;
	/* array type: guint32-array */
	uint32_t cids;
} __attribute__((packed));

/*
 * ID: 19
 * Command: Device Service Subscribe List
 */

#define MBIM_CMD_BASIC_CONNECT_DEVICE_SERVICE_SUBSCRIBE_LIST	19

struct mbim_basic_connect_device_service_subscribe_list_r {
	uint32_t eventscount;
	/* array type: ref-struct-array */
	uint32_t events;
} __attribute__((packed));

struct mbim_basic_connect_device_service_subscribe_list_s {
	uint32_t eventscount;
	/* array type: ref-struct-array */
	uint32_t events;
} __attribute__((packed));

/*
 * ID: 20
 * Command: Packet Statistics
 */

#define MBIM_CMD_BASIC_CONNECT_PACKET_STATISTICS	20

struct mbim_basic_connect_packet_statistics_r {
	uint32_t indiscards;
	uint32_t inerrors;
	uint64_t inoctets;
	uint64_t inpackets;
	uint64_t outoctets;
	uint64_t outpackets;
	uint32_t outerrors;
	uint32_t outdiscards;
} __attribute__((packed));

/*
 * ID: 21
 * Command: Network Idle Hint
 */

#define MBIM_CMD_BASIC_CONNECT_NETWORK_IDLE_HINT	21

struct mbim_basic_connect_network_idle_hint_r {
	/* enum MbimNetworkIdleHintState */
	uint32_t state;
} __attribute__((packed));

struct mbim_basic_connect_network_idle_hint_s {
	/* enum MbimNetworkIdleHintState */
	uint32_t state;
} __attribute__((packed));

/*
 * ID: 22
 * Command: Emergency Mode
 */

#define MBIM_CMD_BASIC_CONNECT_EMERGENCY_MODE	22

struct mbim_basic_connect_emergency_mode_r {
	/* enum MbimEmergencyModeState */
	uint32_t state;
} __attribute__((packed));

struct mbim_basic_connect_emergency_mode_s {
	/* enum MbimEmergencyModeState */
	uint32_t state;
} __attribute__((packed));

struct mbim_basic_connect_emergency_mode_n {
	/* enum MbimEmergencyModeState */
	uint32_t state;
} __attribute__((packed));

struct mbimpacketfilter {
	uint32_t filtersize;
	/* array type: ref-byte-array */
	uint32_t packetfilter;
	/* array type: ref-byte-array */
	uint32_t packetmask;
} __attribute__((packed));

/*
 * ID: 23
 * Command: IP Packet Filters
 */

#define MBIM_CMD_BASIC_CONNECT_IP_PACKET_FILTERS	23

struct mbim_basic_connect_ip_packet_filters_q {
	uint32_t sessionid;
	uint32_t packetfilterscount;
	/* array type: ref-struct-array */
	uint32_t packetfilters;
} __attribute__((packed));

struct mbim_basic_connect_ip_packet_filters_r {
	uint32_t sessionid;
	uint32_t packetfilterscount;
	/* array type: ref-struct-array */
	uint32_t packetfilters;
} __attribute__((packed));

struct mbim_basic_connect_ip_packet_filters_s {
	uint32_t sessionid;
	uint32_t packetfilterscount;
	/* array type: ref-struct-array */
	uint32_t packetfilters;
} __attribute__((packed));

/*
 * ID: 24
 * Command: Multicarrier Providers
 */

#define MBIM_CMD_BASIC_CONNECT_MULTICARRIER_PROVIDERS	24

struct mbim_basic_connect_multicarrier_providers_r {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

struct mbim_basic_connect_multicarrier_providers_s {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

struct mbim_basic_connect_multicarrier_providers_n {
	uint32_t providerscount;
	/* array type: ref-struct-array */
	uint32_t providers;
} __attribute__((packed));

