# src/proxy_manager.py

import json
import logging

logger = logging.getLogger(__name__)

class ProxyManager:
    def __init__(self, input_file, output_file):
        """
        Инициализация менеджера прокси.

        :param input_file: Путь к файлу с прокси
        :param output_file: Путь к выходному JSON файлу
        """
        self.input_file = input_file
        self.output_file = output_file

    def parse_proxy(self, proxy_str):
        """
        Разбор строки прокси на компоненты.

        :param proxy_str: Строка с прокси
        :return: Словарь с информацией о прокси
        """
        proxy_info = {}
        if proxy_str.startswith('socks5://'):
            proxy_info["type"] = "socks5"
            parts = proxy_str[len('socks5://'):].split(':')
        elif proxy_str.startswith('http://'):
            proxy_info["type"] = "http"
            parts = proxy_str[len('http://'):].split(':')
        else:
            # Предполагается формат ip:port:login:pass или ip:port
            parts = proxy_str.split(':')
            if len(parts) == 4:
                proxy_info["type"] = "socks5"  # Предполагаем тип по умолчанию
            elif len(parts) == 2:
                proxy_info["type"] = "socks5"
            else:
                proxy_info["type"] = "unknown"

        if len(parts) >= 2:
            proxy_info["address"] = parts[0]
            proxy_info["port"] = parts[1]
        if len(parts) == 4:
            proxy_info["username"] = parts[2]
            proxy_info["password"] = parts[3]
        return proxy_info

    def convert_to_json(self):
        """
        Конвертация списка прокси из текстового файла в JSON.

        :return: None
        """
        proxies = []
        with open(self.input_file, 'r', encoding='utf-8') as f:
            for line in f:
                proxy_str = line.strip()
                if not proxy_str:
                    continue
                proxy = self.parse_proxy(proxy_str)
                if proxy["type"] == "unknown":
                    logger.warning(f"Неизвестный формат прокси: {proxy_str}")
                    continue
                proxies.append({"type": proxy["type"], 
                                "address": proxy.get("address"), 
                                "port": proxy.get("port"),
                                "username": proxy.get("username"),
                                "password": proxy.get("password"),
                                "settings": {
                                    "comment": f"Proxy {len(proxies)+1}"
                                }})
        with open(self.output_file, 'w', encoding='utf-8') as f:
            json.dump({"proxies": proxies}, f, ensure_ascii=False, indent=4)
        logger.info(f"Конвертация прокси завершена. {len(proxies)} прокси записано в {self.output_file}")
