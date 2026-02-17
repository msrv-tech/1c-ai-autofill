import os
import re
import sys
import requests
from bs4 import BeautifulSoup
import argparse

def get_infostart_version(url):
    """
    Получает текущую версию файла с Infostart.
    """
    print(f"Checking version on Infostart: {url}")
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # Пытаемся найти версию в поле input с name="v" или id="v"
        soup = BeautifulSoup(response.text, 'html.parser')
        v_input = soup.find('input', {'name': 'v'}) or soup.find('input', {'id': 'v'})
        
        if v_input and v_input.get('value'):
            version = v_input.get('value').strip()
            print(f"Current Infostart version: {version}")
            return version
            
        # Если не нашли в input, попробуем поискать в тексте страницы (на случай если там JS рендеринг или другой формат)
        # На скриншоте видно поле "Версия файла" с классом или id
        # Но обычно Infostart отдает форму редактирования, где версия в input
        
        print("Could not find version input on page. It might be a new file or different layout.")
        return None
    except Exception as e:
        print(f"Error getting version from Infostart: {e}")
        return None

def upload_to_infostart(url, file_path, version):
    """
    Загружает файл на Infostart.
    """
    print(f"Uploading {file_path} (version {version}) to Infostart...")
    
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found!")
        return False

    try:
        with open(file_path, 'rb') as f:
            files = {'file': f}
            data = {'v': version}
            
            # Согласно подсказке на скриншоте:
            # "Для обновления файла передать через POST в поле file... Для обновления версии используйте поле v"
            response = requests.post(url, files=files, data=data, timeout=60)
            response.raise_for_status()
            
            print(f"Upload successful! Response: {response.text}")
            return True
    except Exception as e:
        print(f"Error uploading to Infostart: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Sync GitHub Release with Infostart')
    parser.add_argument('--url', required=True, help='Infostart update URL (with secret keys)')
    parser.add_argument('--file', required=True, help='Path to .cfe file')
    parser.add_argument('--version', required=True, help='New version string')
    parser.add_argument('--force', action='store_true', help='Force upload even if versions match')
    
    args = parser.parse_args()
    
    current_is_version = get_infostart_version(args.url)
    
    if not args.force and current_is_version == args.version:
        print(f"Versions match ({args.version}). Skipping upload.")
        return

    success = upload_to_infostart(args.url, args.file, args.version)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
