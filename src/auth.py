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
