from dataclasses import dataclass

@dataclass
class Measurement:
    published_at: str
    internal_name: str
    value: float
