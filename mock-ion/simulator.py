#!/usr/bin/env python3
"""
Mock Infor ION Simulator
Simulates sending BOD (Business Object Documents) to Boomi for processing
Author: https://github.com/xdth
Date: 2025-11-02
"""

import os
import sys
import time
import json
import requests
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

try:
    from colorama import init, Fore, Style
    init()
except ImportError:
    # Fallback if colorama not installed
    class Fore:
        GREEN = YELLOW = RED = CYAN = MAGENTA = ''
        RESET = ''
    Style = Fore

# Configuration
BOOMI_URL = os.getenv('BOOMI_URL', 'http://localhost:8888/boomi/orders')
TEMPLATES_DIR = Path(__file__).parent / 'templates'

# Statistics tracking
stats = {
    'sent': 0,
    'duplicates': 0,
    'errors': 0,
    'last_order_id': None
}

def load_template(template_name):
    """Load XML template from file"""
    template_path = TEMPLATES_DIR / template_name
    if not template_path.exists():
        print(f"{Fore.RED}❌ Template not found: {template_path}{Fore.RESET}")
        return None
    
    with open(template_path, 'r') as f:
        return f.read()

def generate_order_id():
    """Generate a unique order ID based on timestamp"""
    return f"ORD-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

def send_order(xml_content, order_id=None):
    """Send XML order to Boomi endpoint"""
    if order_id:
        # Replace order_id in XML
        xml_content = xml_content.replace('${ORDER_ID}', order_id)
    
    headers = {
        'Content-Type': 'application/xml',
        'X-Source': 'Mock-ION'
    }
    
    try:
        print(f"\n{Fore.CYAN}📡 Sending to: {BOOMI_URL}{Fore.RESET}")
        response = requests.post(BOOMI_URL, data=xml_content, headers=headers, timeout=5)
        
        if response.status_code == 200:
            print(f"{Fore.GREEN}✅ Success: Order sent successfully{Fore.RESET}")
            stats['sent'] += 1
            return True
        elif response.status_code == 409:
            print(f"{Fore.YELLOW}⚠️  Duplicate: Order already exists{Fore.RESET}")
            stats['duplicates'] += 1
            return False
        else:
            print(f"{Fore.RED}❌ Error: HTTP {response.status_code}{Fore.RESET}")
            stats['errors'] += 1
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"{Fore.RED}❌ Error: Cannot connect to Boomi at {BOOMI_URL}{Fore.RESET}")
        print(f"{Fore.YELLOW}   Make sure Boomi is running{Fore.RESET}")
        stats['errors'] += 1
        return False
    except Exception as e:
        print(f"{Fore.RED}❌ Error: {str(e)}{Fore.RESET}")
        stats['errors'] += 1
        return False

def send_normal_order():
    """Send a valid sales order"""
    template = load_template('sales_order.xml')
    if not template:
        return
    
    order_id = generate_order_id()
    stats['last_order_id'] = order_id
    
    # Replace placeholders
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
    
    print(f"\n{Fore.CYAN}📋 Order ID: {order_id}{Fore.RESET}")
    send_order(xml)

def send_duplicate_order():
    """Send a duplicate of the last order"""
    if not stats['last_order_id']:
        print(f"\n{Fore.YELLOW}⚠️  No previous order to duplicate{Fore.RESET}")
        print(f"   Send a normal order first")
        return
    
    template = load_template('sales_order.xml')
    if not template:
        return
    
    # Use the same order ID as last time
    order_id = stats['last_order_id']
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
    
    print(f"\n{Fore.YELLOW}🔁 Resending Order ID: {order_id}{Fore.RESET}")
    send_order(xml)

def send_malformed_order():
    """Send a malformed XML order"""
    template = load_template('malformed.xml')
    if not template:
        return
    
    order_id = generate_order_id()
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    
    print(f"\n{Fore.RED}⚠️  Sending malformed order{Fore.RESET}")
    send_order(xml)

def send_bulk_orders():
    """Send 5 valid orders rapidly"""
    print(f"\n{Fore.MAGENTA}🚀 Sending 5 orders rapidly...{Fore.RESET}")
    template = load_template('sales_order.xml')
    if not template:
        return
    
    for i in range(5):
        order_id = f"BULK-{generate_order_id()}"
        stats['last_order_id'] = order_id
        
        xml = template.replace('${ORDER_ID}', order_id)
        xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
        xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
        
        print(f"\n{Fore.CYAN}[{i+1}/5] Order ID: {order_id}{Fore.RESET}")
        send_order(xml)
        time.sleep(0.5)  # Small delay between sends

def auto_mode():
    """Send one order every 30 seconds"""
    print(f"\n{Fore.MAGENTA}🤖 Auto-mode: Sending 1 order every 30 seconds{Fore.RESET}")
    print(f"   Press Ctrl+C to stop")
    
    template = load_template('sales_order.xml')
    if not template:
        return
    
    try:
        while True:
            order_id = f"AUTO-{generate_order_id()}"
            stats['last_order_id'] = order_id
            
            xml = template.replace('${ORDER_ID}', order_id)
            xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
            xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
            
            print(f"\n{Fore.CYAN}[AUTO] Order ID: {order_id}{Fore.RESET}")
            send_order(xml)
            
            print(f"{Fore.YELLOW}   Next order in 30 seconds...{Fore.RESET}")
            time.sleep(30)
            
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Auto-mode stopped{Fore.RESET}")

def show_statistics():
    """Display current statistics"""
    print(f"\n{Fore.CYAN}📊 Statistics:{Fore.RESET}")
    print(f"   Orders sent: {Fore.GREEN}{stats['sent']}{Fore.RESET}")
    print(f"   Duplicates: {Fore.YELLOW}{stats['duplicates']}{Fore.RESET}")
    print(f"   Errors: {Fore.RED}{stats['errors']}{Fore.RESET}")
    if stats['last_order_id']:
        print(f"   Last Order ID: {stats['last_order_id']}")

def main_menu():
    """Display and handle the main menu"""
    while True:
        print(f"\n{Fore.CYAN}{'='*50}{Fore.RESET}")
        print(f"{Fore.CYAN}     Mock Infor ION Simulator{Fore.RESET}")
        print(f"{Fore.CYAN}{'='*50}{Fore.RESET}")
        print(f"Boomi Endpoint: {BOOMI_URL}")
        show_statistics()
        print(f"\n{Fore.CYAN}Options:{Fore.RESET}")
        print("1. Send Normal Order (valid BOD, new order ID)")
        print("2. Send Duplicate Order (reuse last order ID)")
        print("3. Send Malformed XML (missing required fields)")
        print("4. Send Bulk Orders (5 valid orders rapidly)")
        print("5. Start Auto-Mode (one order every 30s)")
        print("6. Exit")
        
        choice = input(f"\n{Fore.CYAN}Choose option: {Fore.RESET}")
        
        if choice == '1':
            send_normal_order()
        elif choice == '2':
            send_duplicate_order()
        elif choice == '3':
            send_malformed_order()
        elif choice == '4':
            send_bulk_orders()
        elif choice == '5':
            auto_mode()
        elif choice == '6':
            print(f"\n{Fore.GREEN}Goodbye!{Fore.RESET}")
            sys.exit(0)
        else:
            print(f"{Fore.RED}Invalid option{Fore.RESET}")

if __name__ == '__main__':
    try:
        main_menu()
    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}Interrupted by user{Fore.RESET}")
        sys.exit(0)
