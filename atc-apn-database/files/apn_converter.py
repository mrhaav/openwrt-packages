#!/usr/bin/env python3

# Copyright (c) 2025 SuperKali <hello@superkali.me>
# Licensed under the MIT License – see LICENSE file for details.

import xml.etree.ElementTree as ET
import json
import sys
from collections import defaultdict

def clean_value(value):
    """Cleans and normalizes input values"""
    if value is None or value.lower() in ["", "none", "null"]:
        return ""
    return value

def get_auth_type(auth_type):
    """Gets authentication type numeric value"""
    if not auth_type:
        return "0"
    return auth_type

def process_apns_file(xml_file, json_file):
    """Processes the AOSP APN XML file and converts it to a JSON database"""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        apn_db = {}
        carrier_count = defaultdict(int)
        total_apns = 0
        
        all_apns = defaultdict(list)
        
        for apn in root.findall('apn'):
            total_apns += 1
            mcc = clean_value(apn.get('mcc'))
            mnc = clean_value(apn.get('mnc'))
            
            if not mcc or not mnc:
                continue
            
            key = f"{mcc}_{mnc}"
            
            apn_name = clean_value(apn.get('apn'))
            apn_type = clean_value(apn.get('type'))
            
            if not apn_name and not apn_type:
                continue
            
            username = clean_value(apn.get('user'))
            password = clean_value(apn.get('password'))
            auth_type = get_auth_type(clean_value(apn.get('authtype')))
            carrier = clean_value(apn.get('carrier'))
            
            if carrier:
                carrier_count[carrier] += 1
            else:
                carrier_count["Unknown"] += 1
            
            apn_entry = {
                "apn": apn_name
            }
            
            if username:
                apn_entry["username"] = username
                
            if password:
                apn_entry["password"] = password
                
            if auth_type != "0":
                apn_entry["auth"] = auth_type
                
            if carrier:
                apn_entry["carrier"] = carrier
                
            if apn_type:
                apn_entry["type"] = apn_type
            
            all_apns[key].append(apn_entry)
        
        for key, apns in all_apns.items():
            data_apns = []
            
            for apn in apns:
                apn_type = apn.get('type', '').lower()
                apn_name = apn.get('apn', '').lower()
                carrier = apn.get('carrier', '').lower()
                
                if apn_type and any(t in apn_type.split(',') for t in ['mms', 'ims', 'emergency', 'xcap', 'ut']):
                    continue
                
                if apn_name and any(t in apn_name for t in ['mms', 'ims', 'emergency', 'xcap']):
                    continue
                
                is_data_apn = False
                
                if apn_type and any(t in apn_type.split(',') for t in ['default', 'internet', 'supl']):
                    is_data_apn = True
                
                if apn_name and any(t in apn_name for t in ['internet', 'data', 'web', 'net', 'online', 'gprs', 'connect']):
                    is_data_apn = True
                
                if carrier and 'internet' in carrier and not 'mms' in carrier:
                    is_data_apn = True
                
                if is_data_apn:
                    data_apns.append(apn)
            
            selected_apn = None
            if data_apns:
                default_apns = [a for a in data_apns if a.get('type') and 'default' in a.get('type').lower()]
                if default_apns:
                    selected_apn = default_apns[0]
                else:
                    selected_apn = data_apns[0]
            elif len(apns) > 0:
                for apn in apns:
                    apn_type = apn.get('type', '').lower()
                    apn_name = apn.get('apn', '').lower()
                    
                    if apn_type and ('mms' in apn_type or 'ims' in apn_type):
                        continue
                    
                    if apn_name and ('mms' in apn_name or 'ims' in apn_name):
                        continue
                    
                    selected_apn = apn
                    break
                
                if not selected_apn and len(apns) > 0:
                    selected_apn = apns[0]
            
            if selected_apn:
                if 'type' in selected_apn:
                    del selected_apn['type']
                
                apn_db[key] = selected_apn
        
        with open(json_file, 'w') as f:
            json.dump(apn_db, f, indent=2, sort_keys=True)
        
        print(f"\nTotal APNs in file: {total_apns}")
        print(f"Converted {len(apn_db)} unique operators (MCC+MNC)")
        print(f"Top 15 carriers by APN count:")
        for carrier, count in sorted(carrier_count.items(), key=lambda x: x[1], reverse=True)[:15]:
            print(f"  {carrier}: {count}")
            
        return True
    
    except Exception as e:
        print(f"Error during conversion: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python apn_converter.py apns-full-conf.xml apn_database.json")
        sys.exit(1)
    
    xml_file = sys.argv[1]
    json_file = sys.argv[2]
    
    if process_apns_file(xml_file, json_file):
        print(f"Conversion completed successfully. JSON database saved to {json_file}")
    else:
        print("Conversion failed.")
        sys.exit(1)