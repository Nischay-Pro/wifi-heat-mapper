import PySimpleGUI as sg
import os.path
from wifi_heat_mapper.misc import run_iperf, run_speedtest, process_iw, load_json, save_json, verify_iperf
from wifi_heat_mapper.misc import get_property_from, SpeedTestMode
from wifi_heat_mapper.graph import generate_graph
from PIL import Image, ImageTk
import io


class ConfigurationError(Exception):
    pass


def start_gui(floor_map, iperf_server, config_file, output_file=None):

    if os.path.isfile(config_file):
        config_file = os.path.abspath(config_file)
        data = load_json(config_file)
        if data is not False:
            configuration = get_property_from(data, "configuration")
            ssid = get_property_from(configuration, "ssid")
            target_interface = get_property_from(configuration, "target_interface")
            speedtest_mode = SpeedTestMode(get_property_from(configuration, "speedtest"))

            connected_ssid = process_iw(target_interface)["ssid"]
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

    im = Image.open(floor_map)
    canvas_size = (im.size[0], im.size[1])

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
    graph.DrawImage(data=get_img_data(floor_map, first=True), location=(0, canvas_size[1]))

    print("Loaded floor map")

    benchmark_points = get_property_from(data, "results")

    current_selection = None
    benchmark_count = len(benchmark_points.keys())
    if benchmark_count != 0:
        print("Restoring previous benchmark points [{0}]".format(benchmark_count))
        benchmark_points, current_selection = replot(graph, benchmark_points)

    if "iperf3" in configuration["backends"] and not verify_iperf(iperf_ip, iperf_port):
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
                else:
                    try:
                        print("Running benchmark")
                        results = {}

                        if "tcp_r" in get_property_from(configuration, "modes"):
                            iperf_download = run_iperf(iperf_ip, iperf_port, download=True, protocol="tcp")
                            results["download_bits_tcp"] = iperf_download["end"]["sum_received"]["bits_per_second"]
                            results["download_bytes_tcp"] = iperf_download["end"]["sum_received"]["bits_per_second"] / 8
                            results["download_bytes_data_tcp"] = iperf_download["end"]["sum_received"]["bytes"]
                            results["download_time_tcp"] = iperf_download["start"]["test_start"]["duration"]

                        if "tcp" in get_property_from(configuration, "modes"):
                            iperf_download = run_iperf(iperf_ip, iperf_port, download=False, protocol="tcp")
                            results["upload_bits_tcp"] = iperf_download["end"]["sum_sent"]["bits_per_second"]
                            results["upload_bytes_tcp"] = iperf_download["end"]["sum_sent"]["bits_per_second"] / 8
                            results["upload_bytes_data_tcp"] = iperf_download["end"]["sum_sent"]["bytes"]
                            results["upload_time_tcp"] = iperf_download["start"]["test_start"]["duration"]

                        if "udp_r" in get_property_from(configuration, "modes"):
                            iperf_download = run_iperf(iperf_ip, iperf_port, download=True, protocol="udp")
                            results["download_bits_udp"] = iperf_download["end"]["sum"]["bits_per_second"]
                            results["download_bytes_udp"] = iperf_download["end"]["sum"]["bits_per_second"] / 8
                            results["download_bytes_data_udp"] = iperf_download["end"]["sum"]["bytes"]
                            results["download_time_udp"] = iperf_download["start"]["test_start"]["duration"]
                            results["download_jitter_udp"] = iperf_download["end"]["sum"]["jitter_ms"]
                            results["download_jitter_packets_udp"] = iperf_download["end"]["sum"]["packets"]
                            results["download_jitter_lost_packets_udp"] = iperf_download["end"]["sum"]["lost_packets"]

                        if "udp" in get_property_from(configuration, "modes"):
                            iperf_download = run_iperf(iperf_ip, iperf_port, download=False, protocol="udp")
                            results["upload_bits_udp"] = iperf_download["end"]["sum"]["bits_per_second"]
                            results["upload_bytes_udp"] = iperf_download["end"]["sum"]["bits_per_second"] / 8
                            results["upload_bytes_data_udp"] = iperf_download["end"]["sum"]["bytes"]
                            results["upload_time_udp"] = iperf_download["start"]["test_start"]["duration"]
                            results["upload_jitter_udp"] = iperf_download["end"]["sum"]["jitter_ms"]
                            results["upload_jitter_packets_udp"] = iperf_download["end"]["sum"]["packets"]
                            results["upload_jitter_lost_packets_udp"] = iperf_download["end"]["sum"]["lost_packets"]

                        if "speedtest" in get_property_from(configuration, "modes"):
                            speedtest_download = run_speedtest(speedtest_mode)
                            if speedtest_mode == SpeedTestMode.OOKLA:
                                results["speedtest_jitter"] = speedtest_download["ping"]["jitter"]
                                results["speedtest_latency"] = speedtest_download["ping"]["latency"]
                                results["speedtest_download_bandwidth"] = speedtest_download["download"]["bandwidth"]
                                results["speedtest_download_size"] = speedtest_download["download"]["bytes"]
                                results["speedtest_download_elapsed_ms"] = speedtest_download["download"]["elapsed"]
                                results["speedtest_upload_bandwidth"] = speedtest_download["upload"]["bandwidth"]
                                results["speedtest_upload_size"] = speedtest_download["upload"]["bytes"]
                                results["speedtest_upload_elapsed_ms"] = speedtest_download["upload"]["elapsed"]
                            elif speedtest_mode == SpeedTestMode.SIVEL:
                                results["speedtest_latency"] = speedtest_download["server"]["latency"]
                                results["speedtest_download_bandwidth"] = speedtest_download["download"] / 8
                                results["speedtest_download_size"] = speedtest_download["bytes_received"]
                                results["speedtest_upload_bandwidth"] = speedtest_download["upload"] / 8
                                results["speedtest_upload_size"] = speedtest_download["bytes_sent"]

                        results["signal_strength"] = iw["signal_strength"]
                        results["signal_quality"] = iw["signal_strength"] + 110
                        results["signal_quality_percent"] = (iw["signal_strength"] + 110) * (10 / 7)
                        results["channel"] = iw["channel"]
                        results["channel_frequency"] = iw["channel_frequency"]
                        benchmark_points[current_selection]["results"] = results

                        benchmark_points[current_selection]["fill_color"] = "lightblue"
                        benchmark_points, current_selection = replot(graph, benchmark_points)

                        print("Completed benchmark.")
                    except:
                        print("Unable to perform benchmark.")
                        sg.popup_error("Unable to perform benchmark.")
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

    window.close()

    if post_process:
        data = {
            "configuration": configuration,
            "results": benchmark_points
        }
        generate_graph(data, floor_map)


def contains(pt1, pt2):
    return ((pt1[0] - pt2[0]) ** 2 + (pt1[1] - pt2[1]) ** 2) <= 7 ** 2


def get_point(data, index):
    return (data[index]["position"]["x"], data[index]["position"]["y"])


def replot(graph, benchmark_points, clear=False):
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
    for itm in benchmark_points.keys():
        benchmark_points[itm]["selected"] = False
    return benchmark_points


def processed_results(benchmark_points):
    results = 0
    for itm in benchmark_points.keys():
        if benchmark_points[itm]["results"] is not None:
            results += 1
    return results


def get_img_data(f, maxsize=(1200, 850), first=False):
    """Generate image data using PIL
    """
    img = Image.open(f)
    img.thumbnail(maxsize)
    if first:
        bio = io.BytesIO()
        img.save(bio, format="PNG")
        del img
        return bio.getvalue()
    return ImageTk.PhotoImage(img)
