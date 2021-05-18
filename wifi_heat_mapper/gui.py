import PySimpleGUI as sg
import os.path
from wifi_heat_mapper.misc import run_iperf, run_speedtest, process_iw, load_json, save_json, verify_iperf
from wifi_heat_mapper.misc import get_property_from, SpeedTestMode
from wifi_heat_mapper.graph import generate_graph
from wifi_heat_mapper.debugger import log_arguments
from PIL import Image, ImageTk
import io
from tqdm import tqdm
from collections import defaultdict
import logging


class ConfigurationError(Exception):
    pass


iperf3_modes = ["tcp", "tcp_r", "udp", "udp_r"]


@log_arguments
def start_gui(floor_map, iperf_server, config_file, output_file=None):
    """Starting point for the benchmark submodule for whm.

    Args:
        floor_map (str): the path to the floor map image.
        iperf_server (str): the ip address (and port)
        for the iperf3 server.
        config_file (str): the path to the configuration
        file.
        output_file (str): the path to the output file.

    Returns:
        None
    """
    if os.path.isfile(config_file):
        config_file = os.path.abspath(config_file)
        data = load_json(config_file)
        if data is not False:
            configuration = get_property_from(data, "configuration")
            logging.debug("Configuration Loaded: {0}".format(configuration))
            ssid = get_property_from(configuration, "ssid")
            target_interface = get_property_from(configuration, "target_interface")
            target_ip = get_property_from(configuration, "target_ip")
            speedtest_mode = SpeedTestMode(get_property_from(configuration, "speedtest"))
            libre_speed_server_list = get_property_from(configuration, "libre-speed-list").strip()
            if libre_speed_server_list == "":
                libre_speed_server_list = None

            connected_ssid = process_iw(target_interface)["ssid"]
            logging.debug("SSID Connected: {0}".format(connected_ssid))
            if connected_ssid != ssid:
                print("Configuration file is for {0} but user connected to {1}"
                      .format(ssid, connected_ssid))
                print("Please connect to {0} and try benchmarking again."
                      .format(ssid))
                exit(1)

            if output_file is None:
                output_file = config_file

    else:
        raise ConfigurationError("Missing configuration file")

    modes = get_property_from(configuration, "modes")

    if len(set(iperf3_modes).intersection(set(modes))) > 0 and iperf_server is None:
        print("Please specify your iperf3 server IP address.")
        exit(1)

    iperf_ip = iperf_server
    iperf_port = 5201

    if iperf_server is not None:
        if ":" in iperf_server:
            iperf_ip = iperf_server.split(":")[0]
            iperf_port = iperf_server.split(":")[1]
        else:
            iperf_ip = iperf_server
            iperf_port = 5201

    print("Loaded configuration file from: {0}".format(config_file))
    print("Target Interface: {0} and SSID: {1}".format(target_interface, ssid))

    right_click_items = ["Items", ["&Benchmark", "&Delete", "&Mark/Un-Mark as Station"]]

    print("Loading floor map")
    logging.info("Loading floor map: {0}".format(floor_map))

    im = Image.open(floor_map)
    canvas_size = (im.size[0], im.size[1])

    logging.info("Loaded floor map with dims: {0}".format(canvas_size))

    output_path_index = sg.InputText(visible=False, enable_events=True, key='output_path')
    layout = [
        [sg.Graph(
            canvas_size=canvas_size,
            graph_bottom_left=(0, 0),
            graph_top_right=canvas_size,
            key="Floor Map",
            enable_events=True,
            background_color="DodgerBlue",
            right_click_menu=right_click_items)]
    ]

    if not output_file:
        layout.append(
            [sg.Button("Exit"), output_path_index, sg.FileSaveAs(button_text="Save Results",
             file_types=(('JSON file', '*.json'),), default_extension="json", key="FileName"),
             sg.Button("Plot"), sg.Button("Clear All")])
    else:
        layout.append(
            [sg.Button("Exit"), output_path_index, sg.Button("Save Results"),
             sg.Button("Plot"), sg.Button("Clear All")])

    window = sg.Window("Wi-Fi heat mapper", layout, finalize=True)

    if output_file:
        output_path_index.update(output_file)

    graph = window.Element("Floor Map")

    logging.info("Drawing on canvas")
    graph.DrawImage(data=get_img_data(floor_map, first=True), location=(0, canvas_size[1]))
    logging.info("Updated canvas")

    print("Loaded floor map")

    benchmark_points = get_property_from(data, "results")

    current_selection = None
    benchmark_count = len(benchmark_points.keys())
    logging.debug("Benchmarking Points detected from previous run(s): {0}".format(benchmark_count))
    if benchmark_count != 0:
        print("Restoring previous benchmark points [{0}]".format(benchmark_count))
        benchmark_points, current_selection = replot(graph, benchmark_points)

    if "iperf3" in configuration["modes"] and not verify_iperf(iperf_ip, iperf_port):
        print("Could not connect to iperf3 server.")
        sg.popup_error("Could not connect to iperf3 server.")
        exit(1)

    print("Ready for benchmarking.")

    post_process = False

    while True:
        event, values = window.read()

        if event == "Exit" or event == sg.WIN_CLOSED:
            break

        mouse = values["Floor Map"]
        if event == "Floor Map":
            if mouse == (None, None):
                continue

            pt_exists = False
            for itm in benchmark_points.keys():
                pt_bench = get_point(benchmark_points, itm)
                if contains(mouse, pt_bench):
                    pt_exists = True
                    benchmark_points[itm]["selected"] = True
                    if current_selection is None:
                        current_selection = itm
                    else:
                        benchmark_points[current_selection]["selected"] = False
                        current_selection = itm
                    break

            if not pt_exists:
                index = graph.draw_circle(mouse, 7, fill_color="gray", line_color="blue",
                                          line_width=3)
                benchmark_points[index] = {
                    "position": {
                        "x": mouse[0],
                        "y": mouse[1]
                    },
                    "fill_color": "gray",
                    "selected": True,
                    "station": False,
                    "results": None
                }
                if current_selection is not None:
                    benchmark_points[current_selection]["selected"] = False
                    current_selection = index
                else:
                    current_selection = index

        benchmark_points, current_selection = replot(graph, benchmark_points)

        if event == "Delete":
            if current_selection is not None:
                graph.delete_figure(current_selection)
                benchmark_points.pop(current_selection)
                current_selection = None

        if event == "Benchmark":
            if current_selection is not None:

                iw = process_iw(target_interface)
                if iw["ssid"] != ssid:
                    sg.popup_error("SSID mismatch!")
                    print("SSID mismatch!")
                    logging.error("SSID mismatched. Config: {0} | User: {1}".format(ssid, iw["ssid"]))
                else:
                    logging.info("Running benchmark")
                    print("Running benchmark")
                    results = {}
                    benchmark_modes = get_property_from(configuration, "modes")
                    benchmark_iterations = get_property_from(configuration, "benchmark_iterations")
                    results = run_benchmarks(benchmark_modes, benchmark_iterations, iperf_ip, iperf_port,
                                             speedtest_mode, target_ip, libre_speed_server_list)
                    results["signal_strength"] = iw["signal_strength"]
                    results["signal_quality"] = iw["signal_strength"] + 110
                    results["signal_quality_percent"] = min((iw["signal_strength"] + 110) * (10 / 7), 100)
                    results["channel"] = iw["channel"]
                    results["channel_frequency"] = iw["channel_frequency"]
                    benchmark_points[current_selection]["results"] = results

                    benchmark_points[current_selection]["fill_color"] = "lightblue"
                    benchmark_points, current_selection = replot(graph, benchmark_points)

                    print("Completed benchmark.")
                    logging.info("Completed benchmark")
                    if not save_results_to_disk(output_file, configuration, benchmark_points):
                        print("Unable to save to disk")
                        logging.warning("Unable to save to disk.")
            else:
                print("Please select a benchmark point.")
                sg.popup_error("Please select a benchmark point.")

        if event == "Mark/Un-Mark as Station":
            if current_selection is not None:
                if benchmark_points[current_selection]["station"]:
                    benchmark_points[current_selection]["station"] = False
                else:
                    benchmark_points[current_selection]["station"] = True
                benchmark_points, current_selection = replot(graph, benchmark_points)

        if event == "output_path":
            if values["output_path"]:
                benchmark_points = de_select(benchmark_points)
                data = {
                    "configuration": configuration,
                    "results": benchmark_points
                }
                if save_json(values["output_path"], data):
                    print("Saved to disk")
                    sg.popup_ok("Saved to disk")
                    output_path_index.update(value="")
                else:
                    print("Unable to save to disk")
                    sg.popup_error("Unable to save to disk!")
                    logging.error("Unable to save to disk")

        if event == "Save Results":
            benchmark_points = de_select(benchmark_points)
            data = {
                "configuration": configuration,
                "results": benchmark_points
            }
            if save_json(output_file, data):
                print("Saved to disk")
                sg.popup_ok("Saved to disk")
            else:
                print("Unable to save to disk")
                sg.popup_error("Unable to save to disk!")
                logging.error("Unable to save to disk")

        if event == "Plot":
            valid_benchmark_points = processed_results(benchmark_points)
            if valid_benchmark_points >= 4:
                post_process = True
                print("Exporting Results")
                break
            else:
                sg.popup_error("Not enough benchmark points! Try benchmarking {0} more."
                               .format(4 - valid_benchmark_points))

        if event == "Clear All":
            benchmark_points, current_selection = replot(graph, benchmark_points, clear=True)
            logging.error("Wiped all benchmark points")

    window.close()

    if post_process:
        data = {
            "configuration": configuration,
            "results": benchmark_points
        }
        generate_graph(data, floor_map)


