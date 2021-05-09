from PIL import Image
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import cm
from matplotlib.pyplot import imread
from PIL import Image
from scipy.interpolate import griddata, Rbf
from wifi_heat_mapper.config import ConfigurationOptions
from tqdm import tqdm

class GraphPlot:
    def __init__(self, results, key, floor_map, vmin = None, vmax = None):
        self.results = results
        self.floor_map = floor_map
        self.vmin = vmin
        self.vmax = vmax
        self.key = key
        self.processed_results = None
        self.floor_map_dimensions = None

    def process_result(self):
        processed_results = { "x": [], "y": [], "z": [] , "sx": [], "sy": []}
        for result in self.results.keys():
            processed_results["x"].append(self.results[result]["position"]["x"])
            processed_results["y"].append(self.results[result]["position"]["y"])
            processed_results["z"].append(self.results[result]["results"][self.key])
            if self.results[result]["station"]:
                processed_results["sx"].append(self.results[result]["position"]["x"])
                processed_results["sy"].append(self.results[result]["position"]["y"])
        self.processed_results = processed_results

    def add_zero_boundary(self):
        self.processed_results["x"] += [0, 0, self.floor_map_dimensions[0], self.floor_map_dimensions[0]]
        self.processed_results["y"] += [0, self.floor_map_dimensions[1], self.floor_map_dimensions[1], 0]
        self.set_min_max()
        self.processed_results["z"] += [self.vmin] * 4

    def set_floor_map_dimensions(self):
        im = Image.open(self.floor_map)
        xmax, ymax = im.size
        self.floor_map_dimensions = (xmax, ymax)

    def set_min_max(self):
        if self.vmin == None or self.vmax == None:
            self.vmin = min(self.processed_results["z"])
            self.vmax = max(self.processed_results["z"])
        
    def generate_plot(self):
        self.process_result()
        self.set_floor_map_dimensions()
        self.add_zero_boundary()
        
        minimum = 0
        maximum = max(self.floor_map_dimensions)

        xi = np.linspace(minimum, maximum, 100)
        yi = np.linspace(minimum, maximum, 100)

        xi, yi = np.meshgrid(xi, yi)
        di = Rbf(self.processed_results["x"], self.processed_results["y"], self.processed_results["z"], function="linear")
        zi = di(xi, yi)


        fig, ax=plt.subplots(1,1)
        bench_plot = ax.contourf(xi, yi, zi, cmap="RdYlBu_r", vmin=self.vmin, vmax=self.vmax, alpha=0.5, zorder=150, antialiased=True)
        ax.plot(self.processed_results["x"], self.processed_results["y"], zorder=200, marker='o', markeredgecolor='black', markeredgewidth=1, linestyle='None', markersize=10, label="Benchmark Point")
        ax.plot(self.processed_results["sx"], self.processed_results["sy"], zorder=250, marker='o', markeredgecolor='black', markerfacecolor="orange", markeredgewidth=1, linestyle='None', markersize=10, label="Base Station")
        ax.imshow(imread(self.floor_map)[::-1], interpolation='bicubic', zorder=1, alpha=1, origin="lower")
        fig.colorbar(bench_plot)
        plt.title("{}".format(ConfigurationOptions.configuration[self.key]["description"]))
        plt.axis('off')
        plt.legend(bbox_to_anchor=(0.3, -0.02))
        file_name = "{}.png".format(self.key)
        plt.savefig(file_name, dpi=300)
        # plt.show()
        

def generate_graph(data, floor_map):
    benchmark_results = data["results"]
    configuration = data["configuration"]
    graph_modes = ConfigurationOptions.configuration
    for key_name in tqdm(configuration["graphs"], desc="Generating Plots"):
        vmin = None
        vmax = None
        if "vmin" in graph_modes[key_name]:
            vmin = graph_modes[key_name]["vmin"]
        if "vmax" in graph_modes[key_name]:
            vmax = graph_modes[key_name]["vmax"]
        GraphPlot(benchmark_results, key_name, floor_map, vmin=vmin, vmax=vmax).generate_plot()
    print("Finished plotting")