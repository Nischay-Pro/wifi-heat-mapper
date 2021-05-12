import argparse
import sys
from wifi_heat_mapper.gui import start_gui
from wifi_heat_mapper import __version__
from wifi_heat_mapper.config import start_config


def driver():
    parser = argparse.ArgumentParser(
        description="Generate Wi-Fi heat maps")
    subparsers = parser.add_subparsers(dest="mode")
    bootstrap = subparsers.add_parser(
        "bootstrap", description="Run the bootstrap configuration generator",
        help="Run the bootstrap configuration generator")
    bootstrap.add_argument(
        "--config", "-c", dest="config_file", required=False, default="config.json",
        help="Save path for configuration file")
    benchmark = subparsers.add_parser(
        "benchmark", description="Run benchmarks to gather metrics",
        help="Start running benchmarks to gather metrics")
    benchmark.add_argument(
        "--map", "-m", dest="floor_map", required=True, default=None,
        help="Image path to floor map")
    benchmark.add_argument(
        "--server", "-s", dest="iperf_server", required=True, default=None,
        help="IP (and port) address of the iperf3 server")
    benchmark.add_argument(
        "--config", "-c", dest="config_file", required=True, default=None,
        help="Path to configuration file")
    parser.add_argument(
        "-V", "--version", action="store_true", help="show version number and exit")
    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        parser.exit()

    if args.version:
        print_version()
        exit()

    if args.mode == "bootstrap":
        start_config(args.config_file)

    elif args.mode == "benchmark":
        start_gui(args.floor_map, args.iperf_server, args.config_file)


def print_version():
    print(__version__)
