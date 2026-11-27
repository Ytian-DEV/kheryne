from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str = "https://wxdacmoxlvblmakrwkog.supabase.co"
    supabase_publishable_key: str = "sb_publishable_4RgXahz2RGB2O6LWNa-YvQ_pwhTrWCo"
    require_auth: bool = False
    model_version: str = "2.3.0"
    detector_model_path: str = "models/detector.onnx"
    classifier_model_path: str = "models/classifier.onnx"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