def contains(pt1, pt2):
    """Check if tuple (x, y) of first point lies in
    a circle contructed from the center point of
    second point.

    Args:
        pt1 (tuple): tuple of (x, y).
        pt2 (tuple): tuple of (x, y).

    Returns:
        bool: True or False
    """
    return ((pt1[0] - pt2[0]) ** 2 + (pt1[1] - pt2[1]) ** 2) <= 7 ** 2


def get_point(data, index):
    """From a given dictionary and index returns a
    tuple (x, y).

    Args:
        data (dict): Dictionary to retrieve point
        from.
        index (int): Index of the point.

    Returns:
        tuple: Containing the x and y co-ordinates
        in the form of (x, y)
    """
    return (data[index]["position"]["x"], data[index]["position"]["y"])


def replot(graph, benchmark_points, clear=False):
    """Redraws the circles on the canvas from a
    dictionary containing benchmark points.

    Args:
        graph (object): Graph object defining the UI.
        benchmark_points (dict): Dictionary containing
        the benchmark points.
        clear (boolean), optional: True if you want
        to redraw circles.
        False if you want to delete all circles.

    Returns:
        new_benchmark_points (dict): Contaning the
        updated indices of the benchmark points.
        new_selection (int): New index of the selected
        point.
    """
    new_benchmark_point = {}
    new_selection = None
    for itm in benchmark_points.keys():
        graph.delete_figure(itm)
        line_color = "black"
        if not clear:
            if benchmark_points[itm]["station"]:
                line_color = "red"
            if benchmark_points[itm]["selected"]:
                line_color = "blue"
            pt = graph.draw_circle(get_point(benchmark_points, itm), 7, fill_color=benchmark_points[itm]["fill_color"],
                                   line_color=line_color, line_width=3)
            if benchmark_points[itm]["selected"]:
                new_selection = pt
            new_benchmark_point[pt] = benchmark_points[itm]
    return (new_benchmark_point, new_selection)


