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
