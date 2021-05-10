from wifi_heat_mapper.misc import TColor, check_application
from collections import OrderedDict


class ConfigurationOptions:
    configuration = OrderedDict()
    configuration["signal_quality"] = {
        "description": "Wi-Fi Signal Quality (out of 70)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 70,
        "mode": "base",
    }
    configuration["signal_quality_percent"] = {
        "description": "Wi-Fi Signal Quality (in percentage)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 100,
        "mode": "base",
    }
    configuration["signal_strength"] = {
        "description": "Wi-Fi Signal Strength (in dBm)",
        "requirements": ["base"],
        "vmin": -100,
        "vmax": 0,
        "mode": "base",
    }
    configuration["download_bits_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in bits/s)",
        "requirements": ["tcp_r"],
        "mode": "iperf3",
    }
    configuration["download_bytes_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in bytes/s)",
        "requirements": ["tcp_r"],
        "mode": "iperf3",
    }
    configuration["upload_bits_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in bits/s)",
        "requirements": ["tcp"],
        "mode": "iperf3",
    }
    configuration["upload_bytes_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in bytes/s)",
        "requirements": ["tcp"],
        "mode": "iperf3",
    }
    configuration["download_bits_udp"] = {
        "description": "Wi-Fi Download [UDP] (in bits/s)",
        "requirements": ["udp_r"],
        "mode": "iperf3",
    }
    configuration["download_bytes_udp"] = {
        "description": "Wi-Fi Download [UDP] (in bytes/s)",
        "requirements": ["udp_r"],
        "mode": "iperf3",
    }
    configuration["upload_bits_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in bits/s)",
        "requirements": ["udp"],
        "mode": "iperf3",
    }
    configuration["upload_bytes_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in bytes/s)",
        "requirements": ["udp"],
        "mode": "iperf3",
    }
    configuration["download_jitter_udp"] = {
        "description": "Wi-Fi Download Jitter (in ms)",
        "requirements": ["udp_r"],
        "mode": "iperf3",
    }
    configuration["upload_jitter_udp"] = {
        "description": "Wi-Fi Upload Jitter (in ms)",
        "requirements": ["udp"],
        "mode": "iperf3",
    }
    configuration["speedtest_latency"] = {
        "description": "Speedtest Wi-Fi Latency (in ms)",
        "requirements": ["speedtest"],
        "mode": "speedtest",
    }
    configuration["speedtest_jitter"] = {
        "description": "Speedtest Wi-Fi Jitter (in ms)",
        "requirements": ["speedtest"],
        "mode": "speedtest",
    }
    configuration["speedtest_download_bandwidth"] = {
        "description": "Speedtest Wi-Fi Download [TCP] (in bytes/s)",
        "requirements": ["speedtest"],
        "mode": "speedtest",
    }
    configuration["speedtest_upload_bandwidth"] = {
        "description": "Speedtest Wi-Fi Upload [TCP] (in bytes/s)",
        "requirements": ["speedtest"],
        "mode": "speedtest",
    }


def start_config():
    supported_modes = []
    if check_application("iperf3"):
        supported_modes.append("iperf3")
    if check_application("speedtest"):
        supported_modes.append("speedtest")

    if len(supported_modes) == 0:
        print("Could not detect any supported mode [iperf3 or speedtest].")
        exit(1)

    print("Supported Modes: {}{}{}".format(TColor.BLUE, " ".join(map(str, supported_modes)), TColor.RESET))

    print("Supported Graphs:")
    configuration_dict = ConfigurationOptions.configuration
    i = 1
    for itm in configuration_dict.keys():
        mode = configuration_dict[itm]["mode"]
        if mode == "base" or mode in supported_modes:
            print_graph_to_console(i, itm, configuration_dict[itm]["description"])
            i += 1

    print("{}{}{}".format(TColor.UNDERLINE, "=>> Select graphs to plot. eg: 1 2 3 5 6 or simply "
                          "type 'all'", TColor.RESET))
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
    return {"graphs": graph_key, "modes": selection, "backends": supported_modes}


def print_graph_to_console(index, title, description):
    print("  {}{}{} {}{}{}".format(TColor.GREEN, index, TColor.RESET, TColor.MAGENTA, title,
                                   TColor.RESET))
    print("        {}".format(description))
