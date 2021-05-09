from wifi_heat_mapper.misc import TColor, check_application
from collections import OrderedDict


class ConfigurationOptions:
    configuration = OrderedDict()
    configuration["signal_quality"] = {
        "description": "Wi-Fi Signal Quality (out of 70)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 70,
    }
    configuration["signal_quality_percent"] = {
        "description": "Wi-Fi Signal Quality (in percentage)",
        "requirements": ["base"],
        "vmin": 0,
        "vmax": 100,
    }
    configuration["signal_strength"] = {
        "description": "Wi-Fi Signal Strength (in dBm)",
        "requirements": ["base"],
        "vmin": -100,
        "vmax": 0,
    }
    configuration["download_bits_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in bits)",
        "requirements": ["tcp_r"],
    }
    configuration["download_bytes_tcp"] = {
        "description": "Wi-Fi Download [TCP] (in bytes)",
        "requirements": ["tcp_r"],
    }
    configuration["upload_bits_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in bits)",
        "requirements": ["tcp"],
    }
    configuration["upload_bytes_tcp"] = {
        "description": "Wi-Fi Upload [TCP] (in bytes)",
        "requirements": ["tcp"],
    }
    configuration["download_bits_udp"] = {
        "description": "Wi-Fi Download [UDP] (in bits)",
        "requirements": ["udp_r"],
    }
    configuration["download_bytes_udp"] = {
        "description": "Wi-Fi Download [UDP] (in bytes)",
        "requirements": ["udp_r"],
    }
    configuration["upload_bits_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in bits)",
        "requirements": ["udp"],
    }
    configuration["upload_bytes_udp"] = {
        "description": "Wi-Fi Upload [UDP] (in bytes)",
        "requirements": ["udp"],
    }
    configuration["download_jitter_udp"] = {
        "description": "Wi-Fi Download Jitter (in ms)",
        "requirements": ["udp_r"],
    }
    configuration["upload_jitter_udp"] = {
        "description": "Wi-Fi Upload Jitter (in ms)",
        "requirements": ["udp"],
    }


def start_config():
    modes = []
    if check_application("iperf3"):
        modes.append("iperf3")
    if check_application("speedtest"):
        modes.append("speedtest")

    if len(modes) == 0:
        print("Could not detect any supported mode [iperf3 or speedtest].")
        exit(1)

    print("Supported Graphs:")
    configuration_dict = ConfigurationOptions.configuration
    for idx, itm in enumerate(configuration_dict.keys()):
        print_graph_to_console(idx + 1, itm, configuration_dict[itm]["description"])
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
    return {"graphs": graph_key, "modes": selection}


def print_graph_to_console(index, title, description):
    print("  {}{}{} {}{}{}".format(TColor.GREEN, index, TColor.RESET, TColor.MAGENTA, title,
                                   TColor.RESET))
    print("        {}".format(description))
