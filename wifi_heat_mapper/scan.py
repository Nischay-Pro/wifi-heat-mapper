import argparse
from wifi_heat_mapper.misc import check_application, get_application_output, processIW
from wifi_heat_mapper.gui import start_gui
from wifi_heat_mapper.config import start_config


def main(target_interface, floor_map, iperf_server, input_file, output_file):
    required_applications = ["iw"]
    for app in required_applications:
        if not check_application(app):
            print("Could not find required external application: {}!".format(app))
            exit(1)

    cmd = "cat /sys/class/net/{}/operstate".format(target_interface)
    check_interface = get_application_output(cmd, shell=True, timeout=10)
    if check_interface == "invalid":
        print("Interface {} does not exist!".format(target_interface))
        exit(1)
    elif check_interface == "timeout":
        print("Unable to get interface {} status".format(target_interface))
        exit(1)

    check_interface = check_interface.split("\n")[0]
    if check_interface != "up":
        print("Interface {} is not ready.".format(target_interface))
        exit(1)

    iw_results = processIW(target_interface)

    print("Running benchmark for SSID: {}".format(iw_results["ssid"]))

    if ":" in iperf_server:
        iperf_ip = iperf_server.split(":")[0]
        iperf_port = iperf_server.split(":")[1]
    else:
        iperf_ip = iperf_server
        iperf_port = 5201

    configuration = None
    if input_file is None:
        configuration = start_config()

    print("Loading floor map")
    start_gui(target_interface, floor_map, iperf_ip, iperf_port, iw_results["ssid"], input_file,
              output_file, configuration)


def driver():
    parser = argparse.ArgumentParser(
        description="Generate Wi-Fi heat maps")
    parser.add_argument(
        "--target", "-t", dest="target_interface", required=True, default=None,
        help="Target Interface to parse data from.")
    parser.add_argument(
        "--map", "-m", dest="floor_map", required=True, default=None,
        help="Image path to floor map.")
    parser.add_argument(
        "--server", "-s", dest="iperf_server", required=True, default=None,
        help="IP (and port) address of the iperf3 server.")
    parser.add_argument(
        "--input", "-i", dest="input_file", required=False, default=None,
        help="Input file path of the save state.")
    parser.add_argument(
        "--output", "-o", dest="output_file", required=False, default=None,
        help="Output file path for the save state.")
    args = parser.parse_args()

    main(**vars(args))


if __name__ == "__main__":
    driver()
