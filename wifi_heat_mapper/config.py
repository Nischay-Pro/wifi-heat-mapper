from wifi_heat_mapper.misc import TColor, check_application, process_iw, save_json, get_application_output
from wifi_heat_mapper.misc import check_speedtest, SpeedTestMode
from wifi_heat_mapper import __version__
from collections import OrderedDict
import os
import pathlib


class ConfigurationOptions:
    configuration = OrderedDict()
    configuration["signal_quality"] = {
        "description": "Wi-Fi Signal Quality (out of 70)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 70,
        "mode": ["base"],
        "conversion": False,
    }
    configuration["signal_quality_percent"] = {
        "description": "Wi-Fi Signal Quality (in percentage)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 100,
        "mode": ["base"],
        "conversion": False,
    }
    configuration["signal_strength"] = {
        "description": "Wi-Fi Signal Strength (in dBm)",
        "requirements": ["base"],
        "vmin": -100,
        "vmax": 0,
        "mode": ["base"],
        "conversion": False,
    }
    configuration["download_bits_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["tcp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["download_bytes_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["tcp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["upload_bits_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["tcp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["upload_bytes_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["tcp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["download_bits_udp"] = {
        "description": "Wi-Fi Download [UDP] (in {0}/s)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["download_bytes_udp"] = {
        "description": "Wi-Fi Download [UDP] (in {0}/s)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["upload_bits_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in {0}/s)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["upload_bytes_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in {0}/s)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["download_jitter_udp"] = {
        "description": "Wi-Fi Download Jitter (in ms)",
        "requirements": ["udp_r"],
        "mode": ["iperf3"],
        "conversion": False,
    }
    configuration["upload_jitter_udp"] = {
        "description": "Wi-Fi Upload Jitter (in ms)",
        "requirements": ["udp"],
        "mode": ["iperf3"],
        "conversion": False,
    }
    configuration["speedtest_latency"] = {
        "description": "Speedtest Wi-Fi Latency (in ms)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla"],
        "conversion": False,
    }
    configuration["speedtest_jitter"] = {
        "description": "Speedtest Wi-Fi Jitter (in ms)",
        "requirements": ["speedtest"],
        "mode": ["speedtest-ookla"],
        "conversion": False,
    }
    configuration["speedtest_download_bandwidth"] = {
        "description": "Speedtest Wi-Fi Download [TCP] (in {0}/s)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla"],
        "vmin": 0,
        "conversion": True,
    }
    configuration["speedtest_upload_bandwidth"] = {
        "description": "Speedtest Wi-Fi Upload [TCP] (in {0}/s)",
        "requirements": ["speedtest"],
        "mode": ["speedtest", "speedtest-ookla"],
        "vmin": 0,
        "conversion": True,
    }


def start_config(config_file):
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

    if len(supported_modes) == 0:
        print("Could not detect any supported mode [iperf3 or speedtest].")
        exit(1)

    print("Supported Modes: {0}{1}{2}".format(TColor.BLUE, " ".join(map(str, supported_modes)), TColor.RESET))

    print("Supported Graphs:")
    configuration_dict = ConfigurationOptions.configuration
    supported_modes.append("base")
    i = 1
    for itm in configuration_dict.keys():
        mode = configuration_dict[itm]["mode"]
        supported = set(mode).intersection(set(supported_modes))
        if supported:
            print_graph_to_console(i, itm, configuration_dict[itm]["description"])
            i += 1

    print("{0}{1}{2}".format(TColor.UNDERLINE, "=>> Select graphs to plot. eg: 1 2 3 5 6 or simply type 'all'",
                             TColor.RESET))
    response = input("> ")
    selection = []
    graph_key = []

    if response == "all":
        for itm in configuration_dict.keys():
            selection += configuration_dict[itm]["requirements"]
        keys = tuple(range(1, len(configuration_dict.keys()) + 1))
        graph_key = tuple(configuration_dict.keys())

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

    ssid = None
    target_interface = None

    if not check_application("iw"):
        print("Could not detect iw (Wireless tools for Linux)")
        exit(1)

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

        break

    while True:
        ssid = process_iw(target_interface)["ssid"]
        response = input("You are connected to {0}{1}{2}. Is this the interface you want to benchmark on? (y/N) "
                         .format(TColor.BLUE, ssid, TColor.RESET)).lower()

        accept = ("y", "yes")
        if response in accept:
            break

    config_data = {
        "configuration":
            {
                "graphs": graph_key,
                "modes": selection,
                "backends": supported_modes,
                "version": __version__,
                "target_interface": target_interface,
                "ssid": ssid,
                "speedtest": speedtest_type,
            },
        "results": {}
    }

    config_file = os.path.abspath(config_file)

    if pathlib.Path(config_file).suffix != ".json":
        config_file += ".json"

    if save_json(config_file, config_data):
        print("Successfully bootstrapped configuration.")
        print("Configuration file saved at: {0}".format(config_file))


def print_graph_to_console(index, title, description):
    print("  {0}{1}{2} {3}{4}{5}".format(TColor.GREEN, index, TColor.RESET, TColor.MAGENTA, title,
                                         TColor.RESET))
    print("        {0}".format(description))