def de_select(benchmark_points):
    """Sets the 'selected' property for a benchmark
    point to False.

    Args:
        benchmark_points (dict): Dictionary containing
        the benchmark points.

    Returns:
        benchmark_points (dict): Dictionary with
        any 'selected' attribute set to False.
    """
    for itm in benchmark_points.keys():
        benchmark_points[itm]["selected"] = False
    return benchmark_points


def processed_results(benchmark_points):
    """Gets the number of benchmark points for which
    metrics have been captured.

    Args:
        benchmark_points (dict): Dictionary containing
        the benchmark points.

    Returns:
        results (int): Integer containing the number
        of points for which metrics have been captured.
    """
    results = 0
    for itm in benchmark_points.keys():
        if benchmark_points[itm]["results"] is not None:
            results += 1
    return results


def get_img_data(f, maxsize=(1200, 850), first=False):
    """Generate image data using PIL"""
    img = Image.open(f)
    img.thumbnail(maxsize)
    if first:
        bio = io.BytesIO()
        img.save(bio, format="PNG")
        del img
        return bio.getvalue()
    return ImageTk.PhotoImage(img)


def save_results_to_disk(file_path, configuration_data, benchmark_points):
    """Saves the results to disk.

    Args:
        file_path (str): Save path to the configuration file.
        configuration_data (dict): Dictionary containing the
        metrics and configuration details.
        benchmark_points (dict): Dictionary containing
        the benchmark points.

    Returns:
        bool: True if results have been saved to disk,
        False otherwise.
    """
    benchmark_points = de_select(benchmark_points)
    data = {
        "configuration": configuration_data,
        "results": benchmark_points
    }
    return save_json(file_path, data)


