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
