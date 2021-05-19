from wifi_heat_mapper.debugger import log_arguments
import subprocess
from shutil import which
import re
import socket
import json
import iperf3
import importlib
from enum import IntEnum
import os
import logging


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


class ExternalError(Exception):
    pass


def check_application(name):
    """Check if application is available in the
    current environment.

    Args:
        name (str): application (or executable) name.

    Returns:
        bool : True if application is available,
        False if not available.
    """
    return which(name) is not None


def get_application_output(command, shell=False, timeout=None):
    """Run a command and get the output.

    Args:
        command (str, list): The command to run
        and it's arguments.
        shell (bool), optional: True if executing on
        shell, else False. Default is False.
        timeout (int, None), optional: Set a max
        execution time in seconds for the command.

    Returns:
        str: Command output if the command ran with
        a zero exit code. Returns a string containing
        the error reason in case the command failed.
    """
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
    """Verify if a wireless interface exists and is
    operational.

    Args:
        target_interface (str): The network interface to
        verify.

    Returns:
        None
    """
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
    """Get metrics from a wireless interface.

    Args:
        target_interface (str): The network interface to
        capture metrics from.

    Returns:
        dict: A dictionary containing the metrics and
        their values as corresponding (key, value) pairs.
    """
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
    """Create a socket and verify if iperf3 is running
    on the provided ip and port.

    Args:
        ip (str): The ip address of the iperf3 server.
        port (str): The port of the iperf3 server.

    Returns:
        bool: True if connection could be established.
        False if it failed to establish.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    result = sock.connect_ex((ip, port))
    if result == 0:
        sock.close()
        return True
    else:
        sock.close()
        return False


@log_arguments
def run_iperf(ip, port, bind_address, download=True, protocol="tcp", retry=0):
    """Run iperf3 and return the json results.

    Args:
        ip (str): The ip address of the iperf3 server.
        port (str): The port of the iperf3 server.
        bind_address (str): The wireless interface ip
        address of the client which is being used to
        benchmark.
        download (bool), optional: True if testing download,
        False if testing upload. Defaults to True.
        protocol (str), optional: 'tcp' if testing using tcp
        protocol. 'udp' if testing using udp protocol.
        Defaults to 'tcp'
        retry (int), optional: The retry count.

    Returns:
        dict: Dictionary containing the iperf3 results.
    """
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
    iperf_result_json = iperf_result.json
    try:
        get_property_from(iperf_result_json, "start")
        get_property_from(iperf_result_json, "end")
    except ValueError:
        logging.error("Output from iperf3 : {0}".format(iperf_result_json))
        logging.exception("Unable to parse iperf3 result")
        if retry == 2:
            raise ExternalError("External Error generated from iperf3: {0}".format(iperf_result_json["error"])) from\
                  None
        else:
            logging.warning("Rerunning iperf3 with retry count {0}".format(retry + 1))
            run_iperf(ip, port, bind_address, download, protocol, retry + 1)
    return iperf_result_json


@log_arguments
def run_speedtest(mode, bind_address, libre_speed_server_list=None, retry=0):
    """Run speedtest and return the json results.

    Args:
        mode (SpeedTestMode): The speedtest backend to use
        for benchmark.
        bind_address (str): The wireless interface ip
        address of the client which is being used to
        benchmark.
        libre_speed_server_list (str), optional: The
        path to the librespeed server json file.
        Default is None which forces librespeed to use
        global list.
        retry (int), optional: The retry count.

    Returns:
        dict: Dictionary containing the speedtest results.
    """
    try:
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
                logging.debug("Libre Args: {0}".format(libre_args))
            try:
                librespeed_result = json.loads(get_application_output(libre_args, timeout=120))
            except ValueError:
                raise ParseError("Unable to decode output from Librespeed CLI") from None
            return librespeed_result
    except ParseError as err:
        logging.exception("Parse Error has occured.")
        if retry == 2:
            raise err
        else:
            logging.warning("Rerunning Speedtest with retry count {0}".format(retry + 1))
            run_speedtest(mode, bind_address, libre_speed_server_list, retry + 1)


@log_arguments
def test_libre_speed(bind_address, libre_speed_server_list=None):
    """Test user provided server list for librespeed.

    Args:
        bind_address (str): The wireless interface ip
        address of the client which is being used to
        benchmark.
        libre_speed_server_list (str): The
        path to the librespeed server json file.

    Returns:
        bool: True if librespeed works with the
        user provided server list, otherwise False.
    """
    libre_args = ["librespeed-cli", "--json", "--source", bind_address, "--no-download", "--no-upload", "--no-icmp"]
    if not os.path.isfile((libre_speed_server_list)):
        raise OSError("Invalid server list specified for libre office")
    libre_speed_server_list = os.path.abspath(libre_speed_server_list)
    libre_args += ["--local-json", libre_speed_server_list]
    logging.debug("Libre Args: {0}".format(libre_args))
    try:
        json.loads(get_application_output(libre_args, timeout=120))
    except ValueError:
        return False
    return True


def check_speedtest():
    """Detect the speedtest installed and available.

    Args:
        None

    Returns:
        class (SpeedTestMode)
    """
    speedtest_result = get_application_output(["speedtest", "--version"], timeout=10)
    if "Speedtest by Ookla" in speedtest_result:
        return SpeedTestMode.OOKLA
    elif importlib.util.find_spec("speedtest") is not None:
        return SpeedTestMode.SIVEL
    return SpeedTestMode.UNKNOWN


def save_json(file_path, data):
    """Save a json dictionary to disk.

    Args:
        file_path (str): Path to the json
        file.
        data (dict): json dictionary to be saved.

    Returns:
        bool: True if json dictionary was saved,
        False otherwise.
    """
    try:
        with open(file_path, "w") as f:
            json.dump(data, f, indent=4)
            return True
    except:
        return False


def load_json(file_path):
    """Read a json dictionary from disk.

    Args:
        file_path (str): Path to the json
        file.

    Returns:
        dict or bool: json dictionary
        if file was read successfully.
        False if it failed to read.
    """
    try:
        with open(file_path, "r") as f:
            return json.load(f)
    except:
        return False


def get_property_from(dict, key):
    """Get a key value from a dictionary.

    Args:
        dict (dict): Dictionary to read
        from.
        key (str): key in the dictionary
        to get the value for.

    Returns:
        object: Containing the value.

    Raises:
        ValueError: When key does not
        exist in the dictionary.
    """
    try:
        return dict[key]
    except KeyError:
        raise ValueError("Could not retrieve property {0}".format(key)) from None


def bytes_to_human_readable(bytes, ndigits=2, limit=None):
    """Convert bytes to human readable format.

    Args:
        bytes (int): Size in bytes.
        ndigits (int), optional: Number of decimal
        places to round the human readable size to.
        Defaults to 2.
        limit (int), optional: Limit to a predefined
        unit size.

    Returns:
        tuple: Tuple containing the readable bytes
        in float, unit size in float, unit suffix
        in str.
    """
    if limit is None:
        for limit, suffix in HUMAN_BYTE_SIZE:
            if bytes >= limit:
                break

        if limit == 1 and bytes > 1:
            suffix += "s"

    readable_bytes = round((bytes / limit), ndigits)
    return (readable_bytes, limit, suffix)


def get_ip_address_from_interface(interface):
    """Get the IPv4 address of an interface.

    Args:
        target_interface (str): The network interface to
        get the ip address for.

    Returns:
        str or None: Returns the IPv4 address of the
        interface, returns None if no IPv4 address
        exists for that interface.
    """
    data = json.loads(get_application_output(["ip", "-br", "--json", "addr", "show"]))
    for datum in data:
        if datum["ifname"] == interface:
            for address in datum["addr_info"]:
                ip_addr = address["local"]
                if validate_ipv4(ip_addr):
                    return ip_addr
    return None


def validate_ipv4(ip_address):
    """Validate an IPv4 address.

    Args:
        ip_address (str): The IPv4 address to check.

    Returns:
        bool: True if a valid IPv4 address, False
        otherwise.
    """
    if re.match(r"\b((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?:(?<!\.)\b|\.)){4}", ip_address):
        return True
    else:
        return False
