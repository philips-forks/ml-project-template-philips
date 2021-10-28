from pathlib import Path
from setuptools import setup, find_packages
setup(
    name=Path(__file__).parent.name,
    version="0.0.1",
    packages=find_packages(where=["src"]),
)
