#!/bin/bash

# Название проекта
PROJECT_NAME="telegram_chat_monitor"

# Проверка, существует ли директория проекта
if [ -d "$PROJECT_NAME" ]; then
    echo "Директория '$PROJECT_NAME' уже существует. Пожалуйста, удалите ее или выберите другое имя проекта."
    exit 1
fi

# Создание основной директории
mkdir -p "$PROJECT_NAME"

# Переход в основную директорию
cd "$PROJECT_NAME" || exit

echo "Создание файлов в корне проекта..."
# Создание файлов в корне
touch proxies.txt
touch chats.txt
touch requirements.txt
touch README.md

# Создание поддиректорий
echo "Создание поддиректорий..."
mkdir -p config logs db src

# Создание файлов в директории config
echo "Создание файлов в директории 'config'..."
touch config/proxies.json
touch config/chats.json

# Создание файлов в директории logs
echo "Создание файлов в директории 'logs'..."
touch logs/app.log

# Создание файлов в директории db
echo "Создание файлов в директории 'db'..."
# Инициализация пустой базы данных SQLite
sqlite3 db/links.db "PRAGMA foreign_keys = ON;"

# Создание файлов в директории src с шаблонами
echo "Создание файлов в директории 'src' с примерным содержимым..."

# auth.py
cat << 'EOF' > src/auth.py
# src/auth.py

import logging
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.sessions import StringSession

logger = logging.getLogger(__name__)

class TelegramAuth:
    def __init__(self, api_id, api_hash, phone, proxy=None, session_name='session'):
        """
        Инициализация клиента Telegram.

        :param api_id: Ваш API ID
        :param api_hash: Ваш API Hash
        :param phone: Номер телефона аккаунта
        :param proxy: Прокси-сервер (если используется)
        :param session_name: Имя файла сессии
        """
        self.api_id = api_id
        self.api_hash = api_hash
        self.phone = phone
        self.proxy = proxy
        self.session_name = session_name
        self.client = TelegramClient(session_name, api_id, api_hash, proxy=proxy)

    async def start(self):
        """
        Запуск клиента и аутентификация.
        """
        await self.client.connect()
        if not await self.client.is_user_authorized():
            try:
                await self.client.send_code_request(self.phone)
                code = input('Введите код из SMS: ')
                await self.client.sign_in(self.phone, code)
            except SessionPasswordNeededError:
                password = input('Введите 2FA пароль: ')
                await self.client.sign_in(password=password)
        logger.info("Аутентификация завершена.")
        return self.client
EOF

# chat_manager.py
cat << 'EOF' > src/chat_manager.py
# src/chat_manager.py

import json
import re
import logging

logger = logging.getLogger(__name__)

class ChatManager:
    def __init__(self, input_file, output_file):
        """
        Инициализация менеджера чатов.

        :param input_file: Путь к файлу со списком чатов
        :param output_file: Путь к выходному JSON файлу
        """
        self.input_file = input_file
        self.output_file = output_file

    def parse_chat_identifier(self, identifier):
        """
        Определение типа чата по идентификатору.

        :param identifier: Строка с идентификатором чата
        :return: Словарь с информацией о чате
        """
        chat_info = {"identifier": identifier, "settings": {}}
        if identifier.startswith('@'):
            chat_info["type"] = "username"
        elif re.match(r'^https?://t\.me/joinchat/', identifier):
            chat_info["type"] = "invite_link"
        elif identifier.isdigit():
            chat_info["type"] = "id"
        else:
            chat_info["type"] = "unknown"
        return chat_info

    def convert_to_json(self):
        """
        Конвертация списка чатов из текстового файла в JSON.

        :return: None
        """
        chats = []
        with open(self.input_file, 'r', encoding='utf-8') as f:
            for line in f:
                identifier = line.strip()
                if not identifier:
                    continue
                chat = self.parse_chat_identifier(identifier)
                if chat["type"] == "unknown":
                    logger.warning(f"Неизвестный формат чата: {identifier}")
                    continue
                chats.append(chat)
        with open(self.output_file, 'w', encoding='utf-8') as f:
            json.dump({"chats": chats}, f, ensure_ascii=False, indent=4)
        logger.info(f"Конвертация чатов завершена. {len(chats)} чатов записано в {self.output_file}")
