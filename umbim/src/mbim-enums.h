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

#ifndef _MBIM_ENUMS_H__
#define _MBIM_ENUMS_H__

extern struct mbim_enum mbim_service_values[];
extern struct mbim_enum mbim_context_type_values[];
extern struct mbim_enum mbim_cid_basic_connect_values[];
extern struct mbim_enum mbim_cid_sms_values[];
extern struct mbim_enum mbim_cid_ussd_values[];
extern struct mbim_enum mbim_cid_phonebook_values[];
extern struct mbim_enum mbim_cid_stk_values[];
extern struct mbim_enum mbim_cid_auth_values[];
extern struct mbim_enum mbim_cid_dss_values[];
extern struct mbim_enum mbim_cid_ms_firmware_id_values[];
extern struct mbim_enum mbim_cid_ms_host_shutdown_values[];
extern struct mbim_enum mbim_cid_proxy_control_values[];
extern struct mbim_enum mbim_message_type_values[];
extern struct mbim_enum mbim_message_command_type_values[];
extern struct mbim_enum mbim_device_type_values[];
extern struct mbim_enum mbim_cellular_class_values[];
extern struct mbim_enum mbim_voice_class_values[];
extern struct mbim_enum mbim_sim_class_values[];
extern struct mbim_enum mbim_data_class_values[];
extern struct mbim_enum mbim_sms_caps_values[];
extern struct mbim_enum mbim_ctrl_caps_values[];
extern struct mbim_enum mbim_subscriber_ready_state_values[];
extern struct mbim_enum mbim_ready_info_flag_values[];
extern struct mbim_enum mbim_radio_switch_state_values[];
extern struct mbim_enum mbim_pin_type_values[];
extern struct mbim_enum mbim_pin_state_values[];
extern struct mbim_enum mbim_pin_operation_values[];
extern struct mbim_enum mbim_pin_mode_values[];
extern struct mbim_enum mbim_pin_format_values[];
extern struct mbim_enum mbim_provider_state_values[];
extern struct mbim_enum mbim_visible_providers_action_values[];
extern struct mbim_enum mbim_nw_error_values[];
extern struct mbim_enum mbim_register_action_values[];
extern struct mbim_enum mbim_register_state_values[];
extern struct mbim_enum mbim_register_mode_values[];
extern struct mbim_enum mbim_registration_flag_values[];
extern struct mbim_enum mbim_packet_service_action_values[];
extern struct mbim_enum mbim_packet_service_state_values[];
extern struct mbim_enum mbim_activation_command_values[];
extern struct mbim_enum mbim_compression_values[];
extern struct mbim_enum mbim_auth_protocol_values[];
extern struct mbim_enum mbim_context_ip_type_values[];
extern struct mbim_enum mbim_activation_state_values[];
extern struct mbim_enum mbim_voice_call_state_values[];
extern struct mbim_enum mbim_ip_configuration_available_flag_values[];
extern struct mbim_enum mbim_sms_storage_state_values[];
extern struct mbim_enum mbim_sms_format_values[];
extern struct mbim_enum mbim_sms_flag_values[];
extern struct mbim_enum mbim_sms_cdma_lang_values[];
extern struct mbim_enum mbim_sms_cdma_encoding_values[];
extern struct mbim_enum mbim_sms_status_values[];
extern struct mbim_enum mbim_sms_status_flag_values[];
extern struct mbim_enum mbim_ussd_action_values[];
extern struct mbim_enum mbim_ussd_response_values[];
extern struct mbim_enum mbim_ussd_session_state_values[];
extern struct mbim_enum mbim_phonebook_state_values[];
extern struct mbim_enum mbim_phonebook_flag_values[];
extern struct mbim_enum mbim_phonebook_write_flag_values[];
extern struct mbim_enum mbim_stk_pac_profile_values[];
extern struct mbim_enum mbim_stk_pac_type_values[];
extern struct mbim_enum mbim_network_idle_hint_state_values[];
extern struct mbim_enum mbim_emergency_mode_state_values[];
extern struct mbim_enum mbim_dss_link_state_values[];

#endif