def run_benchmarks(benchmark_modes, benchmark_iterations, iperf_ip, iperf_port, speedtest_mode, bind_address,
                   libre_speed_server_list):
    """Runs benchmark for a given benchmark point.

    Args:
        benchmark_modes (tuple): Tuple containing the list
        of modes to use for benchmarking.
        benchmark_iterations (int): Number of times to repeat
        benchmarking.
        iperf_ip (str): ip address of the iperf3 server.
        iperf_port (int): port of the iperf3 server.
        speedtest_mode (SpeedTestMode): Speedtest backend to use.
        bind_address (str): The wireless interface ip
        address of the client which is being used to
        benchmark.
        libre_speed_server_list (str), optional: The
        path to the librespeed server json file.
        Default is None which forces librespeed to use
        global list.

    Returns:
        dict: Dictionary containing metrics and their values in
        corresponding key value pairs.
    """
    results = defaultdict(float)
    if "base" in benchmark_modes:
        progress = (len(benchmark_modes) - 1) * benchmark_iterations
    else:
        progress = len(benchmark_modes) * benchmark_iterations
    pbar = tqdm(total=progress)
    for _ in range(benchmark_iterations):
        if "tcp_r" in benchmark_modes:
            logging.debug("Running iperf3 in tcp_r mode")
            iperf_download = run_iperf(iperf_ip, iperf_port, bind_address, download=True, protocol="tcp")
            results["download_bits_tcp"] += iperf_download["end"]["sum_received"]["bits_per_second"]
            results["download_bytes_tcp"] += iperf_download["end"]["sum_received"]["bits_per_second"] / 8
            results["download_bytes_data_tcp"] += iperf_download["end"]["sum_received"]["bytes"]
            results["download_time_tcp"] += iperf_download["start"]["test_start"]["duration"]
            pbar.update(1)

        if "tcp" in benchmark_modes:
            logging.debug("Running iperf3 in tcp mode")
            iperf_download = run_iperf(iperf_ip, iperf_port, bind_address, download=False, protocol="tcp")
            results["upload_bits_tcp"] += iperf_download["end"]["sum_sent"]["bits_per_second"]
            results["upload_bytes_tcp"] += iperf_download["end"]["sum_sent"]["bits_per_second"] / 8
            results["upload_bytes_data_tcp"] += iperf_download["end"]["sum_sent"]["bytes"]
            results["upload_time_tcp"] += iperf_download["start"]["test_start"]["duration"]
            pbar.update(1)

        if "udp_r" in benchmark_modes:
            logging.debug("Running iperf3 in udp_r mode")
            iperf_download = run_iperf(iperf_ip, iperf_port, bind_address, download=True, protocol="udp")
            results["download_bits_udp"] += iperf_download["end"]["sum"]["bits_per_second"]
            results["download_bytes_udp"] += iperf_download["end"]["sum"]["bits_per_second"] / 8
            results["download_bytes_data_udp"] += iperf_download["end"]["sum"]["bytes"]
            results["download_time_udp"] += iperf_download["start"]["test_start"]["duration"]
            results["download_jitter_udp"] += iperf_download["end"]["sum"]["jitter_ms"]
            results["download_jitter_packets_udp"] += iperf_download["end"]["sum"]["packets"]
            results["download_jitter_lost_packets_udp"] += iperf_download["end"]["sum"]["lost_packets"]
            pbar.update(1)

        if "udp" in benchmark_modes:
            logging.debug("Running iperf3 in udp mode")
            iperf_download = run_iperf(iperf_ip, iperf_port, bind_address, download=False, protocol="udp")
            results["upload_bits_udp"] += iperf_download["end"]["sum"]["bits_per_second"]
            results["upload_bytes_udp"] += iperf_download["end"]["sum"]["bits_per_second"] / 8
            results["upload_bytes_data_udp"] += iperf_download["end"]["sum"]["bytes"]
            results["upload_time_udp"] += iperf_download["start"]["test_start"]["duration"]
            results["upload_jitter_udp"] += iperf_download["end"]["sum"]["jitter_ms"]
            results["upload_jitter_packets_udp"] += iperf_download["end"]["sum"]["packets"]
            results["upload_jitter_lost_packets_udp"] += iperf_download["end"]["sum"]["lost_packets"]
            pbar.update(1)

        if "speedtest" in benchmark_modes:
            logging.debug("Running speedtest enum value: {0}".format(speedtest_mode))
            speedtest_download = run_speedtest(speedtest_mode, bind_address,
                                               libre_speed_server_list=libre_speed_server_list)
            if speedtest_mode == SpeedTestMode.OOKLA:
                results["speedtest_jitter"] += speedtest_download["ping"]["jitter"]
                results["speedtest_latency"] += speedtest_download["ping"]["latency"]
                results["speedtest_download_bandwidth"] += speedtest_download["download"]["bandwidth"]
                results["speedtest_download_size"] += speedtest_download["download"]["bytes"]
                results["speedtest_download_elapsed_ms"] += speedtest_download["download"]["elapsed"]
                results["speedtest_upload_bandwidth"] += speedtest_download["upload"]["bandwidth"]
                results["speedtest_upload_size"] += speedtest_download["upload"]["bytes"]
                results["speedtest_upload_elapsed_ms"] += speedtest_download["upload"]["elapsed"]
                pbar.update(1)

            elif speedtest_mode == SpeedTestMode.SIVEL:
                results["speedtest_latency"] += speedtest_download["server"]["latency"]
                results["speedtest_download_bandwidth"] += speedtest_download["download"] / 8
                results["speedtest_download_size"] += speedtest_download["bytes_received"]
                results["speedtest_upload_bandwidth"] += speedtest_download["upload"] / 8
                results["speedtest_upload_size"] += speedtest_download["bytes_sent"]
                pbar.update(1)

            elif speedtest_mode == SpeedTestMode.LIBRESPEED:
                results["speedtest_jitter"] += speedtest_download["jitter"]
                results["speedtest_latency"] += speedtest_download["ping"]
                results["speedtest_download_bandwidth"] += (speedtest_download["download"] * (1 << 20) / 8)
                results["speedtest_download_size"] += speedtest_download["bytes_received"]
                results["speedtest_upload_bandwidth"] += (speedtest_download["upload"] * (1 << 20) / 8)
                results["speedtest_upload_size"] += speedtest_download["bytes_sent"]
                pbar.update(1)
    pbar.close()

    results = {key: value / benchmark_iterations for key, value in results.items()}

    return results