EOF

# proxy_manager.py
cat << 'EOF' > src/proxy_manager.py
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
EOF

# db_manager.py
cat << 'EOF' > src/db_manager.py
# src/db_manager.py

import sqlite3
import logging

logger = logging.getLogger(__name__)

class DBManager:
    def __init__(self, db_path):
        """
        Инициализация менеджера базы данных.

        :param db_path: Путь к базе данных SQLite
        """
        self.db_path = db_path
        self.connection = sqlite3.connect(self.db_path)
        self.create_tables()

    def create_tables(self):
        """
        Создание необходимых таблиц в базе данных.
        """
        with self.connection:
            self.connection.execute("""
                CREATE TABLE IF NOT EXISTS links (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    chat_id TEXT,
                    message_id INTEGER,
                    link TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                );
            """)
        logger.info("Таблица 'links' создана или уже существует.")

    def insert_link(self, chat_id, message_id, link):
        """
        Вставка новой ссылки в базу данных.

        :param chat_id: Идентификатор чата
        :param message_id: Идентификатор сообщения
        :param link: Извлеченная ссылка
        """
        with self.connection:
            self.connection.execute("""
                INSERT INTO links (chat_id, message_id, link) VALUES (?, ?, ?)
            """, (chat_id, message_id, link))
        logger.debug(f"Ссылка добавлена в базу данных: {link}")

    def close(self):
        """
        Закрытие соединения с базой данных.
        """
        self.connection.close()
        logger.info("Соединение с базой данных закрыто.")
EOF

# event_handler.py
cat << 'EOF' > src/event_handler.py
# src/event_handler.py

import re
import logging

logger = logging.getLogger(__name__)

class EventHandler:
    def __init__(self, client, db_manager):
        """
        Инициализация обработчика событий.

        :param client: Экземпляр TelegramClient
        :param db_manager: Экземпляр DBManager
        """
        self.client = client
        self.db_manager = db_manager
        # Регулярное выражение для поиска нужных ссылок
        self.link_regex = re.compile(r'https://t\.me/xrocket/app\?startapp=(\w+)?')

    async def handle_new_message(self, event):
        """
        Обработчик новых сообщений.

        :param event: Событие нового сообщения
        """
        message = event.message
        chat = await event.get_chat()
        chat_id = str(chat.id)
        message_id = message.id
        text = message.message or ""

        # Поиск ссылок по регулярному выражению
        matches = self.link_regex.findall(text)
        if matches:
            for match in matches:
                full_link = f'https://t.me/xrocket/app?startapp={match}' if match else 'https://t.me/xrocket/app?startapp='
                logger.info(f"Найдена ссылка: {full_link} в чате {chat_id}, сообщение {message_id}")
                self.db_manager.insert_link(chat_id, message_id, full_link)

        # Обработка кнопок и инлайн-кнопок
        if message.buttons:
            for row in message.buttons:
                for button in row:
                    if button.url:
                        if self.link_regex.match(button.url):
                            logger.info(f"Найдена кнопка-ссылка: {button.url} в чате {chat_id}, сообщение {message_id}")
                            self.db_manager.insert_link(chat_id, message_id, button.url)
EOF

# main.py
cat << 'EOF' > src/main.py
# src/main.py

import argparse
import asyncio
import json
import logging
import os
from telethon import events
from auth import TelegramAuth
from chat_manager import ChatManager
from proxy_manager import ProxyManager
from db_manager import DBManager
from event_handler import EventHandler

def setup_logging(log_file='logs/app.log', log_level=logging.INFO):
    """
    Настройка логирования.

    :param log_file: Путь к файлу логов
    :param log_level: Уровень логирования
    """
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler()
        ]
    )

