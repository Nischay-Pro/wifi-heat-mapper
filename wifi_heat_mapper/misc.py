import subprocess
from shutil import which
import re
import socket
import json
import iperf3
import importlib
from enum import IntEnum
import os


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


class SpeedTestMode(IntEnum):
    UNKNOWN = -1
    OOKLA = 0
    SIVEL = 1
    LIBRESPEED = 2


class suppress_stdout_stderr(object):
    # https://stackoverflow.com/questions/11130156/suppress-stdout-stderr-print-from-python-functions
    '''
    A context manager for doing a "deep suppression" of stdout and stderr in
    Python, i.e. will suppress all print, even if the print originates in a
    compiled C/Fortran sub-function.
       This will not suppress raised exceptions, since exceptions are printed
    to stderr just before a script exits, and after the context manager has
    exited (at least, I think that is why it lets exceptions through).

    '''
    def __init__(self):
        # Open a pair of null files
        self.null_fds = [os.open(os.devnull, os.O_RDWR) for x in range(2)]
        # Save the actual stdout (1) and stderr (2) file descriptors.
        self.save_fds = [os.dup(1), os.dup(2)]

    def __enter__(self):
        # Assign the null pointers to stdout and stderr.
        os.dup2(self.null_fds[0], 1)
        os.dup2(self.null_fds[1], 2)

    def __exit__(self, *_):
        # Re-assign the real stdout/stderr back to (1) and (2)
        os.dup2(self.save_fds[0], 1)
        os.dup2(self.save_fds[1], 2)
        # Close all file descriptors
        for fd in self.null_fds + self.save_fds:
            os.close(fd)


HUMAN_BYTE_SIZE = [
    (1 << 60, "EiB"),
    (1 << 50, "PiB"),
    (1 << 40, "TiB"),
    (1 << 30, "GiB"),
    (1 << 20, "MiB"),
    (1 << 10, "KiB"),
    (1, "Byte")
]


class ParseError(Exception):
    pass


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
    except FileNotFoundError:
        return "unavailable"


def verify_interface(target_interface):
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


def process_iw(target_interface):

    verify_interface(target_interface)

    try:
        iw_info = get_application_output(
            ["iw {0} info".format(target_interface)],
            shell=True, timeout=10).replace("\t", " ")

        if iw_info == "invalid":
            print("The interface {0} is not a wireless interface".format(target_interface))
            exit(1)

        results = {}
        results["interface"] = re.findall(r"(?<=Interface )(.*)", iw_info)[0]
        results["interface_mac"] = re.findall(r"([0-9a-fA-F]{2}[:]){5}([0-9a-fA-F]{2})", iw_info)[0]
        tmp = re.findall(r"(?<=channel )(.*?)(?=\,)", iw_info)[0].split(" ")
        results["channel"] = int(tmp[0])
        results["channel_frequency"] = int(tmp[1].replace("(", ""))
        results["ssid"] = re.findall(r"(?<=ssid )(.*)", iw_info)[0]
        iw_info = get_application_output(["iw {0} station dump".format(target_interface)],
                                         shell=True, timeout=10).replace("\t", " ")
        results["ssid_mac"] = re.findall(r"(?<=Station )(.*)(?= \()", iw_info)[0]
        results["signal_strength"] = int(re.findall(r"(?<=signal avg: )(.*)", iw_info)[0].split(" ")[0])
    except IndexError:
        raise ParseError("Unable to parse iw.") from None
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


def run_iperf(ip, port, bind_address, download=True, protocol="tcp"):
    client = iperf3.Client()
    client.server_hostname = ip
    client.port = port
    client.bind_address = bind_address
    client.reverse = False
    client.verbose = False
    client._errno
    if download:
        client.reverse = True
    client.protocol = protocol
    with suppress_stdout_stderr():
        iperf_result = client.run()
    return iperf_result.json


def run_speedtest(mode, bind_address, libre_speed_server_list=None):
    if mode == SpeedTestMode.OOKLA:
        try:
            speedtest_result = json.loads(get_application_output(["speedtest", "-f", "json", "-i", bind_address],
                                                                 timeout=120))
        except ValueError:
            raise ParseError("Unable to decode output from Speedtest Ookla") from None
        return speedtest_result
    elif mode == SpeedTestMode.SIVEL:
        try:
            speedtest_result = json.loads(get_application_output(["speedtest", "--json", "--source", bind_address],
                                                                 timeout=120))
        except ValueError:
            raise ParseError("Unable to decode output from Speedtest Sivel") from None
        return speedtest_result
    elif mode == SpeedTestMode.LIBRESPEED:
        libre_args = ["librespeed-cli", "--json", "--source", bind_address, "--mebibytes"]
        if libre_speed_server_list is not None:
            if not os.path.isfile((libre_speed_server_list)):
                raise OSError("Invalid server list specified for libre office")
            libre_speed_server_list = os.path.abspath(libre_speed_server_list)
            libre_args += ["--local-json", libre_speed_server_list]
        try:
            librespeed_result = json.loads(get_application_output(libre_args, timeout=120))
        except ValueError:
            raise ParseError("Unable to decode output from Librespeed CLI") from None
        return librespeed_result


def test_libre_speed(bind_address, libre_speed_server_list=None):
    libre_args = ["librespeed-cli", "--json", "--source", bind_address, "--no-download", "--no-upload", "--no-icmp"]
    if not os.path.isfile((libre_speed_server_list)):
        raise OSError("Invalid server list specified for libre office")
    libre_speed_server_list = os.path.abspath(libre_speed_server_list)
    libre_args += ["--local-json", libre_speed_server_list]
    try:
        json.loads(get_application_output(libre_args, timeout=120))
    except ValueError:
        return False
    return True


def check_speedtest():
    speedtest_result = get_application_output(["speedtest", "--version"], timeout=10)
    if "Speedtest by Ookla" in speedtest_result:
        return SpeedTestMode.OOKLA
    elif importlib.util.find_spec("speedtest") is not None:
        return SpeedTestMode.SIVEL
    return SpeedTestMode.UNKNOWN


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


def get_property_from(dict, key):
    try:
        return dict[key]
    except KeyError:
        raise ValueError("Could not retrieve property {0}".format(key)) from None


def bytes_to_human_readable(bytes, ndigits=2, limit=None):
    if limit is None:
        for limit, suffix in HUMAN_BYTE_SIZE:
            if bytes >= limit:
                break

        if limit == 1 and bytes > 1:
            suffix += "s"

    readable_bytes = round((bytes / limit), ndigits)
    return (readable_bytes, limit, suffix)


def get_ip_address_from_interface(interface):
    data = json.loads(get_application_output(["ip", "-br", "--json", "addr", "show"]))
    for datum in data:
        if datum["ifname"] == interface:
            for address in datum["addr_info"]:
                ip_addr = address["local"]
                if validate_ipv4(ip_addr):
                    return ip_addr
    return None


def validate_ipv4(ip_address):
    if re.match(r"\b((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?:(?<!\.)\b|\.)){4}", ip_address):
        return True
    else:
        return False
