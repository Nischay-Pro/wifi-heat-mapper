import argparse
import sys
from wifi_heat_mapper.gui import start_gui
from wifi_heat_mapper import __version__
from wifi_heat_mapper.config import start_config
from wifi_heat_mapper.graph import generate_graph
import logging


def driver():
    """Handles the arguments for the package."""
    parser = argparse.ArgumentParser(
        description="Generate Wi-Fi heat maps")
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        "--debug", action="store_true", dest="debug_mode",
        help="print debug statements"
    )
    subparsers = parser.add_subparsers(dest="mode")
    bootstrap = subparsers.add_parser(
        "bootstrap", description="Run the bootstrap configuration generator",
        help="Run the bootstrap configuration generator", parents=[parent_parser])
    bootstrap.add_argument(
        "--config", "-c", dest="config_file", required=False, default="config.json",
        help="Save path for configuration file")
    benchmark = subparsers.add_parser(
        "benchmark", description="Run benchmarks to gather metrics",
        help="Start running benchmarks to gather metrics", parents=[parent_parser])
    benchmark.add_argument(
        "--map", "-m", dest="floor_map", required=True, default=None,
        help="Image path to floor map")
    benchmark.add_argument(
        "--server", "-s", dest="iperf_server", required=False, default=None,
        help="IP (and port) address of the iperf3 server")
    benchmark.add_argument(
        "--config", "-c", dest="config_file", required=True, default=None,
        help="Path to configuration file")
    plot = subparsers.add_parser(
        "plot", description="Generate plots from metrics",
        help="Generate plots from metrics", parents=[parent_parser])
    plot.add_argument(
        "--config", "-c", dest="config_file", required=True, default=None,
        help="Path to configuration file")
    plot.add_argument(
        "--map", "-m", dest="floor_map", required=True, default=None,
        help="Image path to floor map")
    plot.add_argument(
        "--levels", "-l", dest="levels", required=False, default=100,
        help="Determines the number and positions of the contour lines / regions. Default (100)"
    )
    plot.add_argument(
        "--dpi", "-d", dest="dpi", required=False, default=300,
        help="The resolution of the figure in dots-per-inch. Default (300)"
    )
    plot.add_argument(
        "--format", "-f", dest="file_type", required=False, default="png",
        help="Export file format for generated plots. Default (png)"
    )
    subparsers.add_parser(
        "help", description="Show this help message and exit",
        help="Show this help message and exit")
    parser.add_argument(
        "-V", "--version", action="store_true", help="show version number and exit")

    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help()
        parser.exit()

    if args.version:
        print_version()
        exit()

    if args.debug_mode:
        logging.basicConfig(level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s",
                            datefmt="%d-%b-%y %H:%M:%S", filename="debug.log")
        logging.debug("Enabled debug mode")

    if args.mode == "bootstrap":
        start_config(args.config_file)

    elif args.mode == "benchmark":
        start_gui(args.floor_map, args.iperf_server, args.config_file)

    elif args.mode == "plot":
        generate_graph(args.config_file, args.floor_map, levels=int(args.levels), dpi=int(args.dpi),
                       file_type=args.file_type)

    elif args.mode == "help":
        parser.print_help()
        parser.exit()


def print_version():
    """Prints the version of the package."""
    print(__version__)
