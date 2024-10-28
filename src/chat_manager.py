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
