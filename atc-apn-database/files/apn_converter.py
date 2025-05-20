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

def map_auth_type(auth_type):
    """Maps authentication type strings to numeric values"""
    auth_map = {
        "": "0",
        "none": "0",
        "pap": "1",
        "chap": "2",
        "pap chap": "3",
        "chap pap": "3"
    }
    return auth_map.get(auth_type.lower(), "0")

def optimal_apn_score(apn_entry, all_apns_for_mcc_mnc):
    """Scores APNs based on analysis of the Android AOSP APN database patterns"""
    score = 0
    apn_name = apn_entry.get('apn', '').lower()
    apn_type = clean_value(apn_entry.get('type', '')).lower()
    
    if apn_type:
        types = apn_type.split(',')
        if types == ['default'] or set(types) == set(['default', 'supl']):
            score += 200
        elif 'default' in types:
            score += 150
        elif 'internet' in types:
            score += 100
        if any(t in types for t in ['mms', 'ims', 'emergency', 'fota']):
            score -= 150
    else:
        score -= 50

    if len(apn_name) < 10:
        score += 40
    
    internet_patterns = ['internet', 'data', 'web', 'net', 'online', 'gprs']
    if any(pattern in apn_name for pattern in internet_patterns):
        score += 50
    
    if not any(char.isdigit() for char in apn_name):
        score += 30
    
    if not apn_entry.get('user') and not apn_entry.get('password'):
        score += 40
    
    if not apn_entry.get('proxy') and not apn_entry.get('port'):
        score += 30
    
    if apn_entry.get('protocol') == 'IPV4V6' or apn_entry.get('roaming_protocol') == 'IPV4V6':
        score += 25
    
    return score

def process_apns_file(xml_file, json_file):
    """Processes the AOSP APN XML file and converts it to a JSON database"""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        apn_db = {}
        apn_scores = {}
        carrier_count = defaultdict(int)
        
        mcc_mnc_apns = defaultdict(list)
        for apn in root.findall('apn'):
            mcc = clean_value(apn.get('mcc'))
            mnc = clean_value(apn.get('mnc'))
            
            if not mcc or not mnc:
                continue
                
            key = f"{mcc}_{mnc}"
            apn_dict = {attr: clean_value(apn.get(attr)) for attr in 
                       ['apn', 'user', 'password', 'proxy', 'port', 'mmsc', 
                        'mmsproxy', 'mmsport', 'type', 'protocol', 
                        'roaming_protocol', 'carrier']}
            
            mcc_mnc_apns[key].append(apn_dict)
        
        for key, apns in mcc_mnc_apns.items():
            if not apns:
                continue
                
            apn_scores[key] = []
            
            for apn_dict in apns:
                apn_name = apn_dict.get('apn')
                if not apn_name:
                    continue
                    
                carrier = apn_dict.get('carrier', '')
                carrier_count[carrier or "Unknown"] += 1
                
                apn_entry = {
                    "apn": apn_name,
                    "username": apn_dict.get('user', ''),
                    "password": apn_dict.get('password', ''),
                    "auth": map_auth_type(apn_dict.get('authtype', '')),
                    "carrier": carrier
                }
                
                score = optimal_apn_score(apn_dict, apns)
                apn_scores[key].append((score, apn_entry))
        
        for key, scores in apn_scores.items():
            if not scores:
                continue
            
            sorted_scores = sorted(scores, key=lambda x: x[0], reverse=True)
            best_score, best_apn = sorted_scores[0]
            
            if len(sorted_scores) > 1:
                print(f"MCC+MNC: {key}")
                for i, (score, apn) in enumerate(sorted_scores[:3]):
                    print(f"  #{i+1} Score: {score}, APN: {apn['apn']}, Carrier: {apn['carrier']}")
            
            apn_db[key] = best_apn
        
        with open(json_file, 'w') as f:
            json.dump(apn_db, f, indent=2, sort_keys=True)
        
        print(f"\nConverted {len(apn_db)} unique operators (MCC+MNC)")
        print(f"Top 10 carriers by APN count:")
        for carrier, count in sorted(carrier_count.items(), key=lambda x: x[1], reverse=True)[:10]:
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