from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional

class Settings(BaseSettings):
    db_server: str = Field(alias="DB_SERVER")
    db_database: str = Field(alias="DB_DATABASE")
    db_username: str = Field(alias="DB_USERNAME")
    db_password: str = Field(alias="DB_PASSWORD")
    db_trust_cert: str = Field(default="yes", alias="DB_TRUST_CERT")
    db_encrypt: str = Field(default="yes", alias="DB_ENCRYPT")
    db_port: Optional[str] = Field(default=None, alias="DB_PORT")

    app_env: str = Field(default="dev", alias="APP_ENV")
    app_host: str = Field(default="192.168.8.95", alias="APP_HOST")
    app_port: int = Field(default=8000, alias="APP_PORT")

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()
