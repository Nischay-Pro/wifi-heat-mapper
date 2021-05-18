from wifi_heat_mapper.config import ConfigurationOptions
from wifi_heat_mapper.misc import load_json, get_property_from, bytes_to_human_readable
from wifi_heat_mapper.debugger import log_arguments
from PIL import Image
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.pyplot import imread
from scipy.interpolate import Rbf
from tqdm import tqdm
import os
import heapq
import logging


class MissingMetricError(Exception):
    pass


class GraphPlot:
    def __init__(self, results, key, floor_map, vmin=None, vmax=None, conversion=False, reverse=False):
        self.results = results
        self.floor_map = floor_map
        self.vmin = vmin
        self.vmax = vmax
        self.key = key
        self.processed_results = None
        self.floor_map_dimensions = None
        self.conversion = conversion
        self.suffix = None
        self.reverse = reverse

    def process_result(self):
        """Process the results captured for a metric. """
        processed_results = {"x": [], "y": [], "z": [], "sx": [], "sy": []}
        for result in self.results.keys():
            if self.results[result]["results"] is not None:
                processed_results["x"].append(self.results[result]["position"]["x"])
                processed_results["y"].append(self.results[result]["position"]["y"])
                try:
                    processed_results["z"].append(self.results[result]["results"][self.key])
                except KeyError:
                    raise MissingMetricError("Missing Metric {0}".format(self.key)) from None
                if self.results[result]["station"]:
                    processed_results["sx"].append(self.results[result]["position"]["x"])
                    processed_results["sy"].append(self.results[result]["position"]["y"])
        self.processed_results = processed_results

    def add_zero_boundary(self):
        """Add 4 zero (vmin or vmax) benchmark points. """
        self.processed_results["x"] += [0, 0, self.floor_map_dimensions[0],
                                        self.floor_map_dimensions[0]]
        self.processed_results["y"] += [0, self.floor_map_dimensions[1],
                                        self.floor_map_dimensions[1], 0]
        self.set_min_max()
        if self.reverse:
            self.processed_results["z"] += [self.vmax] * 4
        else:
            self.processed_results["z"] += [self.vmin] * 4

    def set_floor_map_dimensions(self):
        """Set the floor map dimensions (x, y) from image. """
        im = Image.open(self.floor_map)
        xmax, ymax = im.size
        self.floor_map_dimensions = (xmax, ymax)

    def set_min_max(self):
        if self.vmin is None:
            self.vmin = min(self.processed_results["z"])
        if self.vmax is None:
            self.vmax = max(self.processed_results["z"])

    def apply_conversion(self):
        """If metric is of type bandwidth apply byte to human
        readable size formula. """
        smallest_values = heapq.nsmallest(2, set(self.processed_results["z"]))
        smallest_value = smallest_values[0]
        if self.vmin == smallest_values[0] == 0:
            smallest_value = smallest_values[1]

        limit = bytes_to_human_readable(smallest_value, 2, None)
        if "bits" in self.key:
            if "Byte" in limit[2]:
                self.suffix = limit[2].replace("Byte", "Bit")
            else:
                self.suffix = limit[2].replace("B", "b")
        else:
            self.suffix = limit[2]
        factor = limit[1]
        self.processed_results["z"] = [z_val / factor for z_val in self.processed_results["z"]]
        self.vmin /= factor
        self.vmax /= factor

    def generate_plot(self, levels, dpi, file_type):
        """Generate heatmap plot from resultant metrics.
        Args:
            levels (int): number of countour levels.
            dpi (int): Dots Per Inch resolution for
            certain image types such as png.
            file_type (str): Plot save file type.

        Returns:
            None
        """
        self.process_result()
        self.set_floor_map_dimensions()
        self.add_zero_boundary()
        if self.conversion:
            self.apply_conversion()

        minimum = 0
        maximum = max(self.floor_map_dimensions)

        xi = np.linspace(minimum, maximum, 100)
        yi = np.linspace(minimum, maximum, 100)

        xi, yi = np.meshgrid(xi, yi)
        di = Rbf(self.processed_results["x"], self.processed_results["y"],
                 self.processed_results["z"], function="linear")
        zi = di(xi, yi)
        zi[zi < self.vmin] = self.vmin
        zi[zi > self.vmax] = self.vmax

        fig, ax = plt.subplots(1, 1)

        bench_plot = ax.contourf(xi, yi, zi, cmap="RdYlBu_r", vmin=self.vmin, vmax=self.vmax,
                                 alpha=0.5, zorder=150, antialiased=True, levels=levels)

        ax.plot(self.processed_results["x"], self.processed_results["y"], zorder=200, marker='o',
                markeredgecolor='black', markeredgewidth=0.5, linestyle='None', markersize=5,
                label="Benchmark Point")

        ax.plot(self.processed_results["sx"], self.processed_results["sy"], zorder=250, marker='o',
                markeredgecolor='black', markerfacecolor="orange", markeredgewidth=0.5,
                linestyle='None', markersize=5, label="Base Station")

        ax.imshow(imread(self.floor_map)[::-1], interpolation='bicubic', zorder=1, alpha=1,
                  origin="lower")

        fig.colorbar(bench_plot)
        desc = ConfigurationOptions.configuration[self.key]["description"]
        if self.suffix is not None:
            desc = desc.format(self.suffix)
        plt.title("{0}".format(desc))
        plt.axis('off')
        plt.legend(bbox_to_anchor=(0.55, -0.05), ncol=2)
        file_name = "{0}.{1}".format(self.key, file_type)
        plt.savefig(file_name, format=file_type, dpi=dpi)


@log_arguments
def generate_graph(data, floor_map, levels=100, dpi=300, file_type="png"):
    """Starting point for the plot submodule for whm.

    Args:
        data (str): the path to the configuration file.
        floor_map (str): the path to the floor map.
        levels (int): number of countour levels.
        dpi (int): Dots Per Inch resolution for
        certain image types such as png.
        file_type (str): Plot save file type.

    Returns:
        None
    """
    file_type = file_type.lower().replace(".", "")
    supported_formats = ["png", "pdf", "ps", "eps", "svg"]
    if file_type not in supported_formats:
        print("Unsupported file type.")
        exit(1)

    if not isinstance(data, dict):
        data = os.path.abspath(data)
        data = load_json(data)
        if not data:
            print("Could not load configuration file.")
            exit(1)
    benchmark_results = get_property_from(data, "results")
    configuration = get_property_from(data, "configuration")
    graph_modes = ConfigurationOptions.configuration
    for key_name in tqdm(configuration["graphs"], desc="Generating Plots"):
        vmin = None
        vmax = None
        if "vmin" in graph_modes[key_name]:
            vmin = graph_modes[key_name]["vmin"]
        if "vmax" in graph_modes[key_name]:
            vmax = graph_modes[key_name]["vmax"]
        logging.debug("Generating plot for {0} with (vmin, vmax) = ({1}, {2})".format(key_name, vmin, vmax))
        GraphPlot(benchmark_results, key_name, floor_map, vmin=vmin, vmax=vmax,
                  conversion=graph_modes[key_name]["conversion"],
                  reverse=graph_modes[key_name]["reverse"])\
            .generate_plot(levels=levels, dpi=dpi, file_type=file_type)
        logging.debug("Finished generating plot")
    print("Finished plotting.")
    logging.debug("Finished plotting")
