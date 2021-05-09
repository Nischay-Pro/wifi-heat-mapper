import PySimpleGUI as sg
import os.path
from wifi_heat_mapper.misc import run_iperf, processIW, load_json, save_json
from wifi_heat_mapper.graph import generate_graph
from PIL import Image


def start_gui(target_interface, floor_map, iperf_ip, iperf_port, ssid, input_file, output_file, configuration):

    right_click_items = ["Items", ["&Benchmark", "&Delete", "&Mark/Un-Mark as Station"]]

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
            right_click_menu=right_click_items)],
        [sg.Button("Exit"), output_path_index, sg.FileSaveAs(button_text="Save Results",
         file_types=(('JSON file', '*.json'),), default_extension="json", key="FileName"),
         sg.Button("Plot"), sg.Button("Clear All")]
    ]

    window = sg.Window("Wi-Fi heat mapper", layout, finalize=True)

    graph = window.Element("Floor Map")
    graph.DrawImage(filename=floor_map, location=(0, canvas_size[1]))

    benchmark_points = {}

    if input_file is not None and os.path.isfile(input_file):
        data = load_json(input_file)
        if data is not False:
            configuration = data["configuration"]
            benchmark_points = data["results"]
            benchmark_points, current_selection = replot(graph, benchmark_points)
            if configuration["ssid"] != ssid:
                print("Configuration file is for {} but user connected to {}"
                      .format(configuration["ssid"], ssid))
                print("Please connect to {} and try benchmarking again."
                      .format(configuration["ssid"]))
                exit(1)

    current_selection = None

    print("Ready for benchmarking.")

    configuration["ssid"] = ssid

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
                # benchmark_points, current_selection = replot(graph, benchmark_points)

        if event == "Benchmark":
            if current_selection is not None:
                # window["Status"].update("Benchmarking!")

                iw = processIW(target_interface)
                if iw["ssid"] != ssid:
                    sg.popup_error("SSID mismatch!")
                    print("SSID mismatch!")
                else:
                    print("Running benchmark")
                    results = {}
                    if "tcp_r" in configuration["modes"]:
                        iperf_download = run_iperf(iperf_ip, iperf_port, download=True, protocol="tcp")
                        results["download_bits_tcp"] = iperf_download["end"]["sum_received"]["bits_per_second"]
                        results["download_bytes_tcp"] = iperf_download["end"]["sum_received"]["bits_per_second"] / 8
                        results["download_bytes_data_tcp"] = iperf_download["end"]["sum_received"]["bytes"]
                        results["download_time_tcp"] = iperf_download["start"]["test_start"]["duration"]

                    if "tcp" in configuration["modes"]:
                        iperf_download = run_iperf(iperf_ip, iperf_port, download=False, protocol="tcp")
                        results["upload_bits_tcp"] = iperf_download["end"]["sum_sent"]["bits_per_second"]
                        results["upload_bytes_tcp"] = iperf_download["end"]["sum_sent"]["bits_per_second"] / 8
                        results["upload_bytes_data_tcp"] = iperf_download["end"]["sum_sent"]["bytes"]
                        results["upload_time_tcp"] = iperf_download["start"]["test_start"]["duration"]

                    if "udp_r" in configuration["modes"]:
                        iperf_download = run_iperf(iperf_ip, iperf_port, download=True, protocol="udp")
                        results["download_bits_udp"] = iperf_download["end"]["sum"]["bits_per_second"]
                        results["download_bytes_udp"] = iperf_download["end"]["sum"]["bits_per_second"] / 8
                        results["download_bytes_data_udp"] = iperf_download["end"]["sum"]["bytes"]
                        results["download_time_udp"] = iperf_download["start"]["test_start"]["duration"]
                        results["download_jitter_udp"] = iperf_download["end"]["sum"]["jitter_ms"]
                        results["download_jitter_packets_udp"] = iperf_download["end"]["sum"]["packets"]
                        results["download_jitter_lost_packets_udp"] = iperf_download["end"]["sum"]["lost_packets"]

                    if "udp" in configuration["modes"]:
                        iperf_download = run_iperf(iperf_ip, iperf_port, download=False, protocol="udp")
                        results["upload_bits_udp"] = iperf_download["end"]["sum"]["bits_per_second"]
                        results["upload_bytes_udp"] = iperf_download["end"]["sum"]["bits_per_second"] / 8
                        results["upload_bytes_data_udp"] = iperf_download["end"]["sum"]["bytes"]
                        results["upload_time_udp"] = iperf_download["start"]["test_start"]["duration"]
                        results["upload_jitter_udp"] = iperf_download["end"]["sum"]["jitter_ms"]
                        results["upload_jitter_packets_udp"] = iperf_download["end"]["sum"]["packets"]
                        results["upload_jitter_lost_packets_udp"] = iperf_download["end"]["sum"]["lost_packets"]

                    results["signal_strength"] = iw["signal_strength"]
                    results["signal_quality"] = iw["signal_strength"] + 110
                    results["signal_quality_percent"] = (iw["signal_strength"] + 110) * (10 / 7)
                    results["channel"] = iw["channel"]
                    results["channel_frequency"] = iw["channel_frequency"]
                    benchmark_points[current_selection]["results"] = results

                    benchmark_points[current_selection]["fill_color"] = "lightblue"
                    benchmark_points, current_selection = replot(graph, benchmark_points)

                    print("Completed benchmark.")
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
            if output_file:
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
            else:
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

        if event == "Plot":
            if len(benchmark_points.keys()) >= 4:
                post_process = True
                print("Exporting Results")
                break
            else:
                sg.popup_error("Not enough benchmark points! Try benchmarking {} more."
                               .format(4 - len(benchmark_points.keys())))

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
