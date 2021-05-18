from wifi_heat_mapper.misc import TColor, check_application, process_iw, save_json, get_application_output
from wifi_heat_mapper.misc import check_speedtest, SpeedTestMode, get_ip_address_from_interface, test_libre_speed
from wifi_heat_mapper.debugger import log_arguments
from wifi_heat_mapper import __version__
from collections import OrderedDict
import os
import pathlib
import logging


class ConfigurationOptions:
    configuration = OrderedDict()
    configuration["signal_quality"] = {
        "description": "Wi-Fi Signal Quality (out of 70)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 70,
        "mode": ["base"],
        "conversion": False,
        "reverse": False,
    }
    configuration["signal_quality_percent"] = {
        "description": "Wi-Fi Signal Quality (in percentage)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 100,
        "mode": ["base"],
        "conversion": False,
        "reverse": False,
    }
    configuration["signal_strength"] = {
        "description": "Wi-Fi Signal Strength (in dBm)",
        "requirements": ["base"],
        "vmin": -100,
        "vmax": 0,
        "mode": ["base"],
        "conversion": False,
        "reverse": False,
    }
    configuration["download_bits_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["tcp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["download_bytes_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["tcp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["upload_bits_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["tcp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["upload_bytes_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["tcp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["download_bits_udp"] = {
        "description": "Wi-Fi Download [UDP] (in {0}/s)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["download_bytes_udp"] = {
        "description": "Wi-Fi Download [UDP] (in {0}/s)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["upload_bits_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in {0}/s)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["upload_bytes_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in {0}/s)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["download_jitter_udp"] = {
        "description": "Wi-Fi Download Jitter (in ms)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "conversion": False,
        "reverse": True,
    }
    configuration["upload_jitter_udp"] = {
        "description": "Wi-Fi Upload Jitter (in ms)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "conversion": False,
        "reverse": True,
        "reverse": True,
    }
    configuration["speedtest_latency"] = {
        "description": "Speedtest Wi-Fi Latency (in ms)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla", "librespeed-cli"],
        "conversion": False,
        "reverse": True,
    }
    configuration["speedtest_jitter"] = {
        "description": "Speedtest Wi-Fi Jitter (in ms)",
        "requirements": ["speedtest"],
        "mode": ["speedtest-ookla", "librespeed-cli"],
        "conversion": False,
        "reverse": True,
    }
    configuration["speedtest_download_bandwidth"] = {
        "description": "Speedtest Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla", "librespeed-cli"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }
    configuration["speedtest_upload_bandwidth"] = {
        "description": "Speedtest Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla", "librespeed-cli"],
        "vmin": 0,
        "conversion": True,
        "reverse": False,
    }


accept = ("y", "yes")
reject = ("n", "no")


@log_arguments
def start_config(config_file):
    """Starting point for the bootstrap submodule for whm.

    Args:
        config_file (str): the path to the configuration file.

    Returns:
        None
    """
    print("Detecting benchmarking capabilities.")
    supported_modes = []
    speedtest_type = SpeedTestMode.UNKNOWN
    if check_application("iperf3"):
        supported_modes.append("iperf3")
    if check_application("speedtest"):
        speedtest_type = check_speedtest()
        if speedtest_type == SpeedTestMode.SIVEL:
            supported_modes.append("speedtest")
        elif speedtest_type == SpeedTestMode.OOKLA:
            supported_modes.append("speedtest-ookla")
    if check_application("librespeed-cli"):
        supported_modes.append("librespeed-cli")

    logging.debug("System supports: {0}".format(str(supported_modes)))

    if len(supported_modes) == 0:
        print("Could not detect any supported mode [iperf3, speedtest or librespeed-cli].")
        exit(1)

    print("Supported Modes: {0}{1}{2}".format(TColor.BLUE, " ".join(map(str, supported_modes)), TColor.RESET))

    ssid = None
    target_interface = None
    libre_speed_list = ""

    if not check_application("iw"):
        print("Could not detect iw (Wireless tools for Linux)")
        exit(1)
    logging.debug("Detected iw")

    while True:
        target_interface = input("Please enter the target wireless interface to run benchmark on (example: wlan0): ")
        target_interface = target_interface.strip()
        if not target_interface.isalnum():
            print("Invalid interface")
            exit(1)
        cmd = "cat /sys/class/net/{0}/operstate".format(target_interface)
        check_interface = get_application_output(cmd, shell=True, timeout=10)
        if check_interface == "invalid":
            print("Interface {0} does not exist!".format(target_interface))
            exit(1)

        elif check_interface == "timeout":
            print("Unable to get interface {0} status".format(target_interface))
            exit(1)

        check_interface = check_interface.split("\n")[0]
        if check_interface != "up":
            print("Interface {0} is not ready.".format(target_interface))
            exit(1)

        logging.debug("Target Interface: {0}".format(target_interface))

        bind_ip = get_ip_address_from_interface(target_interface)
        if bind_ip is None:
            print("Interface {0} does not have a valid IPv4 address assigned.".format(target_interface))

        logging.debug("Target Interface IP Address: {0}".format(bind_ip))

        break

    while True:
        ssid = process_iw(target_interface)["ssid"]
        question = "You are connected to {0}{1}{2}. Is this the interface you want to benchmark on? (y/N) ".format(
                   TColor.BLUE, ssid, TColor.RESET)
        if ask_y_n(question):
            logging.debug("SSID: {0}".format(ssid))
            break

    while True:
        try:
            repeat_count = int(input("How many times do you want to repeat benchmarking? "))
            if repeat_count <= 0:
                raise ValueError
        except ValueError:
            print("Invalid value please try again.")
        else:
            logging.debug("Benchmark Iterations: {0}".format(repeat_count))
            break

    if "librespeed-cli" in supported_modes and speedtest_type != SpeedTestMode.UNKNOWN:
        question = "We detected librespeed-cli. Do you prefer librespeed over speedtest? (y/N) "
        if ask_y_n(question):
            speedtest_type = SpeedTestMode.LIBRESPEED

    logging.debug("SpeedTest Mode: {0}".format(speedtest_type))

    if speedtest_type == SpeedTestMode.LIBRESPEED:
        question = "Do you have a custom librespeed server list you would like to use? (y/N) "
        if ask_y_n(question):
            while True:
                response = input("Please enter the path to the custom server list: ")
                if os.path.isfile(response):
                    print("Testing server list")
                    if test_libre_speed(bind_ip, libre_speed_server_list=response):
                        print("Successfully verified server. Switching to user provided list.")
                        libre_speed_list = response
                        break
                    else:
                        print("Could not verify server. Falling back to official list.")
                        break
                else:
                    print("Invalid file. Please try again.")
        else:
            print("Using official list.")

    logging.debug("Custom Librespeed List: {0}".format(libre_speed_list))

    print("Supported Graphs:")
    configuration_dict = ConfigurationOptions.configuration
    configuration_dict_supported = []
    supported_modes.append("base")
    i = 1
    for itm in configuration_dict.keys():
        mode = configuration_dict[itm]["mode"]
        supported = set(mode).intersection(set(supported_modes))
        if supported:
            configuration_dict_supported.append(itm)
            print_graph_to_console(i, itm, configuration_dict[itm]["description"])
            i += 1

    print("{0}{1}{2}".format(TColor.UNDERLINE, "=>> Select graphs to plot. eg: 1 2 3 5 6 or simply type 'all'",
                             TColor.RESET))
    response = input("> ")
    selection = []
    graph_key = []

    if response == "all":
        for itm in configuration_dict_supported:
            selection += configuration_dict[itm]["requirements"]
        graph_key = tuple(configuration_dict_supported)

    elif len(response) > 0:
        keys = []
        if response.isdecimal():
            keys.append(int(response))
        elif " " in response:
            try:
                response = tuple(map(int, response.split(" ")))
            except ValueError:
                print("Invalid character")
                exit(1)
            for res in response:
                if int(res) <= len(configuration_dict.keys()) and int(res) > 0:
                    keys.append(res)
                else:
                    print("Invalid selection")
                    exit(1)
        else:
            print("Invalid character")
            exit(1)
        keys = tuple(set(keys))
        for key in keys:
            configuration_dict_key = list(configuration_dict)[key - 1]
            selection += configuration_dict[configuration_dict_key]["requirements"]
            graph_key.append(configuration_dict_key)

    else:
        print("No option was selected.")
        exit(1)
    selection = tuple(set(selection))

    config_data = {
        "configuration":
            {
                "graphs": graph_key,
                "modes": selection,
                "backends": supported_modes,
                "version": __version__,
                "target_interface": target_interface,
                "target_ip": bind_ip,
                "ssid": ssid,
                "speedtest": speedtest_type,
                "libre-speed-list": libre_speed_list,
                "benchmark_iterations": repeat_count,
            },
        "results": {}
    }

    config_file = os.path.abspath(config_file)

    logging.debug("Configuration Data: {0}".format(config_data))
    logging.debug("Configuration Save Path: {0}".format(config_file))

    if pathlib.Path(config_file).suffix != ".json":
        config_file += ".json"

    if save_json(config_file, config_data):
        print("Successfully bootstrapped configuration.")
        print("Configuration file saved at: {0}".format(config_file))


def print_graph_to_console(index, title, description):
    """Pretty print the configuration items on the
    terminal for the user.

    Args:
        index (int): row index number.
        title (str): title of the graph item.
        description (str): description of the graph
        item.

    Returns:
        None
    """
    print("  {0}{1}{2} {3}{4}{5}".format(TColor.GREEN, index, TColor.RESET, TColor.MAGENTA, title,
                                         TColor.RESET))
    print("        {0}".format(description))


def ask_y_n(question):
    """Ask a Yes or No question to user and get the
    boolean response for it.

    Args:
        index (int): row index number.
        title (str): title of the graph item.
        description (str): description of the
        graph item.

    Returns:
        bool : True if user accepts, False if
        rejects and repeats the question if
        invalid option.
    """
    while True:
        response = input(question).lower()
        if response in accept:
            return True
        elif response in reject:
            return False
        else:
            print("Invalid option. Please try again.")
