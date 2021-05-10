import subprocess
from shutil import which
import re
import socket
import json
import iperf3


class TColor:
    BLACK = "\u001b[30;1m"
    RED = "\u001b[31;1m"
    GREEN = "\u001b[32;1m"
    YELLOW = "\u001b[33;1m"
    BLUE = "\u001b[34;1m"
    MAGENTA = "\u001b[35;1m"
    CYAN = "\u001b[36;1m"
    WHITE = "\u001b[37;1m"
    RESET = "\u001b[0m"
    UNDERLINE = "\u001b[4m"


def check_application(name):
    return which(name) is not None


def get_application_output(command, shell=False, timeout=None):
    try:
        return subprocess.run(command, shell=shell, check=True, universal_newlines=True,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              timeout=timeout).stdout
    except subprocess.CalledProcessError:
        return "invalid"
    except subprocess.TimeoutExpired:
        return "timeout"


def processIW(target_interface):

    iw_info = get_application_output(
        ["iw {} info".format(target_interface)],
        shell=True, timeout=10).replace("\t", " ")

    if iw_info == "invalid":
        print("The interface {} is not a wireless interface".format(target_interface))
        exit(1)

    results = {}
    results["interface"] = re.findall(r"(?<=Interface )(.*)", iw_info)[0]
    results["interface_mac"] = re.findall(r"(?<=addr ac:)(.*)", iw_info)[0]
    tmp = re.findall(r"(?<=channel )(.*?)(?=\,)", iw_info)[0].split(" ")
    results["channel"] = int(tmp[0])
    results["channel_frequency"] = int(tmp[1].replace("(", ""))
    results["ssid"] = re.findall(r"(?<=ssid )(.*)", iw_info)[0]

    iw_info = get_application_output(["iw {} station dump".format(target_interface)],
                                     shell=True, timeout=10).replace("\t", " ")

    results["ssid_mac"] = re.findall(r"(?<=Station )(.*)(?= \()", iw_info)[0]
    results["signal_strength"] = int(re.findall(r"(?<=signal avg: )(.*)", iw_info)[0].split(" ")[0])
    return results


def verify_iperf(ip, port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    result = sock.connect_ex((ip, port))
    if result == 0:
        sock.close()
        return True
    else:
        sock.close()
        return False


def run_iperf(ip, port, download=True, protocol="tcp"):
    client = iperf3.Client()
    client.server_hostname = ip
    client.port = port
    client.reverse = False
    if download:
        client.reverse = True
    client.protocol = protocol
    iperf_result = client.run()
    return iperf_result.json


def run_speedtest():
    speedtest_result = json.loads(get_application_output(["speedtest", "-f", "json"], timeout=120))
    return speedtest_result


def save_json(file_path, data):
    try:
        with open(file_path, "w") as f:
            json.dump(data, f, indent=4)
            return True
    except:
        return False


def load_json(file_path):
    try:
        with open(file_path, "r") as f:
            return json.load(f)
    except:
        return False