async def main():
    parser = argparse.ArgumentParser(description="Telegram Chat Monitor")
    parser.add_argument('--phone', type=str, help='Номер телефона для аутентификации')
    parser.add_argument('--api-id', type=int, help='API ID Telegram')
    parser.add_argument('--api-hash', type=str, help='API Hash Telegram')
    parser.add_argument('--convert-chats', action='store_true', help='Конвертировать chats.txt в JSON')
    parser.add_argument('--convert-proxies', action='store_true', help='Конвертировать proxies.txt в JSON')
    parser.add_argument('--input-chats', type=str, default='chats.txt', help='Входной файл с чатами')
    parser.add_argument('--output-chats', type=str, default='config/chats.json', help='Выходной JSON файл с чатами')
    parser.add_argument('--input-proxies', type=str, default='proxies.txt', help='Входной файл с прокси')
    parser.add_argument('--output-proxies', type=str, default='config/proxies.json', help='Выходной JSON файл с прокси')
    parser.add_argument('--db-path', type=str, default='db/links.db', help='Путь к базе данных SQLite')
    parser.add_argument('--log-level', type=str, default='INFO', help='Уровень логирования')
    args = parser.parse_args()

    # Настройка логирования
    log_level = getattr(logging, args.log_level.upper(), logging.INFO)
    setup_logging(log_level=log_level)

    logger = logging.getLogger('Main')

    # Конвертация чатов
    if args.convert_chats:
        chat_manager = ChatManager(args.input_chats, args.output_chats)
        chat_manager.convert_to_json()

    # Конвертация прокси
    if args.convert_proxies:
        proxy_manager = ProxyManager(args.input_proxies, args.output_proxies)
        proxy_manager.convert_to_json()

    # Если не требуется конвертация, запускаем мониторинг
    if not (args.convert_chats or args.convert_proxies):
        if not all([args.phone, args.api_id, args.api_hash]):
            logger.error("Для запуска мониторинга необходимо указать --phone, --api-id и --api-hash")
            return

        # Загрузка прокси из JSON
        with open(args.output_proxies, 'r', encoding='utf-8') as f:
            proxies_data = json.load(f)
            proxies = proxies_data.get("proxies", [])

        # Настройка прокси для клиента (используем первый доступный прокси)
        proxy = None
        if proxies:
            first_proxy = proxies[0]
            if first_proxy["type"] == "socks5":
                if first_proxy.get("username") and first_proxy.get("password"):
                    proxy = (first_proxy["type"], first_proxy["address"], int(first_proxy["port"]),
                             first_proxy["username"], first_proxy["password"])
                else:
                    proxy = (first_proxy["type"], first_proxy["address"], int(first_proxy["port"]))
            elif first_proxy["type"] == "http":
                if first_proxy.get("username") and first_proxy.get("password"):
                    proxy = (first_proxy["type"], first_proxy["address"], int(first_proxy["port"]),
                             first_proxy["username"], first_proxy["password"])
                else:
                    proxy = (first_proxy["type"], first_proxy["address"], int(first_proxy["port"]))

        # Аутентификация в Telegram
        auth = TelegramAuth(api_id=args.api_id, api_hash=args.api_hash, phone=args.phone, proxy=proxy)
        client = await auth.start()

        # Загрузка чатов из JSON
        with open(args.output_chats, 'r', encoding='utf-8') as f:
            chats_data = json.load(f)
            chats = chats_data.get("chats", [])

        # Инициализация базы данных
        db_manager = DBManager(args.db_path)

        # Инициализация обработчика событий
        event_handler = EventHandler(client, db_manager)
        client.add_event_handler(event_handler.handle_new_message, events.NewMessage)

        # Проверка доступа к чатам и установка слушателей
        for chat in chats:
            identifier = chat["identifier"]
            try:
                entity = await client.get_entity(identifier)
                logger.info(f"Доступен чат: {identifier}")
            except Exception as e:
                logger.error(f"Нет доступа к чату {identifier}: {e}")

        logger.info("Запуск клиента...")
        await client.run_until_disconnected()
        db_manager.close()

if __name__ == '__main__':
    asyncio.run(main())
EOF

# Заполнение requirements.txt с примерами зависимостей
echo "Заполнение 'requirements.txt'..."
cat << 'EOF' > requirements.txt
telethon==1.31.0
asyncio
sqlite3
argparse
logging
re
EOF

# Заполнение README.md с примером содержимого
echo "Заполнение 'README.md'..."
cat << 'EOF' > README.md
# Telegram Chat Monitor

## Описание

Приложение для мониторинга Telegram-чатов с использованием библиотеки Telethon на Python. Позволяет аутентифицироваться в Telegram, управлять списком чатов и прокси, обрабатывать новые сообщения и сохранять определенные данные в базу данных SQLite.

## Структура Проекта

