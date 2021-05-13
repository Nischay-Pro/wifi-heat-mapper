from setuptools import setup, find_packages
import versioneer

with open('README.md') as file:
    long_description = file.read()

install_requirements = [
    "iperf3>=0.1.11",
    "matplotlib>=3.4.0",
    "tqdm>=4.55.0",
    "Pillow>=8.2.0",
    "scipy>=1.6.0",
    "numpy>=1.20.0",
    "PySimpleGUI>=4.34.0",
]

setup(
    name="whm",
    version=versioneer.get_version(),
    author="Nischay Mamidi",
    author_email="NischayPro@protonmail.com",
    description="A Python application for generating WiFi heatmaps with various parameters",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/Nischay-Pro/wifi-heat-mapper",
    project_urls={
        "Bug Tracker": "https://github.com/Nischay-Pro/wifi-heat-mapper/issues",
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",
        "Operating System :: POSIX :: Linux",
    ],
    entry_points={
        "console_scripts": [
            "whm = wifi_heat_mapper.main:driver"
        ]
    },
    cmdclass=versioneer.get_cmdclass(),
    install_requires=install_requirements,
    packages=find_packages(),
    python_requires=">=3.7",
    zip_safe=True,
)
