#!/usr/bin/env python3
"""
Mock Infor ION Simulator
Simulates sending BOD (Business Object Documents) to Boomi for processing
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
    
    result = ""
    try:
        result += f"{Fore.CYAN}📡 Sending to: {BOOMI_URL}{Fore.RESET}\n"
        response = requests.post(BOOMI_URL, data=xml_content, headers=headers, timeout=5)
        
        if response.status_code == 200:
            result += f"{Fore.GREEN}✅ Success: Order sent successfully{Fore.RESET}"
            stats['sent'] += 1
            return True, result
        elif response.status_code == 409:
            result += f"{Fore.YELLOW}⚠️  Duplicate: Order already exists{Fore.RESET}"
            stats['duplicates'] += 1
            return False, result
        else:
            result += f"{Fore.RED}❌ Error: HTTP {response.status_code}{Fore.RESET}"
            stats['errors'] += 1
            return False, result
            
    except requests.exceptions.ConnectionError:
        result += f"{Fore.RED}❌ Error: Cannot connect to Boomi at {BOOMI_URL}{Fore.RESET}\n"
        result += f"{Fore.YELLOW}   Make sure Boomi is running{Fore.RESET}"
        stats['errors'] += 1
        return False, result
    except Exception as e:
        result += f"{Fore.RED}❌ Error: {str(e)}{Fore.RESET}"
        stats['errors'] += 1
        return False, result

def send_normal_order():
    """Send a valid sales order"""
    template = load_template('sales_order.xml')
    if not template:
        return f"{Fore.RED}❌ Template not found{Fore.RESET}"
    
    order_id = generate_order_id()
    stats['last_order_id'] = order_id
    
    # Replace placeholders
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
    
    result = f"{Fore.CYAN}📋 Order ID: {order_id}{Fore.RESET}\n"
    success, send_result = send_order(xml)
    return result + send_result

def send_duplicate_order():
    """Send a duplicate of the last order"""
    if not stats['last_order_id']:
        return f"{Fore.YELLOW}⚠️  No previous order to duplicate\n   Send a normal order first{Fore.RESET}"
    
    template = load_template('sales_order.xml')
    if not template:
        return f"{Fore.RED}❌ Template not found{Fore.RESET}"
    
    # Use the same order ID as last time
    order_id = stats['last_order_id']
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    xml = xml.replace('${CUSTOMER_ID}', f"CUST-{os.urandom(2).hex()}")
    
    result = f"{Fore.YELLOW}🔁 Resending Order ID: {order_id}{Fore.RESET}\n"
    success, send_result = send_order(xml)
    return result + send_result

def send_malformed_order():
    """Send a malformed XML order"""
    template = load_template('malformed.xml')
    if not template:
        return f"{Fore.RED}❌ Template not found{Fore.RESET}"
    
    order_id = generate_order_id()
    xml = template.replace('${ORDER_ID}', order_id)
    xml = xml.replace('${TIMESTAMP}', datetime.now().isoformat())
    
    result = f"{Fore.RED}⚠️  Sending malformed order{Fore.RESET}\n"
    success, send_result = send_order(xml)
    return result + send_result

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

def clear_screen():
    """Clear the terminal screen"""
    os.system('clear' if os.name == 'posix' else 'cls')

def show_statistics():
    """Display current statistics"""
    print(f"\n{Fore.CYAN}📊 Statistics:{Fore.RESET}")
    print(f"   Orders sent: {Fore.GREEN}{stats['sent']}{Fore.RESET}")
    print(f"   Duplicates: {Fore.YELLOW}{stats['duplicates']}{Fore.RESET}")
    print(f"   Errors: {Fore.RED}{stats['errors']}{Fore.RESET}")
    if stats['last_order_id']:
        print(f"   Last Order ID: {stats['last_order_id']}")

def show_message(message, pause=True):
    """Show a message and optionally pause"""
    print(message)
    if pause:
        input(f"\n{Fore.CYAN}Press Enter to continue...{Fore.RESET}")

def main_menu():
    """Display and handle the main menu"""
    message = None
    
    while True:
        clear_screen()
        print(f"\n{Fore.CYAN}{'='*50}{Fore.RESET}")
        print(f"{Fore.CYAN}     Mock Infor ION Simulator{Fore.RESET}")
        print(f"{Fore.CYAN}{'='*50}{Fore.RESET}")
        print(f"Boomi Endpoint: {BOOMI_URL}")
        show_statistics()
        
        # Show any messages from previous action
        if message:
            print(f"\n{Fore.YELLOW}{'─'*50}{Fore.RESET}")
            print(message)
            print(f"{Fore.YELLOW}{'─'*50}{Fore.RESET}")
            message = None
        
        print(f"\n{Fore.CYAN}Options:{Fore.RESET}")
        print("1. Send Normal Order (valid BOD, new order ID)")
        print("2. Send Duplicate Order (reuse last order ID)")
        print("3. Send Malformed XML (missing required fields)")
        print("4. Send Bulk Orders (5 valid orders rapidly)")
        print("5. Start Auto-Mode (one order every 30s)")
        print("6. Exit")
        
        choice = input(f"\n{Fore.CYAN}Choose option: {Fore.RESET}")
        
        if choice == '1':
            message = send_normal_order()
        elif choice == '2':
            message = send_duplicate_order()
        elif choice == '3':
            message = send_malformed_order()
        elif choice == '4':
            send_bulk_orders()
            input(f"\n{Fore.CYAN}Press Enter to continue...{Fore.RESET}")
            message = None
        elif choice == '5':
            auto_mode()
            message = None
        elif choice == '6':
            clear_screen()
            print(f"\n{Fore.GREEN}Goodbye!{Fore.RESET}")
            sys.exit(0)
        else:
            message = f"{Fore.RED}Invalid option{Fore.RESET}"

if __name__ == '__main__':
    try:
        main_menu()
    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}Interrupted by user{Fore.RESET}")
        sys.exit(0)
        