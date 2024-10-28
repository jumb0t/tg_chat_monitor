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
